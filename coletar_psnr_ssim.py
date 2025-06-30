#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import argparse
import re
import sys
from pathlib import Path
import numpy as np
import pandas as pd
from tabulate import tabulate

PROTOCOLOS = ["rtmp", "rtp", "srt"]
CSV_GLOB = "{proto}*.csv"
LOG_GLOB = "vlc_{proto}*.log"

KEY_RETRANS = re.compile(r"(retransmission|dup ack|fast retransmission)", re.I)
KEY_BUFFER = re.compile(r"(buffering|pre-buffer|cache|underrun|rebuffer)", re.I)

def achar_arquivo(diretorio: Path, padrao: str) -> Path | None:
    for f in diretorio.glob(padrao):
        if f.is_file():
            return f
    return None

def metricas_csv(csv_path: Path) -> dict:
    df = pd.read_csv(csv_path)
    info_col = next((col for col in df.columns if "info" in col.lower()), None)
    time_col = next((col for col in df.columns if "time" in col.lower()), None)
    if not info_col or not time_col:
        raise ValueError("[ERRO] Arquivo CSV não contém colunas esperadas ('Info', 'Time')")
    df[time_col] = pd.to_numeric(df[time_col], errors='coerce')
    df = df.dropna(subset=[time_col])
    n_retx = df[info_col].astype(str).str.contains(KEY_RETRANS, na=False).sum()
    duracao = df[time_col].max() - df[time_col].min()
    diffs = df[time_col].diff().dropna()
    jitter = np.abs(diffs.diff().dropna()).mean() if not diffs.empty else 0.0
    return {
        "Retransmissões": int(n_retx),
        "Tempo Sessão (s)": round(float(duracao), 6),
        "Jitter Médio (s)": round(float(jitter), 6),
    }

def metricas_log_vlc(log_path: Path) -> int:
    if log_path is None:
        return 0
    count = 0
    with log_path.open("r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            if KEY_BUFFER.search(line):
                count += 1
    return count

def playback_start_time(df: pd.DataFrame) -> float:
    time_col = next((col for col in df.columns if "time" in col.lower()), None)
    if not time_col:
        return 0.0
    return float(df[time_col].min())

def duration_of_interruptions(df: pd.DataFrame, threshold: float = 0.5) -> tuple[float, int]:
    time_col = next((col for col in df.columns if "time" in col.lower()), None)
    if not time_col:
        return 0.0, 0
    diffs = df[time_col].diff().dropna()
    long_gaps = diffs[diffs > threshold]
    return float(long_gaps.sum()), int(len(long_gaps))

def estimate_loss_rate(df: pd.DataFrame, protocol_name: str) -> float | str:
    if "Sequence number" in df.columns:
        seq = df["Sequence number"].dropna().astype(int)
        if seq.empty:
            return "N/A"
        expected = seq.max() - seq.min() + 1
        received = len(seq)
        lost = expected - received
        return round(max(0, lost / expected), 5)
    elif protocol_name == "rtp":
        time_col = next((col for col in df.columns if "time" in col.lower()), None)
        if time_col:
            diffs = df[time_col].diff().dropna()
            loss_events = (diffs > 0.1).sum()
            return round(loss_events / len(df), 5)
    return "N/A"

def extrair_psnr(path: Path):
    if path.exists():
        with path.open() as f:
            valores = [float(line.split("psnr_avg:")[1].split()[0])
                       for line in f if "psnr_avg:" in line and "inf" not in line]
            if valores:
                return round(sum(valores) / len(valores), 3)
    return "N/A"

def extrair_ssim(path: Path):
    if path.exists():
        with path.open() as f:
            valores = [float(line.split("All:")[1].split()[0])
                       for line in f if "All:" in line]
            if valores:
                return round(sum(valores) / len(valores), 4)
    return "N/A"

def processar_protocolo(proto: str, base_dir: Path) -> dict:
    csv_file = achar_arquivo(base_dir, CSV_GLOB.format(proto=proto))
    log_file = achar_arquivo(base_dir, LOG_GLOB.format(proto=proto))
    psnr_file = base_dir / "psnr.log"
    ssim_file = base_dir / "ssim.log"

    if csv_file is None:
        print(f"[WARN] CSV de {proto.upper()} não encontrado.")
        return None

    df = pd.read_csv(csv_file)

    try:
        res_csv = metricas_csv(csv_file)
    except Exception as e:
        print(f"[ERRO] {e}")
        res_csv = {
            "Retransmissões": "N/A",
            "Tempo Sessão (s)": "N/A",
            "Jitter Médio (s)": "N/A",
        }

    n_buff = metricas_log_vlc(log_file)
    start_time = playback_start_time(df)
    duration_int, n_interrupt = duration_of_interruptions(df)
    loss_rate = estimate_loss_rate(df, proto.lower())

    return {
        "Protocolo": proto.upper(),
        **res_csv,
        "Buffering": n_buff,
        "Playback Start Time (s)": round(start_time, 3),
        "Duration of Interruptions (s)": round(duration_int, 3),
        "Number of Interruptions": n_interrupt,
        "Taxa de Perda Estimada": loss_rate,
        "PSNR Médio (dB)": extrair_psnr(psnr_file),
        "SSIM Médio": extrair_ssim(ssim_file),
        "CSV": csv_file.name,
        "Log": log_file.name if log_file else "—",
    }

def main():
    parser = argparse.ArgumentParser(description="Coleta métricas QoE e QoS de CSVs e logs VLC")
    parser.add_argument("-d", "--dir", default=".", help="Diretório com os arquivos (padrão: .)")
    parser.add_argument("-o", "--out", default="", help="Salva resultado em CSV (ex.: saida.csv)")
    parser.add_argument("-p", "--proto", choices=PROTOCOLOS, help="Protocolo a ser processado (rtp, rtmp, srt)")
    args = parser.parse_args()

    base_dir = Path(args.dir).expanduser().resolve()
    if not base_dir.is_dir():
        print(f"Diretório '{base_dir}' não existe.", file=sys.stderr)
        sys.exit(1)

    protocolos = [args.proto] if args.proto else PROTOCOLOS
    resultados = []
    for proto in protocolos:
        dados = processar_protocolo(proto, base_dir)
        if dados:
            resultados.append(dados)

    if not resultados:
        print("Nenhum dado processado. Verifique os arquivos.")
        sys.exit(0)

    df_final = pd.DataFrame(resultados).set_index("Protocolo")

    print("\n=== MÉTRICAS COLETADAS ===")
    print(tabulate(df_final, headers="keys", tablefmt="github"))

    if args.out:
        out_path = Path(args.out).with_suffix(".csv")
        df_final.to_csv(out_path)
        print(f"\n[OK] Resultado salvo em '{out_path}'")

if __name__ == "__main__":
    main()