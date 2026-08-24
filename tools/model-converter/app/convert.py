"""Nucleo de la conversion: deteccion de formato, extraccion y escritura.

Aqui vive la extraccion de modelos y de texturas. Es el punto de entrada que
usan tanto el trabajador del servicio como las pruebas.
"""

import json
import time
import zipfile
from pathlib import Path

from app import config, preview
from app.formats import (
    gltf,
    html as formato_html,
    html_navegador,
    obj as formato_obj,
    ply as formato_ply,
    stl as formato_stl,
)
from app.formats.mesh import (
    ConversionError,
    completar_normales,
    stats,
    validar,
)

_PRIORIDAD = [
    ".glb",
    ".gltf",
    ".obj",
    ".stl",
    ".ply",
    ".dae",
    ".off",
    ".3mf",
    ".xyz",
    ".html",
    ".htm",
]


def _sin_registro(mensaje):
    return None


def extraer_zip(ruta_zip, destino, registrar=_sin_registro):
    """Extrae un ZIP saneando rutas para evitar escrituras fuera del destino."""
    destino = Path(destino)
    destino.mkdir(parents=True, exist_ok=True)
    extraidos = []
    with zipfile.ZipFile(ruta_zip) as paquete:
        entradas = paquete.infolist()
        if len(entradas) > config.MAX_ZIP_ENTRIES:
            raise ConversionError(
                "El ZIP tiene "
                + str(len(entradas))
                + " entradas y el limite es "
                + str(config.MAX_ZIP_ENTRIES)
                + "."
            )
        total = sum(int(entrada.file_size) for entrada in entradas)
        if total > config.MAX_ZIP_MB * 1024 * 1024:
            raise ConversionError(
                "El ZIP descomprimido ocupa mas de "
                + str(config.MAX_ZIP_MB)
                + " MB."
            )
        for entrada in entradas:
            if entrada.is_dir():
                continue
            nombre = entrada.filename.replace("\\", "/")
            partes = [p for p in nombre.split("/") if p not in ("", ".", "..")]
            if not partes:
                registrar("Entrada ignorada por ruta insegura: " + entrada.filename)
                continue
            archivo = destino.joinpath(*partes)
            archivo.parent.mkdir(parents=True, exist_ok=True)
            with paquete.open(entrada) as origen, open(archivo, "wb") as salida:
                salida.write(origen.read())
            extraidos.append(archivo)
    if not extraidos:
        raise ConversionError("El ZIP no contiene archivos utilizables.")
    registrar("ZIP extraido: " + str(len(extraidos)) + " archivos")
    return extraidos


def elegir_modelo(archivos):
    """Escoge el archivo de modelo principal dentro de un paquete extraido."""
    aceptadas = config.extensiones_entrada() - {".zip"}
    candidatos = [Path(a) for a in archivos if Path(a).suffix.lower() in aceptadas]
    if not candidatos:
        raise ConversionError(
            "El paquete no contiene ningun modelo con extension soportada."
        )
    def clave(ruta):
        extension = ruta.suffix.lower()
        posicion = _PRIORIDAD.index(extension) if extension in _PRIORIDAD else len(_PRIORIDAD)
        return (posicion, len(ruta.parts), ruta.name.lower())
    candidatos.sort(key=clave)
    return candidatos[0]


def _cargar_trimesh(ruta):
    try:
        import numpy as np
        import trimesh
    except Exception:
        raise ConversionError(
            "El formato " + ruta.suffix + " necesita el backend opcional trimesh."
        )
    from app.formats.mesh import Mesh, Scene

    cargado = trimesh.load(str(ruta), force="scene")
    escena = Scene(mallas=[], materiales={}, imagenes={})
    geometrias = getattr(cargado, "geometry", None) or {"malla": cargado}
    for nombre, geometria in geometrias.items():
        caras = getattr(geometria, "faces", None)
        if caras is None or len(caras) == 0:
            continue
        escena.mallas.append(
            Mesh(
                nombre=str(nombre),
                posiciones=np.asarray(geometria.vertices, dtype=np.float32),
                indices=np.asarray(caras, dtype=np.uint32).reshape(-1),
                normales=None,
                uv=None,
                material=None,
            )
        )
    if not escena.mallas:
        raise ConversionError("trimesh no encontro mallas en el archivo.")
    return escena


def cargar_escena(ruta, registrar=_sin_registro):
    """Lee un archivo de modelo y devuelve la escena interna."""
    ruta = Path(ruta)
    extension = ruta.suffix.lower()
    datos = ruta.read_bytes()
    registrar("Leyendo " + ruta.name + " (" + str(len(datos)) + " bytes, " + extension + ")")
    if extension == ".glb":
        return gltf.read_gltf(datos, base=ruta.parent, formato="glb")
    if extension == ".gltf":
        return gltf.read_gltf(datos, base=ruta.parent, formato="gltf")
    if extension == ".obj":
        return formato_obj.read_obj(datos, base=ruta.parent)
    if extension == ".stl":
        return formato_stl.read_stl(datos, nombre=ruta.stem)
    if extension == ".ply":
        return formato_ply.read_ply(datos, nombre=ruta.stem)
    if extension in (".html", ".htm"):
        incrustado, extension_real, origen = formato_html.extraer_modelo(
            datos, base=ruta.parent
        )
        registrar(
            "Modelo incrustado en HTML ("
            + origen
            + ") -> "
            + extension_real
            + ", "
            + str(len(incrustado))
            + " bytes"
        )
        destino = ruta.parent / (ruta.stem + "_incrustado" + extension_real)
        destino.write_bytes(incrustado)
        if extension_real == ".zip":
            extraidos = extraer_zip(destino, ruta.parent / "html_paquete", registrar)
            destino = elegir_modelo(extraidos)
        return cargar_escena(destino, registrar)
    return _cargar_trimesh(ruta)


def _preparar_html_procedural(origen, directorio_salida, registrar, inicio):
    """Si la pagina genera la geometria con JavaScript, devuelve la version
    exportable en vez de fallar. Devuelve None cuando no aplica.
    """
    datos = origen.read_bytes()
    try:
        formato_html.extraer_modelo(datos, base=origen.parent)
        return None
    except ConversionError:
        pass

    texto = datos.decode("utf-8", "replace")
    if not html_navegador.es_pagina_procedural(texto):
        return None

    preparada, nombre_escena = html_navegador.preparar(datos)
    nombre = origen.stem + "_exportable.html"
    (directorio_salida / nombre).write_bytes(preparada)
    registrar(
        "La pagina construye la geometria con JavaScript (escena: "
        + str(nombre_escena)
        + "). No hay modelo dentro del archivo."
    )
    registrar(
        "Preparado "
        + nombre
        + " ("
        + str(len(preparada))
        + " bytes): abrelo en el navegador y pulsa Descargar GLB."
    )

    info = {
        "nombre_entrada": origen.name,
        "modelo_leido": origen.name,
        "formato_entrada": origen.suffix.lower().lstrip("."),
        "requiere_navegador": True,
        "escena_detectada": nombre_escena,
        "version_three": html_navegador.version_three(texto),
        "salidas": [],
        "geometria": {
            "mallas": 0,
            "vertices": 0,
            "triangulos": 0,
            "materiales": 0,
            "texturas": 0,
        },
        "texturas": [],
        "materiales": [],
        "vista_previa": {"generada": False, "motivo": "requiere navegador"},
        "avisos": [
            "La geometria solo existe cuando el navegador ejecuta el codigo, "
            "asi que no se puede extraer en el servidor.",
            "Descarga "
            + nombre
            + ", abrelo en el navegador y pulsa Descargar GLB.",
            "Sube ese modelo.glb aqui para obtener GLB, OBJ y el paquete.",
        ],
        "paso_siguiente": nombre,
        "segundos": round(time.time() - inicio, 3),
        "version": __import__("app").__version__,
    }
    (directorio_salida / "info.json").write_text(
        json.dumps(info, ensure_ascii=False, indent=2), "utf-8"
    )
    info["archivos"] = sorted(
        p.name for p in directorio_salida.iterdir() if p.is_file()
    )
    return info


def convertir(ruta_entrada, directorio_salida, salidas=None, registrar=None):
    """Convierte un modelo y escribe todas las salidas pedidas.

    Devuelve el diccionario que tambien se guarda como info.json.
    """
    registrar = registrar or _sin_registro
    inicio = time.time()
    ruta_entrada = Path(ruta_entrada)
    directorio_salida = Path(directorio_salida)
    directorio_salida.mkdir(parents=True, exist_ok=True)
    salidas = [s for s in (salidas or config.SALIDAS_VALIDAS) if s in config.SALIDAS_VALIDAS]
    if not salidas:
        raise ConversionError("No se ha pedido ninguna salida valida.")

    origen = ruta_entrada
    if ruta_entrada.suffix.lower() == ".zip":
        extraidos = extraer_zip(
            ruta_entrada, ruta_entrada.parent / "paquete", registrar
        )
        origen = elegir_modelo(extraidos)
        registrar("Modelo principal del paquete: " + origen.name)

    if origen.suffix.lower() in (".html", ".htm"):
        preparado = _preparar_html_procedural(
            origen, directorio_salida, registrar, inicio
        )
        if preparado is not None:
            return preparado

    escena = cargar_escena(origen, registrar)
    completadas = completar_normales(escena)
    if completadas:
        registrar("Normales calculadas para " + str(completadas) + " mallas")
    avisos = validar(escena, config.MAX_TRIANGLES)
    for aviso in avisos:
        registrar("Aviso: " + aviso)

    nombre_base = origen.stem or "modelo"
    cifras = stats(escena)
    registrar(
        "Geometria: "
        + str(cifras["mallas"])
        + " mallas, "
        + str(cifras["vertices"])
        + " vertices, "
        + str(cifras["triangulos"])
        + " triangulos, "
        + str(cifras["materiales"])
        + " materiales, "
        + str(cifras["texturas"])
        + " texturas"
    )

    generados = []

    def _escribir(nombre, datos):
        destino = directorio_salida / nombre
        destino.write_bytes(datos)
        generados.append(nombre)
        registrar("Escrito " + nombre + " (" + str(len(datos)) + " bytes)")
        return destino

    if "glb" in salidas or "zip" in salidas:
        _escribir(nombre_base + ".glb", gltf.write_glb(escena))
    if "obj" in salidas or "zip" in salidas:
        for nombre, datos in formato_obj.write_obj(escena, nombre_base).items():
            _escribir(nombre, datos)
    elif escena.imagenes:
        for nombre, datos in escena.imagenes.items():
            _escribir(nombre, datos)

    metricas_vista = {"generada": False, "motivo": "desactivada"}
    if config.PREVIEW:
        imagen, metricas_vista = preview.renderizar(escena)
        if imagen:
            _escribir("vista_previa.png", imagen)
        else:
            registrar("Vista previa omitida: " + str(metricas_vista.get("motivo")))

    info = {
        "nombre_entrada": ruta_entrada.name,
        "modelo_leido": origen.name,
        "formato_entrada": origen.suffix.lower().lstrip("."),
        "salidas": salidas,
        "geometria": cifras,
        "texturas": sorted(escena.imagenes.keys()),
        "materiales": sorted(escena.materiales.keys()),
        "vista_previa": metricas_vista,
        "avisos": avisos,
        "segundos": round(time.time() - inicio, 3),
        "version": __import__("app").__version__,
    }
    _escribir("info.json", json.dumps(info, ensure_ascii=False, indent=2).encode("utf-8"))

    if "zip" in salidas:
        nombre_zip = nombre_base + "_convertido.zip"
        destino_zip = directorio_salida / nombre_zip
        with zipfile.ZipFile(destino_zip, "w", zipfile.ZIP_DEFLATED) as paquete:
            for nombre in generados:
                paquete.write(directorio_salida / nombre, nombre)
        registrar(
            "Empaquetado "
            + nombre_zip
            + " ("
            + str(destino_zip.stat().st_size)
            + " bytes, "
            + str(len(generados))
            + " archivos)"
        )
        info["paquete"] = nombre_zip
        (directorio_salida / "info.json").write_text(
            json.dumps(info, ensure_ascii=False, indent=2), "utf-8"
        )

    info["archivos"] = sorted(p.name for p in directorio_salida.iterdir() if p.is_file())
    return info
