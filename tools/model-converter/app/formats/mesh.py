"""Estructuras de datos comunes a todos los formatos.

Una escena contiene mallas trianguladas, materiales e imagenes de textura. Los
lectores de cada formato devuelven siempre una escena con esta forma, y los
escritores consumen esa misma forma, de modo que cualquier formato de entrada
puede convertirse a cualquier formato de salida.
"""

from dataclasses import dataclass, field

import numpy as np


class ConversionError(Exception):
    """Error controlado durante la lectura, conversion o escritura."""


@dataclass
class Material:
    nombre: str
    color_base: tuple = (1.0, 1.0, 1.0, 1.0)
    metalicidad: float = 0.0
    rugosidad: float = 0.9
    textura: str = None  # clave dentro de Scene.imagenes


@dataclass
class Mesh:
    nombre: str
    posiciones: np.ndarray  # (n, 3) float32
    indices: np.ndarray  # (3 * t,) uint32
    normales: np.ndarray = None  # (n, 3) float32
    uv: np.ndarray = None  # (n, 2) float32, convenio glTF
    material: str = None  # clave dentro de Scene.materiales

    @property
    def numero_triangulos(self):
        return int(len(self.indices) // 3)


@dataclass
class Scene:
    mallas: list = field(default_factory=list)
    materiales: dict = field(default_factory=dict)
    imagenes: dict = field(default_factory=dict)  # nombre de archivo -> bytes


def triangulos_totales(escena):
    return int(sum(malla.numero_triangulos for malla in escena.mallas))


def caja_envolvente(escena):
    """Devuelve (minimo, maximo) como tuplas de tres flotantes."""
    puntos = [malla.posiciones for malla in escena.mallas if len(malla.posiciones)]
    if not puntos:
        return (0.0, 0.0, 0.0), (0.0, 0.0, 0.0)
    todos = np.concatenate(puntos, axis=0)
    return tuple(float(v) for v in todos.min(axis=0)), tuple(
        float(v) for v in todos.max(axis=0)
    )


def calcular_normales(malla):
    """Normales suavizadas por vertice, promediando las normales de cara."""
    posiciones = np.asarray(malla.posiciones, dtype=np.float64)
    indices = np.asarray(malla.indices, dtype=np.int64).reshape(-1, 3)
    normales = np.zeros_like(posiciones)
    if len(indices):
        a = posiciones[indices[:, 0]]
        b = posiciones[indices[:, 1]]
        c = posiciones[indices[:, 2]]
        caras = np.cross(b - a, c - a)
        for columna in range(3):
            np.add.at(normales, indices[:, columna], caras)
    longitudes = np.linalg.norm(normales, axis=1)
    longitudes[longitudes == 0.0] = 1.0
    return (normales / longitudes[:, None]).astype(np.float32)


def completar_normales(escena):
    """Rellena las normales que falten para no perder sombreado al convertir."""
    completadas = 0
    for malla in escena.mallas:
        if malla.normales is None or len(malla.normales) != len(malla.posiciones):
            malla.normales = calcular_normales(malla)
            completadas += 1
    return completadas


def validar(escena, maximo_triangulos=None):
    """Comprueba la coherencia de la escena y devuelve la lista de avisos."""
    avisos = []
    if not escena.mallas:
        raise ConversionError("El archivo no contiene ninguna malla legible.")
    for malla in escena.mallas:
        cantidad = len(malla.posiciones)
        if cantidad == 0:
            raise ConversionError("La malla " + str(malla.nombre) + " no tiene vertices.")
        if len(malla.indices) % 3 != 0:
            raise ConversionError(
                "La malla " + str(malla.nombre) + " no esta triangulada."
            )
        if len(malla.indices) and int(malla.indices.max()) >= cantidad:
            raise ConversionError(
                "La malla " + str(malla.nombre) + " tiene indices fuera de rango."
            )
        if malla.uv is None:
            avisos.append("La malla " + str(malla.nombre) + " no tiene coordenadas de textura.")
        if malla.material and malla.material not in escena.materiales:
            avisos.append(
                "La malla " + str(malla.nombre) + " apunta a un material inexistente."
            )
            malla.material = None
    total = triangulos_totales(escena)
    if maximo_triangulos and total > maximo_triangulos:
        raise ConversionError(
            "El modelo tiene "
            + str(total)
            + " triangulos y el limite configurado es "
            + str(maximo_triangulos)
            + "."
        )
    return avisos


def stats(escena):
    """Cifras de control que se guardan en info.json y se muestran en la web."""
    minimo, maximo = caja_envolvente(escena)
    sin_uv = sum(1 for malla in escena.mallas if malla.uv is None)
    return {
        "mallas": len(escena.mallas),
        "vertices": int(sum(len(malla.posiciones) for malla in escena.mallas)),
        "triangulos": triangulos_totales(escena),
        "materiales": len(escena.materiales),
        "texturas": len(escena.imagenes),
        "mallas_sin_uv": sin_uv,
        "caja_minima": [round(v, 6) for v in minimo],
        "caja_maxima": [round(v, 6) for v in maximo],
        "dimensiones": [round(maximo[i] - minimo[i], 6) for i in range(3)],
    }
