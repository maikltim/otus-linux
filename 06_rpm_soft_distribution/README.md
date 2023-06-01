# HW6 - Размещение своего RPM в своем репозитории

# Описание

> Создадим свой RPM пакет на основе nginx с поддержкой openssl
> Создадим свой репозиторий и разместим там ранее собранный RPM

# Выполнение

> Для данного задания нам понадобятся следующие установленные пакеты

```
yum install -y redhat-lsb-core wget rpmdevtools rpm-build createrepo yum-utils gcc perl-IPC-Cmd perl-Data-Dumper
```

> Для примера возьмем пакет NGINX и соберем его с поддержкой openssl
> Загрузим SRPM пакет NGINX для дальнейшей работы над ним
> При установке такого пакета в домашней директории создается древо каталогов для сборки

```
wget https://nginx.org/packages/centos/7/SRPMS/nginx-1.20.2-1.el7.ngx.src.rpm
rpm -i nginx-1.20.2-1.el7.ngx.src.rpm
```

> Также нужно скачать и разархивировать исходники для openssl - они потребуются при сборке

```
wget --no-check-certificate https://www.openssl.org/source/openssl-3.0.0.tar.gz
tar -xvf openssl-3.0.0.tar.gz
```

> Заранее поставим все зависимости чтобы в процессе сборки не было ошибок

```
yum-builddep -y rpmbuild/SPECS/nginx.spec
```
> yum-builddep -y rpmbuild/SPECS/nginx.spec 

> Ну и собственно поправим сам spec файл, чтобы NGINX собирался с необходимыми нам опциями: --with-openssl=/root/openssl-3.0.0

> vi rpmbuild/SPECS/nginx.spec

```
./configure %{BASE_CONFIGURE_ARGS} \
    --with-cc-opt="%{WITH_CC_OPT}" \
    --with-ld-opt="%{WITH_LD_OPT}" \
    --with-openssl=/root/openssl-3.0.0 \
    --with-debug
```
> Теперь можно приступить к сборке RPM пакета

```
rpmbuild -bb rpmbuild/SPECS/nginx.spec
Проверка на неупакованный(е) файл(ы): /usr/lib/rpm/check-files /root/rpmbuild/BUILDROOT/nginx-1.20.2-1.el7.ngx.x86_64
Записан: /root/rpmbuild/RPMS/x86_64/nginx-1.20.2-1.el7.ngx.x86_64.rpm
Записан: /root/rpmbuild/RPMS/x86_64/nginx-debuginfo-1.20.2-1.el7.ngx.x86_64.rpm
Выполняется(%clean): /bin/sh -e /var/tmp/rpm-tmp.XycBrF
+ umask 022
+ cd /root/rpmbuild/BUILD
+ cd nginx-1.20.2
+ /usr/bin/rm -rf /root/rpmbuild/BUILDROOT/nginx-1.20.2-1.el7.ngx.x86_64
+ exit 0
```

> Убедимся, что пакеты создались
```
ll rpmbuild/RPMS/x86_64/
total 4756
-rw-r--r--. 1 root root 2816316 Jun  1 12:14 nginx-1.20.2-1.el7.ngx.x86_64.rpm
-rw-r--r--. 1 root root 2048064 Jun  1 12:14 nginx-debuginfo-1.20.2-1.el7.ngx.x86_64.rpm
```

> Теперь можно установить наш пакет и убедиться, что nginx работает
```
yum localinstall -y rpmbuild/RPMS/x86_64/nginx-1.20.2-1.el7.ngx.x86_64.rpm
Installed:
  nginx.x86_64 1:1.20.2-1.el7.nginx

Complete!
```

> стартуем

```
systemctl enable nginx
systemctl start nginx
systemctl status nginx
● nginx.service - nginx - high performance web server
   Loaded: loaded (/usr/lib/systemd/system/nginx.service; enabled; vendor preset: disabled)
   Active: active (running) since Don 2023-06-01 12:16:54 UTC; 8s ago
     Docs: http://nginx.org/en/docs/
  Process: 21068 ExecStart=/usr/sbin/nginx -c /etc/nginx/nginx.conf (code=exited, status=0/SUCCESS)
 Main PID: 21069 (nginx)
   CGroup: /system.slice/nginx.service
           ├─21069 nginx: master process /usr/sbin/nginx -c /etc/nginx/nginx.conf
           ├─21070 nginx: worker process
           └─21071 nginx: worker process

Jun 01 12:16:54 localhost.localdomain systemd[1]: Starting nginx - high performance web server...
Jun 01 12:16:54 localhost.localdomain systemd[1]: Started nginx - high performance web server.
```

> Теперь приступим к созданию своего репозитория. Директория для статики у NGINX по умолчанию /usr/share/nginx/html. Создадим там каталог repo

```
mkdir /usr/share/nginx/html/repo
```

> Копируем туда наш собранный RPM и, например, RPM для установки репозитория Percona-Server

```
cp rpmbuild/RPMS/x86_64/nginx-1.20.2-1.el7.ngx.x86_64.rpm /usr/share/nginx/html/repo/
```

```
wget https://downloads.percona.com/downloads/percona-release/percona-release-1.0-9/redhat/percona-release-1.0-9.noarch.rpm -O /usr/share/nginx/html/repo/percona-release-1.0-9.noarch.rpm
Сохранение в: «/usr/share/nginx/html/repo/percona-release-1.0-9.noarch.rpm»

100%[====================================================================================================================================================>] 16'664      --.-K/s   за 0.08s   

2023-06-01 12:17:56 (196 KB/s) - «/usr/share/nginx/html/repo/percona-release-1.0-9.noarch.rpm» сохранён [16664/16664]
```

> Инициализируем репозиторий командой

```
createrepo -v /usr/share/nginx/html/repo
Spawning worker 0 with 1 pkgs
Spawning worker 1 with 1 pkgs
Worker 0: reading nginx-1.20.2-1.el7.ngx.x86_64.rpm
Worker 1: reading percona-release-1.0-9.noarch.rpm
Workers Finished
Saving Primary metadata
Saving file lists metadata
Saving other metadata
Generating sqlite DBs
Starting other db creation: Thu Jun  1 12:18:10 2023
Ending other db creation: Thu Jun  1 12:18:10 2023
Starting filelists db creation: Thu Jun  1 12:18:10 2023
Ending filelists db creation: Thu Jun  1 12:18:10 2023
Starting primary db creation: Thu Jun  1 12:18:10 2023
Ending primary db creation: Thu Jun  1 12:18:11 2023
Sqlite DBs complete
```

> Для прозрачности настроим в NGINX доступ к листингу каталога
> В location / в файле /etc/nginx/conf.d/default.conf добавим директиву autoindex on. В результате location будет выглядеть так

> vi /etc/nginx/conf.d/default.conf

```
location / {
        root   /usr/share/nginx/html;
        index  index.html index.htm;
        autoindex on;
    }
```

> Проверяем синтаксис и перезапускаем NGINX

```
nginx -t
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful

nginx -s reload
```

> Теперь ради интереса можно посмотреть в браузере или выполнить curl

```
curl -a http://localhost/repo/
<html>
<head><title>Index of /repo/</title></head>
<body>
<h1>Index of /repo/</h1><hr><pre><a href="../">../</a>
<a href="repodata/">repodata/</a>                                          01-Jun-2023 12:18                   -
<a href="nginx-1.20.2-1.el7.ngx.x86_64.rpm">nginx-1.20.2-1.el7.ngx.x86_64.rpm</a>                  01-Jun-2023 12:17             2816316
<a href="percona-release-1.0-9.noarch.rpm">percona-release-1.0-9.noarch.rpm</a>                   11-Nov-2020 21:49               16664
</pre><hr></body>
</html>
```

> Все готово для того, чтобы протестировать репозиторий
> Добавим его в /etc/yum.repos.d

```
cat >> /etc/yum.repos.d/otus.repo << EOF
> [OTUS]
> name=otus-linux
> baseurl=http://localhost/repo
> gpgcheck=0
> enabled=1
> EOF
```
> Убедимся, что репозиторий подключился и посмотрим что в нем есть

```
yum repolist enabled | grep otus
OTUS                                otus-linux                                 2
yum list | grep nginx
nginx.x86_64                                1:1.20.2-1.el7.ngx         @/nginx-1.20.2-1.el7.ngx.x86_64
pcp-pmda-nginx.x86_64                       4.3.2-13.el7_9             updates  
```

> Так как NGINX у нас уже стоит, установим репозиторий percona-release

```
yum install percona-release -y
Installed:
  percona-release.noarch 0:1.0-9                                                                                                                                                              

Complete!
```

> Все прошло успешно. В случае если нам потребуется обновить репозиторий 
> (а это делается при каждом добавлении файлов) снова, то выполним команду createrepo /usr/share/nginx/html/repo/