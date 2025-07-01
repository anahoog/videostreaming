# Simulação de Videostreaming com OMNeT++ e INET

Este projeto realiza simulações de videostreaming utilizando o **OMNeT++ 6.1** e o **INET Framework 4.5**, com **tráfego real de vídeo transmitido via FFmpeg** por meio de interfaces **TAP**. O sistema coleta automaticamente capturas de rede e calcula métricas de qualidade de vídeo (QoS/QoE).

---

## Requisitos

- OMNeT++ 6.1 ([https://omnetpp.org](https://omnetpp.org))
- INET Framework 4.5 (em `samples/inet4.5`)
- Dependências do sistema:
  - `gcc`, `g++`, `clang`, `make`
  - `ffmpeg`, `tcpdump`, `tshark`, `moreutils`
  - Python 3.8+ com `pandas`, `numpy`, `tabulate` (para análise posterior)
- Interfaces TAP (`tapa`, `tapb`) previamente criadas com `setup.sh`

---

## Instalação e Compilação

```bash
# Acesse o diretório do OMNeT++
cd ~/Downloads/omnetpp-6.1

# Ative o ambiente
. setenv

# Clone o INET (caso não tenha)
cd samples
git clone https://github.com/inet-framework/inet.git inet4.5
cd inet4.5

# Ative novamente o ambiente OMNeT++
. ../../setenv

# Compile o INET
make makefiles
make -j$(nproc)
````

---

## Configuração das Interfaces TAP

Antes de rodar os testes, execute:

```bash
./setup.sh
```

> Isso criará as interfaces TAP `tapa` e `tapb` exigidas pelo cenário.

---

## Execução dos Cenários 

```bash
cd showcases/emulation/videostreaming

# Executa o cenário em modo texto

# Cenário sem erro e delay
./VideoStreamingShowcase -u Cmdenv -f omnetpp.ini -c General-01

# Cenário com taxa de erro de 5% e delay de 50ms
./VideoStreamingShowcase -u Cmdenv -f omnetpp.ini -c General-02

# Cenário com taxa de erro de 10% e delay de 50ms
./VideoStreamingShowcase -u Cmdenv -f omnetpp.ini -c General-03

# Cenário com taxa de erro de 5% e delay de 300ms
./VideoStreamingShowcase -u Cmdenv -f omnetpp.ini -c General-04

# Cenário com taxa de erro de 10% e delay de 300ms
./VideoStreamingShowcase -u Cmdenv -f omnetpp.ini -c General-05
```

> Use `-u Qtenv` para rodar com interface gráfica (GUI).

---

## Testes Automatizados com FFmpeg

O script `ffmpeg_coletas.sh` executa testes de streaming com coleta automática de pacotes e métricas de qualidade de vídeo.

### Sintaxe:

```bash
./ffmpeg_coletas.sh <PROTOCOLO>
```

* `PROTOCOLO`: `srt`, `rtp` ou `rtmp`

### O que o script faz:

1. Obtém a duração do vídeo automaticamente
2. Inicia a captura com `tcpdump`
3. Executa a transmissão e recepção com `ffmpeg`
4. Aguarda a recepção por 5 minutos
5. Calcula **PSNR** e **SSIM** com `calculate_metrics.sh`
6. Converte o `.pcap` para `.csv` com `tshark` conforme o protocolo

### Exemplo:

```bash
./ffmpeg_coletas.sh rtp
```

---

## Estrutura de Saída

Cada execução cria um diretório `capturas/<PROTO>_<TIMESTAMP>/` contendo:

* `ffmpeg_tx.log` — Log do transmissor FFmpeg
* `ffmpeg_rx.log` — Log do receptor FFmpeg
* `recebido_<PROTO>.ts` — Arquivo recebido
* `*_capture.pcap` — Captura bruta dos pacotes
* `*_capture.csv` — Captura convertida para CSV (via tshark)
* `psnr_<PROTO>.stats`, `ssim_<PROTO>.stats` — Métricas visuais
* `resultados_<PROTO>.csv` — Resultado consolidado

---

## Métricas Coletadas

### QoS

* Retransmissões (estimadas via tshark)
* Jitter médio
* Tempo de sessão (duração do tráfego)
* Taxa de perda estimada

### QoE (Indireta)

* **Playback Start Time**
* **Number of Interruptions**
* **Duration of Interruptions**
* **PSNR**
* **SSIM**

> O cálculo das métricas visuais é feito via `calculate_metrics.sh` comparando o vídeo original com o recebido.

---

## Ambiente Python (opcional)

Para análise posterior dos resultados:

```bash
python3 -m venv venv
source venv/bin/activate
pip install pandas numpy tabulate
```

---

## Observações

* O tráfego é gerado com `ffmpeg -re` para simular envio em tempo real.
* O modo `listener`/`caller` é usado para conexões SRT.
* O Nginx com módulo RTMP é requerido para testes `rtmp`. Certifique-se de que está instalado corretamente.
* O script `calculate_metrics.sh` usa `ffmpeg` com filtros de PSNR e SSIM.

---

## Referências

* [OMNeT++](https://omnetpp.org)
* [INET Framework](https://inet.omnetpp.org)
* [FFmpeg Filters](https://ffmpeg.org/ffmpeg-filters.html#ssim)
* [Wireshark/tshark](https://www.wireshark.org/docs/man-pages/tshark.html)




