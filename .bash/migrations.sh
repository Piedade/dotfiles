#!/bin/bash

sync_email(){
    local ACCOUNT="$1"
    local DOMAIN="$2"
    local EMAIL="$3"

    if [ $# -eq 0 ]; then
        read -rp "Account: " ACCOUNT
        if [ -z "$ACCOUNT" ]; then
            echo_error "Account is required."
            return 1
        fi

        read -rp "Domain: " DOMAIN
        if [ -z "$DOMAIN" ]; then
            echo_error "Domain is required."
            return 1
        fi

        read -rp "Email: " EMAIL
        if [ -z "$EMAIL" ]; then
            echo_error "Email is required."
            return 1
        fi
    else
        if [ -z "$ACCOUNT" ] || [ -z "$DOMAIN" ] || [ -z "$EMAIL"  ]; then
            echo_error "Usage: sync_email <account> <domain> <email>"
            return 1
        fi
    fi

    # Email folder from local pc
    LOCAL_PATH="./$EMAIL/"
    if [ ! -d "$LOCAL_PATH" ]; then
        echo_error "Folder '$LOCAL_PATH' does not exist."
        return 1
    fi

    echo_info "=================================================================="
    echo_info "🚀 A INICIAR RSYNC DA CONTA DE EMAIL"
    echo_info "=================================================================="
    echo_info "👤 Utilizador cPanel: $ACCOUNT"
    echo_info "📧 Conta de Email:    $EMAIL@$DOMAIN"
    echo_info "📂 Origem (Local):    $LOCAL_PATH"
    echo_info "🖥️ Destino (Remoto):  $ACCOUNT@server:/home/$ACCOUNT/mail/$DOMAIN/$EMAIL/"
    echo_info "------------------------------------------------------------------"

    # Ask the user for confirmation if the variables are correct
    read -rp "Do you want to continue? [y/N]: " answer
    case "$answer" in
        [Yy]* )
            echo_success "Continuing..."
            ;;
        * )
            echo_error "Operation cancelled."
            return 1
            ;;
    esac

    # Executa o rsync com compressão, progresso e ajuste automático de permissões cPanel
    rsync -avzP --chmod=D751,F640 -e "ssh -p $PORTA_SSH" \
        "$LOCAL_PATH" \
        "$ACCOUNT@server:/home/$ACCOUNT/mail/$DOMAIN/$EMAIL/"

    # Verifica se o rsync terminou com sucesso
    if [ $? -eq 0 ]; then
        echo_success "------------------------------------------------------------------"
        echo_success "✅ SUCESSO: A conta [$EMAIL] foi sincronizada e as permissões estão corretas!"
        echo_success "=================================================================="
    else
        echo_error "------------------------------------------------------------------"
        echo_error "❌ ERRO: O rsync falhou a meio da transferência."
        echo_error "=================================================================="
    fi
}
