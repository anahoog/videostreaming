#!/bin/bash

PROTO="rtp"
VIDEO="RickAstley.mkv"
PORT=4004
TIMESTAMP=$(date "+%Y%m%d_%H-%M-%S")
DIR="capturas/${PROTO}_${TIMESTAMP}"
mkdir -p "$DIR"

RECEBIDO="$DIR/recebido_rtp.ts"
PCAP_FILE="$DIR/${PROTO}_capture.pcap"
CSV_FILE="$DIR/${PROTO}_capture.csv"
RECV_LOG="$DIR/ffmpeg_recv.log"
SEND_LOG="$DIR/ffmpeg_transmissor.log"
RESULTS_CSV="$DIR/resultados.csv"
PSNR_LOG="$DIR/psnr.log"
SSIM_LOG="$DIR/ssim.log"

TRANSMISSOR_IP="192.168.2.20"
RECEPTOR_IP="192.168.3.20"

echo "[INFO] Iniciando teste $PROTO em $(date '+%Y-%m-%d %H:%M:%S')"

# Inicia captura de pacotes
echo "[INFO] Iniciando captura de pacotes na porta $PORT..."
sudo tcpdump -i any port $PORT -w "$PCAP_FILE" > /dev/null 2>&1 &
TCPDUMP_PID=$!
sleep 10  # Tempo para tcpdump iniciar corretamente

# Inicia receptor
echo "[INFO] Iniciando recepção RTP..."
ffmpeg -y -timeout 5000000 -i "udp://$RECEPTOR_IP:$PORT?fifo_size=1000000&overrun_nonfatal=1" \
    -c copy "$RECEBIDO" 2>&1 | tee "$RECV_LOG" &
RECV_PID=$!

sleep 3  # Dá tempo para o receptor abrir

# Transmissor
echo "[INFO] Iniciando transmissão RTP para $RECEPTOR_IP:$PORT..."
ffmpeg -re -i "$VIDEO" -an -c:v libx264 -f rtp_mpegts "rtp://192.168.2.99:$PORT" \
    2>&1 | tee "$SEND_LOG"

wait $RECV_PID
kill $TCPDUMP_PID
sleep 2

# Conversão do PCAP para CSV
echo "[INFO] Convertendo $PCAP_FILE para CSV..."
/home/anahoog/Downloads/omnetpp-6.1/samples/inet4.5/showcases/emulation/videostreaming/pcap.sh "$PCAP_FILE" "$CSV_FILE"

# PSNR / SSIM
if [[ -f "$RECEBIDO" && -s "$RECEBIDO" ]]; then
    echo "[INFO] Calculando PSNR..."
    ffmpeg -i "$VIDEO" -i "$RECEBIDO" \
      -lavfi "[0:v]scale=640:360,format=yuv420p[ref];[1:v]scale=640:360,format=yuv420p[test];[ref][test]psnr=stats_file=${PSNR_LOG}" \
      -f null - 2>&1 | tee "$DIR/psnr_exec.log"

    echo "[INFO] Calculando SSIM..."
    ffmpeg -i "$VIDEO" -i "$RECEBIDO" \
      -lavfi "[0:v]scale=640:360,format=yuv420p[ref];[1:v]scale=640:360,format=yuv420p[test];[ref][test]ssim=stats_file=${SSIM_LOG}" \
      -f null - 2>&1 | tee "$DIR/ssim_exec.log"
else
    echo "[ERRO] Arquivo $RECEBIDO não gerado ou está vazio. Pulando PSNR/SSIM."
fi

# Executa análise
echo "[INFO] Executando análise com coletar_psnr_ssim.py..."
python3 coletar_psnr_ssim.py -d "$DIR" -o "$RESULTS_CSV"

# Métricas adicionais
RETRANS=$(grep -i "retransmit" "$RECV_LOG" | wc -l)
BUFFERING=$(grep -Ei "buffering|delay.*queue|drop" "$RECV_LOG" | wc -l)

START_TS=$(grep "udp://" "$RECV_LOG" | head -n1 | cut -d'[' -f2 | cut -d']' -f1)
FIRST_FRAME_TS=$(grep "frame=" "$RECV_LOG" | head -n1 | cut -d'[' -f2 | cut -d']' -f1)

if [[ -n "$START_TS" && -n "$FIRST_FRAME_TS" ]]; then
    PST=$(($(date -d "$FIRST_FRAME_TS" +%s) - $(date -d "$START_TS" +%s)))
else
    PST="N/A"
fi

PERDA_ESTIMADA="N/A"
PSNR_MEDIO=$(awk -F',' 'NR>1 {print $10}' "$RESULTS_CSV")
SSIM_MEDIO=$(awk -F',' 'NR>1 {print $11}' "$RESULTS_CSV")

ORIGINAL_LINE=$(tail -n1 "$RESULTS_CSV")
IFS=',' read -ra FIELDS <<< "$ORIGINAL_LINE"
TEMPO_SESSAO=${FIELDS[2]}
JITTER_MEDIO=${FIELDS[3]}
DURATION_INTERRUPTS=${FIELDS[6]}
NUM_INTERRUPTS=${FIELDS[7]}
CSV_FILE_NAME=$(basename "$CSV_FILE")

HEADER="Protocolo,Retransmissoes,Tempo Sessao (s),Jitter Medio (s),Buffering,Playback Start Time (s),Duration of Interruptions (s),Number of Interruptions,Taxa de Perda Estimada,PSNR Medio (dB),SSIM Medio,CSV,Log"
echo "$HEADER" > "$RESULTS_CSV"
echo "$PROTO,$RETRANS,$TEMPO_SESSAO,$JITTER_MEDIO,$BUFFERING,$PST,$DURATION_INTERRUPTS,$NUM_INTERRUPTS,$PERDA_ESTIMADA,$PSNR_MEDIO,$SSIM_MEDIO,$CSV_FILE_NAME, —" >> "$RESULTS_CSV"

echo
echo "=== MÉTRICAS EXTRAÍDAS ==="
echo "Retransmissões: $RETRANS"
echo "Buffering (estimado): $BUFFERING"
echo "Playback Start Time (s): $PST"
echo "Taxa de Perda Estimada: $PERDA_ESTIMADA"
echo "PSNR Médio: $PSNR_MEDIO dB"
echo "SSIM Médio: $SSIM_MEDIO"
echo
echo "[SUCESSO] Teste RTP finalizado às $(date '+%Y-%m-%d %H:%M:%S')"
echo "Arquivos salvos em: $DIR"
