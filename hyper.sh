# !/bin/bash

# Please note that Hyprland uses the C++26 standard (gcc>=15 or clang>=19)

# Add the experimental repository as a temporary source, will allow to use -t experimental.
#echo "deb http://deb.debian.org/debian experimental main" | sudo tee /etc/apt/sources.list.d/experimental.list

#sudo apt update
#sudo apt -t experimental install clang-19

#sudo update-alternatives --install /usr/bin/clang clang /usr/bin/clang-19 100
#sudo update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-19 100



# GCC 15 and C++26 installation

sudo apt update
sudo apt install -y build-essential libgmp-dev libmpfr-dev libmpc-dev libisl-dev flex bison texinfo



cd /tmp
wget https://ftp.gnu.org/gnu/gcc/gcc-15.1.0/gcc-15.1.0.tar.xz
tar -xf gcc-15.1.0.tar.xz
cd gcc-15.1.0
./contrib/download_prerequisites
mkdir build && cd build
# If error when building GCC
# export CC=/usr/bin/gcc
# export CXX=/usr/bin/g++
../configure --prefix=/usr/local/gcc-15 --enable-languages=c,c++ --disable-multilib --disable-bootstrap
make -j$(nproc)
sudo make install

sudo update-alternatives --install /usr/bin/gcc gcc /usr/local/gcc-15/bin/gcc 60 --slave /usr/bin/g++ g++ /usr/local/gcc-15/bin/g++


# ---- GCC 15 toolchain ----
export GCC15_PREFIX=/usr/local/gcc-15

export CC=$GCC15_PREFIX/bin/gcc
export CXX=$GCC15_PREFIX/bin/g++
export AR=$GCC15_PREFIX/bin/gcc-ar
export NM=$GCC15_PREFIX/bin/gcc-nm
export RANLIB=$GCC15_PREFIX/bin/gcc-ranlib

# ---- Paths ----
export PATH=$GCC15_PREFIX/bin:$PATH
export LD_LIBRARY_PATH=$GCC15_PREFIX/lib64:$LD_LIBRARY_PATH
export LIBRARY_PATH=$GCC15_PREFIX/lib64:$LIBRARY_PATH
export CPLUS_INCLUDE_PATH=$GCC15_PREFIX/include/c++/15.1.0:$CPLUS_INCLUDE_PATH
export C_INCLUDE_PATH=$GCC15_PREFIX/include:$C_INCLUDE_PATH

# ---- CMake sanity ----
export CMAKE_C_COMPILER=$CC
export CMAKE_CXX_COMPILER=$CXX


# Hyprland dependencies
sudo apt install --reinstall  -y \
    git meson ninja-build pkg-config cmake jq \
    wayland-protocols libwayland-dev libxkbcommon-dev \
    libpixman-1-dev libseat-dev seatd libinput-dev \
    libdrm-dev libgbm-dev libegl1-mesa-dev libgles2-mesa-dev \
    libxcb-composite0-dev libxcb-ewmh-dev libxcb-icccm4-dev \
    libxcb-render0-dev libxcb-res0-dev libxcb-xfixes0-dev \
    libxcb-xinput-dev libxcb-xkb-dev libxcb-util-dev \
    libxcb-errors-dev libcairo2-dev libpango1.0-dev libxml2-dev \
    libjpeg-dev libpng-dev libturbojpeg0-dev libfmt-dev \
    libspdlog-dev libglm-dev libpugixml-dev hwdata libzip-dev libmagic-dev \
    bison libabsl-dev libffi-dev libinotifytools0-dev libdisplay-info-dev librsvg2-dev libxcursor-dev

# # Clone wlroots repository
# cd ~/.hyprland
# git clone https://github.com/hyprwm/wlroots.git
# cd wlroots

# # Build wlroots
# meson setup build
# ninja -C build
# sudo ninja -C build install
# sudo ldconfig



# AQUAMARINE dependencies

# hyprwayland-scanner dependency
cd ~/.dotfiles
git clone https://github.com/hyprwm/hyprwayland-scanner.git
cd hyprwayland-scanner
mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local ..
make -j$(nproc)
sudo make install
sudo ldconfig

# hyprutils
cd ~/dotfiles
git clone https://github.com/hyprwm/hyprutils.git
cd hyprutils
mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local ..
make -j$(nproc)
sudo make install
sudo ldconfig

# AQUAMARINE
cd ~/.dotfiles
git clone https://github.com/hyprwm/aquamarine.git
cd aquamarine/
mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX=/usr/local \
      -Dhyprwayland-scanner_DIR=/usr/local/lib/cmake/hyprwayland-scanner ..
make -j$(nproc)
sudo make install
sudo ldconfig



# HYPRLANG
cd ~/.dotfiles
git clone https://github.com/hyprwm/hyprlang
cd hyprlang
mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local ..
make -j$(nproc)
sudo make install
sudo ldconfig



# HYPRCURSOR

# TOMLplusplus dependency
cd ~/.dotfiles
git clone https://github.com/marzer/tomlplusplus.git
cd tomlplusplus
mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local ..
make -j$(nproc)
sudo make install
sudo ldconfig

sudo mkdir -p /usr/local/lib/pkgconfig

sudo tee /usr/local/lib/pkgconfig/tomlplusplus.pc > /dev/null << 'EOF'
prefix=/usr/local
exec_prefix=${prefix}
includedir=${prefix}/include
libdir=${prefix}/lib

Name: tomlplusplus
Description: TOML++ library (header-only)
Version: 3.4.0
Cflags: -I${includedir}/toml++
Libs:
EOF

export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH
pkg-config --modversion tomlplusplus

# HYPRCURSOR
cd ~/.dotfiles
git clone https://github.com/hyprwm/hyprcursor
cd hyprcursor
mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local ..
make -j$(nproc)
sudo make install
sudo ldconfig


# HYPRGRAPHICS
cd ~/.dotfiles
git clone https://github.com/hyprwm/hyprgraphics
cd hyprgraphics
mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local ..
make -j$(nproc)
sudo make install
sudo ldconfig


# LIBXKBCOMMON
cd ~/.dotfiles
git clone https://github.com/xkbcommon/libxkbcommon.git
cd libxkbcommon
meson setup build --prefix=/usr/local -Denable-x11=false
meson compile -C build
sudo meson install -C build
sudo ldconfig


# WAYLAND-PROTOCOLS
cd ~/.dotfiles
git clone https://gitlab.freedesktop.org/wayland/wayland-protocols.git
cd wayland-protocols
meson setup build --prefix=/usr/local
meson compile -C build
sudo meson install -C build
sudo ldconfig


# RE2
cd ~/.dotfiles
git clone https://github.com/google/re2.git
cd re2
mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local ..
make -j$(nproc)
sudo make install
sudo ldconfig


# MUPARSER
cd ~/.dotfiles
git clone https://github.com/beltoforion/muparser.git
cd muparser
mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local ..
make -j$(nproc)
sudo make install
sudo ldconfig


# HYPRWIRE
cd ~/.dotfiles
git clone https://github.com/hyprwm/hyprwire.git
cd hyprwire
mkdir -p build && cd build
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local ..
make -j$(nproc)
sudo make install
sudo ldconfig



# Clone Hyprland repository
cd ~/.dotfiles
git clone --recursive https://github.com/hyprwm/Hyprland
cd Hyprland

# Atualizar submodules (importante para aquamarine e outros subprojects)
git submodule update --init --recursive

# Criar diretório de build
mkdir -p build
cd build

# Configurar CMake apontando para aquamarine e hyprwayland-scanner instalados
cmake -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX=/usr/local \
      -Dhyprwayland-scanner_DIR=/usr/local/lib/cmake/hyprwayland-scanner ..

# Compilar usando todos os cores da CPU
make -j$(nproc)

# Instalar Hyprland
sudo make install

# Atualizar cache de bibliotecas
sudo ldconfig










######## HYPRLAUNCHER

sudo apt install libiniparser-dev libqalculate-dev

cd ~/.dotfiles
git clone https://github.com/hyprwm/hyprtoolkit.git
cd hyprtoolkit
mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release ..
make -j$(nproc)
sudo make install

cd ~/.dotfiles
git clone https://github.com/hyprwm/hyprlauncher.git
cd hyprlauncher
mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release ..
make -j$(nproc)
sudo make install
