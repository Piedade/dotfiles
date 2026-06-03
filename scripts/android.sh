#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/check_env.sh"

ANDROID_STUDIO_FILE="https://redirector.gvt1.com/edgedl/android/studio/ide-zips/2025.3.1.5/android-studio-2025.3.1.5-linux.tar.gz"

echo_info "Installing Android Studio..."

if [ -d "/opt/android-studio" ]; then
    echo_success "Android Studio already installed!"
    return
fi

# JDK: Android Studio usually bundles its own JDK, but it's good to have OpenJDK installed
sudo apt-get -y install default-jdk

# 32-bit libraries (for 64-bit systems): Android Studio and the emulator often rely on some 32-bit libraries.
sudo apt-get -y install libc6:i386 libncurses6:i386 libstdc++6:i386 zlib1g:i386 libbz2-1.0:i386

# Download Android Studio
wget -O android-studio.tar.gz "$ANDROID_STUDIO_FILE"
tar -xvzf android-studio.tar.gz
sudo mv android-studio /opt/
sudo rm -f android-studio.tar.gz

# Hardware VM acceleration uses your computer's processor to significantly improve the execution speed of the emulator
sudo apt-get install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils

# Register Android Studio in the application menu
mkdir -p "$HOME/.local/share/applications"
cat > "$HOME/.local/share/applications/jetbrains-studio.desktop" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Android Studio
Comment=The Drive to Develop
Exec=/opt/android-studio/bin/studio %f
Icon=/opt/android-studio/bin/studio.svg
Categories=Development;IDE;
Terminal=false
StartupNotify=false
StartupWMClass=jetbrains-studio
EOF

# Update desktop database so launchers pick it up
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true

echo_success "Android Studio installed!"
echo_info "Run it with: /opt/android-studio/bin/studio.sh"
echo_info "Or search for 'Android Studio' in your launcher"
