# 変更前のルールの優先順位を取得して保存
original_rule_priorities=$(aws elbv2 describe-rules --listener-arn "ALBリスナーのARN" --query 'Rules[*].[RuleArn, Priority]' --output json)

# リスナールールの優先順位を変更
aws elbv2 set-rule-priorities --cli-input-json '{
    "RulePriorities": [
        {
            "RuleArn": "EC2用ターゲットグループ転送するリスナールールのARN",
            "Priority": 2
        },
        {
            "RuleArn": "Lambda用ターゲットグループ転送するリスナールールのARN",
            "Priority": 1
        }
    ]
}'

# 作業が終了した後、優先順位をデフォルトに
aws elbv2 set-rule-priorities --cli-input-json '{
    "RulePriorities": '$original_rule_priorities'
}'
