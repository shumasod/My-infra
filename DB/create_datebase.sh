#!/bin/bash

# Oracleの環境変数を設定
export ORACLE_HOME=/path/to/oracle_home
export PATH=$ORACLE_HOME/bin:$PATH
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$LD_LIBRARY_PATH

# SQL*Plusを使用してSQLスクリプトを実行
sqlplus /nolog <<EOF
CONNECT / AS SYSDBA
@create_database.sql
EXIT
EOF
