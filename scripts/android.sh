#!/bin/bash

ANDROID_STUDIO_FILE="https://redirector.gvt1.com/edgedl/android/studio/ide-zips/2025.1.1.14/android-studio-2025.1.1.14-linux.tar.gz"

echo_info "Installing Android Studio..."

# JDK: Android Studio usually bundles its own JDK, but it's good to have OpenJDK installed
"${SUDO_CMD}" apt-get -y install default-jdk

# 32-bit libraries (for 64-bit systems): Android Studio and the emulator often rely on some 32-bit libraries.
"${SUDO_CMD}" apt-get -y install libc6:i386 libncurses5:i386 libstdc++6:i386 lib32z1 libbz2-1.0:i386

# Download Android Studio
wget -O android-studio.tar.gz "$ANDROID_STUDIO_FILE"
tar -xvzf android-studio.tar.gz
"${SUDO_CMD}" mv android-studio /opt/
"${SUDO_CMD}" rm -f android-studio.tar.gz

# Hardware VM acceleration uses your computer's processor to significantly improve the execution speed of the emulator
"${SUDO_CMD}" apt-get install qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils

echo_success "Android Studio installed! (you should run /opt/android-studio/bin/studio.sh)"
