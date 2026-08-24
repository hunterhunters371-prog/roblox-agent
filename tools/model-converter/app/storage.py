"""Almacenamiento en disco de los trabajos de conversion.

Cada trabajo vive en su propio directorio, con la entrada, la salida, el estado
y la bitacora separados. Todos los nombres de archivo que llegan del exterior
se sanean antes de tocar el sistema de archivos.
"""

import json
import os
import re
import shutil
import time
import uuid
from pathlib import Path

from app import config

_ID_VALIDO = re.compile(r"^[0-9a-f]{32}$")
_CARACTER_PROHIBIDO = re.compile(r"[^A-Za-z0-9._\- ]")


class TrabajoNoEncontrado(Exception):
    """El identificador no corresponde a ningun trabajo existente."""


def nombre_seguro(nombre, defecto="modelo"):
    """Reduce un nombre de archivo a su parte final saneada."""
    nombre = (nombre or "").replace("\\", "/").split("/")[-1].strip()
    nombre = _CARACTER_PROHIBIDO.sub("_", nombre)
    nombre = nombre.lstrip(".").strip()
    if not nombre:
        return defecto
    return nombre[:120]


def _raiz():
    config.JOBS_DIR.mkdir(parents=True, exist_ok=True)
    return config.JOBS_DIR


def crear_trabajo():
    identificador = uuid.uuid4().hex
    directorio = _raiz() / identificador
    (directorio / "entrada").mkdir(parents=True, exist_ok=True)
    (directorio / "salida").mkdir(parents=True, exist_ok=True)
    return identificador, directorio


def directorio_trabajo(identificador):
    if not _ID_VALIDO.match(identificador or ""):
        raise TrabajoNoEncontrado("Identificador de trabajo con formato invalido")
    directorio = _raiz() / identificador
    if not directorio.is_dir():
        raise TrabajoNoEncontrado("Trabajo no encontrado")
    return directorio


def ruta_descarga(identificador, nombre):
    """Resuelve un archivo de salida comprobando que no escapa del trabajo."""
    directorio = directorio_trabajo(identificador) / "salida"
    candidato = (directorio / nombre_seguro(nombre)).resolve()
    raiz = directorio.resolve()
    if raiz not in candidato.parents and candidato != raiz:
        raise TrabajoNoEncontrado("Ruta fuera del directorio del trabajo")
    if not candidato.is_file():
        raise TrabajoNoEncontrado("Archivo no encontrado")
    return candidato


def escribir_estado(directorio, estado):
    """Escritura atomica: primero temporal, despues os.replace."""
    destino = Path(directorio) / "estado.json"
    temporal = destino.with_suffix(".json.tmp")
    temporal.write_text(json.dumps(estado, ensure_ascii=False, indent=2), "utf-8")
    os.replace(temporal, destino)
    return estado


def leer_estado(directorio):
    destino = Path(directorio) / "estado.json"
    if not destino.is_file():
        raise TrabajoNoEncontrado("El trabajo no tiene estado")
    return json.loads(destino.read_text("utf-8"))


def actualizar_estado(directorio, **campos):
    estado = leer_estado(directorio)
    estado.update(campos)
    estado["actualizado"] = time.time()
    return escribir_estado(directorio, estado)


def registrar(directorio, mensaje):
    """Anade una linea con marca de tiempo a la bitacora del trabajo."""
    linea = time.strftime("%Y-%m-%d %H:%M:%S") + "  " + str(mensaje) + "\n"
    with open(Path(directorio) / "registro.txt", "a", encoding="utf-8") as archivo:
        archivo.write(linea)


def leer_registro(directorio):
    destino = Path(directorio) / "registro.txt"
    if not destino.is_file():
        return ""
    return destino.read_text("utf-8")


def listar_salidas(directorio):
    salida = Path(directorio) / "salida"
    if not salida.is_dir():
        return []
    archivos = []
    for ruta in sorted(salida.iterdir()):
        if ruta.is_file():
            archivos.append({"nombre": ruta.name, "bytes": ruta.stat().st_size})
    return archivos


def listar_trabajos(limite=25):
    raiz = _raiz()
    directorios = [d for d in raiz.iterdir() if d.is_dir() and _ID_VALIDO.match(d.name)]
    directorios.sort(key=lambda d: d.stat().st_mtime, reverse=True)
    trabajos = []
    for directorio in directorios[:limite]:
        try:
            trabajos.append(leer_estado(directorio))
        except Exception:
            continue
    return trabajos


def borrar_trabajo(identificador):
    directorio = directorio_trabajo(identificador)
    shutil.rmtree(directorio, ignore_errors=True)
    return identificador


def limpiar_expirados(horas=None):
    """Borra los trabajos mas antiguos que la caducidad configurada."""
    horas = config.JOB_TTL_HOURS if horas is None else horas
    if horas <= 0:
        return 0
    limite = time.time() - horas * 3600.0
    borrados = 0
    raiz = _raiz()
    for directorio in list(raiz.iterdir()):
        if not directorio.is_dir() or not _ID_VALIDO.match(directorio.name):
            continue
        if directorio.stat().st_mtime < limite:
            shutil.rmtree(directorio, ignore_errors=True)
            borrados += 1
    return borrados
