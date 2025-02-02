#!/bin/bash

RC='\033[0m'
RED='\033[31m'
YELLOW='\033[33m'
GREEN='\033[32m'

# add variables to top level so can easily be accessed by all functions
SUDO_CMD=""
SUGROUP=""
GITPATH=""

## Get the correct user home directory.
USER_HOME=$(getent passwd "${SUDO_USER:-$USER}" | cut -d: -f6)

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

checkEnv() {
    ## Check for requirements.
    REQUIREMENTS='curl groups sudo'
    for req in $REQUIREMENTS; do
        if ! command_exists "$req"; then
            echo "${RED}To run me, you need: $REQUIREMENTS${RC}"
            exit 1
        fi
    done

    SUDO_CMD="sudo"

    echo "Using $SUDO_CMD as privilege escalation software"

    ## Check if the current directory is writable.
    GITPATH=$(dirname "$(realpath "$0")")
    if [ ! -w "$GITPATH" ]; then
        echo "${RED}Can't write to $GITPATH${RC}"
        exit 1
    fi

    ## Check SuperUser Group

    SUPERUSERGROUP='wheel sudo root'
    for sug in $SUPERUSERGROUP; do
        if groups | grep -q "$sug"; then
            SUGROUP="$sug"
            echo "Super user group $SUGROUP"
            break
        fi
    done

    ## Check if member of the sudo group.
    if ! groups | grep -q "$SUGROUP"; then
        echo "${RED}You need to be a member of the sudo group to run me!${RC}"
        exit 1
    fi
}

installDependencies() {
    echo "${YELLOW}Installing dependencies...${RC}"

    # Update packages list and update system
    "${SUDO_CMD}" apt update
    "${SUDO_CMD}" apt upgrade -y

    # Installing Essential Programs
    "${SUDO_CMD}" apt-get install build-essential libxcb-util-dev numlockx feh rofi unzip wget pipewire wireplumber pavucontrol libx11-dev libxft-dev libxinerama-dev libx11-xcb-dev libxcb-res0-dev alsa-utils xdg-utils libimlib2-dev policykit-1-gnome gnome-keyring thunar file-roller dunst -y

    # Installing Other less important Programs
    "${SUDO_CMD}" apt-get install fzf libnotify-bin trash-cli flameshot psmisc neovim papirus-icon-theme lxappearance lightdm xclip bat multitail tree zoxide bash-completion ripgrep alacritty gimp fonts-liberation fonts-noto-color-emoji -y

    # Enable graphical login and change target from CLI to GUI
    systemctl enable lightdm
    systemctl set-default graphical.target
}

installGitHubCLI() {
    (type -p wget >/dev/null || ("${SUDO_CMD}" apt update && "${SUDO_CMD}" apt-get install wget -y)) \
	&& "${SUDO_CMD}" mkdir -p -m 755 /etc/apt/keyrings \
        && out=$(mktemp) && wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        && cat $out | "${SUDO_CMD}" tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
	&& "${SUDO_CMD}" chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
	&& echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | "${SUDO_CMD}" tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
	&& "${SUDO_CMD}" apt update \
	&& "${SUDO_CMD}" apt install gh -y
}

installFonts() {
    FONT_DIR="$USER_HOME/.local/share/fonts"

    # Create the fonts directory if it doesn't exist
    if [ ! -d "$FONT_DIR" ]; then
        mkdir -p "$FONT_DIR" || {
            echo "Failed to create directory: $FONT_DIR"
            return 1
        }
    else
        echo "$FONT_DIR exists, skipping creation."
    fi

    # INSTALL Meslo Fonts
    FONT_ZIP="$FONT_DIR/Meslo.zip"
    FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Meslo.zip"
    FONT_INSTALLED=$(fc-list | grep -i "Meslo")

    if [ -n "$FONT_INSTALLED" ]; then
        echo "Meslo Nerd-fonts are already installed."
    else
        echo "${YELLOW}Installing Meslo Nerd-fonts${RC}"

        # Check if the font zip file already exists
        if [ ! -f "$FONT_ZIP" ]; then
            # Download the font zip file
            wget -P "$FONT_DIR" "$FONT_URL" || {
                echo "Failed to download Meslo Nerd-fonts from $FONT_URL"
                return 1
            }
        else
            echo "Meslo.zip already exists in $FONT_DIR, skipping download."
        fi

        # Unzip the font file if it hasn't been unzipped yet
        if [ ! -d "$FONT_DIR/Meslo" ]; then
            unzip "$FONT_ZIP" -d "$FONT_DIR" || {
                echo "Failed to unzip $FONT_ZIP"
                return 1
            }
        else
            echo "Meslo font files already unzipped in $FONT_DIR, skipping unzip."
        fi

        # Remove the zip file
        rm "$FONT_ZIP" || {
            echo "Failed to remove $FONT_ZIP"
            return 1
        }

        echo "${GREEN}Meslo Nerd-fonts installed successfully${RC}"
    fi

    # INSTALL Apple Fonts
    FONT_ZIP="$FONT_DIR/Apple-Fonts.zip"
    FONT_URL="https://github.com/oyezcubed/Apple-Fonts-San-Francisco-New-York/archive/refs/heads/master.zip"
    FONT_INSTALLED=$(fc-list | grep -i "SF-")

    if [ -n "$FONT_INSTALLED" ]; then
        echo "Apple fonts are already installed."
    else
        echo "${YELLOW}Installing Apple fonts${RC}"

        # Check if the font zip file already exists
        if [ ! -f "$FONT_ZIP" ]; then
            # Download the font zip file
            wget -O "$FONT_ZIP" "$FONT_URL" || {
                echo "Failed to download Apple fonts from $FONT_URL"
                return 1
            }
        else
            echo "Apple-Fonts.zip already exists in $FONT_DIR, skipping download."
        fi

        # Unzip the font file if it hasn't been unzipped yet
        if [ ! -d "$FONT_DIR/Apple-Fonts-San-Francisco-New-York-master" ]; then
            unzip "$FONT_ZIP" -d "$FONT_DIR" || {
                echo "Failed to unzip $FONT_ZIP"
                return 1
            }
        else
            echo "Apple fonts files already unzipped in $FONT_DIR, skipping unzip."
        fi

        # Move fonts
        find "$FONT_DIR/Apple-Fonts-San-Francisco-New-York-master" -type f -exec mv {} "$FONT_DIR/" \; || {
            echo "Failed to move Apple-Fonts-San-Francisco-New-York-master files to $FONT_DIR"
            return 1
        }

        # Remove the zip file
        rm -rf "$FONT_ZIP" "$FONT_DIR/Apple-Fonts-San-Francisco-New-York-master" || {
            echo "Failed to remove $FONT_ZIP"
            return 1
        }
    fi

    # Rebuild the font cache
    fc-cache -fv || {
        echo "Failed to rebuild font cache"
        return 1
    }

    # clean
    rm "$FONT_DIR"/*.txt "$FONT_DIR"/*.md || {
        echo "Failed to clean $FONT_ZIP"
        return 1
    }

    #FIX PERMISSIONS
    "${SUDO_CMD}" chown -R piedade:piedade "$USER_HOME/.local"
}

installStarship() {
    if command_exists starship; then
        echo "Starship already installed"
        return
    fi

    if ! curl -sS https://starship.rs/install.sh | sh -s -- -y; then
        echo "${RED}Something went wrong during starship install!${RC}"
        exit 1
    fi
}


linkConfig() {
    ## Check if a bashrc file is already there.
    OLD_BASHRC="$USER_HOME/.bashrc"
    if [ -e "$OLD_BASHRC" ]; then
        echo "${YELLOW}Moving old bash config file to $USER_HOME/.bashrc.bak${RC}"
        if ! mv "$OLD_BASHRC" "$USER_HOME/.bashrc.bak"; then
            echo "${RED}Can't move the old bash config file!${RC}"
            exit 1
        fi
    fi

    echo "${YELLOW}Linking new bash config file...${RC}"
    ln -svf "$GITPATH/.bashrc" "$USER_HOME/.bashrc" || {
        echo "${RED}Failed to create symbolic link for .bashrc${RC}"
        exit 1
    }

    CONFIG_DIR="$USER_HOME/.config"
    # Create the config directory if it doesn't exist
    if [ ! -d "$CONFIG_DIR" ]; then
        mkdir -p "$CONFIG_DIR" || {
            echo "Failed to create directory: $CONFIG_DIR"
            return 1
        }
    else
        echo "$CONFIG_DIR exists, skipping creation."
    fi

    echo "${YELLOW}Linking config files...${RC}"
	for file in "$GITPATH/config"/*; do
		filename=$(basename "$file")

		"${SUDO_CMD}" ln -svf "$file" "$CONFIG_DIR/$filename" || {
		    echo "${RED}Failed to create symbolic link for $filename${RC}"
		    exit 1
		}
	done

    #FIX PERMISSIONS
	"${SUDO_CMD}" chown -R piedade:piedade $CONFIG_DIR

    DWMPATH="$GITPATH/dwm"
    DWMBLOCKSPATH="$DWMPATH/blocks"

    echo "${YELLOW}Linking dwmblocks scripts to /usr/local/bin...${RC}"
    for file in "$DWMBLOCKSPATH/scripts"/*; do
		filename=$(basename "$file")

		"${SUDO_CMD}" ln -svf "$file" "/usr/local/bin/$filename" || {
		    echo "${RED}Failed to create symbolic link for $filename${RC}"
		    exit 1
		}
    done

    "${SUDO_CMD}" cp "$DWMPATH/dwm.desktop" /usr/share/xsessions

    echo "${YELLOW}Compiling dwm and dwmblocks...${RC}"
    cd "$DWMPATH" && "${SUDO_CMD}" make clean install
    cd "$DWMBLOCKSPATH" && "${SUDO_CMD}" make clean install
    cd "$GITPATH" # reset pwd
}

customizeLightdm() {
    LIGHTDM_IMAGES="/usr/share/images"
    lightdm_icon="red.png"
    lightdm_background="SL-093020-35920-01.jpg"

    echo "${YELLOW}Customizing lightdm...${RC}"
    "${SUDO_CMD}" cp "$GITPATH/lightdm/images/$lightdm_icon" "$LIGHTDM_IMAGES/lightdm_icon.png"
    "${SUDO_CMD}" cp "$GITPATH/lightdm/images/$lightdm_background" "$LIGHTDM_IMAGES/lightdm_background.png"
    # "${SUDO_CMD}" chown root:root "$LIGHTDM_IMAGES/lightdm_icon.png" "$LIGHTDM_IMAGES/lightdm_background.png"


    LIGHT_CONF="/etc/lightdm/lightdm.conf"
    if [ -e "$LIGHT_CONF" ]; then
        echo "${YELLOW}Moving old theme config file to $LIGHT_CONF.bak${RC}"
        if ! "${SUDO_CMD}" mv "$LIGHT_CONF" "$LIGHT_CONF.bak"; then
            echo "${RED}Can't move theme config file!${RC}"
            exit 1
        fi
    fi
    "${SUDO_CMD}" cp "$GITPATH/lightdm/lightdm.conf" "$LIGHT_CONF"


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
}

installVsCode() {
    printf "%b\n" "${YELLOW}Installing VS Code..${RC}."
	wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
    "${SUDO_CMD}" install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
    echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | "${SUDO_CMD}" tee /etc/apt/sources.list.d/vscode.list > /dev/null
    rm -f packages.microsoft.gpg
    "${SUDO_CMD}" apt update
    "${SUDO_CMD}" apt install -y apt-transport-https code
}

installChrome() {
	wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
	"${SUDO_CMD}" dpkg -i ./google-chrome-stable_current_amd64.deb
	"${SUDO_CMD}" apt-get -f install
	rm ./google-chrome-stable_current_amd64.deb
}

checkEnv

installDependencies
installGitHubCLI
installFonts
installStarship

installVsCode
installChrome

customizeLightdm
linkConfig

"${SUDO_CMD}" systemctl reboot
