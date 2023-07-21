# Практика с SELinux

# 1. Запустить nginx на нестандартном порту 3-мя разными способами:
> переключатели setsebool;

> добавление нестандартного порта в имеющийся тип;

> формирование и установка модуля SELinux.

# 1.1 Переключатели setsebool
> Для начала проверим, что в ОС отключен файервол: systemctl status firewalld

> Разрешим в SELinux работу nginx на порту TCP 4881 c помощью переключателей setsebool

> Находим в логах (/var/log/audit/audit.log) информацию о блокировании порта

> Копируем время, в которое был записан этот лог, и, с помощью утилиты audit2why

```
audit2why < /var/log/audit/audit.log
type=AVC msg=audit(1688748432.680:531): avc:  denied  { name_bind } for  pid=2102 comm="nginx" src=4881 scontext=system_u:system_r:httpd_t:s0 tcontext=system_u:object_r:unreserved_port_t:s0 tclass=tcp_socket permissive=0

        Was caused by:
        The boolean nis_enabled was set incorrectly. 
        Description:
        Allow nis to enabled

        Allow access by executing:
        # setsebool -P nis_enabled 1
```

> Утилита audit2why покажет почему трафик блокируется. Исходя из вывода утилиты, мы видим, что нам нужно поменять параметр nis enabled.  

> Включим параметр nis_enabled и перезапустим nginx: setsebool -P nis_enabled on

```
[root@localhost ~]# setsebool -P nis_enabled on
[root@localhost ~]# systemctl restart nginx
[root@localhost ~]# systemctl status nginx
● nginx.service - The nginx HTTP and reverse proxy server
   Loaded: loaded (/usr/lib/systemd/system/nginx.service; disabled; vendor preset: disabled)
   Active: active (running) since Fri 2023-07-07 17:06:52 UTC; 9s ago
  Process: 3154 ExecStart=/usr/sbin/nginx (code=exited, status=0/SUCCESS)
  Process: 3151 ExecStartPre=/usr/sbin/nginx -t (code=exited, status=0/SUCCESS)
  Process: 3150 ExecStartPre=/usr/bin/rm -f /run/nginx.pid (code=exited, status=0/SUCCESS)
 Main PID: 3156 (nginx)
   CGroup: /system.slice/nginx.service
           ├─3156 nginx: master process /usr/sbin/nginx
           └─3158 nginx: worker process

Jul 07 17:06:52 localhost.localdomain systemd[1]: Starting The nginx HTTP and reverse proxy server...
Jul 07 17:06:52 localhost.localdomain nginx[3151]: nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
Jul 07 17:06:52 localhost.localdomain nginx[3151]: nginx: configuration file /etc/nginx/nginx.conf test is successful
Jul 07 17:06:52 localhost.localdomain systemd[1]: Started The nginx HTTP and reverse proxy server.
```
> Также можно проверить работу nginx из браузера. Заходим в любой браузер на хосте и переходим по адресу http://127.0.0.1:4881

> Проверить статус параметра можно с помощью команды: getsebool -a | grep nis_enabled

```
[root@localhost ~]# getsebool -a | grep nis_enabled
nis_enabled --> on
```
> Вернём запрет работы nginx на порту 4881 обратно. Для этого отключим nis_enabled: setsebool -P nis_enabled off
> После отключения nis_enabled служба nginx снова не запустится.

```
[root@localhost ~]# setsebool -P nis_enabled off
[root@localhost ~]# systemctl restart nginx
Job for nginx.service failed because the control process exited with error code. See "systemctl status nginx.service" and "journalctl -xe" for details.
```
> Теперь разрешим в SELinux работу nginx на порту TCP 4881 c помощью добавления нестандартного порта в имеющийся тип:

```
[root@localhost ~]# semanage port -l | grep http
http_cache_port_t              tcp      8080, 8118, 8123, 10001-10010
http_cache_port_t              udp      3130
http_port_t                    tcp      80, 81, 443, 488, 8008, 8009, 8443, 9000
pegasus_http_port_t            tcp      5988
pegasus_https_port_t           tcp      5989
```

> Добавим порт в тип http_port_t: emanage port -a -t http_port_t -p tcp 4881
```
[root@localhost ~]# semanage port -l | grep  http_port_t
http_port_t                    tcp      4881, 80, 81, 443, 488, 8008, 8009, 8443, 9000
pegasus_http_port_t            tcp      5988
```
> Теперь перезапустим службу nginx и проверим её работу: systemctl restart nginx

```
[root@localhost ~]# systemctl restart nginx
[root@localhost ~]# systemctl status nginx
● nginx.service - The nginx HTTP and reverse proxy server
   Loaded: loaded (/usr/lib/systemd/system/nginx.service; disabled; vendor preset: disabled)
   Active: active (running) since Fri 2023-07-07 17:13:20 UTC; 7s ago
  Process: 3213 ExecStart=/usr/sbin/nginx (code=exited, status=0/SUCCESS)
  Process: 3211 ExecStartPre=/usr/sbin/nginx -t (code=exited, status=0/SUCCESS)
  Process: 3210 ExecStartPre=/usr/bin/rm -f /run/nginx.pid (code=exited, status=0/SUCCESS)
 Main PID: 3215 (nginx)
   CGroup: /system.slice/nginx.service
           ├─3215 nginx: master process /usr/sbin/nginx
           └─3217 nginx: worker process

Jul 07 17:13:20 localhost.localdomain systemd[1]: Starting The nginx HTTP and reverse proxy server...
Jul 07 17:13:20 localhost.localdomain nginx[3211]: nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
Jul 07 17:13:20 localhost.localdomain nginx[3211]: nginx: configuration file /etc/nginx/nginx.conf test is successful
Jul 07 17:13:20 localhost.localdomain systemd[1]: Started The nginx HTTP and reverse proxy server.
```
> Также можно проверить работу nginx из браузера. Заходим в любой браузер на хосте и переходим по адресу http://127.0.0.1:4881

> Удалить нестандартный порт из имеющегося типа можно с помощью команды: semanage port -d -t http_port_t -p tcp 4881


```
[root@localhost ~]# semanage port -d -t http_port_t -p tcp 4881

[root@localhost ~]# 
[root@localhost ~]# semanage port -l | grep  http_port_t
http_port_t                    tcp      80, 81, 443, 488, 8008, 8009, 8443, 9000
pegasus_http_port_t            tcp      5988
```

```
[root@localhost ~]# systemctl restart nginx
Job for nginx.service failed because the control process exited with error code. See "systemctl status nginx.service" and "journalctl -xe" for details.
[root@localhost ~]# 
```

```
[root@localhost ~]# systemctl status nginx
● nginx.service - The nginx HTTP and reverse proxy server
   Loaded: loaded (/usr/lib/systemd/system/nginx.service; disabled; vendor preset: disabled)
   Active: failed (Result: exit-code) since Fri 2023-07-07 17:15:03 UTC; 30s ago
  Process: 3213 ExecStart=/usr/sbin/nginx (code=exited, status=0/SUCCESS)
  Process: 3236 ExecStartPre=/usr/sbin/nginx -t (code=exited, status=1/FAILURE)
  Process: 3235 ExecStartPre=/usr/bin/rm -f /run/nginx.pid (code=exited, status=0/SUCCESS)
 Main PID: 3215 (code=exited, status=0/SUCCESS)

Jul 07 17:15:03 localhost.localdomain systemd[1]: Stopped The nginx HTTP and reverse proxy server.
Jul 07 17:15:03 localhost.localdomain systemd[1]: Starting The nginx HTTP and reverse proxy server...
Jul 07 17:15:03 localhost.localdomain nginx[3236]: nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
Jul 07 17:15:03 localhost.localdomain nginx[3236]: nginx: [emerg] bind() to 0.0.0.0:4881 failed (13: Permission denied)
Jul 07 17:15:03 localhost.localdomain nginx[3236]: nginx: configuration file /etc/nginx/nginx.conf test failed
Jul 07 17:15:03 localhost.localdomain systemd[1]: nginx.service: control process exited, code=exited status=1
Jul 07 17:15:03 localhost.localdomain systemd[1]: Failed to start The nginx HTTP and reverse proxy server.
Jul 07 17:15:03 localhost.localdomain systemd[1]: Unit nginx.service entered failed state.
Jul 07 17:15:03 localhost.localdomain systemd[1]: nginx.service failed.
```

> Разрешим в SELinux работу nginx на порту TCP 4881 c помощью формирования и установки модуля SELinux:

> Попробуем снова запустить nginx: systemctl start nginx

```
[root@localhost ~]# systemctl start nginx
Job for nginx.service failed because the control process exited with error code. See "systemctl status nginx.service" and "journalctl -xe" for details.
```
> Nginx не запуститься, так как SELinux продолжает его блокировать. Посмотрим логи SELinux, которые относятся к nginx:

> Воспользуемся утилитой audit2allow для того, чтобы на основе логов SELinux сделать модуль, разрешающий работу nginx на нестандартном порту: 

> Audit2allow сформировал модуль, и сообщил нам команду, с помощью которой можно применить данный модуль: semodule -i nginx.pp

```
[root@localhost ~]# grep nginx /var/log/audit/audit.log | audit2allow -M nginx
******************** IMPORTANT ***********************
To make this policy package active, execute:

semodule -i nginx.pp

[root@localhost ~]# semodule -i nginx.pp
```
> Попробуем снова запустить nginx: systemctl start nginx

```
[root@localhost ~]# systemctl start nginx
[root@localhost ~]# systemctl status nginx
● nginx.service - The nginx HTTP and reverse proxy server
   Loaded: loaded (/usr/lib/systemd/system/nginx.service; disabled; vendor preset: disabled)
   Active: active (running) since Fri 2023-07-07 17:25:02 UTC; 9s ago
  Process: 1797 ExecStart=/usr/sbin/nginx (code=exited, status=0/SUCCESS)
  Process: 1795 ExecStartPre=/usr/sbin/nginx -t (code=exited, status=0/SUCCESS)
  Process: 1793 ExecStartPre=/usr/bin/rm -f /run/nginx.pid (code=exited, status=0/SUCCESS)
 Main PID: 1799 (nginx)
   CGroup: /system.slice/nginx.service
           ├─1799 nginx: master process /usr/sbin/nginx
           └─1800 nginx: worker process

Jul 07 17:25:02 localhost.localdomain systemd[1]: Starting The nginx HTTP and reverse proxy server...
Jul 07 17:25:02 localhost.localdomain nginx[1795]: nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
Jul 07 17:25:02 localhost.localdomain nginx[1795]: nginx: configuration file /etc/nginx/nginx.conf test is successful
Jul 07 17:25:02 localhost.localdomain systemd[1]: Started The nginx HTTP and reverse proxy server.
```

# Part 2

> Попробуем внести изменения в зону: nsupdate -k /etc/named.zonetransfer.key
```
[root@localhost ~]# nsupdate -k /etc/named.zonetransfer.key
> server 192.168.50.10
> zone ddns.lab
> update add www.ddns.lab. 60 A 192.168.50.15
> send
update failed: SERVFAIL
> quit
```

> Изменения внести не получилось. Давайте посмотрим логи SELinux, чтобы понять в чём может быть проблема.

> Для этого воспользуемся утилитой audit2why: cat /var/log/audit/audit.log | audit2why

```
[root@localhost ~]# sudo -i
[root@localhost ~]# cat /var/log/audit/audit.log | audit2why
[root@localhost ~]#
```

> Тут мы видим, что на клиенте отсутствуют ошибки. 

> Не закрывая сессию на клиенте, подключимся к серверу ns01 и проверим логи SELinux:
```
audit2why < /var/log/audit/audit.log
type=AVC msg=audit(1688748432.680:531): avc:  denied  { create } for  pid=4402 comm="isc-worker0000" name="named.ddns.lab.view1.jnl" scontext=system_u:system_r:named_t:s0 tcontext=system_u:object_r:etc_t:s0 tclass=file permissive=0

        Was caused by:
                Missing type enforcement (TE) allow rule.


                You can use audit2allow to generate a loadable module to allow this access.
```

> В логах мы видим, что ошибка в контексте безопасности. Вместо типа named_t используется тип etc_t.
> Проверим данную проблему в каталоге /etc/named:

```
[root@localhost ~]# ls -laZ /etc/named
drw-rwx---. root named system_u:object_r:etc_t:s0       .
drwxr-xr-x. root root  system_u:object_r:etc_t:s0       ..
drw-rwx---. root named unconfined_u:object_r:etc_t:s0   dynamic
-rw-rw----. root named system_u:object_r:etc_t:s0       named.50.168.192.rev
-rw-rw----. root named system_u:object_r:etc_t:s0       named.dns.lab
-rw-rw----. root named system_u:object_r:etc_t:s0       named.dns.lab.view1
-rw-rw----. root named system_u:object_r:etc_t:s0       named.newdns.lab
```

> Тут мы также видим, что контекст безопасности неправильный.

> Проблема заключается в том, что конфигурационные файлы лежат в другом каталоге.

> Посмотреть в каком каталоги должны лежать, файлы, чтобы на них распространялись правильные политики SELinux можно с помощью команды:

> sudo semanage fcontext -l | grep named

```
[root@localhost ~]# sudo semanage fcontext -l | grep named
        /etc/rndc.*              regular file       system_u:object_r:named_conf_t:s0 
        /var/named(/.*)?         all files          system_u:object_r:named_zone_t:s0 
```

> Изменим тип контекста безопасности для каталога /etc/named: sudo chcon -R -t named_zone_t /etc/named

```
[root@localhost ~]# sudo chcon -R -t named_zone_t /etc/named
[root@localhost ~]#
[root@localhost ~]# ls -laZ /etc/named
drw-rwx---. root named system_u:object_r:named_zone_t:s0 .
drwxr-xr-x. root root  system_u:object_r:etc_t:s0       ..
drw-rwx---. root named unconfined_u:object_r:named_zone_t:s0 dynamic
-rw-rw----. root named system_u:object_r:named_zone_t:s0 named.50.168.192.rev
-rw-rw----. root named system_u:object_r:named_zone_t:s0 named.dns.lab
-rw-rw----. root named system_u:object_r:named_zone_t:s0 named.dns.lab.view1
-rw-rw----. root named system_u:object_r:named_zone_t:s0 named.newdns.lab
[root@ns01 ~]# 
```

> Попробуем снова внести изменения с клиента: 

```
[root@localhost ~]# nsupdate -k /etc/named.zonetransfer.key
> server 192.168.50.10
> zone ddns.lab
> update add www.ddns.lab. 60 A 192.168.50.15
> send
> quit 

[root@localhost ~]# dig www.ddns.lab
; <<>> DiG 9.11.4-P2-RedHat-9.11.4-26.P2.el7_9.7 <<>> www.ddns.lab
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 6345
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 1, ADDITIONAL: 2


;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
;; QUESTION SECTION:
;www.ddns.lab.          IN  A


;; ANSWER SECTION:
www.ddns.lab.       60  IN  A   192.168.50.15


;; AUTHORITY SECTION:
ddns.lab.       3600    IN  NS  ns01.dns.lab.


;; ADDITIONAL SECTION:
ns01.dns.lab.       3600    IN  A   192.168.50.10


;; Query time: 1 msec
;; SERVER: 192.168.50.10#53(192.168.50.10)
;; WHEN: Fri Jul 21 18:34:41 UTC 2023
;; MSG SIZE  rcvd: 96
```

> Видим, что изменения применились. Попробуем перезагрузить хосты и ещё раз сделать запрос с помощью dig: 

```
[root@localhost ~]# dig @192.168.50.10 www.ddns.lab
; <<>> DiG 9.11.4-P2-RedHat-9.11.4-26.P2.el7_9.7 <<>> @192.168.50.10 www.ddns.lab
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 52392
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 1, ADDITIONAL: 2


;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
;; QUESTION SECTION:
;www.ddns.lab.          IN  A


;; ANSWER SECTION:
www.ddns.lab.       60  IN  A   192.168.50.15


;; AUTHORITY SECTION:
ddns.lab.       3600    IN  NS  ns01.dns.lab.


;; ADDITIONAL SECTION:
ns01.dns.lab.       3600    IN  A   192.168.50.10


;; Query time: 2 msec
;; SERVER: 192.168.50.10#53(192.168.50.10)
;; WHEN: Fri Jul 21 18:40:32 UTC 2023

```
> Всё правильно. После перезагрузки настройки сохранились. 
