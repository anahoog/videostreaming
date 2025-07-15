#!/bin/bash

# Caminho base do projeto INET
INET_DIR="$HOME/Downloads/omnetpp-6.1/samples/inet4.5"

echo "[INFO] Aplicando correções para FFmpeg >= 5..."

# Substituir avcodec_close() por avcodec_free_context()
sed -i 's/avcodec_close(\([^)]*\))/avcodec_free_context(&\1)/g' \
  "$INET_DIR/src/inet/applications/voipstream/AudioOutFile.cc" \
  "$INET_DIR/src/inet/applications/voipstream/VoipStreamSender.cc" \
  "$INET_DIR/src/inet/applications/voipstream/VoipStreamReceiver.cc"

echo "[INFO] Verificando inclusão do cabeçalho <libavcodec/avcodec.h>..."

# Garantir que <libavcodec/avcodec.h> esteja incluso (se não estiver)
for file in \
  "$INET_DIR/src/inet/applications/voipstream/AudioOutFile.cc" \
  "$INET_DIR/src/inet/applications/voipstream/VoipStreamSender.cc" \
  "$INET_DIR/src/inet/applications/voipstream/VoipStreamReceiver.cc"
do
  if ! grep -q "libavcodec/avcodec.h" "$file"; then
    echo '[INFO] Inserindo cabeçalho em:' "$file"
    sed -i '1i\
extern "C" {\n#include <libavcodec/avcodec.h>\n}\n' "$file"
  fi
done

echo "[INFO] Correções aplicadas. Agora você pode recompilar com:"
echo "  cd $INET_DIR"
echo "  make clean && make makefiles && make -j$(nproc)"
