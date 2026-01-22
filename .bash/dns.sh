# sudo apt install dnsutils
get_dns(){
    if [ -z "$1" ]; then
        echo_error "No domain provided!"
        return 1
    else
        DOMAIN="$1"
        echo_info "DNS Zone for ${DOMAIN}"
        echo
    fi

    for t in A AAAA MX NS TXT CNAME SOA SRV CAA; do
        RESULT=$(dig "$DOMAIN" "$t" +short)
        if [ -n "$RESULT" ]; then
            echo_success "$t"
            echo "$RESULT"
            echo
        fi
    done
}

# sudo apt install spfquery
check_spf() {
    if [ -z "$1" ]; then
        echo_error "No domain provided!"
        return 1
    fi

    DOMAIN="$1"
    SENDER="postmaster@${DOMAIN}"
    IP_REDPOST="194.39.126.152"
    IP_OTHER="$2"

    echo_info "SPF check for ${DOMAIN}"

    echo
    SPF=$(dig "$DOMAIN" TXT +short | grep "v=spf1")
    if [ -z "$SPF" ]; then
        echo_error "No SPF record found"
        return 1
    else
        echo_success "found"
        echo "$SPF"
    fi

    echo
    LOOKUPS=$(echo "$SPF" | grep -o "include:" | wc -l)
    if [ "$LOOKUPS" -gt 10 ]; then
        echo_error "SPF include count: ${LOOKUPS}/10, it may FAIL (too many DNS lookups)"
    else
        echo_success "SPF include count: ${LOOKUPS}/10"
    fi

    echo
    RESULT=$(spfquery -ip "$IP_REDPOST" -sender "$SENDER" -helo "$DOMAIN" 2>/dev/null | head -n1)
    if [ "$RESULT" = "pass" ]; then
        echo_success "$IP_REDPOST (dplay) can send emails"
    else
        echo_error "$IP_REDPOST (dplay) cannot send emails: $RESULT"
    fi

    # other IP
    if [ -n "$IP_OTHER" ]; then
        RESULT2=$(spfquery -ip "$IP_OTHER" -sender "$SENDER" -helo "$DOMAIN" 2>/dev/null | head -n1)
        if [ "$RESULT2" = "pass" ]; then
            echo_success "$IP_OTHER can send emails"
        else
            echo_error "$IP_OTHER cannot send emails: $RESULT2"
        fi
    fi
}
