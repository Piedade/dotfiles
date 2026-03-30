#!/bin/bash

create_email() {
    local ACCOUNT=$1
    local EMAIL=$2

    if [ -z "$ACCOUNT" ] || [ -z "$EMAIL" ] ; then
        echo_error "Usage: create_email <account> <email>"
        return 1
    fi

    # Confirmation to the user that the variables are correct
    echo_info "Account: $ACCOUNT"
    echo_info "Email: $EMAIL"

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


    # Check shell access
    check_shell_access "$ACCOUNT" 1
    case $? in
        1)
            # User exists but no shell → ask if should activate
            echo "Activating shell access..."
            add_shell_access "$ACCOUNT" || { echo_error "Failed to activate shell"; return; }
            ;;
        2)
            echo_error "$ACCOUNT not found."
            return 1
            ;;
        3)
            echo_error "$ACCOUNT has an unusual shell. Please check manually."
            return 1
            ;;
    esac

    local EMAIL_PASS=$(gen_pass)
    local DOMAIN="${EMAIL#*@}"

    echo_info "Creating email..."
    run_remote "uapi Email add_pop email='${EMAIL}' password='${EMAIL_PASS}'"
    echo_success "Email created."
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
}
