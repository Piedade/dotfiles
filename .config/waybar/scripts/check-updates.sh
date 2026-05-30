#!/bin/bash
# Check for available system updates (Debian/Ubuntu)
# This script counts packages that have updates available

# Check if running Debian/Ubuntu with apt
if ! command -v apt &> /dev/null; then
    echo "N/A"
    exit 0
fi

# Get list of upgradable packages
# Using apt list --upgradable, which shows:
# - First line: "Listing..." (we exclude this)
# - Following lines: actual packages with updates
updates=$(apt list --upgradable 2>/dev/null | tail -n +2 | wc -l)

# Display update count, or hide if zero
if [ "$updates" -gt 0 ]; then
    echo "$updates"
else
    echo ""  # Empty = icon hidden in waybar
fi
