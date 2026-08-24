"""Punto de entrada del servicio.

Se arranca siempre con este archivo, no con `python -m app.server`, para que la
raiz del proyecto quede en sys.path y los subprocesos del trabajador puedan
importar el paquete `app`.
"""

import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent
if str(RAIZ) not in sys.path:
    sys.path.insert(0, str(RAIZ))

from app.server import servir  # noqa: E402

if __name__ == "__main__":
    servir()
