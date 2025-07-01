#!/usr/bin/env bash

# Ativa o ambiente virtual
source "$(dirname "$0")/../../../../../.venv/bin/activate"

# Diretório deste script (para chamar analisador)
SCRIPT_DIR="$(dirname "$0")"

# Parâmetros principais
VIDEO="RickAstley.mkv"
PORTA_SRT=4004
PORTA_RTP=4004
PORTA_RTMP=1935

SERV_SRT="192.168.2.20"
SERV_RTP="192.168.2.99"
SERV_RTMP="192.168.2.20"

CLI_SRT="192.168.3.99"
CLI_RTP="192.168.3.20"
CLI_RTMP="192.168.3.99"

# Latência SRT recomendada para cenários de alta perda/delay
SRT_LATENCY=1200  # ajuste conforme necessário

# Uso: ./ffmpeg_coletas.sh <PROTO: srt|rtp|rtmp>
PROTO="$1"
if [[ "$PROTO" != "srt" && "$PROTO" != "rtp" && "$PROTO" != "rtmp" ]]; then
  echo "Usage: $0 <srt|rtp|rtmp>"
  exit 1
fi

# Obtém duração do vídeo em segundos (usa ffprobe)
DURACAO_VIDEO=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$VIDEO")
DURACAO_VIDEO=${DURACAO_VIDEO%.*}  # remove decimais

if [[ -z "$DURACAO_VIDEO" || "$DURACAO_VIDEO" -le 0 ]]; then
  echo "[ERRO] Não foi possível obter a duração do vídeo ($VIDEO)"
  exit 1
fi

# Configura porta, IP e filtro de captura
case "$PROTO" in
  srt)
    PORT=$PORTA_SRT; SERVIP=$SERV_SRT; CLIIP=$CLI_SRT; FILTER="udp port $PORT";;
  rtp)
    PORT=$PORTA_RTP; SERVIP=$SERV_RTP; CLIIP=$CLI_RTP; FILTER="udp port $PORT";;
  rtmp)
    PORT=$PORTA_RTMP; SERVIP=$SERV_RTMP; CLIIP=$CLI_RTMP; FILTER="tcp port $PORT";;
  *) ;;
esac

# Cria pasta de resultados
TS=$(date +"%Y%m%d_%H-%M-%S")
DIR="capturas/${PROTO}_${TS}"
mkdir -p "$DIR"

# Arquivos de log e saída
PCAP="$DIR/${PROTO}_capture.pcap"
CSV_PCAP="$DIR/${PROTO}_capture.csv"
GRAF_DIR="$DIR/graficos"
RECV="$DIR/recebido_${PROTO}.ts"
PSNR_STATS="$DIR/psnr_${PROTO}.stats"
SSIM_STATS="$DIR/ssim_${PROTO}.stats"
RESULT_CSV="$DIR/resultados_${PROTO}.csv"

# Inicia captura de pacotes
echo "[INFO] Capturando pacotes ($FILTER) em $PCAP"
sudo tcpdump -i any $FILTER -w "$PCAP" &
TCPDUMP_PID=$!

# Aguarda interface UP
sleep 5

echo "[INFO] Iniciando transmissor e receptor para $PROTO"
case "$PROTO" in
  srt)
    ffmpeg -re -i "$VIDEO" \
           -c:v libx264 -preset veryfast -b:v 4M \
           -c:a aac -ar 44100 -b:a 128k \
           -f mpegts "srt://$SERVIP:$PORT?mode=listener&pkt_size=1316&latency=$SRT_LATENCY" \
           >"$DIR/ffmpeg_tx.log" 2>&1 &
    TX_PID=$!
    sleep 1
    ffmpeg -i "srt://$CLIIP:$PORT?mode=caller&latency=$SRT_LATENCY" -c copy "$RECV" \
           >"$DIR/ffmpeg_rx.log" 2>&1 &
    RX_PID=$!;;
  rtp)
    ffmpeg -re -i "$VIDEO" \
           -c:v libx264 -preset veryfast -b:v 4M \
           -c:a aac -ar 44100 -b:a 128k \
           -f rtp_mpegts "rtp://${CLIIP}:$PORT?pkt_size=1300" \
           2>&1 | tee "$DIR/ffmpeg_tx.log" &
    TX_PID=$!
    sleep 1
    ffmpeg -i "rtp://${SERVIP}:$PORT" -c copy "$RECV" -loglevel debug \
           2>&1 | ts '[%Y-%m-%d %H:%M:%S]' >"$DIR/ffmpeg_rx.log" &
    RX_PID=$!;;
  rtmp)
    sudo nginx -s stop &> /dev/null && sleep 1 && sudo nginx
    ffmpeg -re -i "$VIDEO" \
           -c:v libx264 -preset veryfast -b:v 4M \
           -c:a aac -ar 44100 -b:a 128k \
           -f flv "rtmp://$SERVIP:$PORT/live/stream" \
           >"$DIR/ffmpeg_tx.log" 2>&1 &
    TX_PID=$!
    sleep 1
    ffmpeg -i "rtmp://$CLIIP:$PORT/live/stream" -c copy "$RECV" \
           >"$DIR/ffmpeg_rx.log" 2>&1 &
    RX_PID=$!;;
esac

# Aguarda o ffmpeg receptor finalizar (encerra quando receber tudo ou der erro)
wait $RX_PID

# Finaliza o transmissor (se ainda estiver rodando) e o tcpdump
kill $TX_PID &>/dev/null
sudo kill $TCPDUMP_PID &>/dev/null

# ---- Chamada ao calculate_metrics.sh ----
echo "[INFO] Extraindo métricas de PSNR e SSIM..."
"$SCRIPT_DIR/calculate_metrics.sh" \
  "$VIDEO" \
  "$RECV" \
  "$PSNR_STATS" \
  "$SSIM_STATS" \
  "$PROTO" \
  "$RESULT_CSV"
