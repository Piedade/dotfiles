#!/bin/bash

echo_info "Installing Archer T2U Nano AC600 (RTL8821AU) Wireless USB Adapter..."


# "${SUDO_CMD}" apt-get install -y dkms rfkill git build-essential
"${SUDO_CMD}" apt-get install -y linux-headers-$(uname -r) dkms rfkill network-manager

# git clone https://github.com/morrownr/8821au-20210708.git
cd /8821au-20210708
"${SUDO_CMD}" ./install-driver.sh


sudo tee /etc/modprobe.d/8821au.conf <<EOF
options 8821au rtw_led_ctrl=1 rtw_power_mgnt=0 rtw_enusb_ss=1
EOF


# sudo vim /etc/NetworkManager/NetworkManager.conf
# managed=true

echo_success "Archer T2U Nano AC600 (RTL8821AU) Wireless USB Adapter installed!"
