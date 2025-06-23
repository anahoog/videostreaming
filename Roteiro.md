# Roteiro de Testes – OMNeT++, RTMP, SRT, FFmpeg, VLC

Este roteiro documenta a execução de testes de transmissão de vídeo em tempo real usando OMNeT++ com INET, transmissões via RTMP, SRT e RTP, bem como as ferramentas FFmpeg, VLC e tcpdump.

---

## Passo a Passo Geral dos Testes

### 1. Iniciar a Simulação com OMNeT++
```bash
cd ~/Downloads/omnetpp-6.1
. setenv
cd samples/inet4.5/
. setenv
cd showcases/emulation/videostreaming/
./setup.sh
inet -u Cmdenv -f omnetpp.ini -c General-01
```

### 2. Iniciar o Servidor RTMP com Nginx
```bash
sudo systemctl start nginx
```

### 3. Transmitir Vídeo com FFmpeg via RTMP

#### a) Com codecs originais (sem recodificação)
```bash
ffmpeg -re -i RickAstley.mkv \
  -c:v libx264 -preset veryfast -b:v 2M \
  -c:a aac -ar 44100 -b:a 128k \
  -f flv "rtmp://192.168.2.20:1935/live/stream"

```

#### b) Com recodificação para H.264/AAC
```bash
ffmpeg -re -i videoplayback.mp4 \
  -c:v libx264 -preset veryfast -b:v 1024k \
  -c:a aac -b:a 128k \
  -f flv "rtmp://192.168.2.20:1935/live/stream"
```

### 4. Reproduzir o Stream RTMP
```bash
ffplay rtmp://192.168.2.20:1935/live/stream
vlc "rtmp://192.168.2.20:1935/live/stream"
```

### 5. Transmitir via SRT

#### a) Listener com FFmpeg
```bash
ffmpeg -re -i RickAstley.mkv \
  -c:v libx264 -preset veryfast -b:v 2M \
  -c:a aac -b:a 128k \
  -f mpegts "srt://192.168.2.20:4004?mode=listener&pkt_size=1316"
```

#### b) Cliente com VLC
```bash
vlc "srt://192.168.3.99:4004?mode=caller"
```

### 6. Transmitir via RTP
```bash
cvlc RickAstley.mkv --loop \
  --sout '#transcode{vcodec=h264,acodec=mp4a,vb=2048k,ab=64k,deinterlace,scale=1,threads=2}:rtp{mux=ts,dst=192.168.2.99,port=4004}'
```

### 7. Reproduzir RTP no Cliente
```bash
vlc rtp://192.168.3.20:4004
```

### 8. Capturar Pacotes para Análise
```bash
sudo tcpdump -i tapa -i tapb -w captura_tap.pcap
```

Ou separadamente:
```bash
sudo tcpdump -i tapa -w srt_tapa_capture.pcap
sudo tcpdump -i tapb -w srt_tapb_capture.pcap
sudo tcpdump -i tapa -w rtmp_tapa_capture.pcap
sudo tcpdump -i tapb -w rtmp_tapb_capture.pcap
```

### 9. Encerrar Processos
```bash
pkill ffmpeg
pkill vlc
sudo systemctl stop nginx
```

---

