#!/bin/bash

echo_info()    { echo -e "\033[1;34m[INFO]\033[0m $1"; }
echo_success() { echo -e "\033[1;32m[SUCCESS]\033[0m $1"; }
echo_error()   { echo -e "\033[1;31m[ERROR]\033[0m $1"; }

ensure_dir() {
    [ ! -d "$1" ] && mkdir -p "$1"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Redirect both stdout and stderr to the log file and display in the terminal
enable_log(){
    exec > >(tee -a "$LOG_FILE") 2>&1
}

# Redirect output directly to the terminal
disable_log(){
    exec > /dev/tty 2>/dev/tty
}

# Function to execute a script if it exists and make it executable
execute_script() {
    local script="$1"
    local script_path="$SCRIPT_DIR/$script"
    if [ -f "$script_path" ]; then
        chmod +x "$script_path"
        if [ -x "$script_path" ]; then
            env "$script_path"
        else
            echo_error "Failed to make script '$script' executable."
        fi
    else
        echo_error "Script '$script' not found in '$SCRIPT_DIR'."
    fi
}

# Function for installing packages with a progress bar
install_package() { 
  if dpkg -l | grep -q -w "$1" ; then
    echo_info "$1 is already installed. Skipping..."
  else 
    sudo apt-get install -y "$1"
    
    # Double check if the package successfully installed
    if dpkg -l | grep -q -w "$1"; then
        echo_success "Package $1 has been successfully installed!"
    else
        echo_error "$1 failed to install. Please check the install.log"
    fi
  fi
}

# Function for build depencies with a progress bar
build_dep() { 
    echo_info "Building dependencies for $1"
    sudo apt-get build-dep -y "$1"
}

# Function for cargo install with a progress bar
cargo_install() { 
    echo_info "Installing $1 using cargo..."
    cargo install "$1"
}

# Function for re-installing packages with a progress bar
re_install_package() {
    sudo apt install --reinstall -y "$1"
    
    if dpkg -l | grep -q -w "$1"; then
        echo_success "Package $1 has been successfully re-installed!"
    else
        echo_error "$1 failed to re-install. Please check the install.log"
    fi
}
