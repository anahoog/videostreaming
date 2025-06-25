
# Simulação de Videostreaming com OMNeT++ e INET

Este projeto executa cenários de simulação de videostreaming utilizando o **OMNeT++ 6.1** e o **INET Framework 4.5**, com geração e recepção de tráfego real usando VLC e FFmpeg por meio de interfaces TAP.

---

## Requisitos

- OMNeT++ 6.1 ([https://omnetpp.org](https://omnetpp.org))
- INET 4.5 (clonado em `samples/inet4.5`)
- `make`, `gcc/g++`, `clang`, `ffmpeg`, `vlc`, `tcpdump`, `moreutils`
- Interfaces TAP criadas (`tapa`, `tapb`)

---

## Instalação e Compilação

```bash
# Acesse o diretório do OMNeT++
cd ~/Downloads/omnetpp-6.1

# Ative o ambiente
. setenv

# Clone o INET, se ainda não estiver presente
cd samples
git clone https://github.com/inet-framework/inet.git inet4.5
cd inet4.5

# Ative o ambiente do INET
. ../../setenv

# Compile o INET
make makefiles
make -j$(nproc)
````

---
## Configuração das Interfaces TAP

Antes de rodar o cenário, certifique-se de criar as interfaces:

```bash
./setup.sh
```

---

## Execução do Cenário `General-01`

```bash
cd showcases/emulation/videostreaming

# Para escutar com o protocolo SRT
./VideoStreamingShowcase -u Cmdenv -f omnetpp.ini -c General-01

```

> Use `-u Qtenv` para abrir com interface gráfica (GUI).

---



## Estrutura de Arquivos

* `omnetpp.ini` — configurações dos cenários
* `*.ned` — topologia da rede
* `VideoStreamingShowcase` — binário da simulação
* `automated_srt_test.sh`, `automated_rtp_test.sh`, `automated_rtmp_test.sh`

---

## Métricas Avaliadas

* **Playback Start Time**
* **Number of Interruptions**
* **Duration of Interruptions**
* **Throughput médio**
* **Jitter estimado**

---

## Coleta de Métricas QoE/QoS

Este projeto inclui o script `coletar_metricas.py`, que realiza a coleta automatizada de métricas de desempenho e experiência de vídeo para os protocolos **RTMP**, **RTP** e **SRT**.

### Métricas coletadas

- Retransmissões  
- Tempo total de sessão (s)  
- Jitter médio (s)  
- Playback Start Time (s)  
- Duration of Interruptions (s)  
- Number of Interruptions  
- Eventos de Buffering (detectados via log do VLC)  
- Taxa de Perda Estimada  
- Nome dos arquivos de origem (CSV, log)

###  Requisitos

Certifique-se de ter o Python ≥ 3.8 e instale as dependências com:

```bash
pip install pandas numpy tabulate

```


Se estiver em um sistema com gerenciamento externo de pacotes (como Ubuntu), recomenda-se criar um ambiente virtual:

```bash
python3 -m venv venv
source venv/bin/activate
pip install pandas numpy tabulate
```

### Como executar

Execute o script apontando para a pasta onde estão os arquivos `.csv` e `vlc_*.log`:

```bash
python3 coletar.py -d /caminho/para/os/arquivos -o resultado.csv
```

* `-d`: Diretório onde estão os arquivos de captura e logs (padrão: diretório atual).
* `-o`: Nome do arquivo CSV de saída com os resultados.

### Exemplo de arquivos esperados

Na pasta informada via `-d`, espera-se encontrar:

* Arquivos CSV com nomes como:

  * `rtmp.csv`
  * `rtp.csv`
  * `srt.csv`
* Arquivos de log VLC com nomes como:

  * `vlc_rtmp.log`
  * `vlc_rtp.log`
  * `vlc_srt.log`

```

Se quiser também a versão para colar diretamente no Overleaf em LaTeX, posso converter para você. Deseja?
```
