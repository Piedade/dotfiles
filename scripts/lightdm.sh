#!/bin/bash

LIGHTDM_IMAGES="/usr/share/images"
lightdm_icon="red.png"
lightdm_background="SL-093020-35920-01.jpg"

echo_info "Customizing lightdm..."

"${SUDO_CMD}" cp "$GITPATH/lightdm/images/$lightdm_icon" "$LIGHTDM_IMAGES/lightdm_icon.png"
"${SUDO_CMD}" cp "$GITPATH/lightdm/images/$lightdm_background" "$LIGHTDM_IMAGES/lightdm_background.png"
# "${SUDO_CMD}" chown root:root "$LIGHTDM_IMAGES/lightdm_icon.png" "$LIGHTDM_IMAGES/lightdm_background.png"

LIGHT_CONF="/etc/lightdm/lightdm.conf"
if [ -e "$LIGHT_CONF" ]; then
    echo_info "Moving old theme config file to $LIGHT_CONF.bak"
    if ! "${SUDO_CMD}" mv "$LIGHT_CONF" "$LIGHT_CONF.bak"; then
        echo_error "Can't move theme config file!"
        exit 1
    fi
fi
"${SUDO_CMD}" cp "$GITPATH/lightdm/lightdm.conf" "$LIGHT_CONF"

## Check if conf file is already there.
THEME_CONF="/etc/lightdm/lightdm-gtk-greeter.conf"
if [ -e "$THEME_CONF" ]; then
    echo_info "Moving old theme config file to $THEME_CONF.bak"
    if ! "${SUDO_CMD}" mv "$THEME_CONF" "$THEME_CONF.bak"; then
        echo_error "Can't move theme config file!"
        exit 1
    fi
fi
"${SUDO_CMD}" cp "$GITPATH/lightdm/lightdm-gtk-greeter.conf" "$THEME_CONF"

echo_success "Lightdm configured!"
