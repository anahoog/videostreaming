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

echo "[INFO] Calculando PSNR (psnr_avg)…"
ffmpeg -i "$VIDEO" -i "$RECEBIDO" \
       -lavfi "psnr=stats_file=${PSNR_STATS}" \
       -f null - 2>/dev/null
PSNR=$(grep -oP 'psnr_avg:\K[0-9]+\.[0-9]+' "$PSNR_STATS" | tail -1)
echo "[INFO] PSNR médio: $PSNR"

echo "[INFO] Calculando SSIM (All)…"
ffmpeg -i "$VIDEO" -i "$RECEBIDO" \
       -lavfi "ssim=stats_file=${SSIM_STATS}" \
       -f null - 2>/dev/null
SSIM=$(grep -oP 'All:\K[0-9]+\.[0-9]+' "$SSIM_STATS" | tail -1)
echo "[INFO] SSIM médio: $SSIM"

echo "[INFO] Gravando CSV de métricas…"
{
  echo "protocol,psnr_avg,ssim_avg"
  printf "%s,%s,%s\n" "$PROTO" "$PSNR" "$SSIM"
} > "$RESULT_CSV"
echo "[INFO] CSV de métricas salvo em $RESULT_CSV"
