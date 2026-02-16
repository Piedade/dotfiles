#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $SCRIPT_DIR/utils.sh
source $SCRIPT_DIR/check_env.sh

echo_info "Linking config files..."

# ln -sfv ~/.dotfiles/.config/waybar ~/.config/waybar

link_file ".bashrc" $GITPATH $USER_HOME

link_file ".my.cnf" $GITPATH $USER_HOME

link_file ".gitconfig" $GITPATH $USER_HOME

link_file ".gitignore" $GITPATH $USER_HOME

link_file ".config/waybar" $GITPATH $USER_HOME

link_file ".config/hypr" $GITPATH $USER_HOME

link_file ".config/rofi" $GITPATH $USER_HOME

link_file ".config/Thunar" $GITPATH $USER_HOME

link_file ".config/alacritty" $GITPATH $USER_HOME

link_file ".config/wallpaper.sh" $GITPATH $USER_HOME

link_file ".config/starship.toml" $GITPATH $USER_HOME

link_file ".config/mimeapps.list" $GITPATH $USER_HOME

# link_file ".vscode" $GITPATH $USER_HOME

echo_success "Linked config done!"
