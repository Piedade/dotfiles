#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo_info "Installing Archer T2U Nano AC600 (RTL8821AU) Wireless USB Adapter..."

# ========================== 8821au-20210708 is old ========================>>>>
# # sudo apt-get install -y dkms rfkill git build-essential
# sudo apt-get install -y linux-headers-$(uname -r) dkms rfkill network-manager

# # git clone https://github.com/morrownr/8821au-20210708.git
# cd /8821au-20210708
# sudo ./install-driver.sh

# sudo tee /etc/modprobe.d/8821au.conf <<EOF
# options 8821au rtw_led_ctrl=1 rtw_power_mgnt=0 rtw_enusb_ss=1
# EOF

# # sudo vim /etc/NetworkManager/NetworkManager.conf
# # managed=true
# <==========================================================================

sudo apt-get install -y linux-headers-generic build-essential dkms network-manager

# https://github.com/lwfinger/rtw88
cd $SCRIPT_DIR/rtw88
sudo dkms install $PWD

sudo make install_fw

sudo cp rtw88.conf /etc/modprobe.d/

# Secure Boot is enabled on your machine.
sudo mokutil --import /var/lib/dkms/mok.pub

echo_success "Archer T2U Nano AC600 (RTL8821AU) Wireless USB Adapter installed!"
