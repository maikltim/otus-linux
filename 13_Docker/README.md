# 1. Создайте свой кастомный образ nginx на базе alpine. После запуска nginx должен отдавать кастомную страницу (достаточно изменить дефолтную страницу nginx) 

> Директория nginx-alpine послужила build контекстом для создания образа maikltim/nginx:v1
>  (ссылка на Docker Hub: https://hub.docker.com/r/maikltim/nginx)

> Для проверки задания выполнить sudo docker run -d -p 81:80 --name nginx -d --rm maikltim/nginx:v1 и перейти на страницу localhost в браузере. 

# Ответы на вопросы

```
Q: Определите разницу между контейнером и образом.
A: Образ - это файл, включающий зависимости, сведения, конфигурацию для дальнейшего развертывания и инициализации контейнера.
По сути это read-only шаблон с инструкциями для создания контейнера.
Контейнер - это работающий (выполняющийся) экземпляр образа, который включает в себя все необходимое,
 для запуска внутри какго-либо приложения (код приложения, среду выполнения, библиотеки, настройки и т.д)

Q: Можно ли в контейнере собрать ядро?
A: Да, можно, как и любую программу из исходников.
```

> В ходе выполнения ДЗ для написания докерфайлов и конфигов пользовался следующими источниками:

> https://wiki.alpinelinux.org/wiki/Nginx
