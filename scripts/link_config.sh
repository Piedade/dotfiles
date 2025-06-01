#!/bin/bash

echo_info "Linking config folder..."

## Check if a bashrc file is already there.
OLD_BASHRC="$USER_HOME/.bashrc"
if [ -e "$OLD_BASHRC" ]; then
    echo_info "Moving old bash config file to $USER_HOME/.bashrc.bak"
    if ! mv "$OLD_BASHRC" "$USER_HOME/.bashrc.bak"; then
        echo_error "Can't move the old bash config file!"
        exit 1
    fi
fi

echo_info "Linking new bash config file..."
ln -svf "$GITPATH/.bashrc" "$USER_HOME/.bashrc" || {
    echo_error "Failed to create symbolic link for .bashrc"
    exit 1
}

CONFIG_DIR="$USER_HOME/.config"
# Create the config directory if it doesn't exist
if [ ! -d "$CONFIG_DIR" ]; then
    mkdir -p "$CONFIG_DIR" || {
        echo_error "Failed to create directory: $CONFIG_DIR"
        return 1
    }
else
    echo_info "$CONFIG_DIR exists, skipping creation."
fi

echo_info "Linking config files..."
for file in "$GITPATH/config"/*; do
    filename=$(basename "$file")

    "${SUDO_CMD}" ln -svf "$file" "$CONFIG_DIR/$filename" || {
        echo_error "Failed to create symbolic link for $filename"
        exit 1
    }
done

# FIX PERMISSIONS
"${SUDO_CMD}" chown -R $USER:$USER $CONFIG_DIR

DWMPATH="$GITPATH/dwm"
DWMBLOCKSPATH="$DWMPATH/blocks"

echo_info "Linking dwmblocks scripts to /usr/local/bin..."
for file in "$DWMBLOCKSPATH/scripts"/*; do
    filename=$(basename "$file")

    "${SUDO_CMD}" ln -svf "$file" "/usr/local/bin/$filename" || {
        echo_error "Failed to create symbolic link for $filename"
        exit 1
    }
done

"${SUDO_CMD}" cp "$DWMPATH/dwm.desktop" /usr/share/xsessions

echo_info "Compiling dwm and dwmblocks..."
cd "$DWMPATH" && "${SUDO_CMD}" make clean install
cd "$DWMBLOCKSPATH" && "${SUDO_CMD}" make clean install
cd "$GITPATH" # reset pwd

echo_success "Config folder linked!"
