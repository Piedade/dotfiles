#!/bin/bash
# create_email.sh
# Script para criar emails via WHM/cPanel com fzf local + SSH remoto

SERVER="root@server"  # <--- muda para o teu servidor

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

# Gerar password aleatória
gen_pass() {
    openssl rand -base64 12
}

# ─────────────── MAIN FUNCTION ───────────────
create_email() {
    local ACCOUNT=$1
    local EMAIL=$2

    # Se não passou ACCOUNT → fzf local
    if [[ -z "$ACCOUNT" ]]; then
        ACCOUNT=$(select_account) || { echo "Operation cancelled"; return 1; }
    fi

    # Se não passou EMAIL → fzf local
    if [[ -z "$EMAIL" ]]; then
        DOMAIN=$(select_domain "$ACCOUNT") || { echo "Operation cancelled"; return 1; }

        # Perguntar prefixo do email
        read -rp "Enter new email prefix (ex: info, geral, support): " prefix
        [[ -z "$prefix" ]] && { echo "Operation cancelled"; return 1; }

        EMAIL="$prefix@$DOMAIN"
    fi

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
    local DOMAIN="${EMAIL#*@}"

    echo "Creating email..."
    ssh "$SERVER" "uapi --user=$ACCOUNT Email add_pop email='$EMAIL' password='$EMAIL_PASS'" \
        && echo "Email created successfully." \
        || { echo "Failed to create email"; return 1; }

    # Mostrar credenciais
    echo
    echo "Segue as credênciais de acesso, pode aceder:"
    echo
    echo "Via web:"
    echo "http://$DOMAIN/webmail"
    echo "Email: $EMAIL"
    echo "Palavra-passe: $EMAIL_PASS"
    echo
    echo "Via cliente de email (ex: Outlook ou Thunderbird):"
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
    local users
    users=$(ssh "$SERVER" "cut -d: -f1 /etc/trueuserowners")
    if [[ $COMP_CWORD -eq 1 ]]; then
        COMPREPLY=( $(compgen -W "$users" -- "$cur") )
    fi
}
complete -F _create_email_autocomplete create_email
