#!/bin/bash

# Ativa o ambiente virtual
source "$(dirname "$0")/../../../../../.venv/bin/activate"

VIDEO="RickAstley.mkv"
SERVER_IP="192.168.2.20"
PORT=4004
PROTO="srt"

TIMESTAMP=$(date '+%Y%m%d_%H-%M-%S')
DIR="capturas/${PROTO}_${TIMESTAMP}"
mkdir -p "$DIR"

FFMPEG_LOG="$DIR/ffmpeg_srt.log"
RECV_LOG="$DIR/ffmpeg_recv.log"
PCAP_FILE="$DIR/srt_capture.pcap"
CSV_FILE="$DIR/srt_capture.csv"
RESULTS_CSV="$DIR/resultados.csv"
RECEBIDO="$DIR/recebido.ts"
PSNR_LOG="$DIR/psnr.log"
SSIM_LOG="$DIR/ssim.log"

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

# Inicia FFmpeg como cliente (caller) e salva vídeo recebido
echo "[INFO] Iniciando FFmpeg (caller SRT) para gravação..."
ffmpeg -i "srt://192.168.3.99:$PORT?mode=caller" -c copy "$RECEBIDO" \
    2>&1 | ts '[%Y-%m-%d %H:%M:%S]' > "$RECV_LOG" &
RECV_PID=$!

sleep 100

echo "[INFO] Encerrando processos..."
kill $FFMPEG_PID &> /dev/null
kill $RECV_PID &> /dev/null
sudo kill $TCPDUMP_PID

echo "[INFO] Convertendo captura para CSV com $(pwd)/pcap.sh..."
./pcap.sh "$PCAP_FILE" "$CSV_FILE"

echo "[INFO] Calculando PSNR..."
ffmpeg -i "$VIDEO" -i "$RECEBIDO" \
  -lavfi "[0:v]scale=640:360,format=yuv420p[ref];[1:v]scale=640:360,format=yuv420p[test];[ref][test]psnr=stats_file=${PSNR_LOG}" \
  -f null - 2>&1 | tee "$DIR/psnr_exec.log"

echo "[INFO] Calculando SSIM..."
ffmpeg -i "$VIDEO" -i "$RECEBIDO" \
  -lavfi "[0:v]scale=640:360,format=yuv420p[ref];[1:v]scale=640:360,format=yuv420p[test];[ref][test]ssim=stats_file=${SSIM_LOG}" \
  -f null - 2>&1 | tee "$DIR/ssim_exec.log"

echo "[INFO] Executando análise com coletar.py..."
python3 coletar_psnr_ssim.py -d "$DIR" -o "$RESULTS_CSV"

# === MÉTRICAS EXTRAS ===
RETRANS=$(grep -i "retransmit" "$RECV_LOG" | wc -l)
BUFFERING=$(grep -Ei "buffering|delay.*queue|drop" "$RECV_LOG" | wc -l)

START_TS=$(grep "Opening 'srt://" "$RECV_LOG" | head -n1 | cut -d'[' -f2 | cut -d']' -f1)
FIRST_FRAME_TS=$(grep "frame=" "$RECV_LOG" | head -n1 | cut -d'[' -f2 | cut -d']' -f1)
if [[ -n "$START_TS" && -n "$FIRST_FRAME_TS" ]]; then
    PST=$(($(date -d "$FIRST_FRAME_TS" +%s) - $(date -d "$START_TS" +%s)))
else
    PST=0
fi

PERDA_ESTIMADA="N/A"
PSNR_MEDIO=$(awk -F',' 'NR>1 {print $10}' "$RESULTS_CSV")
SSIM_MEDIO=$(awk -F',' 'NR>1 {print $11}' "$RESULTS_CSV")

# Extrai as demais métricas do CSV
ORIGINAL_LINE=$(tail -n1 "$RESULTS_CSV")
IFS=',' read -ra FIELDS <<< "$ORIGINAL_LINE"
TEMPO_SESSAO=${FIELDS[2]}
JITTER_MEDIO=${FIELDS[3]}
DURATION_INTERRUPTS=${FIELDS[6]}
NUM_INTERRUPTS=${FIELDS[7]}
CSV_FILE_NAME=$(basename "$CSV_FILE")

# Recria o resultados.csv com cabeçalho e linha final completa
HEADER="Protocolo,Retransmissoes,Tempo Sessao (s),Jitter Medio (s),Buffering,Playback Start Time (s),Duration of Interruptions (s),Number of Interruptions,Taxa de Perda Estimada,PSNR Medio (dB),SSIM Medio,CSV,Log"
echo "$HEADER" > "$RESULTS_CSV"
echo "$PROTO,$RETRANS,$TEMPO_SESSAO,$JITTER_MEDIO,$BUFFERING,$PST,$DURATION_INTERRUPTS,$NUM_INTERRUPTS,$PERDA_ESTIMADA,$PSNR_MEDIO,$SSIM_MEDIO,$CSV_FILE_NAME, —" >> "$RESULTS_CSV"

# Exibe resumo
echo
echo "=== MÉTRICAS EXTRAÍDAS ==="
echo "Retransmissões: $RETRANS"
echo "Buffering (estimado): $BUFFERING"
echo "Playback Start Time (s): $PST"
echo "Taxa de Perda Estimada: $PERDA_ESTIMADA"
echo "PSNR Médio: $PSNR_MEDIO dB"
echo "SSIM Médio: $SSIM_MEDIO"
echo
echo "[SUCESSO] Teste SRT finalizado às $(date '+%Y-%m-%d %H:%M:%S')"
echo "Arquivos salvos em:"
echo "  - $FFMPEG_LOG (transmissão)"
echo "  - $RECV_LOG (recepção)"
echo "  - $RECEBIDO (vídeo recebido)"
echo "  - $PSNR_LOG"
echo "  - $SSIM_LOG"
echo "  - $PCAP_FILE"
echo "  - $CSV_FILE"
echo "  - $RESULTS_CSV"
echo "  - $DIR/psnr_exec.log"
echo "  - $DIR/ssim_exec.log"
