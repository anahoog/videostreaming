#!/usr/bin/env bash

# ========================
# ATIVAÇÃO DO AMBIENTE
# ========================

# Ativa o ambiente virtual Python (para uso posterior de scripts Python)
source "$(dirname "$0")/../../../../../.venv/bin/activate"

# Diretório onde está o script atual
SCRIPT_DIR="$(dirname "$0")"

# ========================
# PARÂMETROS E VARIÁVEIS
# ========================

# Caminho do vídeo de entrada
VIDEO="/home/anahoog/Downloads/omnetpp-6.1/samples/inet4.5/showcases/emulation/videostreaming/v2.mp4"

# Portas usadas por protocolo
PORTA_SRT=4004
PORTA_RTP=4004
PORTA_RTMP=1935

# IPs dos servidores (IP que o host1 enviará o stream de vídeo)
SERV_SRT="192.168.2.20"
SERV_RTP="192.168.2.99"
SERV_RTMP="192.168.2.20"

# IPs dos clientes (Endereço que o cliente usará para obter o stream de vídeo)
CLI_SRT="192.168.3.99"
CLI_RTP="192.168.3.20"
CLI_RTMP="192.168.3.99"

# ========================
# VERIFICAÇÃO DO PROTOCOLO
# ========================

# Primeiro argumento passado ao script (srt, rtp ou rtmp)
PROTO="$1"

# Se não for nenhum dos protocolos aceitos, encerra com erro
if [[ "$PROTO" != "srt" && "$PROTO" != "rtp" && "$PROTO" != "rtmp" ]]; then
  echo "Usage: $0 <srt|rtp|rtmp>"
  exit 1
fi

TS=$(date +"%Y%m%d_%H-%M-%S")    # Gera timestamp para o diretório de resultados
DIR="capturas/${PROTO}_${TS}"    # Cria diretório para armazenar logs e capturas

mkdir -p "$DIR"

PCAP="$DIR/${PROTO}_capture.pcap"          # Arquivo de captura .pcap
CSV_PCAP="$DIR/${PROTO}_capture.csv"       # Arquivo convertido para CSV
GRAF_DIR="$DIR/graficos"                   # (não usado diretamente aqui)
RECEBIDO="$DIR/recebido_${PROTO}.ts"           # Arquivo recebido
PSNR_STATS="$DIR/psnr_${PROTO}.stats"      # Estatísticas de PSNR
SSIM_STATS="$DIR/ssim_${PROTO}.stats"      # Estatísticas de SSIM
RESULT_CSV="$DIR/resultados_${PROTO}.csv"  # Resultados consolidados

echo "[INFO] Capturando pacotes ($FILTER) em $PCAP"
sudo tcpdump -i any $FILTER -w "$PCAP" &
TCPDUMP_PID=$!  # Guarda o PID para matar depois

sleep 5


case "$PROTO" in
  srt)
    PORT=$PORTA_SRT
    SERVIP=$SERV_SRT
    CLIIP=$CLI_SRT
    FILTER="udp port $PORT"
    ;;
  rtp)
    PORT=$PORTA_RTP
    SERVIP=$SERV_RTP
    CLIIP=$CLI_RTP
    FILTER="udp port $PORT"
    ;;
  rtmp)
    PORT=$PORTA_RTMP
    SERVIP=$SERV_RTMP
    CLIIP=$CLI_RTMP
    FILTER="tcp port $PORT"
    ;;
esac



# ========================
# INICIA TRANSMISSÃO E RECEPÇÃO
# ========================

echo "[INFO] Iniciando transmissor e receptor para $PROTO"

case "$PROTO" in
  srt)
    # Transmissor (listener)
    ffmpeg -re -i "$VIDEO" \
           -c:v libx264 -b:v 4M \
           -c:a aac -ar 44100 -b:a 128k \
           -f mpegts "srt://$SERVIP:$PORT?mode=listener&pkt_size=1316" \
           >"$DIR/ffmpeg_tx.log" 2>&1 &
    TX_PID=$!

    sleep 1

    # Receptor (caller)
    ffmpeg -i "srt://$CLIIP:$PORT?mode=caller" -c copy "$RECEBIDO" \
           >"$DIR/ffmpeg_rx.log" 2>&1 &
    RX_PID=$!
    ;;
  
  rtp)
     # Transmissor (sender envia via RTP MPEG-TS)
    ffmpeg -re -i "$VIDEO" \
           -c:v libx264 -b:v 4M \
           -c:a aac -ar 44100 -b:a 128k \
           -f rtp_mpegts "rtp://${SERV_RTP}:$PORT?pkt_size=1300" \
           2>&1 | tee "$DIR/ffmpeg_tx.log" &
    TX_PID=$!

    sleep 1

    # Receptor
    ffmpeg -i "rtp://${CLI_RTP}:$PORT" -c copy "$RECEBIDO" -loglevel debug \
           2>&1 | ts '[%Y-%m-%d %H:%M:%S]' >"$DIR/ffmpeg_rx.log" &
    RX_PID=$!
    ;;

  rtmp)
    # Reinicia o servidor Nginx (com módulo RTMP)
    sudo nginx -s stop &> /dev/null
    sleep 1
    sudo nginx

    # Transmissor: envia via FLV
    ffmpeg -re -i "$VIDEO" \
           -c:v libx264 -b:v 4M \
           -c:a aac -ar 44100 -b:a 128k \
           -f flv "rtmp://$SERVIP:$PORT/live/stream" \
           >"$DIR/ffmpeg_tx.log" 2>&1 &
    TX_PID=$!

    sleep 1

    # Receptor
    ffmpeg -i "rtmp://$CLIIP:$PORT/live/stream" -c copy "$RECEBIDO" \
           >"$DIR/ffmpeg_rx.log" 2>&1 &
    RX_PID=$!
    ;;
esac


sleep 130

# Aguarda o término do receptor
#wait $RX_PID

# Encerra o transmissor e o tcpdump
kill $TX_PID &>/dev/null
sudo kill $TCPDUMP_PID &>/dev/null

# ========================
# ANÁLISE DE MÉTRICAS VISUAIS
# ========================

echo "[INFO] Calculando PSNR (psnr_avg)…"
ffmpeg -i "$VIDEO" -i "$RECEBIDO" \
       -lavfi "psnr=stats_file=${PSNR_STATS}" \
       -f null - 2>/dev/null

PSNR=$(grep -oP 'psnr_avg:\K[0-9]+\.[0-9]+' "$PSNR_STATS" | tail -1)

echo "[INFO] Calculando SSIM (All)…"
ffmpeg -i "$VIDEO" -i "$RECEBIDO" \
       -lavfi "ssim=stats_file=${SSIM_STATS}" \
       -f null - 2>/dev/null

SSIM=$(grep -oP 'All:\K[0-9]+\.[0-9]+' "$SSIM_STATS" | tail -1)

echo "[INFO] Calculando VMAF…"
VMAF_JSON="vmaf_${PROTO}.json"

ffmpeg -i "$VIDEO" -i "$RECEBIDO" \
       -lavfi "[0:v]scale=1920x1080:flags=bicubic[ref];[1:v]scale=1920x1080:flags=bicubic[test];[ref][test]libvmaf=log_path=${VMAF_JSON}:log_fmt=json" \
       -f null - 2>/dev/null

VMAF=$(grep -oP '"aggregate":{"VMAF_score":\K[0-9]+\.[0-9]+' "$VMAF_JSON" | head -1)