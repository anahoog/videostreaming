#!/bin/bash

PROTO=$1

if [[ -z "$PROTO" ]]; then
    echo "[ERRO] Uso: $0 <PROTOCOLO: srt | rtmp | rtp>"
    exit 1
fi

# Ativa o ambiente virtual, se existir
if [[ -f ../../../../../../.venv/bin/activate ]]; then
    echo "Activating python virtual environment in '../../../../../../.venv'"
    source ../../../../../../.venv/bin/activate
fi

VIDEO="RickAstley.mkv"
TIMESTAMP=$(date "+%Y%m%d_%H%M%S")
DIR_BASE="capturas"
DIR="$DIR_BASE/${PROTO}_${TIMESTAMP}"
mkdir -p "$DIR"

FFMPEG_LOG="$DIR/ffmpeg_${PROTO}.log"
VLC_LOG="$DIR/vlc_${PROTO}.log"
PCAP_FILE="$DIR/${PROTO}_capture.pcap"
CSV_FILE="$DIR/${PROTO}_capture.csv"
RESULTADOS="$DIR/resultados.csv"

echo "[INFO] Iniciando teste $PROTO em $(date '+%Y-%m-%d %H:%M:%S')"

case "$PROTO" in
    srt)
        PORT=4004
        URL="srt://192.168.2.20:$PORT?mode=listener&pkt_size=1316"
        VLC_URL="srt://192.168.3.99:$PORT?mode=caller"
        
        echo "[INFO] Capturando pacotes na porta $PORT..."
        sudo tcpdump -i any port $PORT -w "$PCAP_FILE" &
        TCPDUMP_PID=$!

        echo "[INFO] Iniciando FFmpeg (listener SRT)..."
        ffmpeg -re -i "$VIDEO" \
            -c:v libx264 -preset veryfast -b:v 2M \
            -c:a aac -b:a 128k \
            -f mpegts "$URL" 2>&1 | ts '[%Y-%m-%d %H:%M:%S]' > "$FFMPEG_LOG" &
        FFMPEG_PID=$!
        sleep 2

        echo "[INFO] Iniciando VLC (caller SRT)..."
        cvlc "$VLC_URL" -vvv 2>&1 | ts '[%Y-%m-%d %H:%M:%S]' > "$VLC_LOG" &
        VLC_PID=$!
        ;;

    rtmp)
        PORT=1935
        RTMP_URL="rtmp://192.168.2.20:$PORT/live/stream"

        if ! command -v nginx &> /dev/null; then
            echo "[ERRO] nginx com suporte a RTMP não está instalado."
            exit 1
        fi

        echo "[INFO] Reiniciando nginx..."
        sudo nginx -s stop &> /dev/null
        sleep 1
        sudo nginx || { echo "[ERRO] Falha ao iniciar nginx."; exit 1; }

        echo "[INFO] Capturando pacotes na porta $PORT..."
        sudo tcpdump -i any port $PORT -w "$PCAP_FILE" &
        TCPDUMP_PID=$!

        echo "[INFO] Iniciando FFmpeg (RTMP)..."
        ffmpeg -re -i "$VIDEO" \
            -c:v libx264 -preset veryfast -b:v 2M \
            -c:a aac -ar 44100 -b:a 128k \
            -f flv "$RTMP_URL" 2>&1 | ts '[%Y-%m-%d %H:%M:%S]' > "$FFMPEG_LOG" &
        FFMPEG_PID=$!
        sleep 5

        echo "[INFO] Iniciando VLC (RTMP)..."
        cvlc -vvv "$RTMP_URL" 2>&1 | ts '[%Y-%m-%d %H:%M:%S]' > "$VLC_LOG" &
        VLC_PID=$!
        ;;

    rtp)
        PORT=4004
        DEST_IP="192.168.2.99"
        SOURCE_IP="192.168.3.20"
        VLC_URL="rtp://$SOURCE_IP:$PORT"

        echo "[INFO] Capturando pacotes RTP na porta $PORT..."
        sudo tcpdump -i any port $PORT -w "$PCAP_FILE" &
        TCPDUMP_PID=$!

        echo "[INFO] Iniciando FFmpeg (RTP)..."
        ffmpeg -re -i "$VIDEO" \
            -an -c:v libx264 -preset veryfast -b:v 2M \
            -f rtp "rtp://$DEST_IP:$PORT" \
            2>&1 | ts '[%Y-%m-%d %H:%M:%S]' > "$FFMPEG_LOG" &
        FFMPEG_PID=$!
        sleep 2

        echo "[INFO] Iniciando VLC (RTP)..."
        cvlc "$VLC_URL" -vvv 2>&1 | ts '[%Y-%m-%d %H:%M:%S]' > "$VLC_LOG" &
        VLC_PID=$!
        ;;
    *)
        echo "[ERRO] Protocolo inválido: $PROTO"
        exit 1
        ;;
esac

# Espera a execução
sleep 25

# Finaliza os processos
echo "[INFO] Encerrando processos..."
kill $FFMPEG_PID &> /dev/null
kill $VLC_PID &> /dev/null
sudo kill $TCPDUMP_PID

sleep 2

# Conversão do pcap
echo "[INFO] Convertendo captura para CSV..."
./pcap.sh "$PCAP_FILE" "$CSV_FILE"

# Coletando métricas
echo "[INFO] Executando análise com coletar.py..."
python3 coletar.py -d "$DIR" -o "$RESULTADOS"

echo "[SUCESSO] Teste $PROTO finalizado às $(date '+%Y-%m-%d %H:%M:%S')"
echo "Arquivos salvos em:"
echo "  - $FFMPEG_LOG"
echo "  - $VLC_LOG"
echo "  - $PCAP_FILE"
echo "  - $CSV_FILE"
echo "  - $RESULTADOS"
