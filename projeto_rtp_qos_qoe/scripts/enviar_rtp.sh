#!/bin/bash
VIDEO="RickAstley.mkv"
DEST_IP="192.168.3.20"
PORTA=4004

echo "[INFO] Enviando via RTP para $DEST_IP:$PORTA"
ffmpeg -re -i "$VIDEO" -c copy -f rtp_mpegts "rtp://$DEST_IP:$PORTA?pkt_size=1300"
