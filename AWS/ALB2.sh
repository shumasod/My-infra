import boto3

def lambda_handler(event, context):
    elbv2 = boto3.client('elbv2')
    
    # メンテナンスページ用のターゲットグループARN
    maintenance_target_group_arn = 'arn:aws:elasticloadbalancing:'
    
    # メンテナンスページに切り替えるリスナーのARNリスト
    listener_arns = [
        'arn:aws:elasticloadbalancing:',
        # 他のリスナーのARNを追加
    ]
    
    for listener_arn in listener_arns:
        try:
            # 既存のルールを削除
            rules = elbv2.describe_rules(ListenerArn=listener_arn)
            
            for rule in rules['Rules']:
                if rule['Priority'] != 'default':  # デフォルトルール以外を削除
                    elbv2.delete_rule(RuleArn=rule['RuleArn'])
                    print(f"Deleted rule {rule['RuleArn']} for listener {listener_arn}")
            
            # メンテナンスページに転送する新しいルールを作成
            new_rule = elbv2.create_rule(
                ListenerArn=listener_arn,
                Conditions=[
                    {
                        'Field': 'path-pattern',
                        'PathPatternConfig': {
                            'Values': ['*']  # すべてのパスに対して
                        }
                    }
                ],
                Priority=1,  # 最高優先度を指定
                Actions=[
                    {
                        'Type': 'forward',
                        'TargetGroupArn': maintenance_target_group_arn
                    }
                ]
            )
            print(f"Created new rule: {new_rule['Rules'][0]['RuleArn']} for listener {listener_arn}")
        
        except Exception as e:
            print(f"Error modifying rules for listener {listener_arn}: {e}")
            raise e

# テストイベント
lambda_handler({}, {})
