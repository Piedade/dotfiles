#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $SCRIPT_DIR/../utils.sh

echo_info "Installing Hyprland packages..."
sleep 1

execute_script "00-dependencies.sh"
sleep 1

execute_script "hyprutils.sh"
sleep 1

execute_script "hyprlang.sh"
sleep 1

execute_script "hyprcursor.sh"
sleep 1

execute_script "hyprwayland-scanner.sh"
sleep 1

execute_script "hyprgraphics.sh"
sleep 1

execute_script "aquamarine.sh"
sleep 1

execute_script "hyprland-qt-support.sh"
sleep 1

execute_script "hyprtoolkit.sh"
sleep 1

execute_script "hyprland-guiutils.sh"
sleep 1

execute_script "hyprland-protocols.sh"
sleep 1

# Ensure wayland-protocols (from source) is installed to satisfy Hyprland's >= 1.45 requirement
execute_script "wayland-protocols-src.sh"
sleep 1

execute_script "xkbcommon.sh"
sleep 1

execute_script "hyprwire.sh"
sleep 1

execute_script "hyprland.sh"
sleep 1

execute_script "hyprpolkitagent.sh"
sleep 1

execute_script "hyprlock.sh"
sleep 1

execute_script "hypridle.sh"
sleep 1

execute_script "xdg-desktop-portal-hyprland.sh"
sleep 1
