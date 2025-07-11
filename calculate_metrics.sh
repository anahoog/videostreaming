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
sleep 5
echo "[INFO] Calculando PSNR (psnr_avg)…"
ffmpeg -i "$VIDEO" -i "$RECEBIDO" \
       -lavfi "psnr=stats_file=${PSNR_STATS}" \
       -f null - 2>/dev/null
sleep 5
# ---------------------------
# SSIM
# ---------------------------
echo "[INFO] Calculando SSIM (All)…"
ffmpeg -i "$VIDEO" -i "$RECEBIDO" \
       -lavfi "ssim=stats_file=${SSIM_STATS}" \
       -f null - 2>/dev/null

sleep 5

# ---------------------------
# Resultado CSV
# ---------------------------

