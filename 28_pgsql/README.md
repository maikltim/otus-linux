# Репликация м бэкап PostgreSQL

# 1. Создадим Vagrantfile, в котором будут указаны параметры наших ВМ


```
# Описание параметров ВМ
MACHINES = {
  # Имя DV "pam"
  :node1 => {
        # VM box
        :box_name => "centos/stream8",
        # Имя VM
        :vm_name => "node1",
        # Количество ядер CPU
        :cpus => 2,
        # Указываем количество ОЗУ (В Мегабайтах)
        :memory => 2048,
        # Указываем IP-адрес для ВМ
        :ip => "192.168.57.11",
  },
  :node2 => {
        :box_name => "centos/stream8",
        :vm_name => "node2",
        :cpus => 2,
        :memory => 2048,
        :ip => "192.168.57.12",

  },
  :barman => {
        :box_name => "centos/stream8",
        :vm_name => "barman",
        :cpus => 2,
        :memory => 2048,
        :ip => "192.168.57.13",

  },

}

Vagrant.configure("2") do |config|

  MACHINES.each do |boxname, boxconfig|
    
    config.vm.define boxname do |box|
   
      box.vm.box = boxconfig[:box_name]
      box.vm.host_name = boxconfig[:vm_name]
      box.vm.network "private_network", ip: boxconfig[:ip]
      box.vm.provider "virtualbox" do |v|
        v.memory = boxconfig[:memory]
        v.cpus = boxconfig[:cpus]
      end

      # Запуск ansible-playbook
      if boxconfig[:vm_name] == "barman"
       box.vm.provision "ansible" do |ansible|
        ansible.playbook = "ansible/provision.yml"
        ansible.inventory_path = "ansible/hosts"
        ansible.host_key_checking = "false"
        ansible.limit = "all"
       end
      end
    end
  end
end
```

# 2. Настройка hot_standby репликации с использованием слотов с помощью ansible

> В каталоге с нашей лабораторной работой создадим каталог Ansible: mkdir ansible В каталоге ansible создадим файл hosts со следующими параметрами:

```
[servers]
node1 ansible_host=192.168.57.11 ansible_user=vagrant ansible_ssh_private_key_file=./.vagrant/machines/node1/virtualbox/private_key 
node2 ansible_host=192.168.57.12 ansible_user=vagrant ansible_ssh_private_key_file=./.vagrant/machines/node2/virtualbox/private_key 
barman ansible_host=192.168.57.13 ansible_user=vagrant ansible_ssh_private_key_file=./.vagrant/machines/barman/virtualbox/private_key
```

> Далее создадим файл provision.yml в котором непосредственно будет выполняться настройка клиентов:

```
- name: Postgres
  hosts: all
  become: yes
  tasks:
  #Устанавливаем vim и telnet (для более удобной работы с хостами)
  - name: install base tools
    dnf:
      name:
        - vim
        - telnet
      state: present
      update_cache: true

#Запуск ролей install_postgres и postgres_replication на хостах node1 и node2
- name: install postgres 14 and set up replication
  hosts: node1,node2
  become: yes
  roles:
   - install_postgres
   - postgres_replication

#Запуск роли install_barman на всех хостах
- name: set up backup
  hosts: all
  become: yes
  roles:
   - install_barman
```

> Перейдем в папку ansible и создадим папку roles. Создадим роль install_postgres:


```
cd ansible&&mkdir roles&&cd roles
ansible-galaxy init install_postgres
```

> В каталоге tasks создаём файл main.yml и добавляем в него следующее содержимое:

```
---
# Отключаем firewalld и удаляем его из автозагрузки
  - name: disable firewalld service
    service:
      name: firewalld
      state: stopped
      enabled: false
  
  # Отключаем SElinux 
  - name: Disable SELinux
    selinux:
      state: disabled
  
  # Отключаем SElinux после перезагрузки
  - name: Ensure SELinux is set to disable mode
    lineinfile:
      path: /etc/selinux/config
      regexp: '^SELINUX='
      line: SELINUX=disabled


  - name: Импорт GPG-ключа PostgreeSql
    ansible.builtin.rpm_key:
      state: present
      key: https://download.postgresql.org/pub/repos/yum/RPM-GPG-KEY-PGDG-14
    

  # Добавляем репозиторий postgres
  - name: install repo
    dnf:
      name: 'https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm'
      state: present
  
  # Отключаем старый модуль
  - name: disable old postgresql module
    shell: dnf -qy module disable postgresql
  
  # Устанавливаем postgresql14-server
  - name: install postgresql-server 14
    dnf: 
      name: postgresql14-server
      state: present
      update_cache: true
  
  # Проверяем, что postgres на хосте ещё не инициализирован
  - name: check init 
    stat:
      path: /var/lib/pgsql/14/data/pg_stat
    register: stat_result

  # Выполняем инициализацию postgres
  - name: initialization setup
    shell: sudo /usr/pgsql-14/bin/postgresql-14-setup initdb
    when: not stat_result.stat.exists
  
  # Запускаем postgresql-14
  - name: enable and start service
    service:
      name: postgresql-14
      state: started
      enabled: true
```

> Далее, создаём роль postgres_replication:

```
ansible-galaxy init postgres_replication
```

> В каталоге defaults создаём файл main.yml со следующими переменными:

```
---
# defaults file for postgres_replication
replicator_password: 'Otus2022!'
master_ip: '192.168.57.11'
slave_ip: '192.168.57.12'
```

> В каталоге templates создадим файлы:

> pg_hba.conf.j2:

```
# TYPE  DATABASE        USER            ADDRESS                 METHOD
# "local" is for Unix domain socket connections only
local   all                  all                                                peer
# IPv4 local connections:
host    all                  all             127.0.0.1/32              scram-sha-256
# IPv6 local connections:
host    all                  all             ::1/128                       scram-sha-256
# Allow replication connections from localhost, by a user with the
# replication privilege.
local   replication      all                                                peer
host    replication     all             127.0.0.1/32               scram-sha-256
host    replication     all             ::1/128                        scram-sha-256
host    replication replication    {{ master_ip }}/32        scram-sha-256
host    replication replication    {{ slave_ip }}/32        scram-sha-256
```

> postgresql.conf.j2:


```
#Указываем ip-адреса, на которых postgres будет слушать трафик на порту 5432 (параметр port)
listen_addresses = 'localhost, {% if ansible_hostname == "node1" %}{{ master_ip }}{% else %}{{ slave_ip }}{% endif %}'
#Указываем порт порт postgres
port = 5432 
#Устанавливаем максимально 100 одновременных подключений
max_connections = 100
log_directory = 'log' 
log_filename = 'postgresql-%a.log' 
log_rotation_age = 1d 
log_rotation_size = 0 
log_truncate_on_rotation = on 
max_wal_size = 1GB
min_wal_size = 80MB
log_line_prefix = '%m [%p] ' 
#Указываем часовой пояс для Москвы
log_timezone = 'UTC+3'
timezone = 'UTC+3'
datestyle = 'iso, mdy'
lc_messages = 'en_US.UTF-8'
lc_monetary = 'en_US.UTF-8' 
lc_numeric = 'en_US.UTF-8' 
lc_time = 'en_US.UTF-8' 
default_text_search_config = 'pg_catalog.english'
#можно или нет подключаться к postgresql для выполнения запросов в процессе восстановления; 
hot_standby = on
#Включаем репликацию
wal_level = replica
#Количество планируемых слейвов
max_wal_senders = 3
#Максимальное количество слотов репликации
max_replication_slots = 3
#будет ли сервер slave сообщать мастеру о запросах, которые он выполняет.
hot_standby_feedback = on
#Включаем использование зашифрованных паролей
password_encryption = scram-sha-256
```

> В каталоге tasks создаём файл main.yml со следующим содержимым:

```
---
# Установка python-пакетов для модулей psql
  - name: install base tools
    dnf:
      name:
        - python3-pexpect.noarch
        - python3-psycopg2
      state: present
      update_cache: true

#CREATE USER replicator WITH REPLICATION Encrypted PASSWORD 'Otus2022!';
  - name: Create replicator user
    become_user: postgres
    postgresql_user:
      name: replication
      password: '{{ replicator_password }}'
      role_attr_flags: REPLICATION 
    ignore_errors: true
    when: (ansible_hostname == "node1")

  #Остановливаем postgresql-14 на хосте node2
  - name: stop postgresql-server on node2
    service: 
      name: postgresql-14
      state: stopped
    when: (ansible_hostname == "node2")

  #Копиуем конфигурационный файл postgresql.conf
  - name: copy postgresql.conf
    template:
      src: postgresql.conf.j2
      dest: /var/lib/pgsql/14/data/postgresql.conf
      owner: postgres
      group: postgres
      mode: '0600'
    when: (ansible_hostname == "node1")
  
  #Копиуем конфигурационный файл pg_hba.conf
  - name: copy pg_hba.conf
    template:
      src: pg_hba.conf.j2
      dest: /var/lib/pgsql/14/data/pg_hba.conf
      owner: postgres
      group: postgres
      mode: '0600'
    when: (ansible_hostname == "node1")
   #Перезапускаем службу  postgresql-14
  - name: restart postgresql-server on node1
    service: 
      name: postgresql-14
      state: restarted
    when: (ansible_hostname == "node1")

  #Удаляем содержимое каталога /var/lib/pgsql/14/data/
  - name: Remove files from data catalog
    file:
      path: /var/lib/pgsql/14/data/
      state: absent
    when: (ansible_hostname == "node2")

  #Копируем данные с node1 на node2
  - name: copy files from master to slave
    become_user: postgres
    expect:
      command: 'pg_basebackup -h {{ master_ip }} -U  replication -p 5432 -D /var/lib/pgsql/14/data/ -R -P'
      responses: 
        '.*Password*': "{{ replicator_password }}"
    when: (ansible_hostname == "node2")

  #Копируем конфигурационный файл postgresql.conf
  - name: copy postgresql.conf
    template:
      src: postgresql.conf.j2
      dest: /var/lib/pgsql/14/data/postgresql.conf
      owner: postgres
      group: postgres
      mode: '0600'
    when: (ansible_hostname == "node2")

  #Копируем конфигурационный файл pg_hba.conf
  - name: copy pg_hba.conf
    template:
      src: pg_hba.conf.j2
      dest: /var/lib/pgsql/14/data/pg_hba.conf
      owner: postgres
      group: postgres
      mode: '0600'
    when: (ansible_hostname == "node2")
   
  #Запускаем службу postgresql-14 на хосте node2
  - name: start postgresql-server on node2
    service: 
      name: postgresql-14
      state: started
    when: (ansible_hostname == "node2")
```


# 3. Настройка резервного копирования с помощью Ansible

> Cоздаём роль install_barman:

```
Cоздаём роль install_barman:
```

> В каталоге defaults создаём файл main.yml со следующими переменными:

```
---
# defaults file for install_barman
master_ip: '192.168.57.11'
master_user: 'postgres'
barman_ip: '192.168.57.13'
barman_user: 'barman'
barman_user_password: 'Otus2022!'
```

> В каталоге templates создадим файлы: .pgpass.j2:

```
{{ master_ip }}:5432:*:barman:{{ barman_user_password }}
```

> barman.conf.j2:

```
[barman]
#Указываем каталог, в котором будут храниться бекапы
barman_home = /var/lib/barman
#Указываем каталог, в котором будут храниться файлы конфигурации бекапов
configuration_files_directory = /etc/barman.d
#пользователь, от которого будет запускаться barman
barman_user = {{ barman_user }}
#расположение файла с логами
log_file = /var/log/barman/barman.log
#Используемый тип сжатия
compression = gzip
#Используемый метод бекапа
backup_method = rsync
archiver = on
retention_policy = REDUNDANCY 3
immediate_checkpoint = true
#Глубина архива
last_backup_maximum_age = 4 DAYS
minimum_redundancy = 1
```

> В каталоге tasks создаём файл main.yml со следующим содержимым:

```
---
# Установка необходимых пакетов для работы с postgres и пользователями
  - name: install base tools
    dnf:
      name:
        - python3-pexpect.noarch
        - python3-psycopg2
        - bash-completion 
        - wget 
      state: present
      update_cache: true

  # Отключаем firewalld и удаляем его из автозагрузки
  - name: disable firewalld service
    service:
      name: firewalld
      state: stopped
      enabled: false
    when: (ansible_hostname == "barman")

   # Отключаем SElinux
  - name: Disable SELinux
    selinux:
      state: disabled
    when: (ansible_hostname == "barman")

  - name: Ensure SELinux is set to disable mode
    lineinfile:
      path: /etc/selinux/config
      regexp: '^SELINUX='
      line: SELINUX=disabled
    when: (ansible_hostname == "barman")

  - name: Импорт GPG-ключа PostgreeSql
    ansible.builtin.rpm_key:
       state: present
       key: https://download.postgresql.org/pub/repos/yum/RPM-GPG-KEY-PGDG-14
    when: (ansible_hostname == "barman")

  # Добавляем postgres репозиторий на хост barman
  - name: install repo
    dnf:
      name: 'https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm'
      state: present
    when: (ansible_hostname == "barman")

  #  Отключение старого postgres-модуля
  - name: disable old postgresql module
    shell: dnf -qy module disable postgresql
    when: (ansible_hostname == "barman")
  
  #  Установка EPEL-release
  - name: install epel-release
    dnf:
      name:
        - epel-release
      state: present
      update_cache: true

  #  Установка пакетов barman и stgresql-client на сервер barman 
  - name: install barman and postgresql packages on barman
    dnf:
      name:
        - barman
        - barman-cli
        - postgresql14
      state: present
      update_cache: true
    when: (ansible_hostname == "barman")

 #  Установка пакетов barman-cli на серверах node1 и node2 
  - name: install barman-cli and postgresql packages on nodes
    dnf:
      name:
        - barman-cli
      state: present
      update_cache: true
    when: (ansible_hostname != "barman")

#  Генерируем SSH-ключ для пользователя postgres на хосте node1
  - name: generate SSH key for postgres
    user:
      name: postgres
      generate_ssh_key: yes
      ssh_key_type: rsa
      ssh_key_bits: 4096
      force: no
    when: (ansible_hostname == "node1")
 
#  Генерируем SSH-ключ для пользователя barman на хосте barman
  - name: generate SSH key for barman
    user:
      name: barman
      uid: 994
      shell: /bin/bash
      generate_ssh_key: yes
      ssh_key_type: rsa
      ssh_key_bits: 4096
      force: no
    when: (ansible_hostname == "barman")

  #  Забираем содержимое открытого ключа postgres c хоста node1
  - name: fetch all public ssh keys node1
    shell: cat /var/lib/pgsql/.ssh/id_rsa.pub
    register: ssh_keys
    when: (ansible_hostname == "node1")

  #  Копируем ключ c node1 на barman
  - name: transfer public key to barman
    delegate_to: barman
    authorized_key:
      key: "{{ ssh_keys.stdout }}"
      comment: "{{ansible_hostname}}"
      user: barman
    when: (ansible_hostname == "node1")

  #  Забираем содержимое открытого ключа barman c хоста barman 
  - name: fetch all public ssh keys barman
    shell: cat /var/lib/barman/.ssh/id_rsa.pub
    register: ssh_keys
    when: (ansible_hostname == "barman")

 #  Копируем ключ с barman на node1
  - name: transfer public key to node1
    delegate_to: node1
    authorized_key:
      key: "{{ ssh_keys.stdout }}"
      comment: "{{ansible_hostname}}"
      user: postgres
    when: (ansible_hostname == "barman")

  #CREATE USER barman SUPERUSER;
  - name: Create barman user
    become_user: postgres
    postgresql_user:
      name: barman
      password: '{{ barman_user_password }}'
      role_attr_flags: SUPERUSER 
    ignore_errors: true
    when: (ansible_hostname == "node1")

   # Добавляем разрешения для поключения с хоста barman
  - name: Add permission for barman
    lineinfile:
      path: /var/lib/pgsql/14/data/pg_hba.conf
      line: 'host    all   {{ barman_user }}    {{ barman_ip }}/32    scram-sha-256'
    when: (ansible_hostname == "node1") or
          (ansible_hostname == "node2") 

  # Добавляем разрешения для подключения с хоста barman
  - name: Add permission for barman
    lineinfile:
      path: /var/lib/pgsql/14/data/pg_hba.conf
      line: 'host    replication   {{ barman_user }}    {{ barman_ip }}/32    scram-sha-256'
    when: (ansible_hostname == "node1") or
          (ansible_hostname == "node2") 

  # Перезагружаем службу postgresql-server
  - name: restart postgresql-server on node1
    service: 
      name: postgresql-14
      state: restarted
    when: (ansible_hostname == "node1")

  # Создаём БД otus;
  - name: Create DB for backup
    become_user: postgres
    postgresql_db:
      name: otus
      encoding: UTF-8
      template: template0
      state: present
    when: (ansible_hostname == "node1")

  # Создаём таблицу test1 в БД otus;
  - name: Add tables to otus_backup
    become_user: postgres
    postgresql_table:
      db: otus
      name: test1
      state: present
    when: (ansible_hostname == "node1")

  # Копируем файл .pgpass
  - name: copy .pgpass
    template:
      src: .pgpass.j2
      dest: /var/lib/barman/.pgpass
      owner: barman
      group: barman
      mode: '0600'
    when: (ansible_hostname == "barman")

  # Копируем файл barman.conf
  - name: copy barman.conf
    template:
      src: barman.conf.j2
      dest: /etc/barman.conf 
      owner: barman
      group: barman
      mode: '0755'
    when: (ansible_hostname == "barman")

- name: Создать директорию /etc/barman.d
    file:
      path: /etc/barman.d
      state: directory
      owner: barman
      group: barman
      mode: '0755'
    when: (ansible_hostname == "barman")

 # Копируем файл node1.conf
  - name: copy node1.conf
    template:
      src: node1.conf.j2
      dest: /etc/barman.d/node1.conf
      owner: barman
      group: barman
      mode: '0755'
    when: (ansible_hostname == "barman")

  - name: barman switch-wal node1
    become_user: barman
    shell: barman switch-wal node1
    when: (ansible_hostname == "barman")

  - name: barman cron
    become_user: barman
    shell: barman cron
    when: (ansible_hostname == "barman")
```

> Запустим создание виртуальных машин:


```
vagrant up
```

# 4. Проверка корректности репликации

> Проверка репликации: На хосте node1 в psql создадим таблицу test1 и колонку column1 с единственным значением 1; 

```
vagrant ssh
sudo -i -u postgres
psql
postgres=#\l
postgres-# postgres=#\c otus
You are now connected to database "otus" as user "postgres".
otus-# postgres=#\dt
         List of relations
 Schema | Name  | Type  |  Owner
--------+-------+-------+----------
 public | test1 | table | postgres
(1 row)

otus-# postgres =#ALTER TABLE test1 ADD COLUMN column1 integer DEFAULT 1;

otus-# postgres=#\d test1
                Table "public.test1"
 Column  |  Type   | Collation | Nullable | Default
---------+---------+-----------+----------+---------
 column1 | integer |           |          | 1


otus=# \c postgres
You are now connected to database "postgres" as user "postgres".
postgres=# select * from pg_stat_replication;
  pid  | usesysid |   usename   |  application_name  |  client_addr  | client_hostname | client_port |         backend_start         | backend_xmin |   state   | sent_lsn  | write_lsn | flush_lsn | replay_lsn |    write_lag    |    flush_lag    |   replay_lag    | sync_p
riority | sync_state |          reply_time
-------+----------+-------------+--------------------+---------------+-----------------+-------------+-------------------------------+--------------+-----------+-----------+-----------+-----------+------------+-----------------+-----------------+-----------------+-------
--------+------------+-------------------------------
 40067 |    16384 | replication | walreceiver        | 192.168.57.12 |                 |       56364 | 2023-10-20 09:07:00.900455-03 |          741 | streaming | 0/8016FD8 | 0/8016FD8 | 0/8016FD8 | 0/8016FD8  |                 |                 |                 |
      0 | async      | 2023-10-20 09:51:15.324836-03
 40262 |    16385 | barman      | barman_receive_wal | 192.168.57.13 |                 |       57702 | 2023-10-20 09:07:52.977807-03 |              | streaming | 0/8016FD8 | 0/8016FD8 | 0/8000000 |            | 00:00:05.350018 | 00:43:25.578538 | 00:43:25.578538 |
      0 | async      | 2023-10-20 09:51:18.772747-03
(2 rows)
```

> Подключимся к node2 проверим созданную колонку:

```
sudo -i -u postgres
vagrant ssh node2
Last login: Fri Oct 20 12:09:23 2023 from 10.0.2.2
[vagrant@node2 ~]$ sudo -i -u postgres
[postgres@node2 ~]$ psql
psql (14.9)
Type "help" for help.

postgres=# \l
                                  List of databases
   Name    |  Owner   | Encoding |   Collate   |    Ctype    |   Access privileges   
-----------+----------+----------+-------------+-------------+-----------------------
 otus      | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | 
 postgres  | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | 
 template0 | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =c/postgres          +
           |          |          |             |             | postgres=CTc/postgres
 template1 | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =c/postgres          +
           |          |          |             |             | postgres=CTc/postgres
(4 rows)

postgres=# \c otus
You are now connected to database "otus" as user "postgres".
otus=# \dt
         List of relations
 Schema | Name  | Type  |  Owner   
--------+-------+-------+----------
 public | test1 | table | postgres
(1 row)

otus=# \d test1
                Table "public.test1"
 Column  |  Type   | Collation | Nullable | Default 
---------+---------+-----------+----------+---------
 column1 | integer |           |          | 1

otus=# \c postgres
You are now connected to database "postgres" as user "postgres".
postgres=# select * from pg_stat_wal_receiver;
  pid  |  status   | receive_start_lsn | receive_start_tli | written_lsn | flushed_lsn | received_tli |      last_msg_send_time       |     last_msg_receipt_time     | latest_end_lsn |        latest_end_time        | slot_name |  sender_host  | sender_port |             
                                                                                                                            conninfo                                                                                                                                         
-------+-----------+-------------------+-------------------+-------------+-------------+--------------+-------------------------------+-------------------------------+----------------+-------------------------------+-----------+---------------+-------------+-------------
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 42775 | streaming | 0/7000000         |                 1 | 0/8016FD8   | 0/8016FD8   |            1 | 2023-10-20 09:55:14.079976-03 | 2023-10-20 09:55:14.084202-03 | 0/8016FD8      | 2023-10-20 09:47:13.188779-03 |           | 192.168.57.11 |        5432 | user=replica
tion password=******** channel_binding=prefer dbname=replication host=192.168.57.11 port=5432 fallback_application_name=walreceiver sslmode=prefer sslcompression=0 sslsni=1 ssl_min_protocol_version=TLSv1.2 gssencmode=prefer krbsrvname=postgres target_session_attrs=any
(1 row)
```

> Из вывода видно, что появилась новая колонка column1 со значением "1"

# 4. Проверка бэкапа

> Подключимся к хосту barman и выполним бэкап node1.

```
vagrant ssh barman
sudo -i -u barman
# Проверка
[barman@barman ~]$ barman switch-wal node1
The WAL file 000000010000000000000009 has been closed on server 'node1'
[barman@barman ~]$  barman backup node1
Starting backup using postgres method for server node1 in /var/lib/barman/node1/base/20231020T132024
Backup start at LSN: 0/A000060 (00000001000000000000000A, 00000060)
Starting backup copy via pg_basebackup for 20231020T132024
Copy done (time: 9 seconds)
Finalising the backup.
This is the first backup for server node1
WAL segments preceding the current backup have been found:
        000000010000000000000008 from server node1 has been removed
Backup size: 33.6 MiB
Backup end at LSN: 0/C000000 (00000001000000000000000B, 00000000)
Backup completed (start time: 2023-10-20 13:20:25.031490, elapsed time: 12 seconds)
Processing xlog segments from streaming for node1
        000000010000000000000009
        00000001000000000000000A
        00000001000000000000000B
[barman@barman ~]$ barman cron
Starting WAL archiving for server node1
[barman@barman ~]$ barman check node1
Server node1:
        PostgreSQL: OK
        superuser or standard user with backup privileges: OK
        PostgreSQL streaming: OK
        wal_level: OK
        replication slot: OK
        directories: OK
        retention policy settings: OK
        backup maximum age: OK (interval provided: 4 days, latest backup age: 3 minutes)
        backup minimum size: OK (33.6 MiB)
        wal maximum age: OK (no last_wal_maximum_age provided)
        wal size: OK (0 B)
        compression settings: OK
        failed backups: OK (there are 0 failed backups)
        minimum redundancy requirements: OK (have 1 backups, expected at least 1)
        pg_basebackup: OK
        pg_basebackup compatible: OK
        pg_basebackup supports tablespaces mapping: OK
        systemid coherence: OK
        pg_receivexlog: OK
        pg_receivexlog compatible: OK
        receive-wal running: OK
        archiver errors: OK

# Создание резервной копии
[barman@barman ~]$ barman backup node1
Starting backup using postgres method for server node1 in /var/lib/barman/node1/base/20231020T132350
Backup start at LSN: 0/C0000C8 (00000001000000000000000C, 000000C8)
Starting backup copy via pg_basebackup for 20231020T132350
Copy done (time: 8 seconds)
Finalising the backup.
Backup size: 33.6 MiB
Backup end at LSN: 0/E000060 (00000001000000000000000E, 00000060)
Backup completed (start time: 2023-10-20 13:23:50.821174, elapsed time: 12 seconds)
Processing xlog segments from streaming for node1
        00000001000000000000000C
        00000001000000000000000D
        00000001000000000000000E
[barman@barman ~]$ barman list-backup node1
node1 20231020T132350 - Fri Oct 20 10:23:59 2023 - Size: 33.6 MiB - WAL Size: 0 B
node1 20231020T132024 - Fri Oct 20 10:20:34 2023 - Size: 33.6 MiB - WAL Size: 48.2 KiB
```

> Проверка восстановления базы otus Подключимся c psql к node1 и удалим базу otus

```
psql -h 192.168.57.11 -U barman -d postgres
psql (14.9)
Type "help" for help.

postgres=# \l
                                  List of databases
   Name    |  Owner   | Encoding |   Collate   |    Ctype    |   Access privileges
-----------+----------+----------+-------------+-------------+-----------------------
 otus      | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 |
 postgres  | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 |
 template0 | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =c/postgres          +
           |          |          |             |             | postgres=CTc/postgres
 template1 | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =c/postgres          +
           |          |          |             |             | postgres=CTc/postgres
(4 rows)

postgres=# DROP DATABASE otus;
DROP DATABASE
postgres=# \l
                                  List of databases
   Name    |  Owner   | Encoding |   Collate   |    Ctype    |   Access privileges
-----------+----------+----------+-------------+-------------+-----------------------
 postgres  | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 |
 template0 | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =c/postgres          +
           |          |          |             |             | postgres=CTc/postgres
 template1 | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =c/postgres          +
           |          |          |             |             | postgres=CTc/postgres
```

> Восстановим бэкап:

```
barman list-backup node1
[barman@barman ~]$ barman list-backup node1
node1 20231020T132350 - Fri Oct 20 10:23:59 2023 - Size: 33.6 MiB - WAL Size: 0 B
node1 20231020T132024 - Fri Oct 20 10:20:34 2023 - Size: 33.6 MiB - WAL Size: 48.2 KiB

barman recover node1 20231020T132024 /var/lib/pgsql/14/data/ --remote-ssh-comman "ssh postgres@192.168.57.11"

DStarting remote restore for server node1 using backup 20231020T132024
Destination directory: /var/lib/pgsql/14/data/
Remote command: ssh postgres@192.168.57.11
Copying the base backup.
Copying required WAL segments.
Generating archive status files
Identify dangerous settings in destination directory.
Recovery completed (start time: 2023-10-20 13:58:59.965366+00:00, elapsed time: 29 seconds)
Your PostgreSQL server has been successfully prepared for recovery!
```

> Перезапустим службу postgres на node1 и проверим базу Otus:

```
vagrant ssh node1
sudo systemctl status postgresql-14
sudo systemctl start postgresql-14
[vagrant@node1 ~]$ sudo -i -u postgres
[postgres@node1 ~]$ psql
psql (14.9)
Type "help" for help.

postgres=# \l
                                  List of databases
   Name    |  Owner   | Encoding |   Collate   |    Ctype    |   Access privileges   
-----------+----------+----------+-------------+-------------+-----------------------
 otus      | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | 
 postgres  | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | 
 template0 | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =c/postgres          +
           |          |          |             |             | postgres=CTc/postgres
 template1 | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =c/postgres          +
           |          |          |             |             | postgres=CTc/postgres
(4 rows)

postgres=# \c otus
You are now connected to database "otus" as user "postgres".
otus=# \d test1
                Table "public.test1"
 Column  |  Type   | Collation | Nullable | Default 
---------+---------+-----------+----------+---------
 column1 | integer |           |          | 1
```

> Восстанавливаем репликацию:

```
необходимо удалить все данные в /var/lib/pgsql/14/data/ на node2
под пользователем postgres скопировать данные с node1
В файле /var/lib/pgsql/14/data/postgresql.conf меняем параметр:
listen_addresses = 'localhost, 192.168.57.12'
запустить службу postgres
проверить базу otus
```

```
необходимо удалить все данные в /var/lib/pgsql/14/data/ на node2
под пользователем postgres скопировать данные с node1
В файле /var/lib/pgsql/14/data/postgresql.conf меняем параметр:
listen_addresses = 'localhost, 192.168.57.12'
запустить службу postgres
проверить базу otus
```
