#!/bin/bash

echo_info "Checking environment..."

# add variables to top level so can easily be accessed by all functions
SUDO_CMD="sudo"
SUGROUP=""
GITPATH=""

# for some reason, curl is not installed by default
"${SUDO_CMD}" apt-get install curl -y

# Get the correct user home directory.
USER_HOME=$(getent passwd "${SUDO_USER:-$USER}" | cut -d: -f6)

# Check for requirements.
REQUIREMENTS='curl wget groups sudo'
for req in $REQUIREMENTS; do
    if ! command_exists "$req"; then
        echo_error "To run me, you need: $REQUIREMENTS"
        exit 1
    fi
done

echo_info "Using $SUDO_CMD as privilege escalation software"

# Check if the current directory is writable.
GITPATH=$(dirname "$(realpath "$0")")
if [ ! -w "$GITPATH" ]; then
    echo_error "Can't write to $GITPATH"
    exit 1
fi

# Check SuperUser Group
SUPERUSERGROUP='wheel sudo root'
for sug in $SUPERUSERGROUP; do
    if groups | grep -q "$sug"; then
        SUGROUP="$sug"
        echo_info "Super user group $SUGROUP"
        break
    fi
done

# Check if member of the sudo group.
if ! groups | grep -q "$SUGROUP"; then
    echo_error "You need to be a member of the sudo group to run me!"
    exit 1
fi

# Add user to adm group for log access
"${SUDO_CMD}" usermod -aG adm $USER

# Ensure your user has access to DRM devices
"${SUDO_CMD}" usermod -aG video $USER

# Link a single file
link_file(){
    # Check if file is already there.
    OLD_FILE="$3/$1"
    if [ -e "$OLD_FILE" ]; then
        echo_info "Moving old bash config file to $3/$1.bak"
        if ! mv "$OLD_FILE" "$3/$1.bak"; then
            echo_error "Can't move the old config file!"
            exit 1
        fi
    fi

    echo_info "Linking new config file..."
    ln -svf "$2/$1" "$3/$1" || {
        echo_error "Failed to create symbolic link for $1"
        exit 1
    }
}

# Link a folder and its contents
link_folder(){
    SRC="$2/../$1"
    DEST="$3/$1"


#     mkdir -p "$DEST"
#     echo_info "Linking $1 (top-level only)..."
#     for item in "$SRC"/*; do
#         name=$(basename "$item")
#         ln -sfn "$item" "$DEST/$name"
#     done

    echo_info "Linking $1 (files only, recursive)..."

    find "$SRC" -type f | while read -r file; do
        rel="${file#$SRC/}"
        target="$DEST/$rel"

        mkdir -p "$(dirname "$target")"
        ln -sfn "$file" "$target"
    done

    # FIX PERMISSIONS
    "${SUDO_CMD}" chown -R $USER:$USER $FOLDER_TO_LINK
}
