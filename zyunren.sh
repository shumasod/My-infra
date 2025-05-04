#!/bin/bash

# 純・インフラ歌 - シェルスクリプト版

function sing_chorus() {
  echo "目を閉じれば無限のエラーログ"
  echo "血眼で探した原因はただの誤字"
  echo "初めてプロキシ設定で泣いたよ"
  echo "深夜に響くCPU100%の悲鳴"
  echo ""
}

function check_infrastructure() {
  if [ $((RANDOM % 10)) -eq 0 ]; then
    echo "先輩のパスワードはすべて「password」"
    echo "本番環境で rm -rf /* 叩いたお前"
    echo "障害時だけ存在感バリバリの俺"
    echo "一目惚れ"
    echo ""
    return 0
  else
    echo "緊急対応 「直せなかったら首」と脅され"
    echo "社内チャット炎上「何やってんだ」って"
    echo "八つ当たりメールに返信せず削除した後の"
    echo "缶ビール一気飲み"
    echo ""
    return 1
  fi
}

# メイン処理
echo "===== 純・インフラ歌 シェルスクリプト版 ====="
echo ""

# サビを歌う
sing_chorus

# インフラ状態チェック
while true; do
  check_infrastructure
  infra_status=$?
  
  if [ $infra_status -eq 0 ]; then
    echo "眠すぎて 眠すぎて"
    echo "Jenkinsのビルド待ちで机の下で爆睡"
    echo "for i in {1..100}; do echo '障害対応中...'; sleep 1; done"
    echo ""
    break
  else
    echo "ふてくされて サーバールームで一人酒"
    echo "プロジェクトマネージャーが決めた無理な納期"
    echo "初めて徹夜三連続で幻覚見たよ"
    echo "夜空へ響け「動いたら触るな」の歌"
    echo ""
  fi
  
  # 3秒待機
  sleep 3
done

# 最後のサビ
sing_chorus

# アウトロ
echo "深夜の停電でUPS死んで"
echo "データ全部吹っ飛んだ時に"
echo "君は黙ってGitHubから取り出して"
echo "「バージョン管理してなかったの？」って"
echo "あの一言が今も夢に出る"
echo ""

echo "障害対応完了: $(date)"
exit 0
