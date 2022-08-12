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

CREATE PROCEDURE populate()
BEGIN
    DECLARE i int DEFAULT 1;
    WHILE i <= 1000 DO
        INSERT INTO TEXTS (TXT) VALUES ('AWS Data Migration');
        SET i = i + 1;
    END WHILE;
END;

CALL populate();
```