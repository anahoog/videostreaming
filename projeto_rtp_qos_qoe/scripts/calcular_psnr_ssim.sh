#!/bin/bash

VIDEO_ORIGINAL="RickAstley.mkv"
VIDEO_RECEBIDO="logs/recebido_rtp.ts"
OUTDIR="resultados"
mkdir -p "$OUTDIR"

echo "[INFO] Calculando PSNR..."
ffmpeg -i "$VIDEO_ORIGINAL" -i "$VIDEO_RECEBIDO" -lavfi psnr="stats_file=$OUTDIR/psnr.log" -f null - || true

echo "[INFO] Calculando SSIM..."
ffmpeg -i "$VIDEO_ORIGINAL" -i "$VIDEO_RECEBIDO" -lavfi ssim="stats_file=$OUTDIR/ssim.log" -f null - || true

echo "[OK] PSNR e SSIM salvos em $OUTDIR"
