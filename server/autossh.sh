#!/usr/bin/expect

set PW "Password"
set timeout 5

spawn env LANG=C /usr/bin/ssh 'servername'

# シングルクォートで囲むか、変数を外に出す
expect {
   "(yes/no)?" {
       send "yes\r"
       exp_continue
   }
   "password:" {
       send "${PW}\r"
   }
}

expect {
   "\\$" {
       exit 0
   }
}