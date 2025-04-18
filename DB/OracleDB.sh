-- データベースとテーブル作成
CREATE DATABASE my_database
CONTROLFILE REUSE
LOGFILE 
    GROUP 1 ('/path/to/logfile/redo_log1.log') SIZE 1000M REUSE,
    GROUP 2 ('/path/to/logfile/redo_log2.log') SIZE 1000M REUSE,
    GROUP 3 ('/path/to/logfile/redo_log3.log') SIZE 1000M REUSE
MAXLOGFILES 5
MAXLOGMEMBERS 5
MAXLOGHISTORY 100
MAXDATAFILES 100
CHARACTER SET AL32UTF8
NATIONAL CHARACTER SET AL16UTF16
DATAFILE '/path/to/datafile/system01.dbf' SIZE 200M REUSE
SYSAUX DATAFILE '/path/to/datafile/sysaux01.dbf' SIZE 100M REUSE
DEFAULT TEMPORARY TABLESPACE temp
    TEMPFILE '/path/to/datafile/temp01.dbf' SIZE 50M REUSE
UNDO TABLESPACE undotbs
    DATAFILE '/path/to/datafile/undotbs01.dbf' SIZE 50M REUSE
USER SYS IDENTIFIED BY "sys_password"
USER SYSTEM IDENTIFIED BY "system_password";

-- デフォルトユーザーテーブルスペースの作成
CREATE TABLESPACE users
    DATAFILE '/path/to/datafile/users01.dbf' SIZE 50M REUSE
    EXTENT MANAGEMENT LOCAL
    SEGMENT SPACE MANAGEMENT AUTO;

-- データベースをオープン
ALTER DATABASE OPEN;
