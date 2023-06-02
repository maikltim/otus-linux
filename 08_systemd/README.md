# Systemd

# Напишем сервис, который будет раз в 30 секунд мониторить лог на предмет наличия ключевого слова. Файл и слово должны задаваться в /etc/sysconfig

> Для начала создаём файл с конфигурацией для сервиса в директории /etc/sysconfig - из неё сервис будет брать необходимые переменные

> vi /etc/sysconfig/watchlog

```
# Configuration file for my watchlog service
# Place it to /etc/sysconfig
# File and word in that file that we will be monit
WORD="ALERT"
LOG=/var/log/watchlog.log
```
> Затем создаем /var/log/watchlog.log и пишем туда строки на своё усмотрение, плюс ключевое слово ALERT
> Создадим скрипт vi /opt/watchlog.sh

```
#!/bin/bash
WORD=$1
LOG=$2
DATE=`date`
if grep $WORD $LOG &> /dev/null
then
  logger "$DATE: I found word, Master!"
else
  exit 0
fi
```
> Создадим юнит для сервиса watchlog - vi /etc/systemd/system/watchlog.service

```
[Unit]
Description=My watchlog service
[Service]
Type=oneshot
EnvironmentFile=/etc/sysconfig/watchlog
ExecStart=/opt/watchlog.sh $WORD $LOG
```
> Создадим юнит для таймера - vi /etc/systemd/system/watchlog.timer

```
[Unit]
Description=Run watchlog script every 30 second
[Timer]
# Run every 30 second
OnUnitActiveSec=30
Unit=watchlog.service
[Install]
WantedBy=multi-user.target
```
> Затем достаточно только стартануть timer
```
systemctl start watchlog.timer
```
> И убедиться в результате

```
tail -f /var/log/messages


Jun  2 10:34:10 localhost root: Fri Jun  2 10:34:10 UTC 2023: I found word, Master!
Jun  2 10:34:10 localhost systemd: Started My watchlog service.
Jun  2 10:34:10 localhost systemd: Reloading.
Jun  2 10:34:18 localhost systemd: Starting Cleanup of Temporary Directories...
Jun  2 10:34:18 localhost systemd: Starting My watchlog service...
Jun  2 10:34:18 localhost systemd: Started Cleanup of Temporary Directories.
Jun  2 10:34:18 localhost root: Fri Jun  2 10:34:18 UTC 2023: I found word, Master!
Jun  2 10:34:18 localhost systemd: Started My watchlog service.
```

# Из epel установим spawn-fcgi и перепишем init-скрипт на unit-файл. Имя сервиса должно также называться

> Устанавливаем spawn-fcgi и необходимые для него пакеты

```
yum install epel-release -y && yum install spawn-fcgi php php-cli mod_fcgid httpd -y
```

> /etc/rc.d/init.d/spawn-fcg - cам Init скрипт, который будем переписывать
> Но перед этим необходимо раскомментировать строки с переменными в /etc/sysconfig/spawn-fcgi
> Он должен получится следующего вида:

```
# You must set some working options before the "spawn-fcgi" service will work.
# If SOCKET points to a file, then this file is cleaned up by the init script.
#
# See spawn-fcgi(1) for all possible options.
#
# Example :
SOCKET=/var/run/php-fcgi.sock
OPTIONS="-u apache -g apache -s $SOCKET -S -M 0600 -C 32 -F 1 -P /var/run/spawn-fcgi.pid -- /usr/bin/php-cgi"
```

> А сам юнит файл будет следующего вида - vi /etc/systemd/system/spawn-fcgi.service

```
[Unit]
Description=Spawn-fcgi startup service by Otus
After=network.target
[Service]
Type=simple
PIDFile=/var/run/spawn-fcgi.pid
EnvironmentFile=/etc/sysconfig/spawn-fcgi
ExecStart=/usr/bin/spawn-fcgi -n $OPTIONS
KillMode=process
[Install]
WantedBy=multi-user.target
```
> Убеждаемся что все успешно работает

```
systemctl start spawn-fcgi
systemctl status spawn-fcgi

● spawn-fcgi.service - Spawn-fcgi startup service by Otus
   Loaded: loaded (/etc/systemd/system/spawn-fcgi.service; disabled; vendor preset: disabled)
   Active: active (running) since Fri 2023-06-02 11:17:39 UTC; 7s ago
 Main PID: 1828 (php-cgi)
   CGroup: /system.slice/spawn-fcgi.service
           ├─1828 /usr/bin/php-cgi
           ├─1829 /usr/bin/php-cgi
           ├─1830 /usr/bin/php-cgi
           ├─1831 /usr/bin/php-cgi
           ├─1832 /usr/bin/php-cgi
           ├─1833 /usr/bin/php-cgi
           ├─1834 /usr/bin/php-cgi
           ├─1835 /usr/bin/php-cgi
           ├─1836 /usr/bin/php-cgi
           ├─1837 /usr/bin/php-cgi
           ├─1838 /usr/bin/php-cgi
           ├─1839 /usr/bin/php-cgi
           ├─1840 /usr/bin/php-cgi
           ├─1841 /usr/bin/php-cgi
           ├─1842 /usr/bin/php-cgi
           ├─1843 /usr/bin/php-cgi
           ├─1844 /usr/bin/php-cgi
           ├─1845 /usr/bin/php-cgi
           ├─1846 /usr/bin/php-cgi
           ├─1847 /usr/bin/php-cgi
           ├─1848 /usr/bin/php-cgi
           ├─1849 /usr/bin/php-cgi
           ├─1850 /usr/bin/php-cgi
           ├─1851 /usr/bin/php-cgi
           ├─1852 /usr/bin/php-cgi
           ├─1853 /usr/bin/php-cgi
           ├─1854 /usr/bin/php-cgi
           ├─1855 /usr/bin/php-cgi
           ├─1856 /usr/bin/php-cgi
           ├─1857 /usr/bin/php-cgi
           ├─1858 /usr/bin/php-cgi
           ├─1859 /usr/bin/php-cgi
           └─1860 /usr/bin/php-cgi

Jun 02 11:17:39 localhost.localdomain systemd[1]: Started Spawn-fcgi startup service by Otus.
```

# Дополним юнит-файл apache httpd возможностью запустить несколько инстансов сервера с разными конфигами

> Для запуска нескольких экземпляров сервиса будем использовать шаблон в конфигурации файла окружения
>  vi /etc/systemd/system/httpd@second.service /etc/systemd/system/httpd@first.service

```
[Unit]
Description=The Apache HTTP Server
After=network.target remote-fs.target nss-lookup.target
Documentation=man:httpd(8)
Documentation=man:apachectl(8)

[Service]
Type=notify
EnvironmentFile=/etc/sysconfig/httpd-%I
ExecStart=/usr/sbin/httpd $OPTIONS -DFOREGROUND
ExecReload=/usr/sbin/httpd $OPTIONS -k graceful
ExecStop=/bin/kill -WINCH ${MAINPID}
KillSignal=SIGCONT
PrivateTmp=true
[Install]
WantedBy=multi-user.target
```
> В самом файле окружения (которых будет два) задается опция для запуска веб-сервера с необходимым конфигурационным файлом
> cat /etc/sysconfig/httpd-first
```
OPTIONS=-f conf/first.conf
```

> cat /etc/sysconfig/httpd-second
```
OPTIONS=-f conf/second.conf
```

> Соответственно в директории с конфигами httpd должны лежать два конфига, в нашем случае это будут first.conf и second.conf

```
cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/first.conf                              
cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/second.conf
```

> Соответственно в директории с конфигами httpd (/etc/httpd/conf/) должны лежать два конфига, в нашем случае это будут first.conf и second.conf.
> Для создания конфига first.conf просто скопируем оригинальный конфиг, а для second.conf поправим опции PidFile и Listen.

```
grep -E '^PidFile|^Listen' /etc/httpd/conf/second.conf
PidFile "/var/run/httpd-second.pid"
Listen 8008
```

> Теперь можно запустить экземпляры сервиса:
```
systemctl start httpd@first
systemctl start httpd@second
```
> Проверим порты

```
ss -tnulp | grep httpd
tcp    LISTEN     0      128    [::]:8008               [::]:*                   users:(("httpd",pid=1901,fd=4),("httpd",pid=1900,fd=4),("httpd",pid=1899,fd=4),("httpd",pid=1898,fd=4),("httpd",pid=1897,fd=4),("httpd",pid=1896,fd=4),("httpd",pid=1895,fd=4))
tcp    LISTEN     0      128    [::]:80                 [::]:*                   users:(("httpd",pid=1888,fd=4),("httpd",pid=1887,fd=4),("httpd",pid=1886,fd=4),("httpd",pid=1885,fd=4),("httpd",pid=1884,fd=4),("httpd",pid=1883,fd=4),("httpd",pid=1882,fd=4))
```
