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

#!/usr/bin/env bash
# Define que o script deve ser executado usando o interpretador Bash

# Ativa as seguintes opções:
# -e: Encerra o script se qualquer comando retornar erro
# -u: Encerra o script se tentar usar uma variável não definida
# -o pipefail: Faz com que falhas em qualquer parte de um pipe sejam capturadas
set -euo pipefail

# Verifica se o número de argumentos é exatamente 6
if [[ $# -ne 6 ]]; then
  echo "Usage: $0 <VIDEO> <RECEBIDO> <PSNR_STATS> <SSIM_STATS> <PROTO> <RESULT_CSV>"
  exit 1
fi

# Atribui os argumentos a variáveis com nomes significativos
VIDEO="$1"         # Caminho para o vídeo original
RECEBIDO="$2"      # Caminho para o vídeo recebido (transmitido e gravado)
PSNR_STATS="$3"    # Arquivo onde serão salvas as estatísticas de PSNR
SSIM_STATS="$4"    # Arquivo onde serão salvas as estatísticas de SSIM
PROTO="$5"         # Nome do protocolo usado (srt, rtp ou rtmp)
RESULT_CSV="$6"    # Arquivo CSV final com os resultados formatados

# ---------------------------
# Cálculo do PSNR
# ---------------------------
echo "[INFO] Calculando PSNR (psnr_avg)…"

# Executa o filtro PSNR comparando os dois vídeos
# -lavfi aplica o filtro de vídeo "psnr"
# -f null - descarta a saída de vídeo
# 2>/dev/null oculta as mensagens do FFmpeg
ffmpeg -i "$VIDEO" -i "$RECEBIDO" \
       -lavfi "psnr=stats_file=${PSNR_STATS}" \
       -f null - 2>/dev/null

# Extrai o valor de psnr_avg do arquivo de estatísticas
# grep -oP: usa regex para pegar o número após 'psnr_avg:'
# tail -1: pega a última linha encontrada (caso haja mais de uma)
PSNR=$(grep -oP 'psnr_avg:\K[0-9]+\.[0-9]+' "$PSNR_STATS" | tail -1)

echo "[INFO] PSNR médio: $PSNR"

# ---------------------------
# Cálculo do SSIM
# ---------------------------
echo "[INFO] Calculando SSIM (All)…"

# Executa o filtro SSIM com FFmpeg
# stats_file salva as métricas detalhadas por quadro
ffmpeg -i "$VIDEO" -i "$RECEBIDO" \
       -lavfi "ssim=stats_file=${SSIM_STATS}" \
       -f null - 2>/dev/null

# Extrai o valor "All" (SSIM médio global) do arquivo de estatísticas
SSIM=$(grep -oP 'All:\K[0-9]+\.[0-9]+' "$SSIM_STATS" | tail -1)

echo "[INFO] SSIM médio: $SSIM"

# ---------------------------
# Geração do CSV de métricas
# ---------------------------
echo "[INFO] Gravando CSV de métricas…"

# Cria um arquivo CSV com cabeçalho e valores de PSNR e SSIM
{
  echo "protocol,psnr_avg,ssim_avg"     # Cabeçalho
  printf "%s,%s,%s\n" "$PROTO" "$PSNR" "$SSIM"  # Linha de dados
} > "$RESULT_CSV"

echo "[INFO] CSV de métricas salvo em $RESULT_CSV"
