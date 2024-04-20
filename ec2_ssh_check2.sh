#!/bin/bash

# EC2インスタンスにSSH経由で接続
ssh -i /path/to/your/key.pem ubuntu@<EC2_Instance_IP> <<EOF

# EC2インスタンスからRDS for Auroraインスタンスに接続
mysql -h <RDS_for_Aurora_Endpoint> -u <username> -p

# ここにRDSの状態を確認するコマンドを追加
SHOW PROCESSLIST;
SELECT * FROM information_schema.processlist WHERE command != 'Sleep';
SHOW VARIABLES LIKE 'innodb_buffer_pool%';
SHOW VARIABLES LIKE 'slow_query_log';
SELECT table_schema "Database Name", sum( data_length + index_length ) / 1024 / 1024 "Database Size (MB)" FROM information_schema.TABLES GROUP BY table_schema;
SELECT * FROM INFORMATION_SCHEMA.INNODB_LOCKS;
SHOW ENGINE INNODB STATUS;

EOF
