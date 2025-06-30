#!/bin/bash
RECEBIDO="logs/recebido_rtp.ts"
RECV_LOG="logs/ffmpeg_receptor.log"

mkdir -p logs

ffmpeg -i rtp://0.0.0.0:4004 -c copy "$RECEBIDO" \
  -loglevel debug 2>&1 | ts '[%Y-%m-%d %H:%M:%S]' > "$RECV_LOG"
