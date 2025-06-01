#!/bin/bash

echo_info "Installing Starship..."

if command_exists starship; then
    echo_success "Starship already installed!"
    return
fi

if ! curl -sS https://starship.rs/install.sh | sh -s -- -y; then
    echo_error "Something went wrong during starship install!"
    exit 1
fi

echo_success "Starship installed!"
