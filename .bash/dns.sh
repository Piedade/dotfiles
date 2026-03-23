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
        echo_success "Found"
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

check_dmarc() {
    if [ -z "$1" ]; then
        echo_error "No domain provided!"
        return 1
    fi

    DOMAIN="$1"
    echo_info "DMARC check for _dmarc.${DOMAIN}"
    echo

    DMARC=$(dig TXT "_dmarc.${DOMAIN}" +short | tr -d '"')

    if [ -z "$DMARC" ]; then
        echo_error "DMARC not found!"
        return 1
    fi

    echo_success "Found"
    echo "   $DMARC"

    if [[ "$DMARC" == *"p=reject"* ]]; then
        echo_info "Policy: REJECT (Máxima segurança)"
    elif [[ "$DMARC" == *"p=quarantine"* ]]; then
        echo_info "Policy: QUARANTINE (Move para Spam)"
    else
        echo_error "Policy: NONE (Apenas monitorização - vulnerável a spoofing)"
    fi
}

check_dkim() {
    if [ -z "$1" ]; then
        echo_error "No domain provided!"
        return 1
    fi

    DOMAIN="$1"
    # Lista de selectores comuns para tentar "adivinhar" se não souberes o correto
    SELECTORS=("default" "google" "k1" "sig1" "mail" "outlook")

    # Se passares um segundo argumento, ele usa-o como selector prioritário
    if [ -n "$2" ]; then
        SELECTORS=("$2")
    fi

    echo_info "DKIM check for ${DOMAIN}..."
    echo

    FOUND=0
    for SEL in "${SELECTORS[@]}"; do
        DKIM_RECORD=$(dig TXT "${SEL}._domainkey.${DOMAIN}" +short)
        if [ -n "$DKIM_RECORD" ]; then
            echo_success "Found (Selector: $SEL)"
            echo "   $DKIM_RECORD"
            FOUND=1
            break
        fi
    done

    if [ $FOUND -eq 0 ]; then
        echo_error "No DKIM records found in the common selectors."
        echo "   Tip: Check the 'DKIM-Signature' header of an email sent to verify the selector (s=)."
    fi
}

check_spam() {
    DOMAIN="$1"
    EXTRA_IP="$2"

    check_spf "$DOMAIN" "$EXTRA_IP"
    echo

    echo "---"

    check_dkim "$DOMAIN"
    echo

    echo "---"

    check_dmarc "$DOMAIN"
    echo
}
