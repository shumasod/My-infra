#!/bin/bash
set -e
export PATH=$PATH:/usr/local/bin/

TODAY=$(date "+%Y%m%d")
S3_BUCKET=-dumps
DIR="$(cd $(dirname $0); pwd)"
# mysqlのdumpを管理するディレクトリ
DUMP_DIR="${DIR}/../data"
TEBLE_DUMP_DIR="${DUMP_DIR}/dump_tables"
RDIFF_DIR="${DUMP_DIR}/rdiff"

dbIdentifier=$1
dbUser=$2
dbPass=$3
restoreTime=$4
dbHostName=$(aws rds describe-db-instances --db-instance-identifier $dbIdentifier --output json | jq -r '.DBInstances[0].Endpoint.Address')
slackToken=$5
slackPayload=$6

downloadBackup() {
    aws s3 cp s3://$S3_BUCKET/$TODAY ${RDIFF_DIR}_${TODAY} --recursive --only-show-errors
}

restoreDatabase() {
    myloader --host=$dbHostName --user=$dbUser --password=$dbPass --directory=${RDIFF_DIR}_${TODAY} --queries-per-transaction=1000 --threads=200 --compress-protocol --verbose=3
}

slackNofify() {
    if [[ -z "$5" || -z "$6"  ]]; then
        echo "Skip slack notification due to no argument supplied"
        return
    fi
    curl -H "Content-type: application/json" \
        -H "Authorization: Bearer ${slackToken}" \
        --data "${slackPayload}" \
        -X POST 
}

main () {
    # Download backup from s3
    downloadBackup

    # restore database
    restoreDatabase
}

main
