#!/usr/bin/awk -f

#

# colorize-log.awk

# Written by pslabo

#
BEGIN {

	RESET="\033[0m"

	BOLD="1m"

	ITALIC="3m"

	UNDERLINE="4m"

	BLINK="5m"

	REVERSE="7m"

	BLACK="\033[30"

	RED="\033[31"

	GREEN="\033[32"

	BROWN="\033[33"

	BLUE="\033[34"

	PURPLE="\033[35"

	CYAN="\033[36"

	WHITE="\033[37"

	BG_BLACK="40"

	BG_RED="41"

	BG_GREEN="42"

	BG_BROWN="43"

	BG_BLUE="44"

	BG_PURPLE="45"

	BG_CYAN="46"

	BG_WHITE="47"

	SLOW_WARN=50000

	SLOW_FATAL=100000

}

## squid 特有の色付け

# PURGE は緑

$6 ~ /PURGE/ {

	gsub( "PURGE", GREEN";"BOLD"PURGE"RESET, $6 )

}

# キャッシュヒットは青

$NF ~ /TCP(.*)HIT/ {

	status = $NF

	gsub( status, BLUE";"BOLD""status""RESET, $NF )

}

# キャッシュミスはシアン

$NF ~ /TCP(.*)MISS/ {

	status = $NF

	gsub( status, CYAN";"BOLD""status""RESET, $NF )

}

## apache の応答時間の色付け(ログカスタマイズ必要）

# combined 形式のログでは2番目のフィールドが実質的に使われないので

# ここに応答時間を出すようにするとイロイロ便利な気がします。

#

# apache

# LogFormat "%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\"" combined



# LogFormat "%h %D %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\"" combined

# squid

# logformat combined %>a %ui %un [%tl] "%rm %ru HTTP/%rv" %Hs %h" "%{User-Agent}>h" %Ss:%Sh

# ↓

# logformat combined %>a %6tr %un [%tl] "%rm %ru HTTP/%rv" %Hs %h" "%{User-Agent}>h" %Ss:%Sh

# 1 秒以上		赤

# 500ミリ秒〜1秒	紫

# 100ミリ秒〜500ミリ秒	青

# 〜100ミリ秒		緑

{

	response = $2

	if ( response <= 100 ) {

		gsub( ""status"", GREEN";"BOLD""status""RESET, $2 )

	} else if ( response <= 500 ) {

		gsub( ""status"", BLUE";"BOLD""status""RESET, $2 )

	} else if ( response <= 1000 ) {

		gsub( ""status"", PURPLE";"BOLD""status""RESET, $2 )

	} else if ( response > 1000 ) {

		gsub( ""status"", RED";"BOLD""status""RESET, $2 )

		slow=SLOW_FATAL

	}

}

# ステータスコードに基づく色付け

{

	status=$9

	if ( status == 0 || status >= 500 ) {

		# ステータスコード 0 または 500 以上は赤にする

		gsub( "0", RED";"BOLD"0"RESET, $9 )

		slow=SLOW_FATAL

	} else if ( status < 400 ) {

		# ステータスコード 200 〜 399 は緑で着色

		gsub( ""status"", GREEN";"BOLD""status""RESET, $9 )

	} else if ( status < 500  ) {

		# ステータスコード 400 番台は紫で着色

		gsub( ""status"", PURPLE";"BOLD""status""RESET, $9 )

		slow=SLOW_WARN

	}

}

# ログの出力

{

	print

	# 変数 sleep の値が 0 以上なら、無条件に指定時間だけ usleep を入れる

	# 変数 slow がセットされていたら、指定時間だけ usleep を入れる

	if ( sleep > 0 ) {

		system( "usleep "sleep )

	} else if ( slow > 0 ) {

		system( "usleep "slow )

		slow=0

	}

}
