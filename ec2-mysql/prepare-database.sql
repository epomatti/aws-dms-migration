CREATE USER 'dms-user'@'localhost' IDENTIFIED BY 'passw0rd';
GRANT ALL PRIVILEGES ON *.* TO 'dms-user'@'localhost' WITH GRANT OPTION;
CREATE USER 'dms-user'@'%' IDENTIFIED BY 'passw0rd';
GRANT ALL PRIVILEGES ON *.* TO 'dms-user'@'%'WITH GRANT OPTION;

CREATE DATABASE testdb;

USE testdb;

CREATE TABLE TEXTS (
  ID INT NOT NULL AUTO_INCREMENT,
  TXT varchar(255),
  PRIMARY KEY (ID)
);

delimiter //

CREATE PROCEDURE populate()
BEGIN
    DECLARE i int DEFAULT 1;
    WHILE i <= 1000 DO
        INSERT INTO TEXTS (TXT) VALUES ('AWS Data Migration');
        SET i = i + 1;
    END WHILE;
END//

delimiter ;
