#!/bin/bash

# Ativa ambiente virtual se existir
if [[ -f ../../../../../../.venv/bin/activate ]]; then
    echo "Activating python virtual environment in '../../../../../../.venv'"
    source ../../../../../../.venv/bin/activate
fi

PROTO=rtp
VIDEO="soundh264.mp4"
DEST_IP="192.168.2.99"
SOURCE_IP="192.168.3.20"
PORT=4004
RTP_URL="rtp://$SOURCE_IP@$PORT"

# Diretório de saída com timestamp
DIR_BASE="capturas"
TIMESTAMP=$(date "+%Y%m%d_%H%M%S")
DIR="$DIR_BASE/${PROTO}_${TIMESTAMP}"
mkdir -p "$DIR"

FFMPEG_LOG="$DIR/ffmpeg_${PROTO}.log"
VLC_LOG="$DIR/vlc_${PROTO}.log"
PCAP_FILE="$DIR/${PROTO}_capture.pcap"
CSV_FILE="$DIR/${PROTO}_capture.csv"
RESULTADOS="$DIR/resultados.csv"

echo "[INFO] Iniciando teste RTP em $(date '+%Y-%m-%d %H:%M:%S')"

echo "[INFO] Iniciando captura de pacotes na porta $PORT..."
sudo tcpdump -i any port $PORT -w "$PCAP_FILE" &
TCPDUMP_PID=$!

echo "[INFO] Iniciando FFmpeg para envio RTP..."
ffmpeg -re -i "$VIDEO" \
    -an -c:v libx264 -preset veryfast -b:v 2M \
    -f rtp "rtp://$DEST_IP:$PORT" \
    2>&1 | ts '[%Y-%m-%d %H:%M:%S]' > "$FFMPEG_LOG" &

FFMPEG_PID=$!
sleep 2

echo "[INFO] Iniciando VLC como receptor RTP..."
cvlc -vvv "rtp://$SOURCE_IP:$PORT" \
    2>&1 | ts '[%Y-%m-%d %H:%M:%S]' > "$VLC_LOG" &

VLC_PID=$!
sleep 400

echo "[INFO] Encerrando processos..."
kill $FFMPEG_PID &> /dev/null
kill $VLC_PID &> /dev/null
sudo kill $TCPDUMP_PID

sleep 2

echo "[INFO] Convertendo captura para CSV com $(realpath ./pcap.sh)..."
./pcap.sh "$PCAP_FILE" "$CSV_FILE"

echo "[INFO] Executando análise com coletar.py..."
python3 coletar.py -d "$DIR" -o "$RESULTADOS"

echo "[SUCESSO] Teste RTP finalizado às $(date '+%Y-%m-%d %H:%M:%S')"
echo "Arquivos salvos em:"
echo "  - $FFMPEG_LOG"
echo "  - $VLC_LOG"
echo "  - $PCAP_FILE"
echo "  - $CSV_FILE"
echo "  - $RESULTADOS"
