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
