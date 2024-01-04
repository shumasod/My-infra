CNT_REC=(`echo "SELECT COUNT(*) FROM test_table WHERE test_cd==\"$TEST_CD\"" | mysql $DB_USER $DB_PASS -D $DB_NAME -h $DB_HOST`);
if [ $? -gt 0 ]; then
    echo "[ERROR]test_table参照失敗。シェルスクリプトを強制終了する。";
    exit 1;
fi
if [ ${CNT_REC[1]} -eq 0 ]; then
    echo "[ERROR]test_tableにデータなし。シェルスクリプトを強制終了する。";
    exit 1;
fi
