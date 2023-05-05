Задание 1. Добавить в Vagrantfile еще дисков. Сломать/починить raid. Собрать R0/R5/R10 на выбор. Прописать собранный рейд в конф, чтобы рейд собирался при загрузке. Создать GPT раздел и 5 партиций.

Выведем список дисков, подключенных к ВМ:
[vagrant@localhost ~]$ sudo lshw -short | grep disk
/0/100/1.1/0.0.0    /dev/sda   disk        42GB VBOX HARDDISK
/0/100/d/0          /dev/sdb   disk        262MB VBOX HARDDISK
/0/100/d/1          /dev/sdc   disk        262MB VBOX HARDDISK
/0/100/d/2          /dev/sdd   disk        262MB VBOX HARDDISK
/0/100/d/3          /dev/sde   disk        262MB VBOX HARDDISK
/0/100/d/4          /dev/sdf   disk        262MB VBOX HARDDISK
/0/100/d/5          /dev/sdg   disk        262MB VBOX HARDDISK


Перед сборкой рейда занулим суперблоки:

[vagrant@localhost ~]$ mdadm --zero-superblock --force /dev/sd{b,c,d,e,f}

Создадим RAID 10:
[vagrant@localhost ~]$ sudo mdadm --create --verbose /dev/md0 -l 10 -n 4 /dev/sd{b,c,d,e}
mdadm: layout defaults to n2
mdadm: layout defaults to n2
mdadm: chunk size defaults to 512K
mdadm: size set to 253952K
mdadm: Fail to create md0 when using /sys/module/md_mod/parameters/new_array, fallback to creation via node
mdadm: Defaulting to version 1.2 metadata
mdadm: array /dev/md0 started.


Проверим, что рейд собрался нормально:

[vagrant@localhost ~]$ cat /proc/mdstat
Personalities : [raid10] 
md0 : active raid10 sde[3] sdd[2] sdc[1] sdb[0]
      507904 blocks super 1.2 512K chunks 2 near-copies [4/4] [UUUU]
[vagrant@localhost ~]$ sudo mdadm -D /dev/md0 
/dev/md0:
           Version : 1.2
     Creation Time : Fri May  5 08:08:21 2023
        Raid Level : raid10
        Array Size : 507904 (496.00 MiB 520.09 MB)
     Used Dev Size : 253952 (248.00 MiB 260.05 MB)
      Raid Devices : 4
     Total Devices : 4
       Persistence : Superblock is persistent

       Update Time : Fri May  5 08:08:24 2023
             State : clean 
    Active Devices : 4
   Working Devices : 4
    Failed Devices : 0
     Spare Devices : 0

            Layout : near=2
        Chunk Size : 512K

Consistency Policy : resync

              Name : otuslinux:0  (local to host otuslinux)
              UUID : 77e35852:8da4251a:8e5f5006:0c7c11b5
            Events : 17

    Number   Major   Minor   RaidDevice State
       0       8       16        0      active sync set-A   /dev/sdb
       1       8       32        1      active sync set-B   /dev/sdc
       2       8       48        2      active sync set-A   /dev/sdd
       3       8       64        3      active sync set-B   /dev/sde


Полный вывод можно посмотреть тут:

https://gist.github.com/lalbrekht/05a750161f63a2f892b5c314a58ff28b


Создание конфигурационного файла mdadm.conf

Для того, чтобы быть уверенным, что ОС запомнила, какой RAID массив требуется создать и какие компоненты в него входят, создадим файл mdadm.conf

Сначала убедимся, что информация верна:

[vagrant@localhost ~]$ sudo mdadm --detail --scan --verbose
ARRAY /dev/md0 level=raid10 num-devices=4 metadata=1.2 name=otuslinux:0 UUID=77e35852:8da4251a:8e5f5006:0c7c11b5
   devices=/dev/sdb,/dev/sdc,/dev/sdd,/dev/sde

Создадим файл mdadm.conf и помести в него нужную информацию:

[vagrant@localhost ~]$ echo "DEVICE partitions" | sudo tee -a /etc/mdadm.conf
[vagrant@localhost ~]$ sudo mdadm --detail --scan --verbose | awk '/ARRAY/ {print}' | sudo tee -a /etc/mdadm.conf
ARRAY /dev/md0 level=raid10 num-devices=4 metadata=1.2 name=otuslinux:0 UUID=77e35852:8da4251a:8e5f5006:0c7c11b5

Сломаем рейд, пометив один из дисков как неисправный:

[vagrant@localhost ~]$ sudo mdadm /dev/md0 --fail /dev/sdc
mdadm: set /dev/sdc faulty in /dev/md0

Посмотрим, как это отразилось на RAID:

[vagrant@localhost ~]$ cat /proc/mdstat
Personalities : [raid10] 
md0 : active raid10 sde[3] sdd[2] sdc[1](F) sdb[0]
      507904 blocks super 1.2 512K chunks 2 near-copies [4/3] [U_UU]

[vagrant@localhost ~]$ sudo mdadm -D /dev/md0
    Number   Major   Minor   RaidDevice State
       0       8       16        0      active sync set-A   /dev/sdb
       -       0        0        1      removed
       2       8       48        2      active sync set-A   /dev/sdd
       3       8       64        3      active sync set-B   /dev/sde

       1       8       32        -      faulty   /dev/sdc 


Заменим отказавший диск в рейд другим диском:
[vagrant@localhost ~]$ sudo mdadm /dev/md0 --remove /dev/sdc
mdadm: hot removed /dev/sdc from /dev/md0

[vagrant@localhost ~]$ sudo mdadm /dev/md0 --add /dev/sdf
mdadm: added /dev/sdf

Диск должен пройти стадию rebuilding. Например, если это был RAID 1 (зеркало), то данные должны скопироваться на новый диск.

Процесс rebuild-а можно увидеть в выводе следующих команд:

[vagrant@localhost ~]$ cat /proc/mdstat
Personalities : [raid10] 
md0 : active raid10 sdf[4] sde[3] sdd[2] sdb[0]
      507904 blocks super 1.2 512K chunks 2 near-copies [4/4] [UUUU]

[vagrant@localhost ~]$ sudo mdadm -D /dev/md0
    Number   Major   Minor   RaidDevice State
       0       8       16        0      active sync set-A   /dev/sdb
       4       8       80        1      active sync set-B   /dev/sdf
       2       8       48        2      active sync set-A   /dev/sdd
       3       8       64        3      active sync set-B   /dev/sde


Создать GPT раздел, пять партиций и смонтировать их на диск

[vagrant@localhost ~]$ sudo parted -s /dev/md0 mklabel gpt 


Создадим партиции:

[vagrant@localhost ~]$ sudo parted /dev/md0 mkpart primary ext4 0% 20%
[vagrant@localhost ~]$ sudo parted /dev/md0 mkpart primary ext4 40% 60% 
[vagrant@localhost ~]$ sudo parted /dev/md0 mkpart primary ext4 60% 80% 
[vagrant@localhost ~]$ sudo parted /dev/md0 mkpart primary ext4 80% 100%

Далее создаем на этих партициях файловую систему:

[vagrant@localhost ~]$ for i in $(seq 1 5); do sudo mkfs.ext4 /dev/md0p$i; done

Смонтируем полученные файловые системы по каталогам:

[vagrant@localhost ~]$ sudo mkdir -p /raid/part{1,2,3,4,5}
[vagrant@localhost ~]$ for i in $(seq 1 5); do sudo mount /dev/md0p$i /raid/part$i; done