#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/check_env.sh"

# No Windows (dentro da VM):
#
# Instalar o OpenSSH Server — Settings → Apps → Optional Features → Add "OpenSSH Server"
# Ativar e arrancar o serviço:
#
# Start-Service sshd
# Set-Service -Name sshd -StartupType Automatic
#
# O firewall do Windows configura-se automaticamente, mas confirma que a regra existe.
#
# No Linux (host):
# Ver o IP da VM:
#
# virsh net-dhcp-leases default
#
# Copiar a chave SSH para a VM (opcional mas recomendado):
#
# ssh-copy-id piedade@<ip-da-vm>
#
# No VS Code:
# Instalar a extensão Remote - SSH
# Ligar com Ctrl+Shift+P → "Remote-SSH: Connect to Host" → piedade@<ip-da-vm>
#
# Nota sobre rede: O QEMU/KVM usa NAT por defeito (IPs 192.168.122.x). Funciona bem para desenvolvimento. Se quiseres
# que a VM apareça na rede local como um PC separado, precisas de bridge networking — mas para VS Code Remote não é
# necessário.

echo_info "Installing QEMU/KVM..."

if command_exists virt-manager; then
    echo_success "QEMU/KVM already installed!"
    return
fi

sudo apt-get install -y \
    qemu-kvm \
    libvirt-daemon-system \
    libvirt-clients \
    virt-manager \
    bridge-utils \
    virtinst \
    ovmf

# Add user to required groups
sudo usermod -aG libvirt "$USER"
sudo usermod -aG kvm "$USER"

# Enable and start libvirt daemon
sudo systemctl enable --now libvirtd

echo_success "QEMU/KVM installed! Log out and back in for group changes to take effect."
