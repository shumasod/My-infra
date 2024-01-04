service mysql start
mysql --defaults-extra-file=/etc/mysql/my.cnf -u root -e "drop database if exists dbname;"
mysql --defaults-extra-file=/etc/mysql/my.cnf -u root -e "create database dbname;"
mysql --defaults-extra-file=/etc/mysql/my.cnf -u root dbname < file.sql

