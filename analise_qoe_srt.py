import pandas as pd
import numpy as np
import re
import sys
from collections import Counter

def extrair_seqnos(df):
    seqnos = []
    for info in df['Info']:
        if isinstance(info, str) and "UDT type: data" in info:
            match = re.search(r"seqno:\s?(\d+)", info)
            if match:
                seqnos.append(int(match.group(1)))
    return seqnos

def calcular_retransmissoes(seqnos):
    contador = Counter(seqnos)
    total_retx = sum(c - 1 for c in contador.values() if c > 1)
    total_unicos = len(contador)
    taxa = (total_retx / (total_retx + total_unicos)) * 100 if total_unicos else 0
    return total_retx, taxa

def calcular_jitter(tempos):
    deltas = tempos.diff().dropna()
    jitter = np.mean(np.abs(deltas.diff().dropna()))
    return jitter

def calcular_buffering(tempos, limiar=0.5):
    deltas = tempos.diff().dropna()
    buffering_gaps = deltas[deltas > limiar]
    return len(buffering_gaps), buffering_gaps.sum(), buffering_gaps.mean() if len(buffering_gaps) > 0 else 0.0

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Uso: python3 analise_qoe_srt.py <caminho_para_csv>")
        sys.exit(1)

    caminho_csv = sys.argv[1]
    df = pd.read_csv(caminho_csv)
    df['Time'] = pd.to_numeric(df['Time'], errors='coerce')
    df = df.sort_values('Time').dropna(subset=['Time'])

    # Retransmissões
    seqnos = extrair_seqnos(df)
    total_retx, taxa_retx = calcular_retransmissoes(seqnos)

    # Jitter
    jitter = calcular_jitter(df['Time'])

    # Buffering
    eventos_buff, dur_total_buff, dur_media_buff = calcular_buffering(df['Time'])

    # Resultado final
    print("=== Análise QoE SRT ===")
    print(f"Retransmissões: {total_retx}")
    print(f"Taxa de retransmissão: {taxa_retx:.2f}%")
    print(f"Jitter médio: {jitter:.6f} segundos ({jitter*1000:.2f} ms)")
    print(f"Eventos de buffering: {eventos_buff}")
    print(f"Duração total de buffering: {dur_total_buff:.3f} segundos")
    print(f"Duração média por evento: {dur_media_buff:.3f} segundos")
