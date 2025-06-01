#!/bin/bash

ensure_dir $USER_HOME/.local/bin

cat > ~/.local/bin/php <<'EOF'
#!/usr/bin/env bash
exec "$PHP_BIN" "$@"
EOF

chmod +x ~/.local/bin/php

