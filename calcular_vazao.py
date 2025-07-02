import pandas as pd
import sys

if len(sys.argv) != 2:
    print(f"Uso: {sys.argv[0]} <arquivo_csv>")
    sys.exit(1)

csv_file = sys.argv[1]

# Lê o arquivo CSV
df = pd.read_csv(csv_file)

# Verifica as colunas esperadas
if 'frame.time_relative' not in df.columns or 'frame.len' not in df.columns:
    print("O CSV deve conter as colunas 'frame.time_relative' e 'frame.len'.")
    sys.exit(2)

# Tempo de transmissão (segundos)
tempo_total = df['frame.time_relative'].iloc[-1] - df['frame.time_relative'].iloc[0]

# Total de bytes recebidos
total_bytes = df['frame.len'].sum()

# Vazão média (Mbps)
vazao_mbps = (total_bytes * 8) / (tempo_total * 1_000_000)

print(f"Tempo total de transmissão: {tempo_total:.2f} segundos")
print(f"Total de dados recebidos: {total_bytes} bytes")
print(f"Vazão média: {vazao_mbps:.3f} Mbps")
