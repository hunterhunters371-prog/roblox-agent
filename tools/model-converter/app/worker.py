"""Trabajador de un solo trabajo, ejecutado en un proceso aparte.

Aislar la conversion en un proceso permite imponer un limite de tiempo real y
evita que un archivo malformado tumbe el servidor web.

Uso: python -m app.worker <directorio del trabajo>
"""

import sys
import time
import traceback
from pathlib import Path

from app import convert, storage


def ejecutar(directorio):
    directorio = Path(directorio)
    estado = storage.leer_estado(directorio)
    entrada = directorio / "entrada" / estado["archivo"]
    storage.registrar(directorio, "Inicio de la conversion")
    storage.actualizar_estado(
        directorio, estado="procesando", inicio_proceso=time.time(), error=None
    )
    try:
        info = convert.convertir(
            entrada,
            directorio / "salida",
            salidas=estado.get("salidas"),
            registrar=lambda mensaje: storage.registrar(directorio, mensaje),
        )
    except Exception as error:  # noqa: BLE001
        storage.registrar(directorio, "ERROR: " + str(error))
        storage.registrar(directorio, traceback.format_exc())
        storage.actualizar_estado(
            directorio, estado="fallido", error=str(error), fin=time.time()
        )
        return 1
    storage.actualizar_estado(
        directorio,
        estado="completado",
        info=info,
        archivos=storage.listar_salidas(directorio),
        fin=time.time(),
        error=None,
    )
    storage.registrar(directorio, "Conversion completada")
    return 0


def main(argumentos):
    if len(argumentos) != 1:
        sys.stderr.write("Uso: python -m app.worker <directorio del trabajo>\n")
        return 2
    return ejecutar(argumentos[0])


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
