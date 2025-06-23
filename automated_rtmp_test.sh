#!/bin/bash

# Verifica se o utilitário 'ts' está instalado
if ! command -v ts &> /dev/null; then
    echo "[ERRO] O utilitário 'ts' não está instalado. Instale com: sudo apt install moreutils"
    exit 1
fi

# Caminho do vídeo de entrada
VIDEO="RickAstley.mkv"

# IP e porta do servidor RTMP (Nginx)
SERVER_IP="192.168.2.20"
PORT=1935

# Logs e captura
FFMPEG_LOG="ffmpeg_rtmp.log"
VLC_LOG="vlc_rtmp.log"
PCAP_FILE="rtmp_capture.pcap"

# URL do RTMP (servidor NGINX com RTMP ativo)
RTMP_URL="rtmp://$SERVER_IP:$PORT/live/stream"

echo "[INFO] Iniciando teste RTMP em $(date '+%Y-%m-%d %H:%M:%S')"

# Verifica se nginx está instalado
if ! command -v nginx &> /dev/null; then
    echo "[ERRO] nginx não está instalado. Instale o nginx com suporte a RTMP (nginx-rtmp-module)."
    exit 1
fi

# Reinicia o nginx
echo "[INFO] Reiniciando nginx..."
sudo nginx -s stop &> /dev/null
sleep 1
sudo nginx || {
    echo "[ERRO] Falha ao iniciar o nginx."
    exit 1
}

sleep 2

# Captura pacotes RTMP (porta 1935)
echo "[INFO] Iniciando captura de pacotes na porta $PORT..."
sudo tcpdump -i any port $PORT -w "$PCAP_FILE" &
TCPDUMP_PID=$!

# Inicia o servidor de streaming com FFmpeg
echo "[INFO] Iniciando FFmpeg para RTMP..."
ffmpeg -re -stream_loop -1 -i "$VIDEO" \
    -c:v libx264 -preset veryfast -b:v 2M \
    -c:a aac -ar 44100 -b:a 128k \
    -f flv "$RTMP_URL" 2>&1 | ts '[%Y-%m-%d %H:%M:%S]' > "$FFMPEG_LOG" &

FFMPEG_PID=$!
sleep 5

# Inicia o VLC como cliente
echo "[INFO] Iniciando VLC como cliente RTMP..."
cvlc -vvv "$RTMP_URL" 2>&1 | ts '[%Y-%m-%d %H:%M:%S]' > "$VLC_LOG" &

VLC_PID=$!
sleep 25

# Finaliza os processos
echo "[INFO] Encerrando processos..."
kill $FFMPEG_PID &> /dev/null
kill $VLC_PID &> /dev/null
sudo kill $TCPDUMP_PID

echo "[SUCESSO] Teste RTMP finalizado às $(date '+%Y-%m-%d %H:%M:%S')"
echo "Logs salvos em:"
echo "  - $FFMPEG_LOG"
echo "  - $VLC_LOG"
echo "  - $PCAP_FILE"
