#!/bin/bash

# Caminho do vídeo a ser transmitido
VIDEO="RickAstley.mkv"
PORT=4004
RECEBIDO="recebido_rtp.ts"

# IPs das máquinas (ou namespaces ou containers)
TRANSMISSOR_IP="192.168.2.20"
RECEPTOR_IP="192.168.3.20"

# Inicia recepção em background
echo "[INFO] Iniciando recepção RTP..."
ffmpeg -y -timeout 5000000 -i "udp://192.168.3.20:$PORT?fifo_size=1000000&overrun_nonfatal=1" -c copy "$RECEBIDO" \
    2>&1 | tee ffmpeg_receptor.log &
RECV_PID=$!

sleep 3  # Aguarda o receptor iniciar

# Inicia transmissão
echo "[INFO] Iniciando transmissão RTP para $RECEPTOR_IP:$PORT..."
ffmpeg -re -i "$VIDEO" -an -c:v libx264 -f rtp_mpegts "rtp://192.168.2.99:$PORT" \
    2>&1 | tee ffmpeg_transmissor.log

# Aguarda o receptor finalizar
wait $RECV_PID

echo "[OK] Transmissão encerrada. Arquivo salvo como: $RECEBIDO"
