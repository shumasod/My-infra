#!/bin/sh

PW="Password"

expect -c "
set timeout 5
spawn env LANG=C /usr/bin/ssh "servername"
expect \"password:\"
send \"${PW}\n\"
expect \"$\"
exit 0
"
