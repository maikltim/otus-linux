Обновление ядра в базовой системе

Посмотрим на версию ядра.

[vagrant@localhost ~]$ uname -r
3.10.0-862.2.3.el7.x86_64

Подключаем репозиторий, откуда возьмем необходимую версию ядра.

sudo yum install -y http://www.elrepo.org/elrepo-release-7.0-3.el7.elrepo.noarch.rpm
В репозитории есть две версии ядер kernel-ml и kernel-lt. Первая является наиболее свежей стабильной версией, вторая это стабильная версия с длительной поддержкой, но менее свежая, чем первая. В данном случае ядро 5й версии будет в kernel-ml.

Поскольку мы ставим ядро из репозитория, то установка ядра похожа на установку любого другого пакета, но потребует явного включения репозитория при помощи ключа --enablerepo.

Ставим последнее ядро:

[vagrant@localhost ~]$ sudo yum --enablerepo elrepo-kernel install kernel-ml -y
Running transaction
  Installing : kernel-ml-6.3.1-1.el7.elrepo.x86_64                                                                                                         1/1 
  Verifying  : kernel-ml-6.3.1-1.el7.elrepo.x86_64                                                                                                         1/1 

Installed:
  kernel-ml.x86_64 0:6.3.1-1.el7.elrepo                                                                                                                        

Complete!


GRUB UPDATE
После успешной установки нам необходимо сказать системе, что при загрузке нужно использовать новое ядро. В случае обновления ядра на рабочих серверах необходимо перезагрузиться с новым ядром, выбрав его при загрузке. И только при успешно прошедших загрузке нового ядра и тестах сервера переходить к загрузке с новым ядром по-умолчанию. В тестовой среде можно обойти данный этап и сразу назначить новое ядро по-умолчанию.

Обновляем конфигурацию загрузчика:

[vagrant@localhost ~]$ sudo grub2-mkconfig -o /boot/grub2/grub.cfg
Generating grub configuration file ...
Found linux image: /boot/vmlinuz-6.3.1-1.el7.elrepo.x86_64
Found initrd image: /boot/initramfs-6.3.1-1.el7.elrepo.x86_64.img
Found linux image: /boot/vmlinuz-3.10.0-862.2.3.el7.x86_64
Found initrd image: /boot/initramfs-3.10.0-862.2.3.el7.x86_64.img
done


Выбираем загрузку с новым ядром по-умолчанию:

[vagrant@localhost ~]$ sudo grub2-set-default 0

Перезагружаем виртуальную машину:

[vagrant@localhost ~]$ sudo reboot

После перезагрузки виртуальной машины (3-4 минуты, зависит от мощности хостовой машины) заходим в нее и выполняем:

[vagrant@localhost ~]$ uname -r
6.3.1-1.el7.elrepo.x86_64


Packer 

Теперь необходимо создать свой образ системы, с уже установленым ядром 5й версии. Для это воспользуемся ранее установленной утилитой packer. В директории packer есть все необходимые настройки и скрипты для создания необходимого образа системы.

Создаем переменные (variables) с версией и названием нашего проекта (artifact):

    "artifact_description": "CentOS 7.9 - 5.15",
    "artifact_version": "7.9.2009",


В секции builders задаем исходный образ, для создания своего в виде ссылки и контрольной суммы. Параметры подключения к создаваемой виртуальной машине.

      "iso_checksum": "sha256:07b94e6b1a0b0260b94c83d6bb76b26bf7a310dc78d7a9c7432809fb9bc6194a",
      "iso_url": "http://mirror.corbina.net/pub/Linux/centos/7.9.2009/isos/x86_64/CentOS-7-x86_64-Minimal-2009.iso",
В секции post-processors указываем имя файла, куда будет сохранен образ, в случае успешной сборки

      "output": "centos-{{user `artifact_version`}}-kernel-5-x86_64-Minimal.box",


В секции provisioners указываем каким образом и какие действия необходимо произвести для настройки виртуальой машины. Именно в этой секции мы и обновим ядро системы, чтобы можно было получить образ с 5й версией ядра. Настройка системы выполняется несколькими скриптами, заданными в секции scripts.

    "scripts" : 
      [
        "scripts/stage-1-kernel-update.sh",
        "scripts/stage-2-clean.sh"
      ] 


Для создания образа системы достаточно перейти в директорию packer и в ней выполнить команду:

packer build centos.json 

==> Wait completed after 24 minutes 34 seconds

==> Builds finished. The artifacts of successful builds are:
--> centos-7.9: 'virtualbox' provider box: centos-7.9.2009-kernel-5-x86_64-Minimal.box

После создания образа, его рекомендуется проверить. Для проверки  импортируем полученный vagrant box в Vagrant: 
vagrant box add centos-7.9.2009-kernel-5-x86_64-Minimal.box 

Проверим, что образ теперь есть в списке имеющихся образов vagrant:
packer vagrant box list
centos-7-9      (virtualbox, 0)


Создадим Vagrantfile на основе образа centos-7-9:
vagrant init centos_7.9_kernel

В каталоге packer появится Vagrantfile 
Запустим нашу ВМ: vagrant up 
Подключимя к ней по SSH: vagrant ssh 
Проверим версию ядра: 
[vagrant@otus-c8 ~]$ uname -r
6.3.1-1.el7.elrepo.x86_64