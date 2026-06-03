#!/bin/bash

echo_info "Installing galculator..."

if command_exists galculator; then
    echo_success "Galculator already installed!"
    return
fi

sudo apt-get -y install galculator
