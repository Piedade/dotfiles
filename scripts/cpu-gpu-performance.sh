#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/check_env.sh"

echo_info "Installing CPU/GPU performance mode service..."

UNIT_FILE="/etc/systemd/system/performance-mode.service"

if [ -f "$UNIT_FILE" ]; then
    echo_success "Performance mode service already installed!"
    return
fi

sudo tee "$UNIT_FILE" > /dev/null << 'EOF'
[Unit]
Description=Force CPU governor and GPU DPM level to performance
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo performance > "$gov"; done; echo high > /sys/class/drm/card0/device/power_dpm_force_performance_level'

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now performance-mode.service

echo_success "CPU/GPU performance mode service installed!"
