#!/usr/bin/env python3

import pandas as pd
import sys
import os

if len(sys.argv) != 2:
    print(f"Uso: {sys.argv[0]} <arquivo_csv>")
    sys.exit(1)

csv_file = sys.argv[1]

if not os.path.isfile(csv_file):
    print(f"[ERRO] Arquivo não encontrado: {csv_file}")
    sys.exit(2)

# Lê o arquivo CSV
try:
    df = pd.read_csv(csv_file)
except Exception as e:
    print(f"[ERRO] Falha ao ler o arquivo CSV: {e}")
    sys.exit(3)

# Verifica se colunas essenciais estão presentes
if 'frame.time_relative' not in df.columns or 'frame.len' not in df.columns:
    print("O CSV deve conter as colunas 'frame.time_relative' e 'frame.len'.")
    print(f"Colunas encontradas: {list(df.columns)}")
    sys.exit(4)

# Calcula tempo de transmissão
tempo_total = df['frame.time_relative'].iloc[-1] - df['frame.time_relative'].iloc[0]

# Soma total de bytes transmitidos
total_bytes = df['frame.len'].sum()

# Calcula vazão média (em Mbps)
vazao_mbps = (total_bytes * 8) / (tempo_total * 1_000_000)

# Exibe resultados
print(f"Arquivo analisado: {csv_file}")
print(f"Tempo total de transmissão: {tempo_total:.2f} segundos")
print(f"Total de dados recebidos: {total_bytes} bytes")
print(f"Vazão média: {vazao_mbps:.3f} Mbps")
