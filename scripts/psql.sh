#!/bin/bash

echo_info "Installing PostgreSQL..."

"${SUDO_CMD}" apt-get install -y postgresql

"${SUDO_CMD}" su - postgres -c "createuser piedade --superuser"
