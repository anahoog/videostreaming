#!/bin/bash

# Ativa o ambiente virtual
source "$(dirname "$0")/../../../../../.venv/bin/activate"

VIDEO="RickAstley.mkv"
SERVER_IP="192.168.2.20"
PORT=4004
PROTO="srt"

TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
DIR="capturas/${PROTO}_${TIMESTAMP}"
mkdir -p "$DIR"

FFMPEG_LOG="$DIR/ffmpeg_srt.log"
VLC_LOG="$DIR/vlc_srt.log"
PCAP_FILE="$DIR/srt_capture.pcap"
CSV_FILE="$DIR/srt_capture.csv"
RESULTS_CSV="$DIR/resultados.csv"

echo "[INFO] Iniciando teste SRT em $(date '+%Y-%m-%d %H:%M:%S')"

# Captura pacotes SRT (porta 4004)
echo "[INFO] Iniciando captura de pacotes na porta $PORT..."
sudo tcpdump -i any port $PORT -w "$PCAP_FILE" &
TCPDUMP_PID=$!

# Inicia FFmpeg (listener)
echo "[INFO] Iniciando FFmpeg (listener SRT)..."
ffmpeg -re -i "$VIDEO" \
    -c:v libx264 -preset veryfast -b:v 2M \
    -c:a aac -ar 44100 -b:a 128k \
    -f mpegts "srt://$SERVER_IP:$PORT?mode=listener&pkt_size=1316" \
    2>&1 | ts '[%Y-%m-%d %H:%M:%S]' > "$FFMPEG_LOG" &
FFMPEG_PID=$!

sleep 5

# Inicia VLC como cliente (caller)
echo "[INFO] Iniciando VLC (caller SRT)..."
cvlc -vvv "srt://$SERVER_IP:$PORT?mode=caller" 2>&1 | ts '[%Y-%m-%d %H:%M:%S]' > "$VLC_LOG" &
VLC_PID=$!

sleep 25

# Finaliza os processos
echo "[INFO] Encerrando processos..."
kill $FFMPEG_PID &> /dev/null
kill $VLC_PID &> /dev/null
sudo kill $TCPDUMP_PID

# Converte pcap para CSV
echo "[INFO] Convertendo captura para CSV com $(pwd)/pcap.sh..."
./pcap.sh "$PCAP_FILE" "$CSV_FILE"

# Executa coleta de métricas
echo "[INFO] Executando análise com coletar.py..."
python3 coletar.py -d "$DIR" -o "$RESULTS_CSV"

echo "[SUCESSO] Teste SRT finalizado às $(date '+%Y-%m-%d %H:%M:%S')"
echo "Arquivos salvos em:"
echo "  - $FFMPEG_LOG"
echo "  - $VLC_LOG"
echo "  - $PCAP_FILE"
echo "  - $CSV_FILE"
echo "  - $RESULTS_CSV"
