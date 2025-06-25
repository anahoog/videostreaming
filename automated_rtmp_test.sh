#!/bin/bash

# Ativa ambiente virtual Python se necessário
if [[ -f ../../../../../../.venv/bin/activate ]]; then
    echo "Activating python virtual environment in '../../../../../../.venv'"
    source ../../../../../../.venv/bin/activate
fi

PROTO=rtmp
PORT=1935
VIDEO="RickAstley.mkv"
SERVER_IP="192.168.2.20"
RTMP_URL="rtmp://$SERVER_IP:$PORT/live/stream"
DIR_BASE="capturas"
TIMESTAMP=$(date "+%Y%m%d_%H%M%S")
DIR="$DIR_BASE/${PROTO}_${TIMESTAMP}"
mkdir -p "$DIR"

FFMPEG_LOG="$DIR/ffmpeg_${PROTO}.log"
VLC_LOG="$DIR/vlc_${PROTO}.log"
PCAP_FILE="$DIR/${PROTO}_capture.pcap"
CSV_FILE="$DIR/${PROTO}_capture.csv"
RESULTADOS="$DIR/resultados.csv"

echo "[INFO] Iniciando teste RTMP em $(date '+%Y-%m-%d %H:%M:%S')"

# Verifica se nginx está instalado
if ! command -v nginx &> /dev/null; then
    echo "[ERRO] nginx não está instalado. Instale com: sudo apt install nginx"
    exit 1
fi

echo "[INFO] Reiniciando nginx..."
sudo nginx -s stop &> /dev/null
sleep 1
sudo nginx || {
    echo "[ERRO] Falha ao iniciar o nginx."
    exit 1
}

sleep 2

echo "[INFO] Iniciando captura de pacotes na porta $PORT..."
sudo tcpdump -i any port $PORT -w "$PCAP_FILE" &
TCPDUMP_PID=$!

echo "[INFO] Iniciando FFmpeg (servidor RTMP)..."
ffmpeg -re -i "$VIDEO" \
    -c:v libx264 -preset veryfast -b:v 2M \
    -c:a aac -ar 44100 -b:a 128k \
    -f flv "$RTMP_URL" 2>&1 | ts '[%Y-%m-%d %H:%M:%S]' > "$FFMPEG_LOG" &

FFMPEG_PID=$!
sleep 5

echo "[INFO] Iniciando VLC (cliente RTMP)..."
cvlc -vvv "$RTMP_URL" 2>&1 | ts '[%Y-%m-%d %H:%M:%S]' > "$VLC_LOG" &

VLC_PID=$!
DURACAO_TESTE=25
sleep $DURACAO_TESTE

echo "[INFO] Encerrando processos..."
kill $FFMPEG_PID &> /dev/null
kill $VLC_PID &> /dev/null
sudo kill $TCPDUMP_PID

# Aguarda a finalização dos arquivos
sleep 2

echo "[INFO] Convertendo captura para CSV com $(realpath ./pcap.sh)..."
./pcap.sh "$PCAP_FILE" "$CSV_FILE"

echo "[INFO] Executando análise com coletar.py..."
python3 coletar.py -d "$DIR" -o "$RESULTADOS"

echo "[SUCESSO] Teste RTMP finalizado às $(date '+%Y-%m-%d %H:%M:%S')"
echo "Arquivos salvos em:"
echo "  - $FFMPEG_LOG"
echo "  - $VLC_LOG"
echo "  - $PCAP_FILE"
echo "  - $CSV_FILE"
echo "  - $RESULTADOS"
