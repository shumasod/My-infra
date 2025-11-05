

import boto3
import json
import logging
import os
from botocore.exceptions import ClientError

# ロガーの設定
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# 環境変数
REGION = os.environ.get('AWS_REGION', 'ap-northeast-1')
PARAM_PREFIX = os.environ.get('PARAMETER_STORE_PREFIX', '/myapp/alb')

def get_parameters():
    """
    AWS Systems Manager パラメータストアから設定を取得
    """
    ssm = boto3.client('ssm', region_name=REGION)
    
    try:
        # 必要なパラメータを一度に取得
        response = ssm.get_parameters_by_path(
            Path=PARAM_PREFIX,
            WithDecryption=True
        )
        
        params = {}
        for param in response['Parameters']:
            # パラメータ名から接頭辞を削除してキーとして使用
            key = param['Name'].split('/')[-1]
            params[key] = param['Value']
        
        # 必須パラメータが存在するか確認
        if 'maintenance_target_group_arn' not in params:
            raise ValueError("必須パラメータ 'maintenance_target_group_arn' が見つかりません")
            
        # リスナーARNのリスト化（JSONとして保存されている想定）
        if 'listener_arns' in params:
            params['listener_arns'] = json.loads(params['listener_arns'])
        else:
            raise ValueError("必須パラメータ 'listener_arns' が見つかりません")
            
        return params
        
    except ClientError as e:
        logger.error(f"パラメータの取得に失敗しました: {e}")
        raise

def activate_maintenance_mode(listener_arns, maintenance_target_group_arn):
    """
    メンテナンスモードを有効化
    
    Args:
        listener_arns: リスナーARNのリスト
        maintenance_target_group_arn: メンテナンスページ用ターゲットグループARN
    """
    elbv2 = boto3.client('elbv2', region_name=REGION)
    
    for listener_arn in listener_arns:
        try:
            # 既存のルールを一覧
            rules_response = elbv2.describe_rules(ListenerArn=listener_arn)
            
            # 現在のルール設定を保存（後で復元できるように）
            backup_rules = []
            for rule in rules_response['Rules']:
                if rule['Priority'] != 'default':  # デフォルトルール以外を保存
                    backup_rules.append({
                        'RuleArn': rule['RuleArn'],
                        'Priority': rule['Priority']
                    })
            
            # バックアップをSSMパラメータストアに保存
            ssm = boto3.client('ssm', region_name=REGION)
            ssm.put_parameter(
                Name=f"{PARAM_PREFIX}/backup_rules_{listener_arn.split('/')[-1]}",
                Value=json.dumps(backup_rules),
                Type='String',
                Overwrite=True
            )
            
            # 既存のルールを削除
            for rule in rules_response['Rules']:
                if rule['Priority'] != 'default':  # デフォルトルール以外を削除
                    elbv2.delete_rule(RuleArn=rule['RuleArn'])
                    logger.info(f"ルール {rule['RuleArn']} を削除しました")
            
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
                Priority=1,  # 最高優先度
                Actions=[
                    {
                        'Type': 'forward',
                        'TargetGroupArn': maintenance_target_group_arn
                    }
                ]
            )
            logger.info(f"メンテナンスモード用のルールを作成しました: {new_rule['Rules'][0]['RuleArn']}")
        
        except ClientError as e:
            logger.error(f"リスナー {listener_arn} の変更中にエラーが発生しました: {e}")
            raise

def deactivate_maintenance_mode(listener_arns):
    """
    メンテナンスモードを無効化し、元の状態に戻す
    
    Args:
        listener_arns: リスナーARNのリスト
    """
    elbv2 = boto3.client('elbv2', region_name=REGION)
    ssm = boto3.client('ssm', region_name=REGION)
    
    for listener_arn in listener_arns:
        try:
            # バックアップからルール情報を取得
            parameter_name = f"{PARAM_PREFIX}/backup_rules_{listener_arn.split('/')[-1]}"
            try:
                response = ssm.get_parameter(Name=parameter_name)
                backup_rules = json.loads(response['Parameter']['Value'])
            except ClientError as e:
                logger.warning(f"バックアップルールが見つかりません: {e}")
                continue
            
            # 現在のルールを削除
            rules_response = elbv2.describe_rules(ListenerArn=listener_arn)
            for rule in rules_response['Rules']:
                if rule['Priority'] != 'default':
                    elbv2.delete_rule(RuleArn=rule['RuleArn'])
                    logger.info(f"ルール {rule['RuleArn']} を削除しました")
            
            # バックアップから元のルールの優先度を復元
            rule_priorities = []
            for rule in backup_rules:
                rule_priorities.append({
                    'RuleArn': rule['RuleArn'],
                    'Priority': int(rule['Priority'])
                })
            
            if rule_priorities:
                elbv2.set_rule_priorities(RulePriorities=rule_priorities)
                logger.info(f"元のルール優先度を復元しました")
            
            # バックアップパラメータを削除
            ssm.delete_parameter(Name=parameter_name)
            logger.info(f"バックアップパラメータを削除しました: {parameter_name}")
        
        except ClientError as e:
            logger.error(f"リスナー {listener_arn} の復元中にエラーが発生しました: {e}")
            raise

def lambda_handler(event, context):
    """
    Lambdaハンドラー関数
    
    Args:
        event: Lambda呼び出しイベント
        context: Lambda実行コンテキスト
    
    Returns:
        dict: 処理結果
    """
    logger.info("メンテナンスモード切替処理を開始します")
    logger.info(f"イベント: {json.dumps(event)}")
    
    try:
        # パラメータの取得
        params = get_parameters()
        
        # イベントからモード（activate/deactivate）を取得
        mode = event.get('mode', 'activate')
        
        if mode == 'activate':
            activate_maintenance_mode(
                params['listener_arns'],
                params['maintenance_target_group_arn']
            )
            message = "メンテナンスモードを有効化しました"
        elif mode == 'deactivate':
            deactivate_maintenance_mode(params['listener_arns'])
            message = "メンテナンスモードを無効化しました"
        else:
            raise ValueError(f"不明なモード: {mode}")
        
        logger.info(message)
        return {
            'statusCode': 200,
            'body': message
        }
    
    except Exception as e:
        logger.error(f"エラーが発生しました: {e}", exc_info=True)
        return {
            'statusCode': 500,
            'body': f"処理中にエラーが発生しました: {str(e)}"
        }

# テスト用
if __name__ == "__main__":
    # テスト用のイベント
    test_event = {'mode': 'activate'}
    print(lambda_handler(test_event, None))
