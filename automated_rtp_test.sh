#!/bin/bash

# Verifica se o utilitário 'ts' está instalado
if ! command -v ts &> /dev/null; then
    echo "[ERRO] O utilitário 'ts' não está instalado. Instale com: sudo apt install moreutils"
    exit 1
fi



# Caminho do vídeo de entrada
VIDEO="soundh264.mp4"

# IPs e porta
DEST_IP="192.168.2.99"
SOURCE_IP="192.168.3.20"
RTP_PORT=4004
RTP_URL="rtp://192.168.3.20@$RTP_PORT"

# Arquivos de log e captura
VLC_TX_LOG="vlc_rtp_tx.log"
VLC_RX_LOG="vlc_rtp_rx.log"
PCAP_FILE="rtp_capture.pcap"

echo "[INFO] Iniciando teste RTP em $(date '+%Y-%m-%d %H:%M:%S')"

# Inicia captura de pacotes RTP
echo "[INFO] Capturando pacotes RTP na porta $RTP_PORT..."
sudo tcpdump -i any port $RTP_PORT -w "$PCAP_FILE" &
TCPDUMP_PID=$!

# Inicia o VLC como transmissor RTP
echo "[INFO] Iniciando VLC como transmissor RTP..."
cvlc "$VIDEO" --loop \
--sout "#transcode{vcodec=h264,acodec=mp4a,vb=2048k,ab=64k,deinterlace,scale=1,threads=2}:rtp{mux=ts,dst=192.168.2.99,port=$RTP_PORT}" \
2>&1 | ts '[%Y-%m-%d %H:%M:%S]' > "$VLC_TX_LOG" &

VLC_TX_PID=$!
sleep 2

# Inicia o VLC como receptor RTP com log timestampado
echo "[INFO] Iniciando VLC como receptor RTP..."
vlc "rtp://192.168.3.20:4004" -vvv 2>&1 | ts '[%Y-%m-%d %H:%M:%S]' > "$VLC_RX_LOG" &

VLC_RX_PID=$!
sleep 25

# Finaliza os processos
echo "[INFO] Encerrando processos..."
kill $VLC_TX_PID &> /dev/null
kill $VLC_RX_PID &> /dev/null
sudo kill $TCPDUMP_PID

echo "[SUCESSO] Teste RTP finalizado às $(date '+%Y-%m-%d %H:%M:%S')"
echo "Logs salvos em:"
echo "  - $VLC_TX_LOG"
echo "  - $VLC_RX_LOG"
echo "  - $PCAP_FILE"
