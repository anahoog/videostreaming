import pandas as pd
import numpy as np
import sys

def calcular_buffering(csv_path, limiar_segundos=0.5):
    # Ler o CSV
    df = pd.read_csv(csv_path)

    # Garantir que a coluna 'Time' está como numérica
    df['Time'] = pd.to_numeric(df['Time'], errors='coerce')
    df = df.sort_values('Time').dropna(subset=['Time'])

    # Calcular os intervalos entre pacotes consecutivos
    deltas = df['Time'].diff().dropna()

    # Filtrar gaps acima do limiar (eventos de buffering)
    buffering_gaps = deltas[deltas > limiar_segundos]

    # Métricas
    num_eventos = len(buffering_gaps)
    duracao_total = buffering_gaps.sum()
    duracao_media = buffering_gaps.mean() if num_eventos > 0 else 0.0

    return num_eventos, duracao_total, duracao_media

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Uso: python3 calcular_buffering.py <caminho_para_csv>")
        sys.exit(1)

    caminho_csv = sys.argv[1]
    eventos, total, media = calcular_buffering(caminho_csv)

    print(f"Número de eventos de buffering: {eventos}")
    print(f"Duração total das interrupções: {total:.3f} segundos")
    print(f"Duração média por interrupção: {media:.3f} segundos")
