"""Lector de STL binario y ASCII, y escritor de STL binario.

STL no transporta materiales ni coordenadas de textura, asi que la escena
resultante tiene una sola malla sin UV.
"""

import struct

import numpy as np

from app.formats.mesh import ConversionError, Mesh, Scene


def _es_ascii(datos):
    if not datos[:5].lower().startswith(b"solid"):
        return False
    muestra = datos[:2048].lower()
    return b"facet" in muestra or b"endsolid" in muestra


def _leer_ascii(datos):
    texto = bytes(datos).decode("utf-8", "replace")
    posiciones = []
    normales_cara = []
    normal_actual = (0.0, 0.0, 1.0)
    for linea in texto.splitlines():
        partes = linea.split()
        if not partes:
            continue
        clave = partes[0].lower()
        if clave == "facet" and len(partes) >= 5:
            normal_actual = tuple(float(v) for v in partes[2:5])
        elif clave == "vertex" and len(partes) >= 4:
            posiciones.append([float(v) for v in partes[1:4]])
            normales_cara.append(normal_actual)
    if not posiciones or len(posiciones) % 3 != 0:
        raise ConversionError("El STL ASCII no contiene triangulos completos.")
    return np.array(posiciones, dtype=np.float32), np.array(
        normales_cara, dtype=np.float32
    )


def _leer_binario(datos):
    if len(datos) < 84:
        raise ConversionError("El STL binario es demasiado corto.")
    cantidad = struct.unpack("<I", datos[80:84])[0]
    esperado = 84 + cantidad * 50
    if len(datos) < esperado:
        raise ConversionError("El STL binario esta truncado.")
    bruto = np.frombuffer(datos[84:esperado], dtype=np.uint8).reshape(cantidad, 50)
    flotantes = np.ascontiguousarray(bruto[:, :48]).view("<f4").reshape(cantidad, 4, 3)
    normales = np.repeat(flotantes[:, 0, :], 3, axis=0)
    posiciones = flotantes[:, 1:, :].reshape(-1, 3)
    return posiciones.astype(np.float32), normales.astype(np.float32)


def read_stl(datos, nombre="malla"):
    datos = bytes(datos)
    if _es_ascii(datos):
        posiciones, normales = _leer_ascii(datos)
    else:
        posiciones, normales = _leer_binario(datos)
    malla = Mesh(
        nombre=nombre,
        posiciones=posiciones,
        indices=np.arange(len(posiciones), dtype=np.uint32),
        normales=normales,
        uv=None,
        material=None,
    )
    return Scene(mallas=[malla], materiales={}, imagenes={})


def write_stl(escena):
    """Escribe todas las mallas en un unico STL binario."""
    triangulos = []
    for malla in escena.mallas:
        posiciones = np.asarray(malla.posiciones, dtype=np.float32).reshape(-1, 3)
        indices = np.asarray(malla.indices, dtype=np.int64).reshape(-1, 3)
        for a, b, c in indices:
            triangulos.append((posiciones[a], posiciones[b], posiciones[c]))
    salida = bytearray(b"\x00" * 80)
    salida.extend(struct.pack("<I", len(triangulos)))
    for a, b, c in triangulos:
        normal = np.cross(b - a, c - a)
        longitud = float(np.linalg.norm(normal))
        if longitud:
            normal = normal / longitud
        salida.extend(struct.pack("<3f", *[float(v) for v in normal]))
        for punto in (a, b, c):
            salida.extend(struct.pack("<3f", *[float(v) for v in punto]))
        salida.extend(struct.pack("<H", 0))
    return bytes(salida)
