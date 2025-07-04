#!/bin/bash
set -euo pipefail

# Diretórios
BUILD_DIR=~/ffmpeg_build
INSTALL_DIR=/usr/local

# Etapas
echo "[1/5] Instalando dependências..."
sudo apt update
sudo apt install -y autoconf automake build-essential cmake git libtool \
  pkg-config texinfo zlib1g-dev nasm yasm libx264-dev libx265-dev \
  libnuma-dev libvpx-dev libfdk-aac-dev libmp3lame-dev libopus-dev \
  libass-dev libfontconfig1-dev ninja-build meson

echo "[2/5] Clonando e compilando libvmaf..."
cd ~
git clone https://github.com/Netflix/vmaf.git || true
cd vmaf
meson setup libvmaf/build --buildtype=release || true
ninja -C libvmaf/build
sudo ninja -C libvmaf/build install
sudo ldconfig

echo "[3/5] Clonando FFmpeg..."
cd ~
git clone https://git.ffmpeg.org/ffmpeg.git ffmpeg || true
cd ffmpeg

echo "[4/5] Configurando FFmpeg com libvmaf..."
./configure \
  --prefix="$INSTALL_DIR" \
  --pkg-config-flags="--static" \
  --extra-cflags="-I$INSTALL_DIR/include" \
  --extra-ldflags="-L$INSTALL_DIR/lib" \
  --extra-libs="-lpthread -lm" \
  --ld="g++" \
  --bindir="$INSTALL_DIR/bin" \
  --enable-gpl \
  --enable-libx264 \
  --enable-libx265 \
  --enable-libvpx \
 # --enable-libfdk-aac \
  --enable-libmp3lame \
  --enable-libopus \
  --enable-libass \
  --enable-libvmaf

echo "[5/5] Compilando e instalando FFmpeg..."
make -j"$(nproc)"
sudo make install

echo "✅ FFmpeg com libvmaf instalado com sucesso!"
ffmpeg -filters | grep vmaf
