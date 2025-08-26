check_site() {
    local response=$(curl -s -o /dev/null -w "%{http_code}:%{time_total}" "$target_url")
    local status_code=${response%:*}
    local response_time=${response#*:}
    
    if (( status_code >= 200 && status_code < 300 )) && (( $(echo "$response_time <= 5.0" | bc -l) )); then
        echo "Site monitoring: OK"
        return 0
    else
        local msg="Response time error"
        (( status_code >= 300 && status_code < 400 )) && msg="Redirect"
        (( status_code >= 400 && status_code < 500 )) && msg="Client Error"
        (( status_code >= 500 && status_code < 600 )) && msg="Server Error"
        (( status_code < 200 || status_code >= 600 )) && msg="Unknown Status"
        (( $(echo "$response_time > 5.0" | bc -l) )) && msg="Response time exceeded threshold"
        
        echo "Site monitoring: Error"
        ((error_count++))
        [[ $NOTIFY -eq 1 ]] && send_slack "check URL:[$target_url] status:[$msg] response_time:[${response_time}]seconds"
        return 1
    fi
}

main() {
    local NOTIFY=0 error_count=0
    
    for arg in "$@"; do
        case "$arg" in
            -f) NOTIFY=1 ;;
            -[an]) ;; # サーバータイプは不要
            *) target_url="$arg" ;;
        esac
    done
    
    check_site
    
    if [[ $error_count -gt 300 ]]; then
        echo "Error count exceeded 300, exiting"
        exit 1
    fi
}

main "$@"