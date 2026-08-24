#!/usr/bin/env bash
# Arranca el conversor de modelos 3D en Google Cloud Shell.
# Uso: ./arrancar.sh [puerto]

set -euo pipefail

PUERTO="${1:-8080}"
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$RAIZ"

echo "== Conversor de modelos 3D =={"
echo "Directorio: $RAIZ"
echo "Python: $(python3 --version)"

if [ ! -d .venv ]; then
  echo "Creando entorno virtual .venv"
  python3 -m venv .venv
fi
# shellcheck disable=SC1091
source .venv/bin/activate

echo "Instalando dependencias"
python -m pip install --quiet --upgrade pip
python -m pip install --quiet -r requirements.txt

echo "Ejecutando pruebas"
python -m unittest discover -s tests -t . 2>&1 | tail -n 3

export MC_DATA_DIR="${MC_DATA_DIR:-$HOME/model-converter-datos}"
export PORT="$PUERTO"
mkdir -p "$MC_DATA_DIR"

echo
echo "Servidor en el puerto $PUERTO. Datos en $MC_DATA_DIR"
echo "Abre la pagina con el boton Vista previa web de Cloud Shell (Web Preview),"
echo "eligiendo el puerto $PUERTO. Detener con Ctrl+C."
echo

exec python run.py
