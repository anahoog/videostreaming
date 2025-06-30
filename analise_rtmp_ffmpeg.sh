#!/bin/bash

# Ativa o ambiente virtual
source "$(dirname "$0")/../../../../../.venv/bin/activate"

VIDEO="videoplayback(2).mp4"
SERVER_IP="192.168.2.20"
PORT=1935
PROTO="rtmp"

# Corrige o timestamp sem ":" (para evitar problemas com FFmpeg)
TIMESTAMP=$(date '+%Y%m%d_%H-%M-%S')
DIR="capturas/${PROTO}_${TIMESTAMP}"
mkdir -p "$DIR"

FFMPEG_LOG="$DIR/ffmpeg_rtmp.log"
RECV_LOG="$DIR/ffmpeg_recv.log"
PCAP_FILE="$DIR/rtmp_capture.pcap"
CSV_FILE="$DIR/rtmp_capture.csv"
RESULTS_CSV="$DIR/resultados.csv"
RECEBIDO="$DIR/recebido.flv"
PSNR_LOG="$DIR/psnr.log"
SSIM_LOG="$DIR/ssim.log"

echo "[INFO] Iniciando teste RTMP em $(date '+%Y-%m-%d %H:%M:%S')"

# Captura pacotes RTMP (porta 1935)
echo "[INFO] Iniciando captura de pacotes na porta $PORT..."
sudo tcpdump -i any port $PORT -w "$PCAP_FILE" &
TCPDUMP_PID=$!

# Inicia FFmpeg (transmissor) para enviar via RTMP
echo "[INFO] Iniciando FFmpeg (transmissor RTMP)..."
ffmpeg -re -i "$VIDEO" \
    -c:v libx264 -preset veryfast -b:v 2M \
    -c:a aac -ar 44100 -b:a 128k \
    -f flv "rtmp://$SERVER_IP:$PORT/live/stream" \
    2>&1 | ts '[%Y-%m-%d %H:%M:%S]' > "$FFMPEG_LOG" &
FFMPEG_PID=$!

sleep 5

# Inicia FFmpeg como cliente para gravar vídeo via RTMP
echo "[INFO] Iniciando FFmpeg (cliente RTMP) para gravação..."
ffmpeg -i "rtmp://$SERVER_IP:$PORT/live/stream" -c copy "$RECEBIDO" \
    2>&1 | ts '[%Y-%m-%d %H:%M:%S]' > "$RECV_LOG" &
RECV_PID=$!

# Aguarda tempo da transmissão
sleep 400

# Finaliza os processos
echo "[INFO] Encerrando processos..."
kill $FFMPEG_PID &> /dev/null
kill $RECV_PID &> /dev/null
sudo kill $TCPDUMP_PID

# Converte pcap para CSV
echo "[INFO] Convertendo captura para CSV com $(pwd)/pcap.sh..."
./pcap.sh "$PCAP_FILE" "$CSV_FILE"

# Avalia PSNR
echo "[INFO] Calculando PSNR..."
ffmpeg -i "$VIDEO" -i "$RECEBIDO" \
-lavfi "[0:v]scale=640:360,format=yuv420p[ref];[1:v]scale=640:360,format=yuv420p[test];[ref][test]psnr=stats_file=$PSNR_LOG" \
-f null - > /dev/null 2>&1

# Avalia SSIM
echo "[INFO] Calculando SSIM..."
ffmpeg -i "$VIDEO" -i "$RECEBIDO" \
-lavfi "[0:v]scale=640:360,format=yuv420p[ref];[1:v]scale=640:360,format=yuv420p[test];[ref][test]ssim=stats_file=$SSIM_LOG" \
-f null - > /dev/null 2>&1

# Executa coleta de métricas
echo "[INFO] Executando análise com coletar.py..."
python3 coletar_psnr_ssim.py -d "$DIR" -o "$RESULTS_CSV"

# Extrai e mostra os valores médios de PSNR e SSIM
PSNR_MEDIO=$(grep "psnr_avg:" "$PSNR_LOG" | grep -v "inf" | awk '{sum+=$5; count++} END {if (count>0) printf "%.3f", sum/count; else print "N/A"}')
SSIM_MEDIO=$(grep "All:" "$SSIM_LOG" | awk '{sum+=$2; count++} END {if (count>0) printf "%.4f", sum/count; else print "N/A"}')

echo "[INFO] PSNR Médio: $PSNR_MEDIO dB"
echo "[INFO] SSIM Médio: $SSIM_MEDIO"

echo "[SUCESSO] Teste RTMP finalizado às $(date '+%Y-%m-%d %H:%M:%S')"
echo "Arquivos salvos em:"
echo "  - $FFMPEG_LOG (transmissão)"
echo "  - $RECV_LOG (recepção)"
echo "  - $RECEBIDO (vídeo recebido)"
echo "  - $PSNR_LOG"
echo "  - $SSIM_LOG"
echo "  - $PCAP_FILE"
echo "  - $CSV_FILE"
echo "  - $RESULTS_CSV"
