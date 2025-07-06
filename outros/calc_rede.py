#!/usr/bin/env python3
import pandas as pd

# carrega CSV
df = pd.read_csv("capturas/srt_XXXX/srt_capture.csv")

# ordena por tempo
df = df.sort_values("time").reset_index(drop=True)

# sessão
tempo_sessao = df["time"].iloc[-1] - df["time"].iloc[0]

# interarrival times
df["iat"] = df["time"].diff()
jitter_medio = df["iat"].std()

# retransmissões (seq duplicados)
retransmissoes = df["seq"].duplicated().sum()

# perda estimada
expected = df["seq"].max() - df["seq"].min() + 1
recebidos = df["seq"].nunique()
perda = expected - recebidos
taxa_perda = perda / expected

# salva resultados
print(f"{retransmissoes},{tempo_sessao:.3f},{jitter_medio:.6f},{taxa_perda:.6f}")
