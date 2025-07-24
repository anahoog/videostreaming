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
VIDEO="v2.mp4"

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

# ========================
# OBTÉM A DURAÇÃO DO VÍDEO
# ========================

# Usa ffprobe para obter a duração do vídeo em segundos (sem casas decimais)
DURACAO_VIDEO=$(/home/anahoog/bin/ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$VIDEO")
DURACAO_VIDEO=${DURACAO_VIDEO%.*}

# Se a duração não for válida, interrompe o script
if [[ -z "$DURACAO_VIDEO" || "$DURACAO_VIDEO" -le 0 ]]; then
  echo "[ERRO] Não foi possível obter a duração do vídeo ($VIDEO)"
  exit 1
fi

# ========================
# CONFIGURAÇÃO POR PROTOCOLO
# ========================

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
# CRIA DIRETÓRIO DE CAPTURA
# ========================

TS=$(date +"%Y%m%d_%H-%M-%S")    # Gera timestamp para o diretório de resultados
DIR="capturas/${PROTO}_${TS}"    # Cria diretório para armazenar logs e capturas

mkdir -p "$DIR"

# ========================
# DEFINE CAMINHOS DE SAÍDA
# ========================

PCAP="$DIR/${PROTO}_capture_${TS}.pcap"          # Arquivo de captura .pcap
CSV_PCAP="$DIR/${PROTO}_capture_${TS}.csv"       # Arquivo convertido para CSV
RECEBIDO="$DIR/recebido_${PROTO}.ts"           # Arquivo recebido
PSNR_STATS="$DIR/psnr_${PROTO}_${TS}.stats"      # Estatísticas de PSNR
SSIM_STATS="$DIR/ssim_${PROTO}_${TS}.stats"      # Estatísticas de SSIM
RESULT_CSV="$DIR/resultados_${PROTO}_${TS}.csv"  # Resultados consolidados





# ========================
# CAPTURA DE PACOTES
# ========================

echo "[INFO] Capturando pacotes ($FILTER) em $PCAP"
sudo tcpdump -i any $FILTER -w "$PCAP" &
TCPDUMP_PID=$!  # Guarda o PID para matar depois

# Aguarda a interface de rede estar pronta
sleep 5

# ========================
# INICIA TRANSMISSÃO E RECEPÇÃO
# ========================

echo "[INFO] Iniciando transmissor e receptor para $PROTO"

case "$PROTO" in
  srt)
    # Transmissor (listener) com estatísticas SRT
    ffmpeg -loglevel info -stats_period 0.01 \
           -re -i "$VIDEO" \
           -c:v libx264 -b:v 2M \
           -c:a aac -ar 44100 -b:a 128k \
           -f mpegts "srt://$SERVIP:$PORT?mode=listener&pkt_size=1316" \
           >"$DIR/ffmpeg_tx_${TS}_stats.log" 2>&1 &
    TX_PID=$!

    sleep 1

    # Receptor (caller) com estatísticas SRT
    ffmpeg -loglevel info -stats_period 0.01 \
           -i "srt://$CLIIP:$PORT?mode=caller" \
           -c copy "$RECEBIDO" \
           >"$DIR/ffmpeg_rx_${TS}_stats.log" 2>&1 &
    RX_PID=$!

    ;;

  
  rtp)
     # Transmissor (sender envia via RTP MPEG-TS)
    ffmpeg -re -i "$VIDEO" \
           -c:v libx264  -b:v 2M \
           -c:a aac -ar 44100 -b:a 128k \
           -f rtp_mpegts "rtp://${SERV_RTP}:$PORT?pkt_size=1300" \
           2>&1 | tee "$DIR/ffmpeg_tx_${TS}.log" &
    TX_PID=$!

    sleep 1

    # Receptor
    ffmpeg -i "rtp://${CLI_RTP}:$PORT" -c copy "$RECEBIDO" -loglevel debug \
           2>&1 | ts '[%Y-%m-%d %H:%M:%S]' >"$DIR/ffmpeg_rx_${TS}.log" &
    RX_PID=$!
    ;;

  rtmp)
    # Reinicia o servidor Nginx (com módulo RTMP)
    sudo nginx -s stop &> /dev/null
    sleep 5
    sudo nginx

    # Transmissor: envia via FLV
    ffmpeg -re -i "$VIDEO" \
           -c:v libx264 -b:v 2M \
           -c:a aac -ar 44100 -b:a 128k \
           -f flv "rtmp://$SERVIP:$PORT/live/stream" \
           >"$DIR/ffmpeg_tx_${TS}.log" 2>&1 &
    TX_PID=$!

    sleep 1

    # Receptor
    ffmpeg -i "rtmp://$CLIIP:$PORT/live/stream" -c copy "$RECEBIDO" \
           >"$DIR/ffmpeg_rx_${TS}.log" 2>&1 &
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
sleep 10
echo "[INFO] Extraindo métricas de PSNR e SSIM..."
"$SCRIPT_DIR/calculate_metrics.sh" \
  "$VIDEO" \
  "$RECEBIDO" \
  "$PSNR_STATS" \
  "$SSIM_STATS" \
  "$PROTO" \
  "$RESULT_CSV"

case "$PROTO" in
  srt)
    tshark -r "$PCAP" \
      -T fields \
      -e frame.number -e frame.time_relative -e ip.src -e ip.dst \
      -e udp.srcport -e udp.dstport -e frame.len \
      -E header=y -E separator=, \
      > "$CSV_PCAP"
    ;;
  rtp)
    tshark -r "$PCAP" \
      -T fields \
      -e frame.number -e frame.time_relative -e ip.src -e ip.dst \
      -e udp.srcport -e udp.dstport -e rtp.seq -e rtp.timestamp -e frame.len \
      -E header=y -E separator=, \
      > "$CSV_PCAP"
    ;;
  rtmp)
    tshark -r "$PCAP" \
      -T fields \
      -e frame.number -e frame.time_relative -e ip.src -e ip.dst \
      -e tcp.srcport -e tcp.dstport -e frame.len \
      -E header=y -E separator=, \
      > "$CSV_PCAP"
    ;;
esac

