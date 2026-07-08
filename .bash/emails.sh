#!/bin/bash
# create_email.sh
# Script para criar emails via WHM/cPanel com fzf local + SSH remoto

# ─────────────── FZF HELPERS ───────────────

# Escolher conta via fzf (FZF local, lista do servidor via SSH)
select_account() {
    local account
    account=$(ssh "$SERVER" "cut -d: -f1 /etc/trueuserowners" | fzf --prompt="Select account: ")
    [[ -z "$account" ]] && return 1
    echo "$account"
}

# # Escolher email via fzf (FZF local, domínio obtido via SSH)
# select_email() {
#     local account=$1
#     local domain
#     domain=$(ssh "$SERVER" "grep '^DNS=' /var/cpanel/users/$account | cut -d= -f2")
#     [[ -z "$domain" ]] && { echo "Domain not found for $account"; return 1; }

#     local options=("info@$domain" "geral@$domain" "support@$domain" "admin@$domain")
#     local email
#     email=$(printf "%s\n" "${options[@]}" | fzf --prompt="Select email: ")
#     [[ -z "$email" ]] && return 1
#     echo "$email"
# }

select_domain() {
    local account=$1
    local domain
    domain=$(ssh "$SERVER" "grep '^DNS=' /var/cpanel/users/$account | cut -d= -f2")
    [[ -z "$domain" ]] && { echo "Domain not found for $account"; return 1; }
    echo "$domain"
}

# Escolher domínio via fzf (lista todos os domínios do servidor, sem precisar da conta)
select_domain_global() {
    local domain
    domain=$(ssh "$SERVER" "awk -F': ' '{print \$1}' /etc/userdomains" | fzf --prompt="Select domain: ")
    [[ -z "$domain" ]] && return 1
    echo "$domain"
}

# ─────────────── CHECK SHELL ACCESS ───────────────
# Retorna:
# 0 = normal shell
# 1 = precisa ativar shell
# 2 = user não existe
# 3 = shell invulgar
check_shell_access() {
    local account=$1
    local check
    check=$(ssh "$SERVER" "grep -E '^$account:' /etc/passwd | cut -d: -f7")
    if [[ -z "$check" ]]; then
        return 2
    elif [[ "$check" == "/bin/nologin" || "$check" == "/sbin/nologin" ]]; then
        return 1
    elif [[ "$check" != "/bin/bash" ]]; then
        return 3
    fi
    return 0
}

# Ativar shell
add_shell_access() {
    local account=$1
    ssh "$SERVER" "chsh -s /bin/bash $account"
}

# ─────────────── MAIN FUNCTION ───────────────
create_email() {
    local PREFIX=$1
    local DOMAIN=$2

    # Se não passou PREFIX → perguntar (a menos que já seja um email completo)
    if [[ -z "$PREFIX" ]]; then
        read -rp "Enter new email prefix (ex: info, geral, support): " PREFIX
        [[ -z "$PREFIX" ]] && { echo "Operation cancelled"; return 1; }
    fi

    # Se o PREFIX já vier com domínio (ex: info@exemplo.com), usa-o tal como está
    local EMAIL
    if [[ "$PREFIX" == *@* ]]; then
        EMAIL="$PREFIX"
        DOMAIN="${EMAIL#*@}"
    else
        # Se não passou DOMAIN → fzf local (por último)
        if [[ -z "$DOMAIN" ]]; then
            DOMAIN=$(select_domain_global) || { echo "Operation cancelled"; return 1; }
        fi
        EMAIL="$PREFIX@$DOMAIN"
    fi

    # Descobrir a conta dona do domínio
    local ACCOUNT
    ACCOUNT=$(whm_account_by_domain "$DOMAIN") || { echo "Domain not found: $DOMAIN"; return 1; }

    # Confirmação
    echo
    echo "Account: $ACCOUNT"
    echo "Email: $EMAIL"
    read -rp "Do you want to continue? [y/N]: " answer
    case "$answer" in
        [Yy]*) echo "Continuing..." ;;
        *) echo "Operation cancelled."; return 1 ;;
    esac
    echo

    # Check shell access
    check_shell_access "$ACCOUNT"
    case $? in
        1)
            echo "Activating shell access for $ACCOUNT..."
            add_shell_access "$ACCOUNT" || { echo "Failed to activate shell"; return 1; }
            ;;
        2)
            echo "Account $ACCOUNT not found."
            return 1
            ;;
        3)
            echo "Account $ACCOUNT has an unusual shell. Please check manually."
            return 1
            ;;
    esac

    # Criar email
    local EMAIL_PASS
    EMAIL_PASS=$(gen_pass)

    echo "Creating email..."
    local RESULT
    RESULT=$(ssh "$SERVER" "uapi --user=$ACCOUNT Email add_pop email='$EMAIL' password='$EMAIL_PASS'")

    if ! echo "$RESULT" | grep -q "status: 1"; then
        local ERROR_MSG
        ERROR_MSG=$(echo "$RESULT" | grep -A1 "errors:" | tail -n1 | sed -e 's/^\s*-\s*//' -e "s/^['\"]//" -e "s/['\"]$//")
        echo_error "Failed to create email: ${ERROR_MSG:-unknown error}"
        return 1
    fi

    echo_success "Email created successfully."

    # Mostrar credenciais
    echo
    echo "Segue as credênciais de acesso, pode aceder via:"
    echo
    echo "Web:"
    echo "http://$DOMAIN/webmail"
    echo "Email: $EMAIL"
    echo "Palavra-passe: $EMAIL_PASS"
    echo
    echo "Cliente de email (ex: Outlook ou Thunderbird):"
    echo "Utilizador: $EMAIL"
    echo "Palavra-passe: $EMAIL_PASS"
    echo
    echo "Servidor de entrada: $DOMAIN"
    echo "Porta: 993 (IMAP)"
    echo
    echo "Servidor de saída: $DOMAIN"
    echo "Porta: 465 (SMTP)"
    echo
    echo "Nota: IMAP e SMTP requerem autenticação SSL/TLS"
    echo "-------------------------------------------------"
}

# ─────────────── AUTO-COMPLETE OPCIONAL ───────────────
_create_email_autocomplete() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local domains
    domains=$(ssh "$SERVER" "awk -F': ' '{print \$1}' /etc/userdomains")
    if [[ $COMP_CWORD -eq 2 ]]; then
        COMPREPLY=( $(compgen -W "$domains" -- "$cur") )
    fi
}
complete -F _create_email_autocomplete create_email
