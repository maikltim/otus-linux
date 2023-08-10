#!/bin/bash

sudo -i

# Install chrony fro correct time
yum install chrony
systemctl enable chronyd
systemctl start chronyd

# install firewalld

rpm -qa firewalld

yum install firewalld
systemctl status firewalld
systemctl start firewalld
systemctl enable firewalld

# Open ports on firewall
firewall-cmd --permanent --add-port=9090/tcp --add-port=9093/tcp --add-port=9094/{tcp,udp} --add-port=9100/tcp

firewall-cmd --reload

# SElinux 
# getenforce
# Enforcing


setenforce 0
sed -i 's/^SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config

# Install Prometheus

yum install wget

wget https://github.com/prometheus/prometheus/releases/download/v2.46.0/prometheus-2.46.0.linux-amd64.tar.gz

mkdir /etc/prometheus
mkdir /var/lib/prometheus

tar -zxf prometheus-*.linux-amd64.tar.gz

cd prometheus-*.linux-amd64

cp prometheus promtool /usr/local/bin/

cp -r console_libraries consoles prometheus.yml /etc/prometheus

useradd --no-create-home --shell /bin/false prometheus

chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus

chown prometheus:prometheus /usr/local/bin/{prometheus,promtool}


cat > /etc/systemd/system/prometheus.service <<EOF
[Unit]
Description=Prometheus Service
After=network.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
--config.file /etc/prometheus/prometheus.yml \
--storage.tsdb.path /var/lib/prometheus/ \
--web.console.templates=/etc/prometheus/consoles \
--web.listen-address=192.168.11.160:9090 \
--web.console.libraries=/etc/prometheus/console_libraries
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure

[Install]
WantedBy=multi-user.target

EOF

systemctl daemon-reload
systemctl enable prometheus

chown -R prometheus:prometheus /var/lib/prometheus

systemctl start prometheus
systemctl status prometheus

# Install node_exporter

cd  

wget https://github.com/prometheus/node_exporter/releases/download/v1.0.1/node_exporter-1.0.1.linux-amd64.tar.gz

tar -zxf node_exporter-*.linux-amd64.tar.gz

cd node_exporter-*.linux-amd64
cp node_exporter /usr/local/bin/

useradd --no-create-home --shell /bin/false nodeusr

chown -R nodeusr:nodeusr /usr/local/bin/node_exporter

cat > /etc/systemd/system/node_exporter.service <<EOF
[Unit]
Description=Node Exporter Service
After=network.target

[Service]
User=nodeusr
Group=nodeusr
Type=simple
ExecStart=/usr/local/bin/node_exporter
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure

[Install]
WantedBy=multi-user.target

EOF

systemctl daemon-reload
systemctl enable node_exporter
systemctl start node_exporter

# Install Grafana

cat > /etc/yum.repos.d/grafana.repo <<EOF
[grafana]
name=grafana
baseurl=https://packages.grafana.com/oss/rpm
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://packages.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
EOF


yum install grafana

firewall-cmd --permanent --add-port=3000/tcp
firewall-cmd --reload

systemctl enable grafana-server

systemctl start grafana-server