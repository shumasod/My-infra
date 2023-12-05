//Linux自動入力

#!/bin/bash
# test.sh

expect -c "
set timeout 1
spawn env LANG=C su
expect \"Password:\"
send \"hogeroot\n\"
"
echo ""

# rootユーザーで実行いたいコマンドを記述していく
systemctl --no-pager status tomcat
systemctl --no-pager status postgresql
exit 0
