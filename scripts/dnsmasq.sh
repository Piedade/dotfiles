#!/bin/bash

# Automatically handle wildcard *.test names and forward all of them to localhost (127.0.0.1).
# https://community.zextras.com/how-to-install-your-dns-server-using-dnsmasq/
echo_info "Installing dnsmasq..."

"${SUDO_CMD}" apt-get install dnsmasq -y

DNSMASQCONF="/etc/dnsmasq.conf";
RESOLVCONF="/etc/resolv.conf";

if ! "${SUDO_CMD}" mv "$DNSMASQCONF" "$DNSMASQCONF".bak; then
    echo_error "Can't move the old dnsmasq.conf file!"
    exit 1
fi

# Get the server's primary IPv4 address dynamically
# This gets the source IP used for routing to 8.8.8.8 (a reliable public IP)
LOCAL_IP=$(ip route get 8.8.8.8 | awk '{print $7; exit}')

# Check if an IP was found
if [ -z "$LOCAL_IP" ]; then
    echo "Error: Could not determine server's IP address. Please check network configuration."
    exit 1
fi

# upstream DNS server for non-local domain names, using Cloudflare and google public DNS
# add .test to resolve to your local machine
"${SUDO_CMD}" tee "${DNSMASQCONF}" > /dev/null <<EOF
listen-address=127.0.0.1,${LOCAL_IP}
# Or, if you prefer the simpler, listen on all interfaces:
#listen-address=0.0.0.0

# Ensure upstream servers are defined
no-resolv
server=1.1.1.1
server=8.8.8.8

# Your custom local addresses
address=/.test/${LOCAL_IP}
EOF

if ! "${SUDO_CMD}" mv "$RESOLVCONF" "$RESOLVCONF".bak; then
    echo_error "Can't move the old resolv.conf file!"
    exit 1
fi

echo -e "nameserver 127.0.0.1" | "${SUDO_CMD}" tee -a "$RESOLVCONF" > /dev/null

# Change the file’s attributes using the chattr command to make our file immutable.
# This prevents the local network manager from overwriting our changes:
"${SUDO_CMD}" chattr +i /etc/resolv.conf

# reset nameservers
"${SUDO_CMD}" systemctl restart dnsmasq

"${SUDO_CMD}" apt-get update
