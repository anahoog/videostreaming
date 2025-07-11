import pandas as pd
import numpy as np
import re
import sys
from collections import Counter

def extrair_sequencias(info_col):
    seqs = []
    for info in info_col:
        match = re.search(r'seq=(\d+)', str(info))
        if match:
            seqs.append(int(match.group(1)))
    return seqs

def calcular_eventos_de_perda(seqs):
    eventos = 0
    for i in range(1, len(seqs)):
        if seqs[i] - seqs[i - 1] > 1:
            eventos += 1
    return eventos

def calcular_retransmissoes(seqs):
    return int((pd.Series(seqs).value_counts() > 1).sum())

def analisar_buffering(log_path):
    with open(log_path, "r") as f:
        log_lines = f.readlines()

    eventos = [line for line in log_lines if re.search(r'buffer|delay|drop|underrun|overrun|jitter', line, re.IGNORECASE)]
    tipos = []
    for line in eventos:
        if "underrun" in line.lower():
            tipos.append("underrun")
        elif "overrun" in line.lower():
            tipos.append("overrun")
        elif "drop" in line.lower():
            tipos.append("drop")
        elif "delay" in line.lower():
            tipos.append("delay")
        elif "jitter" in line.lower():
            tipos.append("jitter")
        elif "buffer" in line.lower():
            tipos.append("buffer")

    contagem = Counter(tipos)
    return contagem

def analisar_rtp(csv_path, log_path=None):
    df = pd.read_csv(csv_path)
    df['Time'] = pd.to_numeric(df['Time'], errors='coerce')
    df = df.dropna(subset=['Time'])

    # Sequências RTP
    seqs = extrair_sequencias(df['Info'])

    # Eventos de perda e retransmissão
    eventos_perda = calcular_eventos_de_perda(seqs) if seqs else 0
    retransmissoes = calcular_retransmissoes(seqs) if seqs else 0

    # Vazão média
    duracao = df['Time'].max() - df['Time'].min()
    tamanho_total_bits = df['Length'].sum() * 8
    vazao_mbps = (tamanho_total_bits / duracao) / 1_000_000 if duracao > 0 else 0

    # Jitter
    tempos = df['Time'].to_numpy()
    deltas = np.diff(tempos)
    jitter = float(np.std(np.diff(deltas))) if len(deltas) > 2 else 0

    print("\n RESULTADOS DA ANÁLISE RTP")
    print(f"- Pacotes RTP com seq= encontrados : {len(seqs)}")
    print(f"- Eventos de perda                : {eventos_perda}")
    print(f"- Retransmissões detectadas      : {retransmissoes}")
    print(f"- Vazão média (Mbps)             : {vazao_mbps:.4f}")
    print(f"- Jitter estimado (s)            : {jitter:.6f}")

    if log_path:
        buffer_data = analisar_buffering(log_path)
        print("\n EVENTOS DE BUFFERING NO LOG:")
        for tipo, qtd in buffer_data.items():
            print(f"- {tipo.capitalize():<10}: {qtd}")

if __name__ == "__main__":
    if len(sys.argv) not in [2, 3]:
        print("Uso: python3 analise_rtp.py <arquivo.csv> [log_ffmpeg_rx.txt]")
        sys.exit(1)

    csv = sys.argv[1]
    log = sys.argv[2] if len(sys.argv) == 3 else None
    analisar_rtp(csv, log)
