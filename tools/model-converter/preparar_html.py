"""Prepara un HTML de three.js anadiendole botones de exportacion a GLB.

Uso:
    python preparar_html.py entrada.html [salida.html]

Si no se indica salida, se escribe <entrada>_exportable.html junto al original.
El archivo resultante se abre en el navegador y ofrece dos botones: uno exporta
solo el modelo y otro la escena completa. El GLB descargado ya se puede subir al
conversor.
"""

import sys
from pathlib import Path

from app.formats import html_navegador


def main(argumentos):
    if not argumentos or argumentos[0] in ("-h", "--help"):
        sys.stderr.write(__doc__)
        return 2
    entrada = Path(argumentos[0])
    if not entrada.is_file():
        sys.stderr.write("No existe el archivo " + str(entrada) + "\n")
        return 1
    if len(argumentos) > 1:
        salida = Path(argumentos[1])
    else:
        salida = entrada.with_name(entrada.stem + "_exportable.html")

    datos = entrada.read_bytes()
    texto = datos.decode("utf-8", "replace")
    if not html_navegador.es_pagina_procedural(texto):
        sys.stderr.write(
            "La pagina no parece construir la geometria con JavaScript. "
            "Prueba a subirla directamente al conversor.\n"
        )
        return 1

    try:
        preparada, nombre_escena = html_navegador.preparar(datos)
    except ValueError as error:
        sys.stderr.write(str(error) + "\n")
        return 1

    salida.write_bytes(preparada)
    print(
        "Escrito "
        + str(salida)
        + " ("
        + str(len(preparada))
        + " bytes, escena: "
        + str(nombre_escena)
        + ", three "
        + html_navegador.version_three(texto)
        + ")"
    )
    print("Abrelo en el navegador y pulsa Descargar GLB.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
