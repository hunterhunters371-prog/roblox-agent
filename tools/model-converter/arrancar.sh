#!/usr/bin/env bash
# Arranca el conversor de modelos 3D en Google Cloud Shell.
# Uso: ./arrancar.sh [puerto]

set -uo pipefail

PUERTO="${1:-8080}"
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$RAIZ"

echo "== Conversor de modelos 3D =="
echo "Directorio: $RAIZ"
echo "Python: $(python3 --version 2>&1)"

if [ ! -d .venv ]; then
  echo "Creando entorno virtual .venv"
  if ! python3 -m venv .venv; then
    echo "ERROR: no se pudo crear .venv. Instala python3-venv o revisa la version de Python."
    exit 1
  fi
fi
# shellcheck disable=SC1091
source .venv/bin/activate

echo "Instalando dependencias"
python -m pip install --quiet --upgrade pip
if ! python -m pip install --quiet -r requirements.txt; then
  echo "ERROR: fallo la instalacion de dependencias. Salida completa:"
  python -m pip install -r requirements.txt
  exit 1
fi

if [ "${MC_HEADLESS:-1}" != "0" ]; then
  echo "Instalando Chrome headless para HTML procedural (una sola vez, unos 2 minutos)"
  python -m playwright install chromium 2>&1 | tail -n 2 || \
    echo "AVISO: no se pudo instalar Chrome; los HTML con geometria por codigo devolveran la version exportable."
fi

echo "Ejecutando pruebas (no bloquean el arranque)"
python -m unittest discover -s tests -t . 2>&1 | tail -n 3 || true

export MC_DATA_DIR="${MC_DATA_DIR:-$HOME/model-converter-datos}"
export MC_HOST="${MC_HOST:-0.0.0.0}"
export PORT="$PUERTO"
mkdir -p "$MC_DATA_DIR"

if command -v ss >/dev/null 2>&1 && ss -ltn 2>/dev/null | grep -q ":$PUERTO "; then
  echo "AVISO: el puerto $PUERTO ya esta ocupado. Liberalo con: kill \$(lsof -t -i:$PUERTO)"
fi

echo
echo "Arrancando servidor en 0.0.0.0:$PUERTO. Datos en $MC_DATA_DIR"
python run.py &
SERVIDOR=$!

for _ in $(seq 1 30); do
  if curl -fsS "http://localhost:$PUERTO/api/health" >/dev/null 2>&1; then
    echo "Servidor respondiendo en http://localhost:$PUERTO/"
    echo "Abre la pagina con Vista previa web de Cloud Shell, puerto $PUERTO."
    break
  fi
  if ! kill -0 "$SERVIDOR" 2>/dev/null; then
    echo "ERROR: el servidor termino durante el arranque. Revisa el mensaje anterior."
    exit 1
  fi
  sleep 1
done

echo "Detener con Ctrl+C."
wait "$SERVIDOR"
