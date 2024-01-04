DATE=`date "+%Y%m%d%H%M%S"`;
mysqldump --add-locks --disable-keys --extended-insert --lock-all-tables --quick --quote-names $DB_USER $DB_PASS -h $DB_HOST -B $DB_NAME > $BACKUP_BASE_DIR$DB_NAME"_"$DATE".dump"
if [ $? -gt 0 ]; then
    echo "[ERROR]バックアップ失敗。シェルスクリプトを強制終了する。";
    exit 1;
fi
