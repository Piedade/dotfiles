#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/check_env.sh"

echo_info "Installing fonts..."

echo "ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true" | sudo debconf-set-selections
sudo apt-get install -y \
    curl unzip \
    fonts-recommended fonts-font-awesome fonts-noto-color-emoji \
    fonts-roboto fonts-lato fonts-inter fonts-open-sans fonts-montserrat \
    fonts-noto-core fonts-liberation fonts-dejavu \
    fonts-adobe-sourcesans3 \
    ttf-mscorefonts-installer

FONT_DIR="$HOME/.local/share/fonts"

installGoogleFont() {
    local fontName="$1"
    local fontSlug="${2:-$(echo "$fontName" | tr '[:upper:]' '[:lower:]' | tr -d ' ')}"
    local FONT_INSTALLED
    FONT_INSTALLED=$(fc-list | grep -i "$fontName")

    if [ -n "$FONT_INSTALLED" ]; then
        echo_success "$fontName font is already installed."
        return
    fi

    echo_info "Installing $fontName font"
    local fontDir="$FONT_DIR/$fontName"
    mkdir -p "$fontDir"

    local api_response
    api_response=$(curl -sf "https://api.github.com/repos/google/fonts/contents/ofl/${fontSlug}")

    if [ -z "$api_response" ]; then
        echo_error "Failed to fetch font list for $fontName from GitHub"
        rmdir "$fontDir" 2>/dev/null
        return
    fi

    local count=0
    while IFS= read -r url; do
        [ -z "$url" ] && continue
        local fname
        fname=$(basename "$url")
        curl -sf -o "$fontDir/$fname" "$url" && count=$((count + 1))
    done < <(echo "$api_response" | grep -oE 'https://raw\.githubusercontent\.com/[^"]+\.ttf')

    if [ "$count" -gt 0 ]; then
        echo_success "$fontName installed ($count files)"
    else
        echo_error "No font files downloaded for $fontName"
        rm -rf "$fontDir"
    fi
}

installFont() {
    local fontName="$1"

    # INSTALL Meslo Fonts
    FONT_ZIP="$FONT_DIR/$fontName.zip"
    FONT_URL="$2"
    FONT_INSTALLED=$(fc-list | grep -i "$fontName")

    if [ -n "$FONT_INSTALLED" ]; then
        echo_success "$fontName font is already installed."
    else
        echo_info "Installing $fontName font"

        # Check if the font zip file already exists
        if [ ! -f "$FONT_ZIP" ]; then
            # Download the font zip file
            wget -P "$FONT_DIR" "$FONT_URL" || {
                echo_error "Failed to download $fontName font from $FONT_URL"
            }
        else
            echo_info "$fontName.zip already exists in $FONT_DIR, skipping download."
        fi

        # Unzip the font file if it hasn't been unzipped yet
        if [ ! -d "$FONT_DIR/$fontName" ]; then
            unzip -o "$FONT_ZIP" -d "$FONT_DIR" || {
                echo_error "Failed to unzip $FONT_ZIP"
            }
        else
            echo_info "$fontName font files already unzipped in $FONT_DIR, skipping unzip."
        fi

        # Remove the zip file
        rm "$FONT_ZIP" || {
            echo_error "Failed to remove $FONT_ZIP"
        }

        echo_success "$fontName font installed successfully"
    fi
}

# Create the fonts directory if it doesn't exist
if [ ! -d "$FONT_DIR" ]; then
    mkdir -p "$FONT_DIR" || {
        echo_error "Failed to create directory: $FONT_DIR"
    }
else
    echo_info "$FONT_DIR exists, skipping creation."
fi

#FIX PERMISSIONS
sudo chown -R "$USER":"$USER" "$HOME/.local"

installFont "Meslo" https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Meslo.zip
installFont "FiraCode" https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip
installFont "JetBrainsMono" https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
installFont "RobotoMono" https://github.com/ryanoasis/nerd-fonts/releases/latest/download/RobotoMono.zip
installFont "SourceCodePro" https://github.com/ryanoasis/nerd-fonts/releases/latest/download/SourceCodePro.zip
installFont "Lilex" https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Lilex.zip
installFont "NerdFontsSymbolsOnly" https://github.com/ryanoasis/nerd-fonts/releases/latest/download/NerdFontsSymbolsOnly.zip

# INSTALL Apple Fonts
FONT_ZIP="$FONT_DIR/Apple-Fonts.zip"
FONT_URL="https://github.com/oyezcubed/Apple-Fonts-San-Francisco-New-York/archive/refs/heads/master.zip"
FONT_INSTALLED=$(fc-list | grep -i "SF-")

if [ -n "$FONT_INSTALLED" ]; then
    echo_success "Apple fonts are already installed."
else
    echo_info "Installing Apple fonts"

    # Check if the font zip file already exists
    if [ ! -f "$FONT_ZIP" ]; then
        # Download the font zip file
        wget -O "$FONT_ZIP" "$FONT_URL" || {
            echo_error "Failed to download Apple fonts from $FONT_URL"
        }
    else
        echo_info "Apple-Fonts.zip already exists in $FONT_DIR, skipping download."
    fi

    # Unzip the font file if it hasn't been unzipped yet
    if [ ! -d "$FONT_DIR/Apple-Fonts-San-Francisco-New-York-master" ]; then
        unzip "$FONT_ZIP" -d "$FONT_DIR" || {
            echo_error "Failed to unzip $FONT_ZIP"
        }
    else
        echo_info "Apple fonts files already unzipped in $FONT_DIR, skipping unzip."
    fi

    # Move fonts
    find "$FONT_DIR/Apple-Fonts-San-Francisco-New-York-master" -type f -exec mv {} "$FONT_DIR/" \; || {
        echo_error "Failed to move Apple-Fonts-San-Francisco-New-York-master files to $FONT_DIR"
    }

    # Remove the zip file
    rm -rf "$FONT_ZIP" "$FONT_DIR/Apple-Fonts-San-Francisco-New-York-master" || {
        echo_error "Failed to remove $FONT_ZIP"
    }
fi

installGoogleFont "SourceSerif4" "sourceserif4"
installGoogleFont "Poppins" "poppins"
installGoogleFont "Nunito" "nunito"
installGoogleFont "Merriweather" "merriweather"
installGoogleFont "Raleway" "raleway"

# Rebuild the font cache
fc-cache -fv || {
    echo_error "Failed to rebuild font cache"
}

# clean
rm "$FONT_DIR"/*.txt "$FONT_DIR"/*.md || {
    echo_error "Failed to clean $FONT_ZIP"
}
