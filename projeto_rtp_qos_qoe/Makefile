
all: preparar enviar receber capturar analisar

preparar:
	mkdir -p logs capturas resultados resultados/graficos

enviar:
	bash scripts/enviar_rtp.sh &

receber:
	bash scripts/receber_rtp.sh &

capturar:
	sudo bash scripts/capturar_tcpdump.sh

psnr_ssim:
	bash scripts/calcular_psnr_ssim.sh

analisar:
	python3 scripts/analisar_metricas.py

clean:
	rm -rf logs/* capturas/* resultados/*
