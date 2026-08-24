#!/usr/bin/env bash
# Clona (o actualiza) el repositorio y arranca el conversor de modelos 3D.
# Uso desde Cloud Shell:
#   bash <(curl -fsSL https://raw.githubusercontent.com/hunterhunters371-prog/roblox-agent/main/tools/model-converter/instalar.sh)

set -euo pipefail

REPO="https://github.com/hunterhunters371-prog/roblox-agent.git"
RAMA="main"
DESTINO="${MC_DESTINO:-$HOME/roblox-agent}"
PUERTO="${1:-8080}"

if [ -d "$DESTINO/.git" ]; then
  echo "Actualizando $DESTINO"
  git -C "$DESTINO" fetch --depth 1 origin "$RAMA"
  git -C "$DESTINO" reset --hard "origin/$RAMA"
else
  echo "Clonando en $DESTINO"
  git clone --depth 1 --branch "$RAMA" "$REPO" "$DESTINO"
fi

cd "$DESTINO/tools/model-converter"
chmod +x arrancar.sh
exec ./arrancar.sh "$PUERTO"
