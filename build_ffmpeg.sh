#!/usr/bin/env bash
set -euo pipefail

echo "[INFO] Atualizando pacotes e instalando dependências..."
sudo apt update
sudo apt install -y autoconf automake build-essential cmake git-core libtool pkg-config \
  libfreetype6-dev libsdl2-dev libtheora-dev libvorbis-dev libxcb1-dev libxcb-shm0-dev \
  libxcb-xfixes0-dev texinfo wget yasm zlib1g-dev libunistring-dev libssl-dev \
  nasm libx264-dev libx265-dev libnuma-dev libvmaf-dev libfdk-aac-dev

echo "[INFO] Criando diretórios..."
mkdir -p ~/ffmpeg-build ~/bin

echo "[INFO] Clonando FFmpeg..."
cd ~/ffmpeg-build
git clone https://git.ffmpeg.org/ffmpeg.git ffmpeg --depth=1

echo "[INFO] Compilando FFmpeg com suporte a libx264, libvmaf, libfdk-aac..."
cd ffmpeg
./configure \
  --prefix="$HOME/ffmpeg-build" \
  --pkg-config-flags="--static" \
  --extra-cflags="-I$HOME/ffmpeg-build/include" \
  --extra-ldflags="-L$HOME/ffmpeg-build/lib" \
  --extra-libs="-lpthread -lm" \
  --bindir="$HOME/bin" \
  --enable-gpl \
  --enable-libx264 \
  --enable-libx265 \
  --enable-libvmaf \
  --enable-libfdk-aac \
  --enable-nonfree

make -j"$(nproc)"
make install

echo "[INFO] Adicionando $HOME/bin ao PATH (temporariamente)"
export PATH="$HOME/bin:$PATH"

echo "[✔] FFmpeg compilado com sucesso!"
ffmpeg -version | head -n 5
