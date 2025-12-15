"""
ALBメンテナンスモード切替Lambda関数 (修正版)

機能:
- ALBリスナールールの一時的な無効化（メンテナンスモード）
- 既存ルールの完全なバックアップと復元
- トランザクション的なエラーハンドリング
"""

import boto3
import json
import logging
import os
from typing import Dict, List, Any, Optional
from botocore.exceptions import ClientError
from datetime import datetime

# ロガーの設定
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# 環境変数
REGION = os.environ.get('AWS_REGION', 'ap-northeast-1')
PARAM_PREFIX = os.environ.get('PARAMETER_STORE_PREFIX', '/myapp/alb')

# 定数
MAINTENANCE_RULE_PRIORITY = 1
BACKUP_RULE_START_PRIORITY = 100  # バックアップ時にルールを移動する優先度の開始位置


class MaintenanceModeError(Exception):
    """メンテナンスモード切替エラー"""
    pass


def get_parameters() -> Dict[str, Any]:
    """
    AWS Systems Manager パラメータストアから設定を取得
    
    Returns:
        Dict[str, Any]: パラメータの辞書
        
    Raises:
        MaintenanceModeError: パラメータ取得失敗時
    """
    ssm = boto3.client('ssm', region_name=REGION)
    
    try:
        # 必要なパラメータを一度に取得
        response = ssm.get_parameters_by_path(
            Path=PARAM_PREFIX,
            WithDecryption=True,
            Recursive=True
        )
        
        if not response.get('Parameters'):
            raise MaintenanceModeError(
                f"パラメータが見つかりません。Path: {PARAM_PREFIX}"
            )
        
        params = {}
        for param in response['Parameters']:
            # パラメータ名から接頭辞を削除してキーとして使用
            key = param['Name'].replace(f"{PARAM_PREFIX}/", "")
            params[key] = param['Value']
        
        # 必須パラメータの検証
        required_params = ['maintenance_target_group_arn', 'listener_arns']
        missing_params = [p for p in required_params if p not in params]
        if missing_params:
            raise MaintenanceModeError(
                f"必須パラメータが見つかりません: {', '.join(missing_params)}"
            )
        
        # リスナーARNのリスト化（JSONとして保存されている想定）
        try:
            params['listener_arns'] = json.loads(params['listener_arns'])
            if not isinstance(params['listener_arns'], list):
                raise ValueError("listener_arnsはリスト形式である必要があります")
        except (json.JSONDecodeError, ValueError) as e:
            raise MaintenanceModeError(f"listener_arnsのパースに失敗しました: {e}")
        
        logger.info(f"パラメータを取得しました。リスナー数: {len(params['listener_arns'])}")
        return params
        
    except ClientError as e:
        error_code = e.response.get('Error', {}).get('Code', 'Unknown')
        logger.error(f"パラメータの取得に失敗しました: {error_code} - {e}")
        raise MaintenanceModeError(f"パラメータ取得エラー: {error_code}") from e


def backup_listener_rules(listener_arn: str) -> List[Dict[str, Any]]:
    """
    リスナーの既存ルールをバックアップ
    
    Args:
        listener_arn: リスナーARN
        
    Returns:
        List[Dict[str, Any]]: バックアップされたルール情報のリスト
        
    Raises:
        MaintenanceModeError: バックアップ失敗時
    """
    elbv2 = boto3.client('elbv2', region_name=REGION)
    
    try:
        rules_response = elbv2.describe_rules(ListenerArn=listener_arn)
        
        backup_rules = []
        for rule in rules_response['Rules']:
            # デフォルトルールはスキップ
            if rule.get('IsDefault', False) or rule['Priority'] == 'default':
                continue
            
            # ルールの完全な定義を保存
            rule_backup = {
                'RuleArn': rule['RuleArn'],
                'Priority': rule['Priority'],
                'Conditions': rule.get('Conditions', []),
                'Actions': rule.get('Actions', [])
            }
            backup_rules.append(rule_backup)
        
        logger.info(
            f"リスナー {listener_arn.split('/')[-1]} の"
            f"ルールをバックアップしました。件数: {len(backup_rules)}"
        )
        return backup_rules
        
    except ClientError as e:
        error_code = e.response.get('Error', {}).get('Code', 'Unknown')
        logger.error(f"ルールのバックアップに失敗しました: {error_code} - {e}")
        raise MaintenanceModeError(f"バックアップエラー: {error_code}") from e


def save_backup_to_parameter_store(
    listener_arn: str,
    backup_rules: List[Dict[str, Any]]
) -> None:
    """
    バックアップをパラメータストアに保存
    
    Args:
        listener_arn: リスナーARN
        backup_rules: バックアップデータ
        
    Raises:
        MaintenanceModeError: 保存失敗時
    """
    ssm = boto3.client('ssm', region_name=REGION)
    listener_id = listener_arn.split('/')[-1]
    parameter_name = f"{PARAM_PREFIX}/backup_rules_{listener_id}"
    
    try:
        # バックアップデータをJSON化
        backup_data = {
            'listener_arn': listener_arn,
            'backup_timestamp': datetime.utcnow().isoformat(),
            'rules': backup_rules
        }
        
        ssm.put_parameter(
            Name=parameter_name,
            Value=json.dumps(backup_data, ensure_ascii=False),
            Type='SecureString',  # セキュアストリングを使用
            Overwrite=True,
            Description=f'ALBルールバックアップ - {listener_id}'
        )
        
        logger.info(f"バックアップをパラメータストアに保存しました: {parameter_name}")
        
    except ClientError as e:
        error_code = e.response.get('Error', {}).get('Code', 'Unknown')
        logger.error(f"バックアップの保存に失敗しました: {error_code} - {e}")
        raise MaintenanceModeError(f"バックアップ保存エラー: {error_code}") from e


def load_backup_from_parameter_store(listener_arn: str) -> Optional[Dict[str, Any]]:
    """
    パラメータストアからバックアップを読み込み
    
    Args:
        listener_arn: リスナーARN
        
    Returns:
        Optional[Dict[str, Any]]: バックアップデータ、存在しない場合はNone
        
    Raises:
        MaintenanceModeError: 読み込み失敗時（パラメータが存在しない場合を除く）
    """
    ssm = boto3.client('ssm', region_name=REGION)
    listener_id = listener_arn.split('/')[-1]
    parameter_name = f"{PARAM_PREFIX}/backup_rules_{listener_id}"
    
    try:
        response = ssm.get_parameter(Name=parameter_name, WithDecryption=True)
        backup_data = json.loads(response['Parameter']['Value'])
        logger.info(f"バックアップを読み込みました: {parameter_name}")
        return backup_data
        
    except ssm.exceptions.ParameterNotFound:
        logger.warning(f"バックアップが見つかりません: {parameter_name}")
        return None
        
    except (ClientError, json.JSONDecodeError) as e:
        error_msg = str(e)
        logger.error(f"バックアップの読み込みに失敗しました: {error_msg}")
        raise MaintenanceModeError(f"バックアップ読み込みエラー: {error_msg}") from e


def move_rules_to_backup_priority(listener_arn: str, backup_rules: List[Dict[str, Any]]) -> None:
    """
    既存ルールを高い優先度に移動（メンテナンスルール用にスペースを空ける）
    
    Args:
        listener_arn: リスナーARN
        backup_rules: バックアップルール情報
        
    Raises:
        MaintenanceModeError: 優先度変更失敗時
    """
    elbv2 = boto3.client('elbv2', region_name=REGION)
    
    try:
        # 優先度変更のリストを作成
        rule_priorities = []
        for idx, rule in enumerate(backup_rules):
            new_priority = BACKUP_RULE_START_PRIORITY + idx
            rule_priorities.append({
                'RuleArn': rule['RuleArn'],
                'Priority': new_priority
            })
        
        if rule_priorities:
            elbv2.set_rule_priorities(RulePriorities=rule_priorities)
            logger.info(
                f"リスナー {listener_arn.split('/')[-1]} の"
                f"{len(rule_priorities)}件のルールを優先度{BACKUP_RULE_START_PRIORITY}以降に移動しました"
            )
        
    except ClientError as e:
        error_code = e.response.get('Error', {}).get('Code', 'Unknown')
        logger.error(f"ルールの優先度変更に失敗しました: {error_code} - {e}")
        raise MaintenanceModeError(f"優先度変更エラー: {error_code}") from e


def create_maintenance_rule(listener_arn: str, maintenance_target_group_arn: str) -> str:
    """
    メンテナンスページ用のルールを作成
    
    Args:
        listener_arn: リスナーARN
        maintenance_target_group_arn: メンテナンスページ用ターゲットグループARN
        
    Returns:
        str: 作成されたルールのARN
        
    Raises:
        MaintenanceModeError: ルール作成失敗時
    """
    elbv2 = boto3.client('elbv2', region_name=REGION)
    
    try:
        response = elbv2.create_rule(
            ListenerArn=listener_arn,
            Conditions=[
                {
                    'Field': 'path-pattern',
                    'PathPatternConfig': {
                        'Values': ['/*']  # すべてのパスに対して
                    }
                }
            ],
            Priority=MAINTENANCE_RULE_PRIORITY,
            Actions=[
                {
                    'Type': 'forward',
                    'TargetGroupArn': maintenance_target_group_arn
                }
            ],
            Tags=[
                {
                    'Key': 'Purpose',
                    'Value': 'Maintenance'
                },
                {
                    'Key': 'CreatedBy',
                    'Value': 'MaintenanceModeLambda'
                }
            ]
        )
        
        rule_arn = response['Rules'][0]['RuleArn']
        logger.info(f"メンテナンスルールを作成しました: {rule_arn}")
        return rule_arn
        
    except ClientError as e:
        error_code = e.response.get('Error', {}).get('Code', 'Unknown')
        logger.error(f"メンテナンスルールの作成に失敗しました: {error_code} - {e}")
        raise MaintenanceModeError(f"ルール作成エラー: {error_code}") from e


def delete_maintenance_rule(listener_arn: str) -> None:
    """
    メンテナンスルールを削除
    
    Args:
        listener_arn: リスナーARN
        
    Raises:
        MaintenanceModeError: ルール削除失敗時
    """
    elbv2 = boto3.client('elbv2', region_name=REGION)
    
    try:
        # 現在のルールを取得
        rules_response = elbv2.describe_rules(ListenerArn=listener_arn)
        
        # 優先度1のルールを検索（メンテナンスルール）
        maintenance_rule_arn = None
        for rule in rules_response['Rules']:
            if rule['Priority'] == str(MAINTENANCE_RULE_PRIORITY):
                maintenance_rule_arn = rule['RuleArn']
                break
        
        if maintenance_rule_arn:
            elbv2.delete_rule(RuleArn=maintenance_rule_arn)
            logger.info(f"メンテナンスルールを削除しました: {maintenance_rule_arn}")
        else:
            logger.warning(f"メンテナンスルールが見つかりません（リスナー: {listener_arn.split('/')[-1]}）")
        
    except ClientError as e:
        error_code = e.response.get('Error', {}).get('Code', 'Unknown')
        logger.error(f"メンテナンスルールの削除に失敗しました: {error_code} - {e}")
        raise MaintenanceModeError(f"ルール削除エラー: {error_code}") from e


def restore_original_rules(listener_arn: str, backup_data: Dict[str, Any]) -> None:
    """
    元のルールの優先度を復元
    
    Args:
        listener_arn: リスナーARN
        backup_data: バックアップデータ
        
    Raises:
        MaintenanceModeError: 復元失敗時
    """
    elbv2 = boto3.client('elbv2', region_name=REGION)
    backup_rules = backup_data.get('rules', [])
    
    if not backup_rules:
        logger.warning(f"復元するルールがありません（リスナー: {listener_arn.split('/')[-1]}）")
        return
    
    try:
        # 元の優先度に戻す
        rule_priorities = []
        for rule in backup_rules:
            rule_priorities.append({
                'RuleArn': rule['RuleArn'],
                'Priority': int(rule['Priority'])
            })
        
        elbv2.set_rule_priorities(RulePriorities=rule_priorities)
        logger.info(
            f"リスナー {listener_arn.split('/')[-1]} の"
            f"{len(rule_priorities)}件のルールを元の優先度に復元しました"
        )
        
    except ClientError as e:
        error_code = e.response.get('Error', {}).get('Code', 'Unknown')
        logger.error(f"ルールの復元に失敗しました: {error_code} - {e}")
        raise MaintenanceModeError(f"ルール復元エラー: {error_code}") from e


def delete_backup_from_parameter_store(listener_arn: str) -> None:
    """
    パラメータストアからバックアップを削除
    
    Args:
        listener_arn: リスナーARN
    """
    ssm = boto3.client('ssm', region_name=REGION)
    listener_id = listener_arn.split('/')[-1]
    parameter_name = f"{PARAM_PREFIX}/backup_rules_{listener_id}"
    
    try:
        ssm.delete_parameter(Name=parameter_name)
        logger.info(f"バックアップを削除しました: {parameter_name}")
    except ssm.exceptions.ParameterNotFound:
        logger.warning(f"削除するバックアップが見つかりません: {parameter_name}")
    except ClientError as e:
        # バックアップの削除失敗は警告のみ（処理は継続）
        logger.warning(f"バックアップの削除に失敗しました: {e}")


def activate_maintenance_mode(
    listener_arns: List[str],
    maintenance_target_group_arn: str
) -> Dict[str, Any]:
    """
    メンテナンスモードを有効化
    
    Args:
        listener_arns: リスナーARNのリスト
        maintenance_target_group_arn: メンテナンスページ用ターゲットグループARN
        
    Returns:
        Dict[str, Any]: 処理結果
        
    Raises:
        MaintenanceModeError: 有効化失敗時
    """
    success_listeners = []
    failed_listeners = []
    
    for listener_arn in listener_arns:
        listener_id = listener_arn.split('/')[-1]
        try:
            logger.info(f"リスナー {listener_id} のメンテナンスモードを有効化します")
            
            # 1. 既存ルールをバックアップ
            backup_rules = backup_listener_rules(listener_arn)
            
            # 2. バックアップをパラメータストアに保存
            save_backup_to_parameter_store(listener_arn, backup_rules)
            
            # 3. 既存ルールを高い優先度に移動
            move_rules_to_backup_priority(listener_arn, backup_rules)
            
            # 4. メンテナンスルールを作成
            create_maintenance_rule(listener_arn, maintenance_target_group_arn)
            
            success_listeners.append(listener_id)
            logger.info(f"リスナー {listener_id} のメンテナンスモードを有効化しました")
            
        except Exception as e:
            failed_listeners.append({'listener_id': listener_id, 'error': str(e)})
            logger.error(f"リスナー {listener_id} の処理中にエラーが発生しました: {e}")
            
            # 一部失敗した場合でも継続
            if len(failed_listeners) == len(listener_arns):
                # すべて失敗した場合はエラーを投げる
                raise MaintenanceModeError("すべてのリスナーの処理に失敗しました")
    
    return {
        'success_count': len(success_listeners),
        'success_listeners': success_listeners,
        'failed_count': len(failed_listeners),
        'failed_listeners': failed_listeners
    }


def deactivate_maintenance_mode(listener_arns: List[str]) -> Dict[str, Any]:
    """
    メンテナンスモードを無効化し、元の状態に戻す
    
    Args:
        listener_arns: リスナーARNのリスト
        
    Returns:
        Dict[str, Any]: 処理結果
        
    Raises:
        MaintenanceModeError: 無効化失敗時
    """
    success_listeners = []
    failed_listeners = []
    
    for listener_arn in listener_arns:
        listener_id = listener_arn.split('/')[-1]
        try:
            logger.info(f"リスナー {listener_id} のメンテナンスモードを無効化します")
            
            # 1. バックアップを読み込み
            backup_data = load_backup_from_parameter_store(listener_arn)
            
            if not backup_data:
                logger.warning(f"バックアップが存在しないためスキップします: {listener_id}")
                continue
            
            # 2. メンテナンスルールを削除
            delete_maintenance_rule(listener_arn)
            
            # 3. 元のルールの優先度を復元
            restore_original_rules(listener_arn, backup_data)
            
            # 4. バックアップを削除
            delete_backup_from_parameter_store(listener_arn)
            
            success_listeners.append(listener_id)
            logger.info(f"リスナー {listener_id} のメンテナンスモードを無効化しました")
            
        except Exception as e:
            failed_listeners.append({'listener_id': listener_id, 'error': str(e)})
            logger.error(f"リスナー {listener_id} の処理中にエラーが発生しました: {e}")
            
            # 一部失敗した場合でも継続
            if len(failed_listeners) == len(listener_arns):
                # すべて失敗した場合はエラーを投げる
                raise MaintenanceModeError("すべてのリスナーの処理に失敗しました")
    
    return {
        'success_count': len(success_listeners),
        'success_listeners': success_listeners,
        'failed_count': len(failed_listeners),
        'failed_listeners': failed_listeners
    }


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Lambdaハンドラー関数
    
    Args:
        event: Lambda呼び出しイベント
            - mode: 'activate' または 'deactivate'
        context: Lambda実行コンテキスト
    
    Returns:
        dict: 処理結果
    """
    logger.info("=" * 60)
    logger.info("メンテナンスモード切替処理を開始します")
    logger.info(f"イベント: {json.dumps(event, ensure_ascii=False)}")
    logger.info("=" * 60)
    
    try:
        # パラメータの取得
        params = get_parameters()
        
        # イベントからモード（activate/deactivate）を取得
        mode = event.get('mode', '').lower()
        
        if mode not in ['activate', 'deactivate']:
            raise ValueError(
                f"不明なモード: {mode}。'activate' または 'deactivate' を指定してください"
            )
        
        # 処理実行
        if mode == 'activate':
            result = activate_maintenance_mode(
                params['listener_arns'],
                params['maintenance_target_group_arn']
            )
            message = "メンテナンスモードを有効化しました"
        else:  # deactivate
            result = deactivate_maintenance_mode(params['listener_arns'])
            message = "メンテナンスモードを無効化しました"
        
        # 結果のログ出力
        logger.info("=" * 60)
        logger.info(f"処理結果: {message}")
        logger.info(f"成功: {result['success_count']}件, 失敗: {result['failed_count']}件")
        if result['failed_listeners']:
            logger.warning(f"失敗したリスナー: {result['failed_listeners']}")
        logger.info("=" * 60)
        
        return {
            'statusCode': 200 if result['failed_count'] == 0 else 207,  # 207: Multi-Status
            'body': json.dumps({
                'message': message,
                'result': result
            }, ensure_ascii=False)
        }
    
    except MaintenanceModeError as e:
        logger.error(f"メンテナンスモードエラー: {e}", exc_info=True)
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': 'MaintenanceModeError',
                'message': str(e)
            }, ensure_ascii=False)
        }
    
    except Exception as e:
        logger.error(f"予期しないエラーが発生しました: {e}", exc_info=True)
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': type(e).__name__,
                'message': str(e)
            }, ensure_ascii=False)
        }


# ローカルテスト用
if __name__ == "__main__":
    # テスト用のイベント
    test_events = [
        {'mode': 'activate'},
        {'mode': 'deactivate'}
    ]
    
    for test_event in test_events:
        print(f"\n{'=' * 60}")
        print(f"テスト実行: {test_event}")
        print(f"{'=' * 60}")
        result = lambda_handler(test_event, None)
        print(json.dumps(result, indent=2, ensure_ascii=False))
