# 実行権限の付与
chmod +x run_test.sh

# テスト実行
./run_test.sh

# または段階的に実行
vagrant up
ansible-playbook -i inventory/test.ini site.yml --tags phase1
ansible-playbook -i inventory/test.ini site.yml --tags phase2
# ... 以下同様
