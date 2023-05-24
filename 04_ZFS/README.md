# Установка ZFS.

```
[root@localhost ~]# yum install -y yum-utils
[root@localhost ~]# yum -y install http://download.zfsonlinux.org/epel/zfs-release.el7_8.noarch.rpm
[root@localhost ~]# gpg --quiet --with-fingerprint /etc/pki/rpm-gpg/RPM-GPG-KEY-zfsonlinux
[root@localhost ~]# yum-config-manager --enable zfs-kmod
[root@localhost ~]# yum-config-manager --disable zfs
[root@localhost ~]# yum install -y zfs
```

> Проверим, загружен ли модуль zfs, есл инет, загрузим его:
```
[root@localhost ~]# lsmod | grep zfs
[root@localhost ~]# modprobe zfs
[root@localhost ~]# lsmod | grep zfs
zfs                  3986816  0 
zunicode              331170  1 zfs
zlua                  151525  1 zfs
zcommon                89551  1 zfs
znvpair                94388  2 zfs,zcommon
zavl                   15167  1 zfs
icp                   301854  1 zfs
spl                   104299  5 icp,zfs,zavl,zcommon,znvpair
```

> Смотрим список всех дисков, которые есть в виртуальной машине:

```
[root@localhost ~]# lsblk
NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda      8:0    0   40G  0 disk 
`-sda1   8:1    0   40G  0 part /
sdb      8:16   0  512M  0 disk 
sdc      8:32   0  512M  0 disk 
sdd      8:48   0  512M  0 disk 
sde      8:64   0  512M  0 disk 
sdf      8:80   0  512M  0 disk 
sdg      8:96   0  512M  0 disk 
sdh      8:112  0  512M  0 disk 
sdi      8:128  0  512M  0 disk 
```

> Создаём пул из двух дисков в режиме RAID 1:
> Создадим ещё 3 пула:

```
[root@localhost ~]# zpool create otus1 mirror /dev/sdb /dev/sdc
[root@localhost ~]# zpool create otus2 mirror /dev/sdd /dev/sde
[root@localhost ~]# zpool create otus3 mirror /dev/sdf /dev/sdg
[root@localhost ~]# zpool create otus4 mirror /dev/sdh /dev/sdi
```

> Смотрим информацию о пулах:

``` 
[root@localhost ~]# zpool list
NAME    SIZE  ALLOC   FREE  CKPOINT  EXPANDSZ   FRAG    CAP  DEDUP    HEALTH  ALTROOT
otus1   480M  91.5K   480M        -         -     0%     0%  1.00x    ONLINE  -
otus2   480M  91.5K   480M        -         -     0%     0%  1.00x    ONLINE  -
otus3   480M   106K   480M        -         -     0%     0%  1.00x    ONLINE  -
otus4   480M  91.5K   480M        -         -     0%     0%  1.00x    ONLINE  -
```

# 1. Определить алгоритм с наилучшим сжатием (gzip-9, zle, lzjb, lz4).

> Добавим разные алгоритмы сжатия в каждую файловую систему:

```
[root@localhost ~]# zfs set compression=lzjb otus1  
[root@localhost ~]# zfs set compression=lz4 otus2
[root@localhost ~]# zfs set compression=gzip-9 otus3
[root@localhost ~]# zfs set compression=zle otus4
```
> Проверим, что все файловые системы имеют разные методы сжатия:

```
[root@localhost ~]# zfs get all | grep compression
otus1  compression           lzjb                   local
otus2  compression           lz4                    local
otus3  compression           gzip-9                 local
otus4  compression           zle                    local
```

> Скачаем один и тот же текстовый файл во все пулы:

```
[root@localhost ~]# for i in {1..4}; do wget -P /otus$i https://gutenberg.org/cache/epub/2600/pg2600.converter.log; done
```
> Проверим, что файл был скачан во все пулы: 

```
[root@localhost ~]# ls -l /otus*
/otus1:
total 22049
-rw-r--r--. 1 root root 40931771 May  2 08:18 pg2600.converter.log

/otus2:
total 17986
-rw-r--r--. 1 root root 40931771 May  2 08:18 pg2600.converter.log

/otus3:
total 10955
-rw-r--r--. 1 root root 40931771 May  2 08:18 pg2600.converter.log

/otus4:
total 40000
-rw-r--r--. 1 root root 40931771 May  2 08:18 pg2600.converter.log
```

> Уже на этом этапе видно, что самый оптимальный метод сжатия у нас используется в пуле otus3.

> Проверим, сколько места занимает один и тот же файл в разных пулах и проверим степень сжатия файлов:

```
[root@localhost ~]# zfs list
NAME    USED  AVAIL     REFER  MOUNTPOINT
otus1  21.6M   330M     21.6M  /otus1
otus2  17.7M   334M     17.6M  /otus2
otus3  10.8M   341M     10.7M  /otus3
otus4  39.2M   313M     39.1M  /otus4

[root@localhost ~]# zfs get all | grep compressratio | grep -v ref
otus1  compressratio         1.81x                  -
otus2  compressratio         2.22x                  -
otus3  compressratio         3.65x                  -
otus4  compressratio         1.00x                  -
```

> Таким образом, у нас получается, что алгоритм gzip-9 самый эффективный по сжатию. 

# 2. Определение настроек пула.

> Скачиваем архив в домашний каталог:

```
[root@localhost ~]# wget -O archive.tar.gz --no-check-certificate 'https://drive.google.com/u/0/uc?id=1KRBNW33QWqbvbVHa3hLJivOAt60yukkg&export=download&confirm=t&uuid=3b77f7de-8d9a-4465-a4b3-ab17576d96fa&at=AKKF8vy8o15FSfARgn34dPdujNWQ:1684919321480'
--2023-05-24 09:13:09--  https://drive.google.com/u/0/uc?id=1KRBNW33QWqbvbVHa3hLJivOAt60yukkg&export=download&confirm=t&uuid=3b77f7de-8d9a-4465-a4b3-ab17576d96fa&at=AKKF8vy8o15FSfARgn34dPdujNWQ:1684919321480
Resolving drive.google.com (drive.google.com)... 172.217.168.206, 2a00:1450:400e:80c::200e
Connecting to drive.google.com (drive.google.com)|172.217.168.206|:443... connected.
HTTP request sent, awaiting response... 302 Found
Location: https://drive.google.com/uc?id=1KRBNW33QWqbvbVHa3hLJivOAt60yukkg&export=download&confirm=t&uuid=3b77f7de-8d9a-4465-a4b3-ab17576d96fa&at=AKKF8vy8o15FSfARgn34dPdujNWQ:1684919321480 [following]
--2023-05-24 09:13:10--  https://drive.google.com/uc?id=1KRBNW33QWqbvbVHa3hLJivOAt60yukkg&export=download&confirm=t&uuid=3b77f7de-8d9a-4465-a4b3-ab17576d96fa&at=AKKF8vy8o15FSfARgn34dPdujNWQ:1684919321480
Reusing existing connection to drive.google.com:443.
HTTP request sent, awaiting response... 303 See Other
Location: https://doc-0c-bo-docs.googleusercontent.com/docs/securesc/ha0ro937gcuc7l7deffksulhg5h7mbp1/e7op6kondfqlopjb19eaht76j6l6jbp4/1684919550000/16189157874053420687/*/1KRBNW33QWqbvbVHa3hLJivOAt60yukkg?e=download&uuid=3b77f7de-8d9a-4465-a4b3-ab17576d96fa [following]
Warning: wildcards not supported in HTTP.
--2023-05-24 09:13:18--  https://doc-0c-bo-docs.googleusercontent.com/docs/securesc/ha0ro937gcuc7l7deffksulhg5h7mbp1/e7op6kondfqlopjb19eaht76j6l6jbp4/1684919550000/16189157874053420687/*/1KRBNW33QWqbvbVHa3hLJivOAt60yukkg?e=download&uuid=3b77f7de-8d9a-4465-a4b3-ab17576d96fa
Resolving doc-0c-bo-docs.googleusercontent.com (doc-0c-bo-docs.googleusercontent.com)... 142.250.179.129, 2a00:1450:400e:801::2001
Connecting to doc-0c-bo-docs.googleusercontent.com (doc-0c-bo-docs.googleusercontent.com)|142.250.179.129|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 7275140 (6.9M) [application/x-gzip]
Saving to: 'archive.tar.gz'

100%[=================================================================================================================================================>] 7,275,140   1.09MB/s   in 6.4s   

2023-05-24 09:13:24 (1.09 MB/s) - 'archive.tar.gz' saved [7275140/7275140]
```

> Разархивируем его:
```
[root@localhost ~]# tar -xzvf archive.tar.gz
zpoolexport/
zpoolexport/filea
zpoolexport/fileb
```

> Проверим, возможно ли импортировать данный каталог в пул:

```
[root@localhost ~]# zpool import -d zpoolexport/
   pool: otus
     id: 6554193320433390805
  state: ONLINE
 action: The pool can be imported using its name or numeric identifier.
 config:

        otus                         ONLINE
          mirror-0                   ONLINE
            /root/zpoolexport/filea  ONLINE
            /root/zpoolexport/fileb  ONLINE
```
> Данный вывод показывает нам имя пула, тип raid и его состав. 

> Сделаем импорт данного пула к нам в ОС:

```
[root@localhost ~]# zpool import -d zpoolexport/ otus
[root@localhost ~]# zpool status
  pool: otus
 state: ONLINE
  scan: none requested
config:

        NAME                         STATE     READ WRITE CKSUM
        otus                         ONLINE       0     0     0
          mirror-0                   ONLINE       0     0     0
            /root/zpoolexport/filea  ONLINE       0     0     0
            /root/zpoolexport/fileb  ONLINE       0     0     0

errors: No known data errors

  pool: otus1
 state: ONLINE
  scan: none requested
config:

        NAME        STATE     READ WRITE CKSUM
        otus1       ONLINE       0     0     0
          mirror-0  ONLINE       0     0     0
            sdb     ONLINE       0     0     0
            sdc     ONLINE       0     0     0

errors: No known data errors

  pool: otus2
 state: ONLINE
  scan: none requested
config:

        NAME        STATE     READ WRITE CKSUM
        otus2       ONLINE       0     0     0
          mirror-0  ONLINE       0     0     0
            sdd     ONLINE       0     0     0
            sde     ONLINE       0     0     0

errors: No known data errors

  pool: otus3
 state: ONLINE
  scan: none requested
config:

        NAME        STATE     READ WRITE CKSUM
        otus3       ONLINE       0     0     0
          mirror-0  ONLINE       0     0     0
            sdf     ONLINE       0     0     0
            sdg     ONLINE       0     0     0

errors: No known data errors

  pool: otus4
 state: ONLINE
  scan: none requested
config:

        NAME        STATE     READ WRITE CKSUM
        otus4       ONLINE       0     0     0
          mirror-0  ONLINE       0     0     0
            sdh     ONLINE       0     0     0
            sdi     ONLINE       0     0     0

errors: No known data errors
```

> Команда zpool status выдаст нам информацию о составе импортированного пула

> Далее нам нужно определить настройки
> Запрос сразу всех параметром файловой системы: zfs get all otus

```
[root@localhost ~]# zfs get all otus
NAME  PROPERTY              VALUE                  SOURCE
otus  type                  filesystem             -
otus  creation              Fri May 15  4:00 2020  -
otus  used                  2.04M                  -
otus  available             350M                   -
otus  referenced            24K                    -
otus  compressratio         1.00x                  -
otus  mounted               yes                    -
otus  quota                 none                   default
otus  reservation           none                   default
otus  recordsize            128K                   local
otus  mountpoint            /otus                  default
otus  sharenfs              off                    default
otus  checksum              sha256                 local
otus  compression           zle                    local
otus  atime                 on                     default
otus  devices               on                     default
otus  exec                  on                     default
otus  setuid                on                     default
otus  readonly              off                    default
otus  zoned                 off                    default
otus  snapdir               hidden                 default
otus  aclinherit            restricted             default
otus  createtxg             1                      -
otus  canmount              on                     default
otus  xattr                 on                     default
otus  copies                1                      default
otus  version               5                      -
otus  utf8only              off                    -
otus  normalization         none                   -
otus  casesensitivity       sensitive              -
otus  vscan                 off                    default
otus  nbmand                off                    default
otus  sharesmb              off                    default
otus  refquota              none                   default
otus  refreservation        none                   default
otus  guid                  14592242904030363272   -
otus  primarycache          all                    default
otus  secondarycache        all                    default
otus  usedbysnapshots       0B                     -
otus  usedbydataset         24K                    -
otus  usedbychildren        2.01M                  -
otus  usedbyrefreservation  0B                     -
otus  logbias               latency                default
otus  objsetid              54                     -
otus  dedup                 off                    default
otus  mlslabel              none                   default
otus  sync                  standard               default
otus  dnodesize             legacy                 default
otus  refcompressratio      1.00x                  -
otus  written               24K                    -
otus  logicalused           1020K                  -
otus  logicalreferenced     12K                    -
otus  volmode               default                default
otus  filesystem_limit      none                   default
otus  snapshot_limit        none                   default
otus  filesystem_count      none                   default
otus  snapshot_count        none                   default
otus  snapdev               hidden                 default
otus  acltype               off                    default
otus  context               none                   default
otus  fscontext             none                   default
otus  defcontext            none                   default
otus  rootcontext           none                   default
otus  relatime              off                    default
otus  redundant_metadata    all                    default
otus  overlay               off                    default
otus  encryption            off                    default
otus  keylocation           none                   default
otus  keyformat             none                   default
otus  pbkdf2iters           0                      default
otus  special_small_blocks  0                      default
```
> C помощью команды get можно уточнить конкретный параметр, например:
> Размер: zfs get available otus

```
[root@localhost ~]# zfs get available otus
NAME  PROPERTY   VALUE  SOURCE
otus  available  350M   -
```
> Тип: zfs get readonly otus

```
[root@localhost ~]# zfs get readonly otus
NAME  PROPERTY  VALUE   SOURCE
otus  readonly  off     default
```
> По типу FS мы можем понять, что позволяет выполнять чтение и запись

> Значение recordsize: zfs get recordsize otus

```
[root@localhost ~]# zfs get recordsize otus
NAME  PROPERTY    VALUE    SOURCE
otus  recordsize  128K     local
```
> Тип сжатия (или параметр отключения): zfs get compression otus

```
[root@localhost ~]# zfs get compression otus
NAME  PROPERTY     VALUE     SOURCE
otus  compression  zle       local
```

> Тип контрольной суммы: zfs get checksum otus

```
[root@localhost ~]# zfs get checksum otus
NAME  PROPERTY  VALUE      SOURCE
otus  checksum  sha256     local
```

# 3. Работа со снапшотом, поиск сообщения от преподавателя

> Скачаем файл, указанный в задании:

```
[root@localhost ~]# wget -O otus_task2.file --no-check-certificate "https://drive.google.com/u/0/uc?id=1gH8gCL9y7Nd5Ti3IRmplZPF1XjzxeRAG&export=download"
--2023-05-24 09:24:43--  https://drive.google.com/u/0/uc?id=1gH8gCL9y7Nd5Ti3IRmplZPF1XjzxeRAG&export=download
Resolving drive.google.com (drive.google.com)... 172.217.168.206, 2a00:1450:400e:80c::200e
Connecting to drive.google.com (drive.google.com)|172.217.168.206|:443... connected.
HTTP request sent, awaiting response... 302 Found
Location: https://drive.google.com/uc?id=1gH8gCL9y7Nd5Ti3IRmplZPF1XjzxeRAG&export=download [following]
--2023-05-24 09:24:43--  https://drive.google.com/uc?id=1gH8gCL9y7Nd5Ti3IRmplZPF1XjzxeRAG&export=download
Reusing existing connection to drive.google.com:443.
HTTP request sent, awaiting response... 303 See Other
Location: https://doc-00-bo-docs.googleusercontent.com/docs/securesc/ha0ro937gcuc7l7deffksulhg5h7mbp1/nsdj66uq5tls41sk29cg7nrqn0u8js2a/1684920225000/16189157874053420687/*/1gH8gCL9y7Nd5Ti3IRmplZPF1XjzxeRAG?e=download&uuid=9f5ec445-5f21-4b40-b65a-c7308a928879 [following]
Warning: wildcards not supported in HTTP.
--2023-05-24 09:24:47--  https://doc-00-bo-docs.googleusercontent.com/docs/securesc/ha0ro937gcuc7l7deffksulhg5h7mbp1/nsdj66uq5tls41sk29cg7nrqn0u8js2a/1684920225000/16189157874053420687/*/1gH8gCL9y7Nd5Ti3IRmplZPF1XjzxeRAG?e=download&uuid=9f5ec445-5f21-4b40-b65a-c7308a928879
Resolving doc-00-bo-docs.googleusercontent.com (doc-00-bo-docs.googleusercontent.com)... 142.250.179.129, 2a00:1450:400e:801::2001
Connecting to doc-00-bo-docs.googleusercontent.com (doc-00-bo-docs.googleusercontent.com)|142.250.179.129|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 5432736 (5.2M) [application/octet-stream]
Saving to: 'otus_task2.file'

100%[=================================================================================================================================================>] 5,432,736    986KB/s   in 5.2s   

2023-05-24 09:24:52 (1018 KB/s) - 'otus_task2.file' saved [5432736/5432736]
```

> Восстановим файловую систему из снапшота:
```
[root@localhost ~]# zfs receive otus/test@today < otus_task2.file
[root@localhost ~]# zfs list
NAME             USED  AVAIL     REFER  MOUNTPOINT
otus            4.93M   347M       25K  /otus
otus/hometask2  1.88M   347M     1.88M  /otus/hometask2
otus/test       2.83M   347M     2.83M  /otus/test
otus1           21.6M   330M     21.6M  /otus1
otus2           17.7M   334M     17.6M  /otus2
otus3           10.8M   341M     10.7M  /otus3
otus4           39.2M   313M     39.1M  /otus4
```
> Далее, ищем в каталоге /otus/test файл с именем “secret_message”:

```
[root@localhost ~]# find /otus/test -name "secret_message"
/otus/test/task1/file_mess/secret_message
```
> Смотрим содержимое найденного файла:
```
[root@localhost ~]# cat /otus/test/task1/file_mess/secret_message
https://github.com/sindresorhus/awesome
```
> Тут мы видим ссылку на GitHub, можем скопировать её в адресную строку и посмотреть репозиторий.
> https://github.com/sindresorhus/awesome





