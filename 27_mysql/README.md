# 1. Настройка source

```
vagrant ssh mysql-source
sudo  cp /vagrant/conf.d/* /etc/my.cnf.d/
sudo cat /var/log/mysqld.log | grep 'root@localhost:' | awk '{print $11}'
mysql -uroot -p
ALTER USER USER() IDENTIFIED BY 'NDdd3984_*';
FLUSH PRIVILEGES;
mysql -uroot -p'NDdd3984_*'
SHOW VARIABLES LIKE 'gtid_mode';
CREATE DATABASE bet;
mysql -uroot -p'NDdd3984_*' -D /vagrant/bet.dmp </vagrant/bet.dmp
exit
mysql -uroot -p'NDdd3984_*' -D bet</vagrant/bet.dmp
mysql -uroot -p'NDdd3984_*'
CREATE USER 'repl'@'%' IDENTIFIED BY 'DJFnfj4876_*';
GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%' IDENTIFIED BY 'DJFnfj4876_*';
exit
mysqldump --all-databases --triggers --routines --master-data --ignore-table=bet.events_on_demand --ignore-table=bet.v_same_event -uroot -p'NDdd3984_*'>/vagrant/master.sql
```

# 2. Настройка replica

```
sudo  cp /vagrant/conf.d/* /etc/my.cnf.d/
sudo -s
cd /etc/my.cnf.d/
sed -i 's/server-id = 1/server-id = 2/' 01-base.cnf
sed -i '/^#replicate-ignore-table/s/^#//' 05-binlog.cnf
cat 01-base.cnf 05-binlog.cnf
systemctl restart mysql
sudo cat /var/log/mysqld.log | grep 'root@localhost:' | awk '{print $11}'
mysql -uroot -p
```

> Если возникла проблема с паролем, то

```
sudo systemctl stop mysqld
sudo systemctl set-environment MYSQLD_OPTS="--skip-grant-tables --skip-networking"
sudo systemctl restart mysqld
mysql -u root
mysql> FLUSH PRIVILEGES;
mysql> ALTER USER 'root'@'localhost' IDENTIFIED BY 'DJFnfj4876_*';
mysql> FLUSH PRIVILEGES;
mysql> exit
sudo systemctl stop mysqld
sudo systemctl unset-environment MYSQLD_OPTS
mysql -u root -p
```

```
#SOURCE ~/master.sql;
# на centos8 возниакет ошибка, после команды source ( загрузка базы, что база уже существует, поэтому репликацию запускам без загрузки базы )
```

```
SELECT @@server_id;
CHANGE MASTER TO MASTER_HOST = "192.168.57.4", MASTER_PORT = 3306, MASTER_USER = "repl", MASTER_PASSWORD = 'DJFnfj4876_*', MASTER_AUTO_POSITION = 1;
start slave;
SHOW SLAVE STATUS\G
mysql> SHOW SLAVE STATUS\G
*************************** 1. row ***************************
               Slave_IO_State: Waiting for master to send event
                  Master_Host: 192.168.57.4
                  Master_User: repl
                  Master_Port: 3306
                Connect_Retry: 60
              Master_Log_File: mysql-bin.000006
          Read_Master_Log_Pos: 194
               Relay_Log_File: mysql-replica-relay-bin.000009
                Relay_Log_Pos: 407
        Relay_Master_Log_File: mysql-bin.000006
             Slave_IO_Running: Yes
            Slave_SQL_Running: Yes
```

# 3. Проверим репликацию

```
vagrant ssh mysql-source
mysql -u root
mysql> USE bet;
mysql> INSERT INTO bookmaker (id,bookmaker_name) VALUES(1,'1xbet');
mysql> SELECT * FROM bookmaker;

+----+----------------+
| id | bookmaker_name |
+----+----------------+
|  1 | 1xbet          |
|  4 | betway         |
|  5 | bwin           |
|  6 | ladbrokes      |
|  3 | unibet         |
+----+----------------+
5 rows in set (0.00 sec)

vagrant ssh mysql-replica
mysql -u root
mysql> USE bet;
mysql> SELECT * FROM bookmaker;
mysql> SELECT * FROM bookmaker;
+----+----------------+
| id | bookmaker_name |
+----+----------------+
|  1 | 1xbet          |
|  4 | betway         |
|  5 | bwin           |
|  6 | ladbrokes      |
|  3 | unibet         |
+----+----------------+
5 rows in set (0.00 sec)
```