#!/usr/bin/env python3
import argparse, json, re, os
from glob import glob
import csv

def find_file(dirpath, *patterns):
    for pat in patterns:
        matches = glob(os.path.join(dirpath, pat))
        if matches:
            return matches[0]
    return None

def extract_values(path, regex):
    vals = []
    with open(path) as f:
        for line in f:
            m = re.search(regex, line)
            if m:
                grp = next((g for g in m.groups() if g), None)
                if grp is not None:
                    vals.append(float(grp))
    return vals

def extract_vmaf_list(path):
    with open(path) as f:
        data = json.load(f)
    frames = data.get('frames', data if isinstance(data, list) else [])
    return [fr.get('metrics', {}).get('vmaf', 0) for fr in frames]

def avg_rtp_jitter(csv_path):
    jitters = []
    with open(csv_path, newline='') as f:
        reader = csv.DictReader(f)
        jitter_cols = [c for c in reader.fieldnames if 'jitter' in c.lower()]
        for row in reader:
            for col in jitter_cols:
                val = row.get(col)
                if val and val.lower() not in ('nan',''):
                    try:
                        jitters.append(float(val))
                    except ValueError:
                        pass
    return sum(jitters)/len(jitters) if jitters else None

def estimate_jitter_from_csv(csv_path, time_col_keywords=('time',)):
    times = []
    with open(csv_path, newline='') as f:
        reader = csv.DictReader(f)
        time_col = next((c for c in reader.fieldnames if any(k in c.lower() for k in time_col_keywords)), None)
        if not time_col:
            return None
        for row in reader:
            try:
                times.append(float(row[time_col]))
            except:
                continue
    if len(times) < 2:
        return None
    times.sort()
    deltas = [t2 - t1 for t1, t2 in zip(times, times[1:])]
    mean = sum(deltas) / len(deltas)
    var = sum((d - mean)**2 for d in deltas) / len(deltas)
    return (var**0.5) * 1000

def count_rebuffers_from_csv(csv_path, threshold_s=0.1, time_col_keywords=('time',)):
    times = []
    with open(csv_path, newline='') as f:
        reader = csv.DictReader(f)
        time_col = next((c for c in reader.fieldnames if any(k in c.lower() for k in time_col_keywords)), None)
        if not time_col:
            return None
        for row in reader:
            try:
                times.append(float(row[time_col]))
            except:
                continue
    times.sort()
    stalls = 0
    prev = None
    for t in times:
        if prev is not None and (t - prev) > threshold_s:
            stalls += 1
        prev = t
    return stalls

def parse_tx(path):
    sent = None
    frames = []
    with open(path) as f:
        for line in f:
            if m := re.search(r'pkts_sent=(\d+)', line):
                sent = int(m.group(1))
            if re.search(r'frame=\s*0 .*bitrate=\s*N/A', line):
                continue
            if m := re.search(r'frame=\s*(\d+)', line):
                frames.append(int(m.group(1)))
    if sent is None and frames:
        sent = max(frames)
    return sent

def parse_rx(path):
    frames = []
    jitters = []
    rebufs = 0
    with open(path) as f:
        for line in f:
            if re.search(r'frame=\s*0 .*bitrate=\s*N/A', line):
                continue
            if m := re.search(r'frame=\s*(\d+)', line):
                frames.append(int(m.group(1)))
            if m := re.search(r'delayed for ([0-9\.]+) ms', line):
                jitters.append(float(m.group(1)))
            if re.search(r'(?i)(rebuffer|buffering)', line):
                rebufs += 1
    recv = max(frames) if frames else None
    avg_jitter = sum(jitters)/len(jitters) if jitters else None
    return recv, avg_jitter, rebufs

def main():
    parser = argparse.ArgumentParser(description='Extrai métricas de qualidade e SRT/RTP')
    parser.add_argument('capture_dir', help='Diretório com logs e stats')
    args = parser.parse_args()
    d = args.capture_dir.rstrip('/') + '/'

    psnr_f = find_file(d, 'psnr*.txt','psnr*.stats')
    ssim_f = find_file(d, 'ssim*.txt','ssim*.stats')
    vmaf_f = find_file(d, 'vmaf.json')  # <-- nome exato
    tx_log = find_file(d, 'ffmpeg_tx*_stats.txt','ffmpeg_tx*.log')
    rx_log = find_file(d, 'ffmpeg_rx*_stats.txt','ffmpeg_rx*.log')
    rtp_csv = find_file(d, '*.csv')

    psnr_vals = extract_values(psnr_f, r'psnr_y:([0-9\.]+)|PSNR y avg: ([0-9\.]+)') if psnr_f else []
    ssim_vals = extract_values(ssim_f, r'All:([0-9\.]+)') if ssim_f else []
    vmaf_vals = extract_vmaf_list(vmaf_f) if vmaf_f else []

    # salva VMAF por frame
    if vmaf_f:
        print(f"✔ Arquivo VMAF encontrado: {vmaf_f}")
        try:
            with open(vmaf_f) as f:
                data = json.load(f)

            if isinstance(data, dict):
                frames = data.get("frames", [])
            elif isinstance(data, list):
                frames = data
            else:
                frames = []

            print(f"✔ Total de frames carregados: {len(frames)}")

            output_vmaf_txt = os.path.join(d, 'vmaf_por_frame.txt')
            written = 0
            with open(output_vmaf_txt, 'w') as out:
                for frame in frames:
                    frame_num = frame.get("frameNum")
                    vmaf_val = frame.get("metrics", {}).get("vmaf") if isinstance(frame.get("metrics"), dict) else None
                    if frame_num is not None and vmaf_val is not None:
                        out.write(f"frameNum: {frame_num}, vmaf: {vmaf_val:.6f}\n")
                        written += 1

            if written > 0:
                print(f"✔ Arquivo salvo com {written} linhas em: {output_vmaf_txt}")
            else:
                print("⚠ Nenhum frame válido com VMAF foi encontrado para salvar.")
        except Exception as e:
            print(f"❌ Erro ao salvar VMAF por frame: {e}")
    else:
        print("⚠ Nenhum arquivo VMAF encontrado.")

    psnr = sum(psnr_vals)/len(psnr_vals) if psnr_vals else None
    ssim = sum(ssim_vals)/len(ssim_vals) if ssim_vals else None
    vmaf = sum(vmaf_vals)/len(vmaf_vals) if vmaf_vals else None

    thr_k = extract_values(tx_log, r'bitrate=\s*([0-9\.]+)kbits/s') if tx_log else []
    thr = (sum(thr_k)/len(thr_k)/1000) if thr_k else None

    sent = parse_tx(tx_log) if tx_log else None
    recv, jitter, rebufs = parse_rx(rx_log) if rx_log else (None,None,None)

    if rtp_csv:
        csv_jit = avg_rtp_jitter(rtp_csv)
        csv_est_jit = estimate_jitter_from_csv(rtp_csv)
        jitter = csv_jit if csv_jit is not None else (csv_est_jit if csv_est_jit is not None else jitter)
        csv_rebuf = count_rebuffers_from_csv(rtp_csv)
        rebufs = csv_rebuf if csv_rebuf is not None else rebufs

    lost = None
    pct_loss = None
    if sent is not None and recv is not None:
        lost = sent - recv
        pct_loss = (lost/sent*100) if sent > 0 else None

    print(f"PSNR médio (dB): {psnr:.2f}" if psnr is not None else "PSNR: não disponível")
    print(f"SSIM médio: {ssim:.4f}" if ssim is not None else "SSIM: não disponível")
    print(f"VMAF médio: {vmaf:.2f}" if vmaf is not None else "VMAF: não disponível")
    print(f"Vazão média (Mbps): {thr:.3f}" if thr is not None else "Vazão: não disponível")
    print()
    print("== Estatísticas de Transmissão/Recepção ==")
    print(f"Pacotes transmitidos: {sent}" if sent is not None else "Pacotes transmitidos: –")
    print(f"Pacotes recebidos: {recv}" if recv is not None else "Pacotes recebidos: –")
    print(f"Pacotes perdidos: {lost}" if lost is not None else "Pacotes perdidos: –")
    if pct_loss is not None:
        print(f"Perda percentual: {pct_loss:.2f}%")
    print(f"Jitter médio (ms): {jitter:.2f}" if jitter is not None else "Jitter: não disponível")
    print(f"Rebuffering (eventos): {rebufs}" if rebufs is not None else "Rebuffering: não disponível")

if __name__=='__main__':
    main()
