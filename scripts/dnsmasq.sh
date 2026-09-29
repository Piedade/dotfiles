#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/check_env.sh"

# Automatically handle wildcard *.test names and forward all of them to localhost (127.0.0.1).
# https://community.zextras.com/how-to-install-your-dns-server-using-dnsmasq/
echo_info "Installing dnsmasq..."

# /etc/dnsmasq.conf's "address=/.test/${LOCAL_IP}" (below) points .test at this
# machine's real LAN IP instead of 127.0.0.1 so other devices on the same
# network (phone, KVM VMs) can resolve it too -- but that means it goes stale
# every time the LAN changes (different Wi-Fi, a hotspot, ...), leaving .test
# unreachable until this script is run again by hand. This dispatcher script
# keeps it in sync automatically: NetworkManager runs it on every interface
# up/dhcp event, and it rewrites dnsmasq.conf + restarts dnsmasq only when the
# detected IP actually changed. Installed unconditionally (not gated by the
# "already installed" check below) so it's added even on a machine that
# already has dnsmasq from before this script existed.
DISPATCHER="/etc/NetworkManager/dispatcher.d/90-dnsmasq-test-domain"
sudo tee "$DISPATCHER" > /dev/null <<'EOF'
#!/bin/bash
# Keeps /etc/dnsmasq.conf's .test wildcard address (and listen-address) in
# sync with this machine's current LAN IP. See scripts/dnsmasq.sh in
# ~/.dotfiles for why .test resolves to the LAN IP instead of 127.0.0.1.
# Logs every invocation via logger (journalctl -t dnsmasq-test-domain) --
# NetworkManager doesn't surface a dispatcher script's own stdout/stderr
# anywhere else, so without this there's no way to tell whether it ran, and
# why it did or didn't touch dnsmasq.
#
# Deliberately does NOT filter by action ($2: up/down/dhcp4-change/...) --
# confirmed by testing that the default route can flip well after the
# dhcp4-change event that grabbed the new lease (NM logged the route-policy
# switch itself 7 minutes later, under an action name outside any reasonable
# guessed list). Reacting to every dispatcher call and letting the IP compare
# below decide is cheap (one `ip route get` + one `grep`) and can't miss
# whatever action name NM ends up using for the actual route switch.
interface="$1"
action="$2"
log() { logger -t dnsmasq-test-domain "[$interface/$action] $*"; }

DNSMASQCONF="/etc/dnsmasq.conf"
if [ ! -f "$DNSMASQCONF" ]; then
    log "no $DNSMASQCONF, skipping"
    exit 0
fi

NEW_IP=$(ip route get 8.8.8.8 2>/dev/null | awk '{print $7; exit}')
if [ -z "$NEW_IP" ]; then
    log "could not determine current IP, skipping"
    exit 0
fi

CURRENT_IP=$(grep -oP '^address=/\.test/\K.*' "$DNSMASQCONF")
if [ "$NEW_IP" = "$CURRENT_IP" ]; then
    log "IP unchanged ($CURRENT_IP), nothing to do"
    exit 0
fi

log "IP changed $CURRENT_IP -> $NEW_IP, updating dnsmasq.conf and restarting"
sed -i \
    -e "s/^listen-address=127\.0\.0\.1,.*/listen-address=127.0.0.1,${NEW_IP}/" \
    -e "s#^address=/\.test/.*#address=/.test/${NEW_IP}#" \
    "$DNSMASQCONF"

if systemctl restart dnsmasq; then
    log "dnsmasq restarted OK"
else
    log "dnsmasq restart FAILED"
fi
EOF
sudo chown root:root "$DISPATCHER"
sudo chmod 755 "$DISPATCHER"

if command_exists dnsmasq; then
    echo_success "Dnsmasq already installed!"
    return
fi

sudo apt-get install dnsmasq -y

DNSMASQCONF="/etc/dnsmasq.conf";
RESOLVCONF="/etc/resolv.conf";

if ! sudo mv "$DNSMASQCONF" "$DNSMASQCONF".bak; then
    echo_error "Can't move the old dnsmasq.conf file!"
    return 1
fi

# Get the server's primary IPv4 address dynamically
# This gets the source IP used for routing to 8.8.8.8 (a reliable public IP)
LOCAL_IP=$(ip route get 8.8.8.8 | awk '{print $7; exit}')

# Check if an IP was found
if [ -z "$LOCAL_IP" ]; then
    echo "Error: Could not determine server's IP address. Please check network configuration."
    return 1
fi

# upstream DNS server for non-local domain names, using Cloudflare and google public DNS
# add .test to resolve to your local machine
sudo tee "${DNSMASQCONF}" > /dev/null <<EOF
listen-address=127.0.0.1,${LOCAL_IP}
# Or, if you prefer the simpler, listen on all interfaces:
#listen-address=0.0.0.0

# Without this, dnsmasq ignores listen-address for the actual socket bind and
# grabs the wildcard 0.0.0.0:53/:67 anyway, which blocks libvirt's own
# per-network dnsmasq (e.g. the "default" NAT network used by KVM VMs, see
# scripts/kvm.sh) from binding to its bridge address (192.168.122.1).
# Use bind-dynamic, not bind-interfaces: at boot, dnsmasq.service can start
# before \${LOCAL_IP} is assigned to the interface yet, and bind-interfaces
# requires the address to already exist at start-up ("Cannot assign requested
# address" — confirmed on 2026-09-07, killed DNS resolution after a reboot
# since /etc/resolv.conf only points at 127.0.0.1). bind-dynamic tracks
# interfaces as they come up instead of binding once at start.
bind-dynamic

# Ensure upstream servers are defined
no-resolv
server=1.1.1.1
server=8.8.8.8

# Your custom local addresses
address=/.test/${LOCAL_IP}
EOF

if ! sudo mv "$RESOLVCONF" "$RESOLVCONF".bak; then
    echo_error "Can't move the old resolv.conf file!"
    return 1
fi

echo -e "nameserver 127.0.0.1" | sudo tee -a "$RESOLVCONF" > /dev/null

# Change the file’s attributes using the chattr command to make our file immutable.
# This prevents the local network manager from overwriting our changes:
sudo chattr +i /etc/resolv.conf

# reset nameservers
sudo systemctl restart dnsmasq

sudo apt-get update
