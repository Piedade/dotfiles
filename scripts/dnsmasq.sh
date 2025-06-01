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

# upstream DNS server for non-local domain names, using Cloudflare and google public DNS
# add .test to resolve to your local machine
echo -e "server=1.1.1.1\nserver=8.8.8.8\n\naddress=/.test/127.0.0.1" | "${SUDO_CMD}" tee -a "$DNSMASQCONF" > /dev/null

if ! "${SUDO_CMD}" mv "$RESOLVCONF" "$RESOLVCONF".bak; then
    echo_error "Can't move the old resolv.conf file!"
    exit 1
fi

echo -e "nameserver 127.0.0.1" | "${SUDO_CMD}" tee -a "$RESOLVCONF" > /dev/null

# Change the file’s attributes using the chattr command to make our file immutable.
# This prevents the local network manager from overwriting our changes:
"${SUDO_CMD}" chattr +i /etc/resolv.conf

# reset nameservers
"${SUDO_CMD}" apt-get update
