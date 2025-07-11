#!/usr/bin/env bash

# Diretórios
FFMPEG_SRC=~/ffmpeg
FFMPEG_BUILD=~/ffmpeg-build
FFMPEG_BIN=~/bin

# 1. Instalar dependências (se ainda não tiver)
sudo apt update
sudo apt install -y cmake build-essential git pkg-config libssl-dev

# 2. Clonar e compilar a biblioteca SRT
cd ~/Downloads
git clone https://github.com/Haivision/srt.git
cd srt
mkdir build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX="$FFMPEG_BUILD"
make -j$(nproc)
make install

# 3. Recompilar o FFmpeg com suporte a SRT
cd "$FFMPEG_SRC"
make distclean

./configure \
  --prefix="$FFMPEG_BIN" \
  --pkg-config-flags="--static" \
  --extra-cflags="-I$FFMPEG_BUILD/include" \
  --extra-ldflags="-L$FFMPEG_BUILD/lib" \
  --extra-libs="-lpthread -lm" \
  --bindir="$FFMPEG_BIN" \
  --enable-gpl \
  --enable-libsrt \
  --enable-libx264 \
  --enable-libfdk-aac \
  --enable-libvmaf \
  --enable-libass \
  --enable-libfreetype \
  --enable-libmp3lame \
  --enable-libopus \
  --enable-libvorbis \
  --enable-libvpx \
  --enable-libx265 \
  --enable-nonfree

make -j$(nproc)
make install

echo "✅ FFmpeg recompilado com suporte a SRT"
