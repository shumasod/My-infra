check_response_time() {
  local response_time
  response_time=$(curl -o /dev/null -s -w "%{time_total}" "$target_url")

  # レスポンスタイムの閾値（秒単位）を設定
  local threshold=1.0

  if (( $(echo "$response_time > $threshold" | bc -l) )); then
    return 1  # レスポンスタイムが閾値を超えた場合はエラー
  else
    return 0  # レスポンスタイムが閾値内の場合はOK
  fi
}


#==========================================================================
#メインの処理
#==========================================================================

main() {
  # スクリプトへの引数を確認
  for arg in "$@"; do
    case "$arg" in
      -f)
        NOTIFY=1
        ;;
      *)
        target_url="$arg"
        ;;
    esac
  done

  if h_check; then
    if check_response_time; then
      echo "サイト監視: OK"
    else
      echo "サイト監視: レスポンスタイムエラー"
      if [[ $NOTIFY -eq 1 ]]; then
        # 通知メッセージ整形
        message="check URL:[$target_url]   status:[$message]   response_time:[$response_time]秒"
        send_slack "$message"
      fi
    fi
  else
    echo "サイト監視: エラー"
    if [[ $NOTIFY -eq 1 ]]; then
      # 通知メッセージ整形
      message="check URL:[$target_url]   status:[$message]"
      send_slack "$message"
    fi
  fi
}

# main 関数を呼び出す

main "$@"


