audit2why < /var/log/audit/audit.log
type=AVC msg=audit(1688748432.680:531): avc:  denied  { name_bind } for  pid=2102 comm="nginx" src=4881 scontext=system_u:system_r:httpd_t:s0 tcontext=system_u:object_r:unreserved_port_t:s0 tclass=tcp_socket permissive=0

        Was caused by:
        The boolean nis_enabled was set incorrectly. 
        Description:
        Allow nis to enabled

        Allow access by executing:
        # setsebool -P nis_enabled 1

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

```
[root@localhost ~]# getsebool -a | grep nis_enabled
nis_enabled --> on
```

```
[root@localhost ~]# setsebool -P nis_enabled off
[root@localhost ~]# systemctl restart nginx
Job for nginx.service failed because the control process exited with error code. See "systemctl status nginx.service" and "journalctl -xe" for details.
```

```
[root@localhost ~]# systemctl restart nginx
Job for nginx.service failed because the control process exited with error code. See "systemctl status nginx.service" and "journalctl -xe" for details.
[root@localhost ~]# ^C
[root@localhost ~]# semanage port -l | grep http
http_cache_port_t              tcp      8080, 8118, 8123, 10001-10010
http_cache_port_t              udp      3130
http_port_t                    tcp      80, 81, 443, 488, 8008, 8009, 8443, 9000
pegasus_http_port_t            tcp      5988
pegasus_https_port_t           tcp      5989
```

```
[root@localhost ~]# semanage port -l | grep  http_port_t
http_port_t                    tcp      4881, 80, 81, 443, 488, 8008, 8009, 8443, 9000
pegasus_http_port_t            tcp      5988
```

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
```
[root@localhost ~]# systemctl start nginx
Job for nginx.service failed because the control process exited with error code. See "systemctl status nginx.service" and "journalctl -xe" for details.
```

```
[root@localhost ~]# grep nginx /var/log/audit/audit.log | audit2allow -M nginx
******************** IMPORTANT ***********************
To make this policy package active, execute:

semodule -i nginx.pp

[root@localhost ~]# semodule -i nginx.pp
```

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

```
# Part 2
; <<>> DiG 9.11.4-P2-RedHat-9.11.4-26.P2.el7_9.13 <<>> www.ddns.lab
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NXDOMAIN, id: 63282
;; flags: qr rd ra; QUERY: 1, ANSWER: 0, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 65494
;; QUESTION SECTION:
;www.ddns.lab.                  IN      A
```