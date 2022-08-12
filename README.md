# aws-rds-migrate


```sql
CREATE USER 'sysadmin'@'localhost' IDENTIFIED BY 'passw0rd';
GRANT ALL PRIVILEGES ON *.* TO 'sysadmin'@'localhost' WITH GRANT OPTION;
CREATE USER 'sysadmin'@'%' IDENTIFIED BY 'passw0rd';
GRANT ALL PRIVILEGES ON *.* TO 'sysadmin'@'%'WITH GRANT OPTION;

CREATE DATABASE testdb;

CREATE TABLE TEXTS (
  ID INT NOT NULL AUTO_INCREMENT,
  TXT varchar(255),
  PRIMARY KEY (ID)
);
```