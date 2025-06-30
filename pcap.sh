#!/bin/bash

# Verifica se os parâmetros foram fornecidos
PCAP="$1"
CSV="$2"

if [[ -z "$PCAP" || -z "$CSV" ]]; then
  echo "[ERRO] Uso: $0 <arquivo.pcap> <arquivo.csv>"
  exit 1
fi

echo "[INFO] Convertendo $PCAP para $CSV..."

# Executa o tshark para extrair os campos relevantes e válidos
tshark -r "$PCAP" \
  -T fields \
  -E header=y -E separator=, -E quote=d -E occurrence=f \
  -e frame.number \
  -e frame.time_relative \
  -e ip.src \
  -e ip.dst \
  -e frame.len \
  -e _ws.col.Protocol \
  -e _ws.col.Info \
  > "$CSV"

# Verificação de sucesso
if [[ $? -eq 0 ]]; then
  echo "[OK] CSV gerado em: $CSV"
else
  echo "[ERRO] Falha ao gerar CSV"
fi