#!/usr/bin/env bash

# Update & Upgrade
sudo apt-get update
sudo apt-get upgrade -y

# MySQL
sudo apt-get install mysql-server -y
sudo systemctl start mysql.service

sudo sed -i 's/127.0.0.1/0.0.0.0/0#g' /etc/mysql/mysql.conf.d/mysqld.cnf
sudo systemctl restart mysql

sudo ufw allow 3306
