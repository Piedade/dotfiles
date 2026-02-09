#!/bin/bash

source ./utils.sh
source ./check_env.sh

echo_info "Linking config files..."

link_file ".bashrc" $GITPATH $USER_HOME
link_file ".my.cnf" $GITPATH $USER_HOME
link_file ".gitconfig" $GITPATH $USER_HOME
link_file ".gitignore" $GITPATH $USER_HOME

# ln -sfv ~/.dotfiles/.config/waybar ~/.config/waybar
link_file ".config/waybay" $GITPATH $USER_HOME

# ln -sfv ~/.dotfiles/.config/hypr ~/.config/hypr
link_file ".config/hypr" $GITPATH $USER_HOME


echo_info "Linking folders..."

# link_folder ".config" $GITPATH $USER_HOME
link_folder ".vscode" $GITPATH $USER_HOME

# # DWM config
# DWMPATH="$GITPATH/dwm"
# DWMBLOCKSPATH="$DWMPATH/blocks"

# echo_info "Linking dwmblocks scripts to /usr/local/bin..."
# link_folder "scripts" $DWMBLOCKSPATH "/usr/local/bin/"

# # Add desktop session for dwm
# "${SUDO_CMD}" cp "$DWMPATH/dwm.desktop" /usr/share/xsessions

# echo_info "Compiling dwm and dwmblocks..."
# cd "$DWMPATH" && "${SUDO_CMD}" make clean install
# cd "$DWMBLOCKSPATH" && "${SUDO_CMD}" make clean install
# cd "$GITPATH" # reset pwd

echo_success "Linked config done!"
