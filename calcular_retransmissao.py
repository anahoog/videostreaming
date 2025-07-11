import pandas as pd
import re
from collections import Counter
import sys

def extrair_seqnos(csv_path):
    df = pd.read_csv(csv_path)
    seqnos = []

    for info in df['Info']:
        if isinstance(info, str) and "UDT type: data" in info:
            match = re.search(r"seqno:\s?(\d+)", info)
            if match:
                seqnos.append(int(match.group(1)))

    return seqnos

def calcular_retransmissoes(seqnos):
    contador = Counter(seqnos)
    total_retransmissoes = sum(count - 1 for count in contador.values() if count > 1)
    total_pacotes_unicos = len(contador)
    taxa = (total_retransmissoes / (total_retransmissoes + total_pacotes_unicos)) * 100
    return total_retransmissoes, taxa

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Uso: python3 calcular_retransmissao.py <caminho_para_csv>")
        sys.exit(1)

    caminho_csv = sys.argv[1]
    seqnos = extrair_seqnos(caminho_csv)
    total, taxa = calcular_retransmissoes(seqnos)

    print(f"Total de retransmissões: {total}")
    print(f"Taxa de retransmissão: {taxa:.2f}%")
