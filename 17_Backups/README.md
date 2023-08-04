# Задание 

> Настроить стенд Vagrant с двумя виртуальными машинами server и backup.

> Настроить политику бэкапа директории /etc с клиента (server) на бекап сервер (backup):

# Выполнение задания

# Установка borgbackup на обоих хостах

> Подключаем EPEL репозиторий с дополнительными пакетами yum install epel-release

> Устанавливаем на server и backup сервере borgbackup yum install borgbackup

> На хосте backup создаем пользователя borg:

```
[root@backup ~]# useradd -m borg
```
> На хосте server генерируем SSH-ключ и добавляем его в ~borg/.ssh/authorized_keys на хост backup:

```
[root@server ~]# ssh-keygen
Generating public/private rsa key pair.
Enter file in which to save the key (/root/.ssh/id_rsa): 
Created directory '/root/.ssh'.
Enter passphrase (empty for no passphrase): 
Enter same passphrase again: 
Your identification has been saved in /root/.ssh/id_rsa.
Your public key has been saved in /root/.ssh/id_rsa.pub.
The key fingerprint is:
SHA256:s4zmXOg5EbTBw6r5aAMTvSwCo0C2KvUAX36Kz+FPYqs root@server
The key's randomart image is:
+---[RSA 2048]----+
|     o           |
|.o  . *          |
|o+.o o +         |
|=.= o +          |
|== B o .S        |
|O * + .+ o       |
|o+ *o.=.+        |
|  +.=O.o         |
| .Eo..*.         |
+----[SHA256]-----+
[root@server ~]# cat .ssh/id_rsa.pub 
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDQITlLOAa6vmbrNMakdm6rUzVFNVj9T8Teen0fr+oJMX/C172Ab3bDwJdAr7dVF84gXChCB5FQb2V+UBHjM5+fIW93JAmzWd0umZ0byMGsJG67DIqAdeG9NbhZv4rlWj2/HyK+47jubQohPe9y5JOt4I+Eu7pJr9so1CClQWZKCi7Z1cMQByasMDyghXflz0fnIrrEw57AdPGsC4VbJm8d4XJ4UYb7TSEx0Y1cEsERVWOGU9jYoaaj/LojtxDmqrdd6BSeB0lXVajVO+srpTMBZnrp3oMO0O8iU5oOibJQ22dvfjsiekr1jDGR/TfGS3Rr8TodS4C2HC/TrRXQuX/H root@server
```

```
[root@backup ~]# mkdir ~borg/.ssh && echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDQITlLOAa6vmbrNMakdm6rUzVFNVj9T8Teen0fr+oJMX/C172Ab3bDwJdAr7dVF84gXChCB5FQb2V+UBHjM5+fIW93JAmzWd0umZ0byMGsJG67DIqAdeG9NbhZv4rlWj2/HyK+47jubQohPe9y5JOt4I+Eu7pJr9so1CClQWZKCi7Z1cMQByasMDyghXflz0fnIrrEw57AdPGsC4VbJm8d4XJ4UYb7TSEx0Y1cEsERVWOGU9jYoaaj/LojtxDmqrdd6BSeB0lXVajVO+srpTMBZnrp3oMO0O8iU5oOibJQ22dvfjsiekr1jDGR/TfGS3Rr8TodS4C2HC/TrRXQuX/H root@server" > ~borg/.ssh/authorized_keys
[root@backup ~]# chown -R borg:borg ~borg/.ssh
```
# Шифрование

> Теперь с хоста server (с клиента) инициируем репозиторий с шифрованием (опция --encryption) с именем EtcRepo на хосте backup:

```
[root@server ~]# borg init --encryption=repokey-blake2 borg@192.168.11.160:EtcRepo
The authenticity of host '192.168.11.160 (192.168.11.160)' can't be established.
ECDSA key fingerprint is SHA256:2zRqUfaK+LN9jlhtdvnDc2WvDcUhpSRSRKDk/m7RgEY.
ECDSA key fingerprint is MD5:8d:49:7f:8d:03:06:8c:99:47:8c:5b:db:5e:ef:35:06.
Are you sure you want to continue connecting (yes/no)? yes
Remote: Warning: Permanently added '192.168.11.160' (ECDSA) to the list of known hosts.
Enter new passphrase: 
Enter same passphrase again: 
Do you want your passphrase to be displayed for verification? [yN]: y
Your passphrase (between double-quotes): "passphrase"
Make sure the passphrase displayed above is exactly what you wanted.

By default repositories initialized with this version will produce security
errors if written to with an older version (up to and including Borg 1.0.8).

If you want to use these older versions, you can disable the check by running:
borg upgrade --disable-tam ssh://borg@192.168.11.160/./EtcRepo

See https://borgbackup.readthedocs.io/en/stable/changes.html#pre-1-0-9-manifest-spoofing-vulnerability for details about the security implications.

IMPORTANT: you will need both KEY AND PASSPHRASE to access this repo!
If you used a repokey mode, the key is stored in the repo, but you should back it up separately.
Use "borg key export" to export the key, optionally in printable format.
Write down the passphrase. Store both at safe place(s).
```

> Также borg попросит ввести passphrase (в моем случае я ввел "passphrase").

> Ключ шифрования после инициализации репозитория будет храниться на хосте backup в файле <REPO_DIR>/config:

```
[root@backup ~]# cat /home/borg/EtcRepo/config                                    
[repository]
version = 1
segments_per_dir = 1000
max_segment_size = 524288000
append_only = 0
storage_quota = 0
additional_free_space = 0
id = 6fba60ac8aac9d559d0246fb0d183f9cda57448948f8daa284938ad64e41eefe
key = hqlhbGdvcml0aG2mc2hhMjU2pGRhdGHaAZ6v6bVQUfD9YGZZ2kbmS23I1R6rFvY4dfAS0i
        AEG3QA2JC/3ORBFgOUla52hyUVvxIGG18jeTAj6dgsP1VUIUZYJ63kmGMrsnwlEvopDPMl
        j6CLZ1axHyjWbjCrPzBIOTpS7dtwXtpEAS+Iis0KlbEALPtvMrgoLPSFn6AZZHnCKtZQNE
        wYIWcAk9x4FDzCzaV8jJXj3RzTy9GHKBLvctrd2nSkr/vtGKreNIjlPqHUB31TvAsV/Z/f
        SsPda146e1MCWusKR+i6Doacg2RcpnIdVb60bsNnrQeyqyWFTQGkIkociB2oURj6CSfFc6
        0y8IJyd1zYF9zy+97wNAFEK7Vdh4TU1IXFl4NmaGBK6IVhs4VhRA1BmDbrdKkXaRMdi23t
        HeIv/VoK+U8YvHixKOqjes/n6FArykMoEDg0rjL8cFiLTMryr7ry8eUFq/a/y96IGa2Q9R
        l8IApe/0HM/JAHBm4c/r0l3cT4Z2qWcYr7Cww0puu6siW5pVhDr0un9R88+7UY8nk3bObn
        nlRrNhFbQ1dD6NmdDUZ8vH6OJVmkaGFzaNoAIMLRcwHPXXCUHdt7HH8yXY3gq67qKl0RsZ
        Okcz0AQH7Gqml0ZXJhdGlvbnPOAAGGoKRzYWx02gAgExJKbjCOcWiHxoafhY603R12Mj7A
        vVCSUZbkxU/zRCOndmVyc2lvbgE=

[root@backup ~]# 
```
> При настроенном шифровании passphrase будет запрашиваться каждый раз при запуске процедуры бэкапа. 

> Поэтому для автоматизации бэкапа в скрипте одним из способов является передача passphrase 

> в переменную окружения BORG_PASSPHRASE: export BORG_PASSPHRASE='passphrase'.

# Логирование

> Borg пишет свои логи в stderr, поэтому для записи логов в файл, нужно перенаправить в него stderr. В скрипте за это отвечают следующие строки:

```
LOG=/var/log/borg_backup.log

borg create \
  --stats --list --debug --progress \
  ${BACKUP_USER}@${BACKUP_HOST}:${BACKUP_REPO}::"etc-server-{now:%Y-%m-%d_%H:%M:%S}" \
  /etc 2>> ${LOG}

borg prune \
  -v --list \
  ${BACKUP_USER}@${BACKUP_HOST}:${BACKUP_REPO} \
  --keep-daily=7 \
  --keep-weekly=4 2>> ${LOG}
```

# Политика хранения бэкапа

> глубина бекапа должна быть год, хранить можно по последней копии на конец месяца, кроме последних трех.

>  Последние три месяца должны содержать копии на каждый день.

>  Т.е. должна быть правильно настроена политика удаления старых бэкапов;

```
borg prune \
  -v --list \
  ${BACKUP_USER}@${BACKUP_HOST}:${BACKUP_REPO} \
  --keep-daily=90 \
  --keep-monthly=12 \
  --keep-yearly=1 2>> ${LOG}
```

# Автоматическое выполнение бэкапа

> Автоматизируем создание бэкапов с помощью systemd Создаем сервис и таймер в каталоге /etc/systemd/system/

```
[root@server ~]# cat /etc/systemd/system/borg-backup.service
[Unit]
Description=Borg /etc backup
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
ExecStart=/root/borg-backup.sh

[root@server ~]# cat /etc/systemd/system/borg-backup.timer
[Unit]
Description=Borg backup timer

[Timer]
#run hourly
OnBootSec=5min
OnUnitActiveSec=1h
Unit=borg-backup.service

[Install]
WantedBy=multi-user.target
```
> Обновим конфигурацию systemd и запустим таймер:

```
[root@server ~]# systemctl daemon-reload
[root@server ~]# systemctl enable --now borg-backup.timer 
Created symlink from /etc/systemd/system/multi-user.target.wants/borg-backup.timer to /etc/systemd/system/borg-backup.timer.
```

# Работа с архивом

> Создадим /etc/testdir с файлами внутри:
```
[root@server ~]# mkdir /etc/testdir && touch /etc/testdir/testfile{01..05}
[root@server ~]# ll /etc/testdir/
total 0
-rw-r--r--. 1 root root 0 Aug  4 13:48 testfile01
-rw-r--r--. 1 root root 0 Aug  4 13:48 testfile02
-rw-r--r--. 1 root root 0 Aug  4 13:48 testfile03
-rw-r--r--. 1 root root 0 Aug  4 13:48 testfile04
-rw-r--r--. 1 root root 0 Aug  4 13:48 testfile05
```
> Выполним задание бэкапа:

```
[root@server ~]# ./borg-backup.sh

[root@server ~]# borg@192.168.11.160:EtcRepo::"etc-{now:%Y-%m-%d_%H:%M:%S}" /etc
Enter passphrase for key ssh://borg@192.168.10.20/./EtcRepo: 
Enter passphrase for key ssh://borg@192.168.10.20/./EtcRepo: 
etc-2023-08-04_13:58:13 Fri, 2023-08-04 13:58:14 [05035261c38d4994b7029373b1e72c6084c7e149f758fa099ed305476d7981fe]
```
> Видим один единственный архив etc-2023-08-04_13:58:13, посмотрим его содержимое:
```
d /etc/NetworkManager/dnsmasq.d
d /etc/NetworkManager/system-connections
A /etc/NetworkManager/NetworkManager.conf
d /etc/NetworkManager
d /etc/statetab.d
A /etc/samba/lmhosts
A /etc/samba/smb.conf
A /etc/samba/smb.conf.example
d /etc/samba
A /etc/gssproxy/99-nfs-client.conf
A /etc/gssproxy/gssproxy.conf
A /etc/gssproxy/24-nfs-server.conf
d /etc/gssproxy
d /etc/firewalld/helpers
A /etc/firewalld/zones/public.xml
A /etc/firewalld/zones/public.xml.old
d /etc/firewalld/zones
d /etc/firewalld/icmptypes
d /etc/firewalld/ipsets
A /etc/firewalld/firewalld.conf
A /etc/firewalld/lockdown-whitelist.xml
d /etc/firewalld/services
d /etc/firewalld
A /etc/vmware-tools/scripts/vmware/network
d /etc/vmware-tools/scripts/vmware
d /etc/vmware-tools/scripts
A /etc/vmware-tools/GuestProxyData/server/key.pem
A /etc/vmware-tools/GuestProxyData/server/cert.pem
d /etc/vmware-tools/GuestProxyData/server
d /etc/vmware-tools/GuestProxyData/trusted
d /etc/vmware-tools/GuestProxyData
A /etc/vmware-tools/vgauth/schemas/XMLSchema-hasFacetAndProperty.xsd
A /etc/vmware-tools/vgauth/schemas/XMLSchema-instance.xsd
A /etc/vmware-tools/vgauth/schemas/XMLSchema.dtd
A /etc/vmware-tools/vgauth/schemas/XMLSchema.xsd
A /etc/vmware-tools/vgauth/schemas/catalog.xml
A /etc/vmware-tools/vgauth/schemas/datatypes.dtd
A /etc/vmware-tools/vgauth/schemas/saml-schema-assertion-2.0.xsd
A /etc/vmware-tools/vgauth/schemas/xenc-schema.xsd
A /etc/vmware-tools/vgauth/schemas/xml.xsd
A /etc/vmware-tools/vgauth/schemas/xmldsig-core-schema.xsd
d /etc/vmware-tools/vgauth/schemas
d /etc/vmware-tools/vgauth
A /etc/vmware-tools/guestproxy-ssl.conf
A /etc/vmware-tools/poweroff-vm-default
A /etc/vmware-tools/poweron-vm-default
A /etc/vmware-tools/resume-vm-default
A /etc/vmware-tools/statechange.subr
A /etc/vmware-tools/suspend-vm-default
A /etc/vmware-tools/vgauth.conf
```

> Удалим /etc/testdir:

```
[root@server ~]# rm -rf /etc/testdir/
[root@server ~]# ll /etc/testdir
ls: cannot access /etc/testdir: No such file or directory
[root@server ~]# 
```

> Восстановим /etc/testdir из бэкапа. Сначала создадим директорию /borgbackup и примонтируем в неё репозиторий с бэкапом:

```
[root@server ~]# mkdir /borgbackup
[root@server ~]# borg mount borg@192.168.11.160:EtcRepo::etc-2023-08-04_13:58:13 /borgbackup/
Enter passphrase for key ssh://borg@192.168.11.160/./EtcRepo: 

[root@server ~]# ll /borgbackup/
total 0
drwxr-xr-x. 1 root root 0 Aug  4 13:48 etc
```
> Проверим наличие testdir в /borgbackup/etc:

```
[root@server ~]# ll /borgbackup/etc/testdir/
total 0
-rw-r--r--. 1 root root 0 Aug  4 13:48 testfile01
-rw-r--r--. 1 root root 0 Aug  4 13:48 testfile02
-rw-r--r--. 1 root root 0 Aug  4 13:48 testfile03
-rw-r--r--. 1 root root 0 Aug  4 13:48 testfile04
-rw-r--r--. 1 root root 0 Aug  4 13:48 testfile05
[root@server ~]# 
```

> Теперь можно скопировать testdir в /etc:

```
[root@server ~]# cp -Rp /borgbackup/etc/testdir/ /etc
[root@server ~]# ll /etc/testdir/
total 0
-rw-r--r--. 1 root root 0 Aug  4 13:48 testfile01
-rw-r--r--. 1 root root 0 Aug  4 13:48 testfile02
-rw-r--r--. 1 root root 0 Aug  4 13:48 testfile03
-rw-r--r--. 1 root root 0 Aug  4 13:48 testfile04
-rw-r--r--. 1 root root 0 Aug  4 13:48 testfile05
```

> Теперь можно отмонтировать репозиторий с бэкапом:

```
[root@server ~]# borg umount /borgbackup/
[root@server ~]# ll /borgbackup/
total 0
```
