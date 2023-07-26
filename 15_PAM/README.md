# HW-15 PAM

# Цель домашнего задания

> Научиться создавать пользователей и добавлять им ограничения 

# 1. Запретить всем пользователям, кроме группы admin логин в выходные (суббота и воскресенье), без учета праздников


> Для выполения первой части ДЗ был использован модуль pam_exec.so и написан скрипт pam_script.sh
> создан тестовый пользователь test_admin входящий в группу admin

> Для выполения второй части ДЗ была использована библиотека PolKit
> созданный тестовый пользователь test_docker входящий в группы docker и admin, написано правило, позволяющее только перезагружать только docker сервис

# Настройка запрета для всех пользователей (кроме группы Admin) логина в выходные дни (Праздники не учитываются)
> Подключаемся к нашей созданной ВМ: vagrant ssh
> Переходим в root-пользователя: sudo -i
> Создаём пользователя otusadm и otus: sudo useradd otusadm && sudo useradd otus
> Создаём пользователям пароли: echo "Otus2022!" | sudo passwd --stdin otusadm && echo "Otus2022!" | sudo passwd --stdin otus
> Для примера мы указываем одинаковые пароли для пользователя otus и otusadm
> Создаём группу admin: sudo groupadd -f admin
> Добавляем пользователей vagrant,root и otusadm в группу admin:
> usermod otusadm -a -G admin && usermod root -a -G admin && usermod vagrant -a -G admin
> Обратите внимание, что мы просто добавили пользователя otusadm в группу admin. Это не делает пользователя otusadm администратором.
> После создания пользователей, нужно проверить, что они могут подключаться по SSH к нашей ВМ. Для этого пытаемся подключиться с хостовой машины: 
> Далее вводим наш созданный пароль  
> Если всё настроено правильно, на этом моменте мы сможет подключиться по SSH под пользователем otus и otusadm

```
ssh otus@192.168.11.11
otus@192.168.11.11's password: 
[otus@pam ~]$ whoami
otus
[otus@pam ~]$ exit
logout
Connection to 192.168.11.11 closed
```

> Далее настроим правило, по которому все пользователи кроме тех, что указаны в группе admin не смогут подключаться в выходные дни:
> Проверим, что пользователи root, vagrant и otusadm есть в группе admin:
```
[root@pam ~]# cat /etc/group | grep admin
printadmin:x:994:
admin:x:1003:otusadm,root,vagrant
```
> Информация о группах и пользователях в них хранится в файле /etc/group, пользователи указываются через запятую. 
> Создадим файл-скрипт /usr/local/bin/login.sh
> Добавим права на исполнение файла: chmod +x /usr/local/bin/login.sh
> Укажем в файле /etc/pam.d/sshd модуль pam_exec и наш скрипт:
```
vi /etc/pam.d/sshd 


#%PAM-1.0
auth       substack     password-auth
auth       include      postlogin
account    required     pam_nologin.so
account    required     pam_exec.so /usr/local/bin/login.sh
account    include      password-auth
password   include      password-auth
# pam_selinux.so close should be the first session rule
session    required     pam_selinux.so close
session    required     pam_loginuid.so
# pam_selinux.so open should only be followed by sessions to be executed in the user context
session    required     pam_selinux.so open env_params
session    required     pam_namespace.so
session    optional     pam_keyinit.so force revoke
session    optional     pam_motd.so
session    include      password-auth
session    include      postlogin
```
> Если Вы выполняете данную работу в выходные, то можно сразу попробовать подключиться к нашей ВМ.
> Если нет, тогда можно руками поменять время в нашей ОС, например установить 29 июля 2023 года (Суббота):
```
[root@pam ~]# sudo date 072912302023.00
Sat Jul 29 12:30:00 UTC 2023
```


