#!/usr/bin/env python3
import argparse
import pandas as pd
import matplotlib.pyplot as plt
import os
import glob

def analisar_csv(input_csv, output_dir):
    # Lê dados do CSV de captura
    df = pd.read_csv(input_csv)
    df['timestamp'] = pd.to_numeric(df.get('frame.time_relative', None), errors='coerce')
    df['bytes']     = pd.to_numeric(df.get('frame.len', None), errors='coerce')
    df = df.dropna(subset=['timestamp', 'bytes'])

    # Calcula delta e jitter
    df['delta']  = df['timestamp'].diff()
    df['jitter'] = df['delta'].rolling(window=2).std()

    # Calcula throughput em bps por segundo
    df['bps'] = df['bytes'] * 8
    bps_por_seg = df.groupby(df['timestamp'].astype(int))['bps'].sum()

    # Identifica protocolo pelo nome do arquivo
    protocolo = os.path.basename(input_csv).split('_')[0]

    # Cria pasta específica para este protocolo nos gráficos
    dir_proto = os.path.join(output_dir, protocolo)
    os.makedirs(dir_proto, exist_ok=True)

    # Gráfico de Throughput
    plt.figure()
    bps_por_seg.plot()
    plt.title(f'Taxa de Transmissão (bps) - {protocolo.upper()}')
    plt.xlabel('Tempo (s)')
    plt.ylabel('Bits por segundo')
    plt.grid()
    plt.savefig(os.path.join(dir_proto, 'taxa_transmissao.png'))
    plt.close()

    # Gráfico de Jitter
    plt.figure()
    df['jitter'].plot()
    plt.title(f'Jitter Estimado - {protocolo.upper()}')
    plt.xlabel('Pacotes')
    plt.ylabel('Jitter (s)')
    plt.grid()
    plt.savefig(os.path.join(dir_proto, 'jitter.png'))
    plt.close()

    print(f'[OK] Gráficos salvos em {dir_proto}')


def main():
    parser = argparse.ArgumentParser(
        description='Analisa throughput e jitter para múltiplos protocolos a partir de arquivos *_capture.csv.'
    )
    parser.add_argument(
        '-i', '--input-dir',
        default='.',
        help='Diretório onde estão os arquivos *_capture.csv (padrão: diretório atual)'
    )
    parser.add_argument(
        '-o', '--output-dir',
        default=os.path.join('.', 'resultados', 'graficos'),
        help='Diretório para salvar os gráficos organizados por protocolo'
    )
    args = parser.parse_args()

    input_dir = args.input_dir
    output_dir = args.output_dir

    # Busca todos os CSVs de captura
    pattern = os.path.join(input_dir, '*_capture.csv')
    csvs = glob.glob(pattern)
    if not csvs:
        print(f'Nenhum arquivo *_capture.csv encontrado em {input_dir}')
        return

    # Analisa cada CSV
    for csv_path in csvs:
        analisar_csv(csv_path, output_dir)

if __name__ == '__main__':
    main()
