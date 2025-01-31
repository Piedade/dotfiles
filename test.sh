#!/bin/bash

RC='\033[0m'
RED='\033[31m'
YELLOW='\033[33m'
GREEN='\033[32m'

FONT_DIR="$HOME/.local/share/fonts"

# Create the fonts directory if it doesn't exist
if [ ! -d "$FONT_DIR" ]; then
    mkdir -p "$FONT_DIR" || {
        echo "Failed to create directory: $FONT_DIR"
        return 1
    }
else
    echo "$FONT_DIR exists, skipping creation."
fi

# INSTALL Meslo Fonts
FONT_ZIP="$FONT_DIR/Meslo.zip"
FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Meslo.zip"
FONT_INSTALLED=$(fc-list | grep -i "Meslo")

if [ -n "$FONT_INSTALLED" ]; then
    echo "Meslo Nerd-fonts are already installed."
else
    echo "${YELLOW}Installing Meslo Nerd-fonts${RC}"

    # Check if the font zip file already exists
    if [ ! -f "$FONT_ZIP" ]; then
        # Download the font zip file
        wget -P "$FONT_DIR" "$FONT_URL" || {
            echo "Failed to download Meslo Nerd-fonts from $FONT_URL"
            return 1
        }
    else
        echo "Meslo.zip already exists in $FONT_DIR, skipping download."
    fi

    # Unzip the font file if it hasn't been unzipped yet
    if [ ! -d "$FONT_DIR/Meslo" ]; then
        unzip "$FONT_ZIP" -d "$FONT_DIR" || {
            echo "Failed to unzip $FONT_ZIP"
            return 1
        }
    else
        echo "Meslo font files already unzipped in $FONT_DIR, skipping unzip."
    fi

    # Remove the zip file
    rm "$FONT_ZIP" || {
        echo "Failed to remove $FONT_ZIP"
        return 1
    }

    echo "${GREEN}Meslo Nerd-fonts installed successfully${RC}"
fi

# INSTALL Apple Fonts
FONT_ZIP="$FONT_DIR/Apple-Fonts.zip"
FONT_URL="https://github.com/oyezcubed/Apple-Fonts-San-Francisco-New-York/archive/refs/heads/master.zip"
FONT_INSTALLED=$(fc-list | grep -i "SF-")

if [ -n "$FONT_INSTALLED" ]; then
    echo "Apple fonts are already installed."
else
    echo "${YELLOW}Installing Apple fonts${RC}"

    # Check if the font zip file already exists
    if [ ! -f "$FONT_ZIP" ]; then
        # Download the font zip file
        wget -O "$FONT_ZIP" "$FONT_URL" || {
            echo "Failed to download Apple fonts from $FONT_URL"
            return 1
        }
    else
        echo "Apple-Fonts.zip already exists in $FONT_DIR, skipping download."
    fi

    # Unzip the font file if it hasn't been unzipped yet
    if [ ! -d "$FONT_DIR/Apple-Fonts-San-Francisco-New-York-master" ]; then
        unzip "$FONT_ZIP" -d "$FONT_DIR" || {
            echo "Failed to unzip $FONT_ZIP"
            return 1
        }
    else
        echo "Apple fonts files already unzipped in $FONT_DIR, skipping unzip."
    fi

    # Move fonts
    find "$FONT_DIR/Apple-Fonts-San-Francisco-New-York-master" -type f -exec mv {} "$FONT_DIR/" \; || {
        echo "Failed to move Apple-Fonts-San-Francisco-New-York-master files to $FONT_DIR"
        return 1
    }

    # Remove the zip file
    rm -rf "$FONT_ZIP" "$FONT_DIR/Apple-Fonts-San-Francisco-New-York-master" || {
        echo "Failed to remove $FONT_ZIP"
        return 1
    }
fi

# Rebuild the font cache
fc-cache -fv || {
    echo "Failed to rebuild font cache"
    return 1
}

# clean
rm "$FONT_DIR"/*.txt "$FONT_DIR"/*.md || {
    echo "Failed to clean $FONT_ZIP"
    return 1
}
