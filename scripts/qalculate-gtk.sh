#!/bin/bash

echo_info "Installing calculator..."

"${SUDO_CMD}" apt-get install -y qalculate-gtk
