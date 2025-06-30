#!/bin/bash
PCAP="capturas/rtp_capture.pcap"
PORTA=4004

mkdir -p capturas

echo "[INFO] Capturando pacotes RTP na porta $PORTA"
sudo tcpdump -i any udp port $PORTA -w "$PCAP"
