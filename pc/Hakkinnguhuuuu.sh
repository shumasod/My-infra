# ハッキングしたように見せかけるPowershellスクリプト 
# ランダムな文字列を生成
$randStr = [System.Random]::new().NextString(100)
# ランダムなファイル名を生成 
$randFile = [System.IO.Path]::GetRandomFileName()
# ランダムなテキストを生成
$randText = [System.Random]::new().NextString(1000)
# テキストをファイルに書き込み
[System.IO.File]::WriteAllText($randFile, $randText)
# ファイルを開く
$process = Start-Process -FilePath $randFile
# プロセスを待機
$process.WaitForExit()
# メッセージを出力
Write-Host "ハッキングが完了しました。"