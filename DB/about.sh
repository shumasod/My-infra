＃＃削除

echo "DROP DATABASE IF EXISTS "$DB_NAME | mysql $DB_USER $DB_PASS -h $DB_HOST
if [ $? -gt 0 ]; then
    echo "[ERROR]データベース削除失敗。シェルスクリプトを強制終了する。";
    exit 1;
fi

##作成

echo "CREATE DATABASE IF NOT EXISTS "$DB_NAME | mysql $DB_USER $DB_PASS -h $DB_HOST
if [ $? -gt 0 ]; then
    echo "[ERROR]データベース作成失敗。シェルスクリプトを強制終了する。";
    exit 1;
fi


##SQLファイルをインポート

cat $IMPORT_FILE | mysql $DB_USER $DB_PASS -h $DB_HOST -D $DB_NAME
if [ $? -gt 0 ]; then
    echo "[ERROR]インポート失敗。シェルスクリプトを強制終了する。";
    exit 1;
fi


##viewテンプレートファイルをインポート

mysql  $DB_USER $DB_PASS -h $DB_HOST -D $DB_NAME < $IMPORT_VIEW_FILE
if [ $? -gt 0 ]; then
    echo "[ERROR]viewテンプレートファイルのインポート失敗。シェルスクリプトを強制終了する。";
    exit 1;
fi
