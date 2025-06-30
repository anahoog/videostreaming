#!/usr/bin/env bash

# Ativa o ambiente virtual
source "$(dirname "$0")/../../../../../.venv/bin/activate"

# Parâmetros
VIDEO="RickAstley.mkv"
PORT=4004
SERVER_IP="0.0.0.0"          # Listener bind
CLIENT_IP="192.168.3.99"    # Onde o caller vai se conectar
PROTO="srt"

# Diretório de saída
TIMESTAMP=$(date '+%Y%m%d_%H-%M-%S')
DIR="capturas/${PROTO}_${TIMESTAMP}"
mkdir -p "$DIR"

# Logs e arquivos de métricas
LOG_SEND="$DIR/ffmpeg_send.log"
LOG_RECV="$DIR/ffmpeg_recv.log"
PSNR_LOG="$DIR/psnr.log"
SSIM_LOG="$DIR/ssim.log"
RESULTS_CSV="$DIR/resultados.csv"

echo "[INFO] Iniciando teste SRT em $(date '+%Y-%m-%d %H:%M:%S')"

#
# 1) Sender (listener) com estatísticas SRT a cada 1s
#
ffmpeg -hide_banner -nostats -re -i "$VIDEO" \
    -c:v libx264 -preset veryfast -b:v 2M \
    -c:a aac -ar 44100 -b:a 128k \
    -f mpegts "srt://:$PORT?mode=listener&pkt_size=1316&stats=1000" \
    2> "$LOG_SEND" &
PID_SEND=$!

sleep 2

#
# 2) Receiver (caller) com showinfo + PSNR + SSIM
#
ffmpeg -hide_banner -nostats \
    -i "srt://$CLIENT_IP:$PORT?mode=caller&stats=1000" \
    -i "$VIDEO" \
    -filter_complex "[0:v]showinfo[INFO];[1:v][0:v]psnr=stats_file=$PSNR_LOG;[1:v][0:v]ssim=stats_file=$SSIM_LOG" \
    -map "[INFO]" -f null - \
    2> "$LOG_RECV"

kill $PID_SEND &> /dev/null

#
# 3) Extrai métricas do sender (SRT stats)
#
STATS_LINE=$(grep "\[srt-stats\]" "$LOG_SEND" | tail -1)
TOTAL=$(echo "$STATS_LINE" | grep -oP 'total=\K[0-9]+')
RETRANS=$(echo "$STATS_LINE" | grep -oP 'retrans=\K[0-9]+')
LOSS_PKTS=$(echo "$STATS_LINE" | grep -oP 'loss=\K[0-9]+')
RTT_MS=$(echo "$STATS_LINE" | grep -oP 'rtt=\K[0-9]+')
TAXA_PERDA=$(awk "BEGIN{printf \"%.6f\", $LOSS_PKTS/$TOTAL}")

#
# 4) Extrai timestamps (pts_time) do receiver e calcula:
#    session time, playback start, jitter, interrupções
#
# 4.1) Lista de timestamps
PTS_TIMES=( $(grep "pts_time:" "$LOG_RECV" | awk -F'pts_time:' '{print $2}') )
FIRST=${PTS_TIMES[0]}
LAST=${PTS_TIMES[-1]}

# 4.2) Tempo de sessão e Playback Start Time
SES_S=$(awk "BEGIN{printf \"%.3f\", $LAST - $FIRST}")
PLAY_START=$FIRST

# 4.3) Jitter médio (std dev dos intervalos)
JITTER=$(printf "%s\n" "${PTS_TIMES[@]}" | \
  awk 'BEGIN{prev="";s1=0;s2=0;n=0;}
       { if(prev!=""){d=$1-prev; s1+=d; s2+=d*d; n++;} prev=$1; }
       END{ if(n>0){m=s1/n; printf "%f", sqrt(s2/n - m*m);} else print "0"; }')

# 4.4) Número e duração total de interrupções (gap > 0.5s)
read NUM_INT DUR_BUFF <<<"$(printf "%s\n" "${PTS_TIMES[@]}" | \
  awk 'BEGIN{prev="";c=0;d=0;}
       { if(prev!=""){gap=$1-prev; if(gap>0.5){c++; d+=gap;} } prev=$1; }
       END{ printf "%d %f", c, d; }')"

#
# 5) PSNR e SSIM
#
PSNR=$(grep "psnr_avg:" "$PSNR_LOG" | awk -F'psnr_avg:' '{sum+=$2} END{printf "%.3f", sum/NR}')
SSIM=$(grep "^All:" "$SSIM_LOG"  | awk '{print $2}')

#
# 6) Grava todas as métricas no CSV
#
echo "Retransmissoes,TempoSessao(s),Jitter(s),PlaybackStart(s),NumInterruptions,BufferingTime(s),TaxaPerda,RTT(ms),PSNR(dB),SSIM" \
  > "$RESULTS_CSV"

echo "$RETRANS,$SES_S,$JITTER,$PLAY_START,$NUM_INT,$DUR_BUFF,$TAXA_PERDA,$RTT_MS,$PSNR,$SSIM" \
  >> "$RESULTS_CSV"

echo "[INFO] Resultados gravados em $RESULTS_CSV"
