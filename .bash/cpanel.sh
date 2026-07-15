#!/bin/bash

change_cpanel_password() {
    local ACCOUNT="$1"

    if [ -z "$ACCOUNT" ]; then
        ACCOUNT=$(select_account) || { echo_error "Usage: change_cpanel_password <account>"; return 1; }
    fi

    if [[ ! "$ACCOUNT" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo_error "Invalid account name: '$ACCOUNT'"
        return 1
    fi

    # Confirmation to the user that the variables are correct
    echo_info "Account: $ACCOUNT"

    # Ask the user for confirmation if the variables are correct
    read -rp "Do you want to continue? [y/N]: " answer
    case "$answer" in
        [Yy]* )
            echo "Continuing..."
            ;;
        * )
            echo_error "Operation cancelled."
            return 1
            ;;
    esac

    local PASS=$(gen_pass)

    ssh root@server "whmapi1 passwd user=${ACCOUNT} password='${PASS}'"
    echo_success "Password changed."
    echo

    local PRIMARY_DOMAIN=$(ssh root@server "whmapi1 accountsummary user=${ACCOUNT}" | grep "domain:" | head -n1 | awk '{print $2}')

    echo "==="
    echo
    echo "Os dados de acesso são os seguintes:"
    echo
    echo "URL do cPanel: $PRIMARY_DOMAIN/cpanel"
    echo "Utilizador: $ACCOUNT"
    echo "Palavra-passe: $PASS"
    echo
    echo "Salientamos, no entanto, que a partir deste momento, deixamos de nos responsabilizar por qualquer problema, incidente ou prejuízo que possa decorrer da sua utilização, incluindo, mas não se limitando a, alterações nas configurações, eliminação de ficheiros, bases de dados ou quaisquer outras operações técnicas realizadas."
    echo
    echo "Para qualquer esclarecimento adicional, permanecemos ao dispor."
    echo "Cumprimentos,"
    echo
}

# ─────────────── AUTO-COMPLETE OPCIONAL ───────────────
_change_cpanel_password_autocomplete() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local accounts
    if [[ $COMP_CWORD -eq 1 ]]; then
        accounts=$(ssh "$SERVER" "cut -d: -f1 /etc/trueuserowners" 2>/dev/null)
        COMPREPLY=( $(compgen -W "$accounts" -- "$cur") )
    fi
}
complete -F _change_cpanel_password_autocomplete change_cpanel_password
