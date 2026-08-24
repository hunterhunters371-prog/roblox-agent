"""Extraccion del modelo 3D incrustado en un archivo HTML.

Las IA generativas suelen entregar el modelo dentro de una pagina HTML con un
visor. El modelo puede venir de cuatro maneras, y aqui se cubren todas:

1. URI de datos en base64, por ejemplo `src="data:model/gltf-binary;base64,..."`.
2. JSON glTF dentro de una etiqueta `<script>`.
3. Texto OBJ o PLY incrustado en una etiqueta `<script>` o `<template>`.
4. Referencia a un archivo vecino, util cuando el HTML llega dentro de un ZIP.

Se devuelven los bytes del modelo y su extension real, para que el resto del
conversor lo trate como cualquier otro archivo de entrada.
"""

import base64
import binascii
import re
from pathlib import Path

from app.formats.mesh import ConversionError

_MIME_EXT = {
    "model/gltf-binary": ".glb",
    "model/gltf+json": ".gltf",
    "model/obj": ".obj",
    "model/stl": ".stl",
    "application/sla": ".stl",
    "model/ply": ".ply",
    "application/zip": ".zip",
}

_DATA_URI = re.compile(
    r"data:(?P<mime>[A-Za-z0-9.+/_-]*)[^,\"']*?base64,(?P<carga>[A-Za-z0-9+/=\s]{100,})",
    re.DOTALL,
)
_SCRIPT = re.compile(
    r"<(?:script|template)\b(?P<atributos>[^>]*)>(?P<cuerpo>.*?)</(?:script|template)\s*>",
    re.IGNORECASE | re.DOTALL,
)
_TIPO = re.compile(r"type\s*=\s*[\"']([^\"']+)[\"']", re.IGNORECASE)
_REFERENCIA = re.compile(
    r"[\"']([^\"'?#<>]+\.(?:glb|gltf|obj|stl|ply|dae|off|3mf|xyz|zip))[\"']",
    re.IGNORECASE,
)
_LINEA_V = re.compile(r"(?m)^\s*v\s+-?\d")
_LINEA_F = re.compile(r"(?m)^\s*f\s+\S")


def _detectar(datos):
    """Deduce la extension real de unos bytes de modelo, o None."""
    if not datos:
        return None
    if datos[:4] == b"glTF":
        return ".glb"
    if datos[:2] == b"PK":
        return ".zip"
    cabecera = datos[:8192].decode("utf-8", "ignore")
    limpio = cabecera.lstrip()
    if limpio.startswith("{") and '"asset"' in cabecera:
        return ".gltf"
    if limpio.startswith("ply"):
        return ".ply"
    if limpio.startswith("solid") and "facet" in cabecera:
        return ".stl"
    if _LINEA_V.search(cabecera) and _LINEA_F.search(cabecera):
        return ".obj"
    if len(datos) > 84 and (len(datos) - 84) % 50 == 0:
        return ".stl"
    return None


def _decodificar(carga):
    limpio = re.sub(r"\s+", "", carga)
    relleno = len(limpio) % 4
    if relleno:
        limpio += "=" * (4 - relleno)
    try:
        return base64.b64decode(limpio, validate=False)
    except (binascii.Error, ValueError):
        return b""


def _de_uris(texto):
    for coincidencia in _DATA_URI.finditer(texto):
        datos = _decodificar(coincidencia.group("carga"))
        if len(datos) < 32:
            continue
        mime = (coincidencia.group("mime") or "").lower()
        extension = _detectar(datos) or _MIME_EXT.get(mime)
        if extension:
            return datos, extension, "URI de datos " + (mime or "sin mime")
    return None


def _de_scripts(texto):
    for coincidencia in _SCRIPT.finditer(texto):
        cuerpo = coincidencia.group("cuerpo").strip()
        if len(cuerpo) < 32:
            continue
        tipo = _TIPO.search(coincidencia.group("atributos") or "")
        tipo = (tipo.group(1).lower() if tipo else "")
        if tipo in ("", "text/javascript", "module", "application/javascript"):
            if '"asset"' not in cuerpo and not _LINEA_F.search(cuerpo):
                continue
        datos = cuerpo.encode("utf-8")
        extension = _MIME_EXT.get(tipo) or _detectar(datos)
        if extension:
            return datos, extension, "etiqueta script " + (tipo or "sin tipo")
    return None


def _de_referencias(texto, base):
    if base is None:
        return None
    base = Path(base)
    for coincidencia in _REFERENCIA.finditer(texto):
        referencia = coincidencia.group(1).replace("\\", "/")
        partes = [p for p in referencia.split("/") if p not in ("", ".", "..")]
        if not partes:
            continue
        candidatos = [base.joinpath(*partes)]
        candidatos.extend(base.rglob(partes[-1]))
        for candidato in candidatos:
            if candidato.is_file():
                datos = candidato.read_bytes()
                extension = candidato.suffix.lower()
                return datos, extension, "archivo vecino " + candidato.name
    return None


def extraer_modelo(datos, base=None):
    """Devuelve (bytes del modelo, extension, descripcion del origen)."""
    if isinstance(datos, (bytes, bytearray)):
        texto = bytes(datos).decode("utf-8", "replace")
    else:
        texto = str(datos)
    for buscador in (_de_uris(texto), _de_scripts(texto), _de_referencias(texto, base)):
        if buscador:
            return buscador
    raise ConversionError(
        "El HTML no contiene ningun modelo 3D recuperable. Se buscan URI de datos "
        "en base64, JSON glTF incrustado, texto OBJ o PLY incrustado y referencias "
        "a archivos vecinos. Si la pagina construye la geometria con codigo "
        "JavaScript (por ejemplo BoxGeometry de three.js), exporta el modelo a GLB "
        "desde el visor y sube ese archivo."
    )
