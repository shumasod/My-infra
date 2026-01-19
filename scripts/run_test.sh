#!/bin/bash
# run_test.sh

set -e

echo "=========================================="
echo "Valkey クラスター テストセットアップ"
echo "=========================================="
echo ""

# ディレクトリ構造の作成
mkdir -p inventory

# Phase 1: 環境の起動
echo "[Phase 1] Vagrant環境の起動..."
vagrant up

# Phase 2: 接続テスト
echo ""
echo "[Phase 2] 接続テスト..."
ansible all -i inventory/test.ini -m ping

# Phase 3: システム準備
echo ""
echo "[Phase 3] システム準備..."
ansible-playbook -i inventory/test.ini site.yml --tags phase1

# Phase 4: Valkeyインストール
echo ""
echo "[Phase 4] Valkeyインストール..."
ansible-playbook -i inventory/test.ini site.yml --tags phase2

# Phase 5: 設定とサービス起動
echo ""
echo "[Phase 5] 設定とサービス起動..."
ansible-playbook -i inventory/test.ini site.yml --tags phase3

# Phase 6: クラスター作成
echo ""
echo "[Phase 6] クラスター作成..."
ansible-playbook -i inventory/test.ini site.yml --tags phase4

# Phase 7: 検証
echo ""
echo "[Phase 7] 動作確認..."
ansible-playbook -i inventory/test.ini site.yml --tags phase5

echo ""
echo "=========================================="
echo "セットアップ完了！"
echo "=========================================="
echo ""
echo "各ノードへのアクセス:"
echo "  vagrant ssh valkey-node1"
echo "  vagrant ssh valkey-node2"
echo "  vagrant ssh valkey-node3"
echo ""
echo "Valkeyクラスターの確認:"
echo "  vagrant ssh valkey-node1 -c 'valkey-cli cluster nodes'"
echo ""
echo "環境の削除:"
echo "  vagrant destroy -f"
