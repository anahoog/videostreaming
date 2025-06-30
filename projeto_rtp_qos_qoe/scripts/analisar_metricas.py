import pandas as pd
import matplotlib.pyplot as plt
import os

df = pd.read_csv("resultados/rtp_capture.csv")
df['timestamp'] = pd.to_numeric(df['frame.time_relative'], errors='coerce')
df['bytes'] = pd.to_numeric(df['frame.len'], errors='coerce')
df = df.dropna()

df['delta'] = df['timestamp'].diff()
df['jitter'] = df['delta'].rolling(window=2).std()
df['bps'] = df['bytes'] * 8
bps_por_seg = df.groupby(df['timestamp'].astype(int))['bps'].sum()

os.makedirs("resultados/graficos", exist_ok=True)

plt.figure()
bps_por_seg.plot()
plt.title("Taxa de Transmissão (bps)")
plt.xlabel("Tempo (s)")
plt.ylabel("Bits por segundo")
plt.grid()
plt.savefig("resultados/graficos/taxa_transmissao.png")

plt.figure()
df['jitter'].plot()
plt.title("Jitter Estimado")
plt.xlabel("Pacotes")
plt.ylabel("Jitter (s)")
plt.grid()
plt.savefig("resultados/graficos/jitter.png")

# PSNR e SSIM
psnr_medio = None
ssim_medio = None

try:
    psnr_lines = open("resultados/psnr.log").readlines()
    psnr_values = [float(line.split("psnr_avg:")[1].split()[0]) for line in psnr_lines if "psnr_avg" in line]
    psnr_medio = sum(psnr_values) / len(psnr_values)
except:
    print("[WARN] Não foi possível calcular PSNR médio.")

try:
    ssim_lines = open("resultados/ssim.log").readlines()
    for line in reversed(ssim_lines):
        if "All:" in line:
            ssim_medio = float(line.split("All:")[1].split()[0])
            break
except:
    print("[WARN] Não foi possível calcular SSIM médio.")

# Exportar planilha com métricas resumidas
resumo = {
    "PSNR Médio": [psnr_medio],
    "SSIM Médio": [ssim_medio],
    "Jitter Médio": [df['jitter'].mean()],
    "Taxa Média (bps)": [bps_por_seg.mean()]
}

df_resumo = pd.DataFrame(resumo)
df_resumo.to_excel("resultados/metricas_resumo.xlsx", index=False)

print("[OK] Gráficos e planilha gerados em resultados/")
