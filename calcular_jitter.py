import pandas as pd
import numpy as np
import sys

def calcular_jitter(csv_path):
    # Lê o CSV
    df = pd.read_csv(csv_path)

    # Converte a coluna 'Time' para numérico
    df['Time'] = pd.to_numeric(df['Time'], errors='coerce')
    df = df.sort_values('Time').dropna(subset=['Time'])

    # Calcula os deltas entre tempos consecutivos
    deltas = df['Time'].diff().dropna()

    # Calcula jitter como média do valor absoluto das variações entre deltas (RFC 3550-style)
    jitter = np.mean(np.abs(deltas.diff().dropna()))
    return jitter

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Uso: python3 calcular_jitter.py <caminho_para_csv>")
        sys.exit(1)

    caminho_csv = sys.argv[1]
    jitter = calcular_jitter(caminho_csv)
    print(f"Jitter médio: {jitter:.6f} segundos ({jitter*1000:.2f} ms)")
