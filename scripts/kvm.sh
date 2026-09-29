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

# --- Criar a VM (exemplo, Windows 11) ---
# Não corre como parte deste script (nome/tamanho/caminhos são específicos de
# cada VM) — fica aqui só como referência de um comando que funcionou:
#
# sudo virt-install \
#   --name win11 \
#   --memory 16384 \
#   --vcpus 8 \
#   --cpu host-passthrough \
#   --os-variant win11 \
#   --disk path=/var/lib/libvirt/images/win11.qcow2,size=100,bus=virtio \
#   --disk path=<caminho-da-iso-do-windows>,device=cdrom \
#   --disk path="$VIRTIO_WIN_ISO",device=cdrom \
#   --network network=default,model=virtio \
#   --graphics spice \
#   --video qxl \
#   --sound ich9 \
#   --boot firmware=efi \
#   --tpm backend.type=emulator,backend.version=2.0
#
# Nota: --loader/--nvram-template não existem como flags de topo no
# virt-install 5.0 (davam "unrecognized arguments") — usa --boot firmware=efi,
# que escolhe automaticamente o OVMF com Secure Boot certo a partir do
# --os-variant + --tpm.
#
# Durante a instalação, o Windows não vê o disco nem a rede virtio até
# carregares os drivers manualmente (ecrã "Load driver", no CD do virtio-win):
#   Disco: viostor\w11\amd64
#   Rede:  NetKVM\w11\amd64
#
# Clipboard partilhado (SPICE): dentro da VM, instala o "Spice guest tools"
# (https://www.spice-space.org/download.html) — mas sem o driver vioserial
# (pasta vioserial\w11\amd64 no CD do virtio-win) o serviço não tem como
# ligar ao canal e o Ctrl+C/Ctrl+V não funciona. Depois de instalar o
# vioserial, confirma em services.msc que o serviço do Spice Guest Tools
# está "Running" (Startup type: Automatic) — arranca-o manualmente se
# precisares. Para confirmar do lado do host que ligou:
#   virsh -c qemu:///system dumpxml <nome-da-vm> | grep spicevmc -A2
# deve mostrar state='connected' (não 'disconnected').

echo_info "Installing QEMU/KVM..."

if command_exists virt-manager; then
    echo_success "QEMU/KVM already installed!"
else
    sudo apt-get install -y \
        qemu-kvm \
        libvirt-daemon-system \
        libvirt-clients \
        virt-manager \
        bridge-utils \
        virtinst \
        ovmf \
        swtpm \
        virt-viewer

    # Add user to required groups
    sudo usermod -aG libvirt "$USER"
    sudo usermod -aG kvm "$USER"

    echo_success "QEMU/KVM installed! Log out and back in for group changes to take effect."
fi

# Enable and start libvirt daemon
sudo systemctl enable --now libvirtd

# --- Rede virtual "default" (NAT) ---
# libvirtd fica enabled mas a rede "default" nem sempre arranca sozinha na
# primeira vez — sem ela, virt-install falha a criar a interface de rede da VM.
#
# Se isto falhar com "failed to create listening socket for 192.168.122.1:
# Address already in use", o dnsmasq do sistema (scripts/dnsmasq.sh) está a
# fazer bind wildcard (0.0.0.0:53) e a bloquear o dnsmasq próprio desta rede.
# dnsmasq.sh já inclui "bind-interfaces" para evitar isto em instalações de
# raiz; numa máquina onde o dnsmasq já estava instalado antes dessa correção,
# corrige manualmente com:
#   echo "bind-interfaces" | sudo tee -a /etc/dnsmasq.conf
#   sudo systemctl restart dnsmasq
echo_info "Starting default libvirt network..."
if ! sudo virsh net-info default &>/dev/null; then
    echo_error "Rede 'default' não existe no libvirt. Verifica a instalação do libvirt-daemon-system."
else
    sudo virsh net-start default 2>/dev/null
    sudo virsh net-autostart default
    echo_success "Rede 'default' ativa e com autostart."
fi

# --- Drivers VirtIO ---
# Sem estes, o instalador do Windows não vê o disco virtio nem a placa de rede
# virtio (mais rápidos que os dispositivos emulados por omissão).
VIRTIO_WIN_ISO="$USER_HOME/Downloads/virtio-win.iso"
if [ -f "$VIRTIO_WIN_ISO" ]; then
    echo_success "virtio-win.iso already downloaded!"
else
    echo_info "Downloading virtio-win drivers ISO..."
    wget -O "$VIRTIO_WIN_ISO" https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso
fi

# --- Acesso da qemu:///system ao $HOME ---
# A VM corre como o utilizador de sistema 'libvirt-qemu', que não consegue
# atravessar a home do utilizador por causa das permissões por omissão
# (drwx------). Sem isto, o virt-install cria a VM mas o arranque falha logo
# com "Permission denied" ao tentar abrir qualquer ISO/disco dentro de
# ~/Downloads. Dá-se apenas search (x), não read — 'libvirt-qemu' continua
# sem conseguir listar a pasta, só abrir caminhos que já conhece.
if ! getfacl -p "$USER_HOME" 2>/dev/null | grep -q "^user:libvirt-qemu:.*x$"; then
    echo_info "Granting libvirt-qemu search access to $USER_HOME..."
    sudo setfacl -m u:libvirt-qemu:x "$USER_HOME"
fi
