#!/bin/bash

# エラーハンドリングを設定
set -e

# 変数定義
LISTENER_ARN="ALBリスナーのARN"
EC2_RULE_ARN="EC2用ターゲットグループ転送するリスナールールのARN"
LAMBDA_RULE_ARN="Lambda用ターゲットグループ転送するリスナールールのARN"

# 変更前のルールの優先順位を取得して保存
echo "現在のルール優先順位を取得中..."
original_rule_priorities=$(aws elbv2 describe-rules \
    --listener-arn "${LISTENER_ARN}" \
    --query 'Rules[*].[RuleArn, Priority]' \
    --output json)

# 取得結果の確認
if [ -z "${original_rule_priorities}" ]; then
    echo "エラー: ルールの優先順位の取得に失敗しました"
    exit 1
fi

echo "優先順位を変更中..."
# リスナールールの優先順位を変更
aws elbv2 set-rule-priorities \
    --cli-input-json "{
    \"RulePriorities\": [
        {
            \"RuleArn\": \"${EC2_RULE_ARN}\",
            \"Priority\": 2
        },
        {
            \"RuleArn\": \"${LAMBDA_RULE_ARN}\",
            \"Priority\": 1
        }
    ]
}" || {
    echo "エラー: 優先順位の変更に失敗しました"
    exit 1
}

echo "優先順位の変更が完了しました"
# 作業が終了した後、優先順位をデフォルトに
aws elbv2 set-rule-priorities --cli-input-json '{
    "RulePriorities": '$original_rule_priorities'
}'
