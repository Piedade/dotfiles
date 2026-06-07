#!/bin/bash

# Startup applications (exec — runs once per session)

## System tray / polkit
lxpolkit &

## Keyring (SSH agent + secrets)
eval $(gnome-keyring-daemon --start --components=pkcs11,secrets,ssh)
export SSH_AUTH_SOCK
systemctl --user import-environment SSH_AUTH_SOCK
ssh-add ~/.ssh/id_ed25519 2>/dev/null

## Clipboard history watcher
wl-paste --watch cliphist store &

## systemd / D-Bus environment for portals
export XDG_CURRENT_DESKTOP=sway
systemctl --user import-environment DISPLAY WAYLAND_DISPLAY SWAYSOCK XDG_CURRENT_DESKTOP
dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY SWAYSOCK XDG_CURRENT_DESKTOP
systemctl --user start xdg-desktop-portal-wlr
