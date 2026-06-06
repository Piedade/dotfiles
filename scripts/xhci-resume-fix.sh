#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/check_env.sh"

echo_info "Installing xHCI resume fix..."

HOOK_FILE="/usr/lib/systemd/system-sleep/xhci-reset.sh"

if [ -f "$HOOK_FILE" ]; then
    echo_success "xHCI resume fix already installed!"
    return
fi

sudo tee "$HOOK_FILE" > /dev/null << 'EOF'
#!/bin/bash
if [ "$1" = "post" ]; then
    for xhci in /sys/bus/pci/drivers/xhci_hcd/????:??:??.?; do
        [ -e "$xhci" ] || continue
        echo "${xhci##*/}" > /sys/bus/pci/drivers/xhci_hcd/unbind
        echo "${xhci##*/}" > /sys/bus/pci/drivers/xhci_hcd/bind
    done
fi
EOF

sudo chmod +x "$HOOK_FILE"

echo_success "xHCI resume fix installed!"
