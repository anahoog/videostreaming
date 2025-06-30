#!/usr/bin/env bash

# Ativa o ambiente virtual
source "$(dirname "$0")/../../../../../.venv/bin/activate"

# Parâmetros
VIDEO="RickAstley.mkv"
PORTA_SRT=4004
PORTA_RTP=5005
PORTA_RTMP=1935

SERVIDOR_IP_SRT="192.168.2.20"
SERVIDOR_IP_RTP="192.168.2.99"
SERVIDOR_IP_RTMP="192.168.2.20"

CLIENTE_IP_SRT="192.168.3.99"
CLIENTE_IP_RTP="192.168.3.20"
CLIENTE_IP_RTMP="192.168.3.99"

# Uso: ./ffmpeg_coletas.sh <PROTO: srt|rtp|rtmp>
PROTO="$1"
if [[ -z "$PROTO" || ( "$PROTO" != "srt" && "$PROTO" != "rtp" && "$PROTO" != "rtmp" ) ]]; then
    echo "Usage: $0 <srt|rtp|rtmp>"
    exit 1
fi

# Seleção de porta e IPs
case "$PROTO" in
    srt)
        PORT=$PORTA_SRT
        SERVIDOR_IP=$SERVIDOR_IP_SRT
        CLIENTE_IP=$CLIENTE_IP_SRT
        ;;
    rtp)
        PORT=$PORTA_RTP
        SERVIDOR_IP=$SERVIDOR_IP_RTP
        CLIENTE_IP=$CLIENTE_IP_RTP
        ;;
    rtmp)
        PORT=$PORTA_RTMP
        SERVIDOR_IP=$SERVIDOR_IP_RTMP
        CLIENTE_IP=$CLIENTE_IP_RTMP
        ;;
esac

# Prepara diretório e arquivos de saída
TS=$(date '+%Y%m%d_%H-%M-%S')
DIR="capturas/${PROTO}_${TS}"
mkdir -p "$DIR"

FFMPEG_LOG="$DIR/ffmpeg_${PROTO}.log"
RECV_LOG="$DIR/ffmpeg_recv_${PROTO}.log"
PCAP_FILE="$DIR/${PROTO}_capture.pcap"
RECEBIDO="$DIR/recebido_${PROTO}.ts"
RESULTS_CSV="$DIR/resultados_${PROTO}.csv"
PSNR_STATS="$DIR/psnr_${PROTO}.stats"
SSIM_STATS="$DIR/ssim_${PROTO}.stats"

echo "[INFO] Iniciando teste $PROTO em $(date '+%Y-%m-%d %H:%M:%S') (porta $PORT)"

# Captura de pacotes
sudo tcpdump -i any udp port "$PORT" -w "$PCAP_FILE" &
TCPDUMP_PID=$!

# Transmissão e recepção
case "$PROTO" in
    srt)
        echo "[INFO] Transmissor SRT (listener)…"
        ffmpeg -re -i "$VIDEO" \
            -c:v libx264 -preset veryfast -b:v 2M \
            -c:a aac -ar 44100 -b:a 128k \
            -f mpegts "srt://$SERVIDOR_IP:$PORT?mode=listener&pkt_size=1316" \
            >"$FFMPEG_LOG" 2>&1 &
        TX_PID=$!
        sleep 5
        echo "[INFO] Receptor SRT (caller)…"
        ffmpeg -i "srt://$CLIENTE_IP:$PORT?mode=caller" \
            -c copy "$RECEBIDO" \
            >"$RECV_LOG" 2>&1 &
        RX_PID=$!
        ;;
         rtp)
        echo "[INFO] Iniciando receptor RTP (salvando em TS)…"
        ffmpeg -y \
            -i "rtp://192.168.2.99:4004" \
            -c copy "$RECEBIDO" \
            2>&1 | tee "$RECV_LOG" &
        RX_PID=$!

        sleep 3  # dá tempo para o receptor abrir

        echo "[INFO] Iniciando transmissor RTP…"
        ffmpeg -re -i "$VIDEO" \
            -c copy -f rtp_mpegts \
            "rtp://192.168.3.20:4004?pkt_size=1300" \
            2>&1 | tee "$FFMPEG_LOG" &
        TX_PID=$!

        # espera o transmissor terminar de enviar
        wait "$TX_PID"
        # dá um tempinho para o receptor fechar o TS
        sleep 1
        kill "$RX_PID"
        ;;


    rtmp)
        echo "[INFO] Reiniciando nginx…"
        sudo nginx -s stop &> /dev/null && sleep 1
        sudo nginx
        echo "[INFO] Transmissor RTMP…"
        ffmpeg -re -i "$VIDEO" \
            -c:v libx264 -preset veryfast -b:v 2M \
            -c:a aac -ar 44100 -b:a 128k \
            -f flv "rtmp://$SERVIDOR_IP:$PORT/live/stream" \
            >"$FFMPEG_LOG" 2>&1 &
        TX_PID=$!
        sleep 5
        echo "[INFO] Receptor RTMP…"
        ffmpeg -i "rtmp://$CLIENTE_IP:$PORT/live/stream" \
            -c copy "$RECEBIDO" \
            >"$RECV_LOG" 2>&1 &
        RX_PID=$!
        ;;
esac

# Duração do teste (segundos)
sleep 100

echo "[INFO] Encerrando processos…"
kill "$TX_PID" &>/dev/null
kill "$RX_PID" &>/dev/null
sudo kill "$TCPDUMP_PID"

# Cálculo de PSNR e SSIM
echo "[INFO] Calculando PSNR…"
ffmpeg -i "$VIDEO" -i "$RECEBIDO" \
    -lavfi "psnr=stats_file=${PSNR_STATS}" -f null - \
    > /dev/null 2>&1

echo "[INFO] Calculando SSIM…"
ffmpeg -i "$VIDEO" -i "$RECEBIDO" \
    -lavfi "ssim=stats_file=${SSIM_STATS}" -f null - \
    > /dev/null 2>&1

# Extrai médias finais
FINAL_PSNR=$(grep -oP 'psnr_avg:\K[0-9]+\.[0-9]+' "$PSNR_STATS" | tail -1)
FINAL_SSIM=$(grep -oP 'All:\K[0-9]+\.[0-9]+'     "$SSIM_STATS" | tail -1)

# Grava resultados em CSV
{
  echo "protocol,psnr,ssim"
  echo "$PROTO,$FINAL_PSNR,$FINAL_SSIM"
} > "$RESULTS_CSV"

echo "[INFO] Resultados finais:"
echo "  PSNR médio: $FINAL_PSNR"
echo "  SSIM médio: $FINAL_SSIM"
echo "[INFO] CSV de resultados: $RESULTS_CSV"
