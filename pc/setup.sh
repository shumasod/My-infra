@echo off
REM ===========================================================
REM 制作日：2023.11.30
REM 製作者：Shuma
REM バージョン：1.1β
REM Windowsキッティング用スクリプト
REM WindowsPC設定bat
REM ===========================================================

REM 変数========================================================
REM コンピュータ情報
set PCName="LAPTOP"

REM ネットワーク情報
set IPAddress="xxx.xxx.xxx.xxx"
set SubnetMask="xxx.xxx.xxx.xxx"
set DefaultGateway="xxx.xxx.xxx.xxx"

REM DNS情報
set DNS1="8.8.8.8
set DNS2="8.8.4.4"

REM === Windowsライセンスユーザ情報 ===
set RegPath="HKLM\Software\Microsoft\Windows NT\CurrentVersion"
set RegOrga="WindowsUser"
set RegOwnr="WindowsUser"

REM === ログ保存先情報 ===
set LogFileName="SetupComputer.log"
set LogSavePath="C:\"
REM ===========================================================

set Log=%LogSavePath%%LogFileName%

REM 開始日時情報の取得(タイムスタンプ)
REM 日付情報の取得
set year=%date:~0,4%
set month=%date:~5,2%
set day=%date:~8,2%

REM 時刻の取得
set hr=%time:~0,2%
set min=%time:~3,2%
set sec=%time:~6,2%
echo "開始日時" >> %Log%
echo %year%.%month%.%day% >> %Log%
echo %hr%:%min%:%sec%  >> %Log%

REM コンピュータ名の設定
wmic computersystem where name="%COMPUTERNAME%" call rename name=%PCName% >> %Log%

REM ネットワークアダプタの設定
netsh interface ip set address "イーサネット" static %IPAddress% %SubnetMask% %DefaultGateway%  >> %Log%

REM プライマリDNSの設定
netsh interface ip set dns "イーサネット" static %DNS1% primary no >> %Log%
REM セカンダリDNSの設定
netsh interface ip add dns "イーサネット" %DNS2% >> %Log%

netsh interface ip show config "イーサネット" >> %Log%
getmac >> %Log%
getmac /v /fo list  >> %Log%

REM Windowsライセンスユーザの登録
reg add %RegPath% /v RegisterdOrganization /t REG_SZ /d %RegOrga% /f
reg add %RegPath% /v RegisterdOwner /t REG_SZ /d %RegOwnr% /f

REM 終了日時情報の取得(タイムスタンプ)
REM 日付情報の取得
set year=%date:~0,4%
set month=%date:~5,2%
set day=%date:~8,2%

REM 時刻の取得
set hr=%time:~0,2%
set min=%time:~3,2%
set sec=%time:~6,2%
echo "終了日時" >> %Log%
echo %year%.%month%.%day% >> %Log%
echo %hr%:%min%:%sec%  >> %Log%

REM 再起動処理
shutdown /r /t 3

exit
