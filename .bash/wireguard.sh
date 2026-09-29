#!/bin/bash

# WireGuard clients live outside the dotfiles repo (they hold private keys),
# one folder per person: ~/Documents/VPN/<slug>/<slug>.conf + _privatekey +
# _publickey (see bernardo_santos/, carolina_santos/, etc for the template).
# ~/Documents/VPN/.last_ip_used tracks the last 10.0.0.x octet handed out, so
# a removed user's freed IP is never silently reused for someone new.
VPN_DIR="$HOME/Documents/VPN"
VPN_SERVER_PUBKEY="bLnHESTZRYhYe87LHEGkT8pzhYHtS5d/JfP2ve1P4Rg="
VPN_LAST_IP_FILE="$VPN_DIR/.last_ip_used"

# Creates a new WireGuard peer: generates the keypair, adds it to the server
# (wg0.conf on the "vpn" host, hot-reloaded with wg syncconf) and only then
# writes the local .conf/keys — so a failed server-side add never leaves
# orphan local files or burns an IP that was never actually granted.
# Uso: wireguard_add_user ["Nome Completo"]
wireguard_add_user() {
    local FULL_NAME="$1"
    if [ -z "$FULL_NAME" ]; then
        read -rp "Nome da pessoa (ex: Maria Costa): " FULL_NAME
    fi
    [ -z "$FULL_NAME" ] && { echo_error "É preciso indicar um nome."; return 1; }

    # "ssh vpn" resolves to 10.0.0.1, só alcançável através do próprio túnel.
    if ! ip link show type wireguard 2>/dev/null | grep -q .; then
        local REPLY
        read -rp "A tua VPN não está ligada, e é preciso para adicionar o peer no servidor via 'ssh vpn'. Ligar agora? [y/N]: " REPLY
        if [[ "$REPLY" != "y" && "$REPLY" != "Y" ]]; then
            echo_error "A operação foi cancelada."
            return 1
        fi

        systemctl start wg-quick@red || { echo_error "Falhou a ligar a VPN (systemctl start wg-quick@red)."; return 1; }

        if ! ip link show type wireguard 2>/dev/null | grep -q .; then
            echo_error "A VPN continua sem ligar depois de tentar arrancá-la."
            return 1
        fi
        echo_success "VPN ligada."
    fi

    local SLUG
    SLUG=$(echo "$FULL_NAME" | iconv -f utf8 -t ascii//TRANSLIT 2>/dev/null | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '_' | sed 's/^_*//; s/_*$//')
    [ -z "$SLUG" ] && { echo_error "Não foi possível gerar um nome de pasta a partir de '$FULL_NAME'."; return 1; }

    local USER_DIR="$VPN_DIR/$SLUG"
    if [ -e "$USER_DIR" ]; then
        echo_error "'$USER_DIR' já existe."
        return 1
    fi

    local NEXT_IP
    NEXT_IP=$(_wireguard_next_ip) || return 1

    local PRIVATE_KEY PUBLIC_KEY
    PRIVATE_KEY=$(wg genkey)
    PUBLIC_KEY=$(echo "$PRIVATE_KEY" | wg pubkey)

    echo_info "Utilizador: $SLUG · IP: 10.0.0.${NEXT_IP}/24 · a adicionar o peer no servidor (ssh vpn)..."

    # Standard hot-reload for WireGuard: append the [Peer] block then
    # `wg syncconf` from `wg-quick strip`, so existing tunnels aren't dropped.
    local PEER_BLOCK PEER_B64
    PEER_BLOCK=$(printf '\n# %s\n[Peer]\nPublicKey = %s\nAllowedIPs = 10.0.0.%s/32\n' "$FULL_NAME" "$PUBLIC_KEY" "$NEXT_IP")
    PEER_B64=$(printf '%s' "$PEER_BLOCK" | base64 -w0)

    # wg-quick strip and wg syncconf must run inside the SAME sudo process:
    # sudo closes fds >= 3 by default (closefrom), so a separate `sudo
    # wg-quick strip` for the process substitution leaves wg syncconf trying
    # to fopen an fd that's already gone ("fopen: No such file or directory").
    if ! ssh -t vpn "echo '${PEER_B64}' | base64 -d | sudo tee -a /etc/wireguard/wg0.conf > /dev/null && sudo bash -c 'wg syncconf wg0 <(wg-quick strip wg0)'"; then
        echo_error "Falhou a adicionar o peer no servidor. Nada foi criado localmente — nenhum ficheiro nem IP foi consumido."
        return 1
    fi

    mkdir -p "$USER_DIR"
    echo "$PRIVATE_KEY" > "$USER_DIR/${SLUG}_privatekey"
    chmod 600 "$USER_DIR/${SLUG}_privatekey"
    echo "$PUBLIC_KEY" > "$USER_DIR/${SLUG}_publickey"

    cat > "$USER_DIR/${SLUG}.conf" <<EOF
# Client
[Interface]
PrivateKey = ${PRIVATE_KEY}
# IP
Address = 10.0.0.${NEXT_IP}/24
DNS = 8.8.8.8

# Server
[Peer]
PublicKey = ${VPN_SERVER_PUBKEY}
Endpoint = vpn.redpost.pt:51820
AllowedIPs = 10.0.0.0/24, 192.168.1.0/24
PersistentKeepalive = 25
EOF

    echo "$NEXT_IP" > "$VPN_LAST_IP_FILE"

    echo_success "Peer '$SLUG' adicionado ao servidor (sem downtime) e ficheiros criados em $USER_DIR."
    echo_info "Podes gerar um QR code para o telemóvel com: create_qrcode \"\$(cat $USER_DIR/${SLUG}.conf)\" ou 'qrencode -t ansiutf8 < $USER_DIR/${SLUG}.conf'"
}
export -f wireguard_add_user

# Next free 10.0.0.x octet: the higher of what's already used across every
# existing client .conf (in case one was added/removed by hand) and
# .last_ip_used (in case an IP was reserved but its folder isn't there yet), + 1.
_wireguard_next_ip() {
    local FROM_CONFS FROM_FILE MAX_USED

    FROM_CONFS=$(grep -rhoE 'Address = 10\.0\.0\.[0-9]+/24' "$VPN_DIR"/*/*.conf 2>/dev/null | grep -oE '[0-9]+/24' | cut -d/ -f1 | sort -n | tail -1)
    FROM_FILE=0
    [ -f "$VPN_LAST_IP_FILE" ] && FROM_FILE=$(cat "$VPN_LAST_IP_FILE")

    MAX_USED="${FROM_CONFS:-1}"
    if [[ "$FROM_FILE" =~ ^[0-9]+$ ]] && [ "$FROM_FILE" -gt "$MAX_USED" ]; then
        MAX_USED=$FROM_FILE
    fi

    local NEXT=$((MAX_USED + 1))
    if [ "$NEXT" -gt 254 ]; then
        echo_error "Subnet 10.0.0.0/24 esgotada (próximo IP seria .${NEXT})." >&2
        return 1
    fi
    echo "$NEXT"
}
export -f _wireguard_next_ip
