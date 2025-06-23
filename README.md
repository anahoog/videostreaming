
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

# Para escutar com o protocolo RTP e RTMP
./VideoStreamingShowcase -u Cmdenv -f omnetpp.ini -c General-03
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


