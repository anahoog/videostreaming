#!/bin/bash

# Verifica se o utilitário 'ts' está instalado
if ! command -v ts &> /dev/null; then
    echo "[ERRO] O utilitário 'ts' não está instalado. Instale com: sudo apt install moreutils"
    exit 1
fi

# Caminho do vídeo
VIDEO="soundh264.mp4"

# IPs e porta
SERVER_IP="192.168.2.20"
CLIENT_IP="192.168.3.99"
PORT=4004

# Arquivos de saída
FFMPEG_LOG="ffmpeg_srt.log"
VLC_LOG="vlc_srt.log"
PCAP_FILE="srt_capture.pcap"

echo "[INFO] Iniciando teste SRT em $(date '+%Y-%m-%d %H:%M:%S')"

# Iniciar captura de pacotes SRT
echo "[INFO] Iniciando captura de pacotes na porta $PORT..."
sudo tcpdump -i any port $PORT -w "$PCAP_FILE" &
TCPDUMP_PID=$!

# Iniciar FFmpeg como servidor SRT (listener) com timestamps no log
echo "[INFO] Iniciando FFmpeg (listener SRT)..."
ffmpeg -re -i "$VIDEO" \
  -c:v libx264 -preset veryfast -b:v 2M \
  -c:a aac -b:a 128k \
  -f mpegts "srt://$SERVER_IP:$PORT?mode=listener&pkt_size=1316" \
  2>&1 | ts '[%Y-%m-%d %H:%M:%S]' > "$FFMPEG_LOG" &

FFMPEG_PID=$!
sleep 3

# Iniciar o VLC como cliente SRT (caller) com timestamps no log
echo "[INFO] Iniciando VLC (caller SRT)..."
cvlc -vvv "srt://$CLIENT_IP:$PORT?mode=caller" \
  2>&1 | ts '[%Y-%m-%d %H:%M:%S]' > "$VLC_LOG" &

VLC_PID=$!

# Tempo de execução do teste (ajuste conforme necessário)
DURACAO_TESTE=25
sleep $DURACAO_TESTE

# Finaliza os processos
echo "[INFO] Encerrando processos..."
kill $FFMPEG_PID &> /dev/null
kill $VLC_PID &> /dev/null
sudo kill $TCPDUMP_PID

echo "[SUCESSO] Teste SRT finalizado às $(date '+%Y-%m-%d %H:%M:%S')"
echo "Logs salvos em:"
echo "  - $FFMPEG_LOG"
echo "  - $VLC_LOG"
echo "  - $PCAP_FILE"
