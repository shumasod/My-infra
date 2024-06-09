def revert_to_original_handler(event, context):
    elbv2 = boto3.client('elbv2')
    
    # 元のターゲットグループARNを設定
    original_target_groups = {
        'arn:aws:elasticloadbalancing:
    }
    
    for listener_arn, target_group_arn in original_target_groups.items():
        try:
            # 既存のルールを削除
            rules = elbv2.describe_rules(ListenerArn=listener_arn)
            
            for rule in rules['Rules']:
                if rule['Priority'] != 'default':
                    elbv2.delete_rule(RuleArn=rule['RuleArn'])
                    print(f"Deleted rule {rule['RuleArn']} for listener {listener_arn}")
            
            # 元のターゲットグループに転送する新しいルールを作成
            new_rule = elbv2.create_rule(
                ListenerArn=listener_arn,
                Conditions=[
                    {
                        'Field': 'path-pattern',
                        'PathPatternConfig': {
                            'Values': ['*']
                        }
                    }
                ],
                Priority=1,  # 高い優先度を指定
                Actions=[
                    {
                        'Type': 'forward',
                        'TargetGroupArn': target_group_arn
                    }
                ]
            )
            print(f"Created new rule: {new_rule['Rules'][0]['RuleArn']} for listener {listener_arn}")
        
        except Exception as e:
            print(f"Error modifying rules for listener {listener_arn}: {e}")
            raise e

# テストイベント
revert_to_original_handler({}, {})
