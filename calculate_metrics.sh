#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 6 ]]; then
  echo "Usage: $0 <VIDEO> <RECEBIDO> <PSNR_STATS> <SSIM_STATS> <PROTO> <RESULT_CSV>"
  exit 1
fi

VIDEO="$1"
RECEBIDO="$2"
PSNR_STATS="$3"
SSIM_STATS="$4"
PROTO="$5"
RESULT_CSV="$6"

# ---------------------------
# PSNR
# ---------------------------
echo "[INFO] Calculando PSNR (psnr_avg)…"
ffmpeg -i "$VIDEO" -i "$RECEBIDO" \
       -lavfi "psnr=stats_file=${PSNR_STATS}" \
       -f null - 2>/dev/null

echo "[INFO] Calculando PSNR médio..."
PSNR=$(awk -F'psnr_avg:' '/psnr_avg:/ && !/psnr_avg:inf/ {sum+=$2; count++} END {if (count>0) printf "%.5f", sum/count; else print "0"}' "$PSNR_STATS")
echo "[INFO] PSNR médio para $PROTO: $PSNR dB"

# ---------------------------
# SSIM
# ---------------------------
echo "[INFO] Calculando SSIM (All)…"
ffmpeg -i "$VIDEO" -i "$RECEBIDO" \
       -lavfi "ssim=stats_file=${SSIM_STATS}" \
       -f null - 2>/dev/null

SSIM=$(grep "All:" "$SSIM_STATS" | \
       grep -v "All:inf" | \
       awk -F'All:' '{if ($2 > 0) { sum+=$2; count+=1 } } END {if (count>0) printf "%.6f", sum/count; else print "0"}')


# ---------------------------
# Resultado CSV
# ---------------------------
echo "[INFO] Gravando resultados em $RESULT_CSV"
echo "Protocolo,PSNR(dB),SSIM" > "$RESULT_CSV"
echo "$PROTO,$PSNR,$SSIM" >> "$RESULT_CSV"
