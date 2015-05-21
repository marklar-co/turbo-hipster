create database abe_db;
CREATE USER 'abe_db_u'@'localhost' IDENTIFIED BY 'abe_pass';
grant all on abe_db.* to abe_db_u;
