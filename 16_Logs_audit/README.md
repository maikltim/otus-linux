# Настраиваем центральный сервер сбор логов

> Для правильной работы c логами, нужно, чтобы на всех хостах было настроено одинаковое время.

> Укажем часовой пояс (Московское время):  cp /usr/share/zoneinfo/Europe/Moscow /etc/localtime,

> перезупустим службу NTP Chrony: systemctl restart chronyd

> Проверим, что служба работает корректно: systemctl status chronyd

```
[root@web ~]# systemctl restart chronyd
[root@web ~]# systemctl status chronyd
● chronyd.service - NTP client/server
   Loaded: loaded (/usr/lib/systemd/system/chronyd.service; enabled; vendor preset: enabled)
   Active: active (running) since Thu 2023-07-27 08:13:49 MSK; 13s ago
     Docs: man:chronyd(8)
           man:chrony.conf(5)
  Process: 3019 ExecStartPost=/usr/libexec/chrony-helper update-daemon (code=exited, status=0/SUCCESS)
  Process: 3015 ExecStart=/usr/sbin/chronyd $OPTIONS (code=exited, status=0/SUCCESS)
 Main PID: 3017 (chronyd)
   CGroup: /system.slice/chronyd.service
           └─3017 /usr/sbin/chronyd

Jul 27 08:13:49 web systemd[1]: Stopped NTP client/server.
Jul 27 08:13:49 web systemd[1]: Starting NTP client/server...
Jul 27 08:13:49 web chronyd[3017]: chronyd version 3.4 starting (+CMDMON +NTP +REFCLOCK +RTC +PRIVDROP +SCFILTER +SIGND +ASYNCDNS +SECHASH +IPV6 +DEBUG)
Jul 27 08:13:49 web chronyd[3017]: Frequency 7817.509 +/- 7.366 ppm read from /var/lib/chrony/drift
Jul 27 08:13:49 web systemd[1]: Started NTP client/server.
Jul 27 08:13:55 web chronyd[3017]: Selected source 185.51.192.61
```
> Далее проверим, что время и дата указаны правильно: date

```
[root@web ~]# date
Thu Jul 27 08:15:15 MSK 2023
```

# Настроить NTP нужно на обоих серверах.

> Также, для удобства редактирования конфигурационных файлов можно установить текстовый редактор vim: yum install -y vim

#  Установка nginx на виртуальной машине web
> Для установки nginx сначала нужно установить epel-release: yum install epel-release 

> Установим nginx: yum install -y nginx 
> Установим nginx: yum install -y nginx 

```
[root@web ~]# systemctl status nginx
● nginx.service - The nginx HTTP and reverse proxy server
   Loaded: loaded (/usr/lib/systemd/system/nginx.service; enabled; vendor preset: disabled)
   Active: active (running) since Thu 2023-07-27 08:21:20 MSK; 13s ago
 Main PID: 3220 (nginx)
   CGroup: /system.slice/nginx.service
           ├─3220 nginx: master process /usr/sbin/nginx
           └─3222 nginx: worker process

Jul 27 08:21:19 web systemd[1]: Starting The nginx HTTP and reverse proxy server...
Jul 27 08:21:20 web nginx[3216]: nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
Jul 27 08:21:20 web nginx[3216]: nginx: configuration file /etc/nginx/nginx.conf test is successful
Jul 27 08:21:20 web systemd[1]: Started The nginx HTTP and reverse proxy server.
```
```
[root@web ~]# ss -tln | grep 80
LISTEN     0      128          *:80                       *:*                  
LISTEN     0      128       [::]:80                    [::]:*     
```
> Также работу nginx можно проверить на хосте. В браузере ввведем в адерсную строку http://192.168.50.10 

> Видим что nginx запустился корректно.


# Настройка центрального сервера сбора логов
> Откроем еще одно окно терминала и подключаемся по ssh к ВМ log: vagrant ssh log
> Перейдем в пользователя root: sudo -i
> rsyslog должен быть установлен по умолчанию в нашей ОС, проверим это:

```
[root@log ~]# yum list rsyslog
Failed to set locale, defaulting to C
Loaded plugins: fastestmirror
Determining fastest mirrors
 * base: centos.mirror.transip.nl
 * extras: mirror.hostnet.nl
 * updates: mirror.hostnet.nl
base                                                                                                                                                    | 3.6 kB  00:00:00     
extras                                                                                                                                                  | 2.9 kB  00:00:00     
updates                                                                                                                                                 | 2.9 kB  00:00:00     
(1/4): base/7/x86_64/group_gz                                                                                                                           | 153 kB  00:00:00     
(2/4): extras/7/x86_64/primary_db                                                                                                                       | 250 kB  00:00:00     
(3/4): base/7/x86_64/primary_db                                                                                                                         | 6.1 MB  00:00:01     
(4/4): updates/7/x86_64/primary_db                                                                                                                      |  22 MB  00:00:05     
Installed Packages
rsyslog.x86_64                                                                   8.24.0-52.el7                                                                        @anaconda
Available Packages
rsyslog.x86_64        
```

> Все настройки Rsyslog хранятся в файле /etc/rsyslog.conf 

> Для того, чтобы наш сервер мог принимать логи, нам необходимо внести следующие изменения в файл:

> Открываем порт 514 (TCP и UDP):

> Находим закомментированные строки:

```
# rsyslog configuration file

# For more information see /usr/share/doc/rsyslog-*/rsyslog_conf.html
# If you experience problems, see http://www.rsyslog.com/doc/troubleshoot.html

#### MODULES ####

# The imjournal module bellow is now used as a message source instead of imuxsock.
$ModLoad imuxsock # provides support for local system logging (e.g. via logger command)
$ModLoad imjournal # provides access to the systemd journal
#$ModLoad imklog # reads kernel messages (the same are read from journald)
#$ModLoad immark  # provides --MARK-- message capability

# Provides UDP syslog reception
#$ModLoad imudp
#$UDPServerRun 514

# Provides TCP syslog reception
#$ModLoad imtcp
#$InputTCPServerRun 514


#### GLOBAL DIRECTIVES ####

# Where to place auxiliary files
```

> И приводим их к виду:

```
# Provides UDP syslog reception
$ModLoad imudp
$UDPServerRun 514

# Provides TCP syslog reception
$ModLoad imtcp
$InputTCPServerRun 514
```

> В конец файла /etc/rsyslog.conf добавляем правила приёма сообщений от хостов
```
#Add remote logs
$template RemoteLogs,"/var/log/rsyslog/%HOSTNAME%/%PROGRAMNAME%.log"
*.* ?RemoteLogs
& ~
```
```
Данные параметры будут отправлять в папку /var/log/rsyslog логи, 
которые будут приходить от других серверов. Например, Access-логи nginx от сервера web, 
будут идти в файл /var/log/rsyslog/web/nginx_access.log
```

> Далее сохраняем файл и перезапускаем службу rsyslog: systemctl restart rsyslog

> Если ошибок не допущено, то у нас будут видны открытые порты TCP,UDP 514

```
[root@log ~]# ss -tuln | grep 514
udp    UNCONN     0      0         *:514                   *:*                  
udp    UNCONN     0      0      [::]:514                [::]:*                  
tcp    LISTEN     0      25        *:514                   *:*                  
tcp    LISTEN     0      25     [::]:514                [::]:* 
```

# Далее настроим отправку логов с web-сервера
> Проверим версию nginx: rpm -qa | grep nginx

```
[root@web ~]# rpm -qa | grep nginx
nginx-1.20.1-10.el7.x86_64
nginx-filesystem-1.20.1-10.el7.noarch
```
> Версия nginx должна быть 1.7 или выше. В нашем примере используется версия nginx 1.20.

> Находим в файле /etc/nginx/nginx.conf раздел с логами и приводим их к следующему виду:

```
error_log /var/log/nginx/error.log;
error_log syslog:server=192.168.50.15:514,tag=nginx_error;

http {
    access_log syslog:server=192.168.50.15:514,tag=nginx_access,severity=info combined;
```

> Для Access-логов указываем удаленный сервер и уровень логов, которые нужно отправлять. 
> Для error_log добавляем удаленный сервер. Если требуется чтобы логи хранились локально 
> и отправлялись на удаленный сервер, требуется указать 2 строки. 
> Tag нужен для того, чтобы логи записывались в разные файлы.

> По умолчанию, error-логи отправляют логи, которые имеют severity: error, crit, alert и emerg. 
> Если трубуется хранили или пересылать логи с другим severity, то это также можно указать в настройках nginx.

> Далее проверяем, что конфигурация nginx указана правильно: nginx -t

```
[root@web ~]# nginx -t
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

> Далее перезапустим nginx: systemctl restart nginx

> Чтобы проверить, что логи ошибок также улетают на удаленный сервер,
> можно удалить картинку, к которой будет обращаться nginx во время открытия веб-сраницы: rm /usr/share/nginx/html/img/header-background.png

```
[root@web ~]# rm /usr/share/nginx/html/img/header-background.png
rm: remove regular file '/usr/share/nginx/html/img/header-background.png'? yes
```

> Попробуем несколько раз зайти по адресу http://192.168.50.15

> Далее заходим на log-сервер и смотрим информацию об nginx:

```
[root@log ~]# cat /var/log/rsyslog/web/nginx_access.log 
Jul 27 08:59:12 web nginx_access: 192.168.50.1 - - [27/Jul/2023:08:59:12 +0300] "GET / HTTP/1.1" 304 0 "-" "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36"
Jul 27 08:59:12 web nginx_access: 192.168.50.1 - - [27/Jul/2023:08:59:12 +0300] "GET / HTTP/1.1" 304 0 "-" "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36"
Jul 27 08:59:13 web nginx_access: 192.168.50.1 - - [27/Jul/2023:08:59:13 +0300] "GET / HTTP/1.1" 304 0 "-" "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36"
Jul 27 08:59:13 web nginx_access: 192.168.50.1 - - [27/Jul/2023:08:59:13 +0300] "GET / HTTP/1.1" 304 0 "-" "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36"
Jul 27 09:02:42 web nginx_access: 192.168.50.1 - - [27/Jul/2023:09:02:42 +0300] "GET / HTTP/1.1" 304 0 "-" "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36"
Jul 27 09:02:43 web nginx_access: 192.168.50.1 - - [27/Jul/2023:09:02:43 +0300] "GET / HTTP/1.1" 304 0 "-" "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36"
Jul 27 09:02:43 web nginx_access: 192.168.50.1 - - [27/Jul/2023:09:02:43 +0300] "GET / HTTP/1.1" 304 0 "-" "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36"
Jul 27 09:02:43 web nginx_access: 192.168.50.1 - - [27/Jul/2023:09:02:43 +0300] "GET / HTTP/1.1" 304 0 "-" "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36"
Jul 27 09:02:44 web nginx_access: 192.168.50.1 - - [27/Jul/2023:09:02:44 +0300] "GET / HTTP/1.1" 304 0 "-" "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36"
Jul 27 09:02:44 web nginx_access: 192.168.50.1 - - [27/Jul/2023:09:02:44 +0300] "GET / HTTP/1.1" 304 0 "-" "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36"
Jul 28 13:47:06 web nginx_access: 192.168.50.1 - - [28/Jul/2023:13:47:06 +0300] "GET /img/header-background.png HTTP/1.1" 404 3650 "http://192.168.50.10/" "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36"
Jul 28 13:47:11 web nginx_access: 192.168.50.1 - - [28/Jul/2023:13:47:11 +0300] "GET / HTTP/1.1" 304 0 "-" "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36"
Jul 28 13:47:11 web nginx_access: 192.168.50.1 - - [28/Jul/2023:13:47:11 +0300] "GET /img/header-background.png HTTP/1.1" 404 3650 "http://192.168.50.10/" "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36"
Jul 28 13:47:11 web nginx_access: 192.168.50.1 - - [28/Jul/2023:13:47:11 +0300] "GET / HTTP/1.1" 304 0 "-" "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36"
Jul 28 13:47:12 web nginx_access: 192.168.50.1 - - [28/Jul/2023:13:47:12 +0300] "GET /img/header-background.png HTTP/1.1" 404 3650 "http://192.168.50.10/" "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36"
Jul 28 13:47:12 web nginx_access: 192.168.50.1 - - [28/Jul/2023:13:47:12 +0300] "GET / HTTP/1.1" 304 0 "-" "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36"
Jul 28 13:47:12 web nginx_access: 192.168.50.1 - - [28/Jul/2023:13:47:12 +0300] "GET /img/header-background.png HTTP/1.1" 404 3650 "http://192.168.50.10/" "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36"
Jul 28 13:47:12 web nginx_access: 192.168.50.1 - - [28/Jul/2023:13:47:12 +0300] "GET / HTTP/1.1" 304 0 "-" "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36"
Jul 28 13:47:12 web nginx_access: 192.168.50.1 - - [28/Jul/2023:13:47:12 +0300] "GET /img/header-background.png HTTP/1.1" 404 3650 "http://192.168.50.10/" "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36"

[root@log ~]# cat /var/log/rsyslog/web/nginx_error.log
Jul 28 13:47:06 web nginx_error: 2023/07/28 13:47:06 [error] 624#624: *1 open() "/usr/share/nginx/html/img/header-background.png" failed (2: No such file or directory), client: 192.168.50.1, server: _, request: "GET /img/header-background.png HTTP/1.1", host: "192.168.50.10", referrer: "http://192.168.50.10/"
```
> Видим, что логи отправляются корректно. 

# Настройка аудита, контролирующего изменения конфигурации nginx

> За аудит отвечает утилита auditd, в RHEL-based системах обычно он уже предустановлен. Проверим это: rpm -qa | grep audit

```
[root@web ~]# rpm -qa | grep audit
audit-2.8.5-4.el7.x86_64
audit-libs-2.8.5-4.el7.x86_64
```

> Настроим аудит изменения конфигурации nginx:
> Добавим правило, которое будет отслеживать изменения в конфигруации nginx. Для этого в конец файла /etc/audit/rules.d/audit.rules добавим следующие строки:
```
-w /etc/nginx/nginx.conf -p wa -k nginx_conf
-w /etc/nginx/default.d/ -p wa -k nginx_conf
```

> Данные правила позволяют контролировать запись (w) и измения атрибутов (a) в:

```
/etc/nginx/nginx.conf
Всех файлов каталога /etc/nginx/default.d/
Для более удобного поиска к событиям добавляется метка nginx_conf
```

> Перезапускаем службу auditd: service auditd restart

```
[root@web ~]# service auditd restart
Stopping logging:                                          [  OK  ]
Redirecting start to /bin/systemctl start auditd.service
```
> После данных изменений у нас начнут локально записываться логи аудита. 

> Чтобы проверить, что логи аудита начали записываться локально, нужно внести изменения 

> в файл /etc/nginx/nginx.conf или поменять его атрибут,

> потом посмотреть информацию об изменениях: ausearch -f /etc/nginx/nginx.confq

> Также можно воспользоваться поиском по файлу /var/log/audit/audit.log, указав наш тэг: grep nginx_conf /var/log/audit/audit.log

```
[root@web ~]# grep nginx_conf /var/log/audit/audit.log
type=CONFIG_CHANGE msg=audit(1690541743.150:621): auid=4294967295 ses=4294967295 subj=system_u:system_r:unconfined_service_t:s0 op=add_rule key="nginx_conf" list=4 res=1
type=CONFIG_CHANGE msg=audit(1690541743.150:622): auid=4294967295 ses=4294967295 subj=system_u:system_r:unconfined_service_t:s0 op=add_rule key="nginx_conf" list=4 res=1
```
> Далее настроим пересылку логов на удаленный сервер. Auditd по умолчанию не умеет пересылать логи, 
> для пересылки на web-сервере потребуется установить пакет audispd-plugins: yum -y install audispd-plugins

> Найдем и поменяем следующие строки в файле /etc/audit/auditd.conf: 

```
log_format = RAW
name_format = HOSTNAME
```

> В файле /etc/audisp/plugins.d/au-remote.conf поменяем параметр active на yes

```
active = yes
direction = out
path = /sbin/audisp-remote
type = always
#args =
format = string
```

> В файле /etc/audisp/audisp-remote.conf требуется указать адрес сервера и порт, на который будут отправляться логи

```
remote_server = 192.168.50.15
```

> Далее перезапускаем службу auditd: service auditd restart

```
[root@web ~]# service auditd restart
Stopping logging:                                          [  OK  ]
Redirecting start to /bin/systemctl start auditd.service
```

> Отроем порт TCP 60, для этого уберем значки комментария в файле /etc/audit/auditd.conf:

```
tcp_listen_port = 60
```

> Далее перезапускаем службу auditd: service auditd restart

```
[root@web ~]# service auditd restart
Stopping logging:                                          [  OK  ]
Redirecting start to /bin/systemctl start auditd.service
```

> На этом настройка пересылки логов аудита закончена. Можем попробовать поменять атрибут 

> у файла /etc/nginx/nginx.conf и проверить на log-сервере, что пришла информация об изменении атрибута:

```
[root@web ~]# ls -l /etc/nginx/nginx.conf
-rw-r--r--. 1 root root 2568 Jul 27 09:02 /etc/nginx/nginx.conf
[root@web ~]# chmod +x /etc/nginx/nginx.conf
[root@web ~]# ls -l /etc/nginx/nginx.conf
-rwxr-xr-x. 1 root root 2568 Jul 27 09:02 /etc/nginx/nginx.conf
```
> Видим лог об изменении атрибута файла на web

```
type=USER_END msg=audit(1690541024.894:162): pid=931 uid=0 auid=1000 ses=1 subj=system_u:system_r:sshd_t:s0-s0:c0.c1023 msg='op=login id=1000 exe="/usr/sbin/sshd" hostname=10.0.2.2 addr=10.0.2.2 terminal=ssh res=success'
type=USER_LOGOUT msg=audit(1690541024.894:163): pid=931 uid=0 auid=1000 ses=1 subj=system_u:system_r:sshd_t:s0-s0:c0.c1023 msg='op=login id=1000 exe="/usr/sbin/sshd" hostname=10.0.2.2 addr=10.0.2.2 terminal=ssh res=success'
type=USER_LOGIN msg=audit(1690541024.938:164): pid=931 uid=0 auid=1000 ses=1 subj=system_u:system_r:sshd_t:s0-s0:c0.c1023 msg='op=login id=1000 exe="/usr/sbin/sshd" hostname=10.0.2.2 addr=10.0.2.2 terminal=ssh res=success'
type=USER_START msg=audit(1690541024.938:165): pid=931 uid=0 auid=1000 ses=1 subj=system_u:system_r:sshd_t:s0-s0:c0.c1023 msg='op=login id=1000 exe="/usr/sbin/sshd" hostname=10.0.2.2 addr=10.0.2.2 terminal=ssh res=success'
type=CRYPTO_KEY_USER msg=audit(1690541024.947:166): pid=931 uid=0 auid=1000 ses=1 subj=system_u:system_r:sshd_t:s0-s0:c0.c1023 msg='op=destroy kind=server fp=SHA256:21:a5:c4:e9:5f:73:17:a6:76:10:65:84:75:7c:19:68:dc:83:71:f2:84:6c:2e:87:56:79:17:f0:93:d8:4d:62 direction=? spid=1253 suid=1000  exe="/usr/sbin/sshd" hostname=? addr=? terminal=? res=success'
type=USER_END msg=audit(1690541024.974:167): pid=931 uid=0 auid=1000 ses=1 subj=system_u:system_r:sshd_t:s0-s0:c0.c1023 msg='op=login id=1000 exe="/usr/sbin/sshd" hostname=10.0.2.2 addr=10.0.2.2 terminal=ssh res=success'
type=USER_LOGOUT msg=audit(1690541024.974:168): pid=931 uid=0 auid=1000 ses=1 subj=system_u:system_r:sshd_t:s0-s0:c0.c1023 msg='op=login id=1000 exe="/usr/sbin/sshd" hostname=10.0.2.2 addr=10.0.2.2 terminal=ssh res=success'
type=USER_LOGIN msg=audit(1690541025.017:169): pid=931 uid=0 auid=1000 ses=1 subj=system_u:system_r:sshd_t:s0-s0:c0.c1023 msg='op=login id=1000 exe="/usr/sbin/sshd" hostname=10.0.2.2 addr=10.0.2.2 terminal=ssh res=success'
type=USER_START msg=audit(1690541025.017:170): pid=931 uid=0 auid=1000 ses=1 subj=system_u:system_r:sshd_t:s0-s0:c0.c1023 msg='op=login id=1000 exe="/usr/sbin/sshd" hostname=10.0.2.2 addr=10.0.2.2 terminal=ssh res=success'
type=CRYPTO_KEY_USER msg=audit(1690541025.022:171): pid=931 uid=0 auid=1000 ses=1 subj=system_u:system_r:sshd_t:s0-s0:c0.c1023 msg='op=destroy kind=server fp=SHA256:21:a5:c4:e9:5f:73:17:a6:76:10:65:84:75:7c:19:68:dc:83:71:f2:84:6c:2e:87:56:79:17:f0:93:d8:4d:62 direction=? spid=1262 suid=1000  exe="/usr/sbin/sshd" hostname=? addr=? terminal=? res=success'
```
