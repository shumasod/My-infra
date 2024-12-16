#!/bin/bash

# AWS CLIの設定が適切に行われていることを確認してください

# リージョンとアカウントIDを設定
REGION="your-region"
ACCOUNT_ID="your-account-id"

# ロードバランサー名を設定
LB_NAME="your-load-balancer-name"

# 1. 現在のリスナーとそのルールを取得
LISTENER_ARN=$(aws elbv2 describe-listeners --load-balancer-arn arn:aws:elasticloadbalancing:$REGION:$ACCOUNT_ID:loadbalancer/app/$LB_NAME/1234567890abcdef --query "Listeners[?Port==443].ListenerArn" --output text)

# 2. 現在のリスナーに設定されているルールを取得
RULES=$(aws elbv2 describe-rules --listener-arn $LISTENER_ARN --query 'Rules[*].{Priority:Priority,RuleArn:RuleArn}' --output json)

# 3. 変更対象のルールを探し、優先度を変更
echo $RULES | jq -c '.[]' | while read -r RULE; do
    PRIORITY=$(echo $RULE | jq -r '.Priority')
    RULE_ARN=$(echo $RULE | jq -r '.RuleArn')

    if [ "$PRIORITY" = "1" ]; then
        # 4. 優先度を変更
        aws elbv2 modify-rule --rule-arn $RULE_ARN --conditions file://conditions.json --actions file://actions.json --priority 99
        echo "Rule with priority 1 changed to priority 99"
    fi
done