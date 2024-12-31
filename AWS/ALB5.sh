#!/bin/bash

# ALBの名前とリージョンを設定
ALB_NAME="your-alb-name"
AWS_REGION="your-aws-region"

# 新しいリスナールールの設定
NEW_RULE_PRIORITY=1
NEW_RULE_PATH_PATTERN="/new/path/*"
NEW_RULE_TARGET_GROUP="your-target-group-name"

# ALBのARNを取得
ALB_ARN=$(aws elbv2 describe-load-balancers --names $ALB_NAME --region $AWS_REGION --query 'LoadBalancers[0].LoadBalancerArn' --output text)

# リスナーのARNを取得
LISTENER_ARN=$(aws elbv2 describe-listeners --load-balancer-arn $ALB_ARN --region $AWS_REGION --query 'Listeners[0].ListenerArn' --output text)

# 新しいリスナールールを作成
NEW_RULE_ARN=$(aws elbv2 create-rule --listener-arn $LISTENER_ARN --priority $NEW_RULE_PRIORITY --path-pattern $NEW_RULE_PATH_PATTERN --region $AWS_REGION --query 'Rules[0].RuleArn' --output text)

# ターゲットグループのARNを取得
TARGET_GROUP_ARN=$(aws elbv2 describe-target-groups --names $NEW_RULE_TARGET_GROUP --region $AWS_REGION --query 'TargetGroups[0].TargetGroupArn' --output text)

# リスナールールにターゲットグループを関連付け
aws elbv2 modify-rule --rule-arn $NEW_RULE_ARN --actions "Type=forward,TargetGroupArn=$TARGET_GROUP_ARN" --region $AWS_REGION
