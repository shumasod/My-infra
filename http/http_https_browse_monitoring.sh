check_response_time() {
    local response_time
    response_time=$(curl -o /dev/null -s -w "%{time_total}" "$target_url")
    local threshold=5.0
    if (( $(echo "$response_time > $threshold" | bc -l) )); then
        return 1  # Response time exceeds threshold, return error
    else
        return 0  # Response time is within threshold, return success
    fi
}

h_check() {
    local status_code
    local message
    if [[ "$server_type" == "apache" ]]; then
        status_code=$(curl -s -o /dev/null -w "%{http_code}" "$target_url")
    elif [[ "$server_type" == "nginx" ]]; then
        status_code=$(curl -I "$target_url" | grep "HTTP/" | awk '{print $2}')
    else
        echo "Invalid server type: $server_type"
        return 1
    fi

    if (( status_code >= 200 && status_code < 300 )); then
        message="OK"
        return 0
    elif (( status_code >= 300 && status_code < 400 )); then
        message="Redirect"
        return 1
    elif (( status_code >= 400 && status_code < 500 )); then
        message="Client Error"
        return 1
    elif (( status_code >= 500 && status_code < 600 )); then
        message="Server Error"
        return 1
    else
        message="Unknown Status"
        return 1
    fi
}

main() {
    local NOTIFY=0
    local target_url
    local server_type
    local error_count=0

    for arg in "$@"; do
        case "$arg" in
            -f)
                NOTIFY=1
                ;;
            -a)
                server_type="apache"
                ;;
            -n)
                server_type="nginx"
                ;;
            *)
                target_url="$arg"
                ;;
        esac
    done

    if h_check; then
        if check_response_time; then
            echo "Site monitoring: OK"
        else
            echo "Site monitoring: Response time error"
            ((error_count++))
            if [[ $NOTIFY -eq 1 ]]; then
                message="check URL:[$target_url] status:[Response time exceeded threshold] response_time:[$response_time]seconds"
                send_slack "$message"
            fi
        fi
    else
        echo "Site monitoring: Error"
        ((error_count++))
        if [[ $NOTIFY -eq 1 ]]; then
            message="check URL:[$target_url] status:[$message]"
            send_slack "$message"
        fi
    fi

    if [[ $error_count -gt 300 ]]; then
        echo "Error count exceeded 300, exiting"
        exit 1
    fi
}

main "$@"