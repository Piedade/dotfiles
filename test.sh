#!/bin/sh -e

SUDO_CMD="sudo"

LIGHTDM_IMAGES="/usr/share/images"
lightdm_icon="red.png"
lightdm_background="SL-093020-35920-01.jpg"

echo "${YELLOW}Customizing lightdm...${RC}"
"${SUDO_CMD}" cp "$GITPATH/lightdm/images/$lightdm_icon" "$LIGHTDM_IMAGES/lightdm_icon.png"
"${SUDO_CMD}" cp "$GITPATH/lightdm/images/$lightdm_background" "$LIGHTDM_IMAGES/lightdm_background.png"
"${SUDO_CMD}" chown root:root "$LIGHTDM_IMAGES/$lightdm_icon" "$LIGHTDM_IMAGES/$lightdm_background"

## Check if conf file is already there.
THEME_CONF="/etc/lightdm/lightdm-gtk-greeter.conf"
if [ -e "$THEME_CONF" ]; then
    echo "${YELLOW}Moving old theme config file to $THEME_CONF.bak${RC}"
    if ! "${SUDO_CMD}" mv "$THEME_CONF" "$THEME_CONF.bak"; then
        echo "${RED}Can't move theme config file!${RC}"
        exit 1
    fi
fi

"${SUDO_CMD}" cp "$GITPATH/lightdm/lightdm-gtk-greeter.conf" "$THEME_CONF"
