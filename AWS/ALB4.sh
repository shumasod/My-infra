#!/bin/bash

# ALBリスナーのARNを設定
LISTENER_ARN="ALBリスナーのARN"

# EC2用ターゲットグループ転送するリスナールールのARN
EC2_RULE_ARN="EC2用ターゲットグループ転送するリスナールールのARN"

# Lambda用ターゲットグループ転送するリスナールールのARN
LAMBDA_RULE_ARN="Lambda用ターゲットグループ転送するリスナールールのARN"

# 変更前のルールの優先順位を取得して保存
ORIGINAL_RULE_PRIORITIES=$(aws elbv2 describe-rules --listener-arn "$LISTENER_ARN" --query 'Rules[*].[RuleArn,Priority]' --output json)

# リスナールールの優先順位を変更
aws elbv2 set-rule-priorities --rule-priorities \
  "RuleArn=$LAMBDA_RULE_ARN,Priority=1" \
  "RuleArn=$EC2_RULE_ARN,Priority=2"

# 作業が終了した後、優先順位をデフォルトに戻す
aws elbv2 set-rule-priorities --rule-priorities "$ORIGINAL_RULE_PRIORITIES"

echo "リスナールールの変更が完了し、優先順位がデフォルトに戻りました。"
