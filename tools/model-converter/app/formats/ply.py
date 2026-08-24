"""Lector de PLY en ASCII y binario, little endian y big endian."""

import numpy as np

from app.formats.mesh import ConversionError, Mesh, Scene

_TIPOS = {
    "char": "i1",
    "int8": "i1",
    "uchar": "u1",
    "uint8": "u1",
    "short": "i2",
    "int16": "i2",
    "ushort": "u2",
    "uint16": "u2",
    "int": "i4",
    "int32": "i4",
    "uint": "u4",
    "uint32": "u4",
    "float": "f4",
    "float32": "f4",
    "double": "f8",
    "float64": "f8",
}


def _cabecera(datos):
    fin = datos.find(b"end_header")
    if fin < 0:
        raise ConversionError("El PLY no tiene cabecera valida.")
    salto = datos.find(b"\n", fin)
    texto = datos[:salto].decode("ascii", "replace")
    return texto.splitlines(), salto + 1


def read_ply(datos, nombre="malla"):
    datos = bytes(datos)
    lineas, inicio = _cabecera(datos)
    formato = "ascii"
    elementos = []
    for linea in lineas:
        partes = linea.split()
        if not partes:
            continue
        if partes[0] == "format" and len(partes) >= 2:
            formato = partes[1]
        elif partes[0] == "element" and len(partes) >= 3:
            elementos.append({"nombre": partes[1], "cuenta": int(partes[2]), "props": []})
        elif partes[0] == "property" and elementos:
            if partes[1] == "list" and len(partes) >= 5:
                elementos[-1]["props"].append(
                    {"lista": True, "conteo": partes[2], "tipo": partes[3], "nombre": partes[4]}
                )
            elif len(partes) >= 3:
                elementos[-1]["props"].append(
                    {"lista": False, "tipo": partes[1], "nombre": partes[2]}
                )

    vertices = []
    caras = []
    if formato == "ascii":
        cuerpo = datos[inicio:].decode("ascii", "replace").split()
        cursor = 0
        for elemento in elementos:
            for _ in range(elemento["cuenta"]):
                if elemento["nombre"] == "vertex":
                    fila = {}
                    for propiedad in elemento["props"]:
                        fila[propiedad["nombre"]] = float(cuerpo[cursor])
                        cursor += 1
                    vertices.append(fila)
                elif elemento["nombre"] == "face":
                    for propiedad in elemento["props"]:
                        if propiedad["lista"]:
                            cantidad = int(float(cuerpo[cursor]))
                            cursor += 1
                            indices = [int(float(v)) for v in cuerpo[cursor : cursor + cantidad]]
                            cursor += cantidad
                            caras.append(indices)
                        else:
                            cursor += 1
                else:
                    cursor += len(elemento["props"])
    else:
        orden = "<" if "little" in formato else ">"
        posicion = inicio
        for elemento in elementos:
            if elemento["nombre"] == "vertex" and not any(
                p["lista"] for p in elemento["props"]
            ):
                dtype = np.dtype(
                    [
                        (p["nombre"], orden + _TIPOS[p["tipo"]])
                        for p in elemento["props"]
                    ]
                )
                bloque = np.frombuffer(
                    datos, dtype=dtype, count=elemento["cuenta"], offset=posicion
                )
                posicion += dtype.itemsize * elemento["cuenta"]
                for fila in bloque:
                    vertices.append(
                        {nombre_prop: float(fila[nombre_prop]) for nombre_prop in dtype.names}
                    )
            else:
                for _ in range(elemento["cuenta"]):
                    for propiedad in elemento["props"]:
                        if propiedad["lista"]:
                            tipo_conteo = np.dtype(orden + _TIPOS[propiedad["conteo"]])
                            cantidad = int(
                                np.frombuffer(
                                    datos, dtype=tipo_conteo, count=1, offset=posicion
                                )[0]
                            )
                            posicion += tipo_conteo.itemsize
                            tipo_valor = np.dtype(orden + _TIPOS[propiedad["tipo"]])
                            indices = np.frombuffer(
                                datos, dtype=tipo_valor, count=cantidad, offset=posicion
                            )
                            posicion += tipo_valor.itemsize * cantidad
                            if elemento["nombre"] == "face":
                                caras.append([int(v) for v in indices])
                        else:
                            tipo_valor = np.dtype(orden + _TIPOS[propiedad["tipo"]])
                            posicion += tipo_valor.itemsize

    if not vertices:
        raise ConversionError("El PLY no contiene vertices.")
    posiciones = np.array(
        [[fila.get("x", 0.0), fila.get("y", 0.0), fila.get("z", 0.0)] for fila in vertices],
        dtype=np.float32,
    )
    normales = None
    if "nx" in vertices[0]:
        normales = np.array(
            [[fila.get("nx", 0.0), fila.get("ny", 0.0), fila.get("nz", 1.0)] for fila in vertices],
            dtype=np.float32,
        )
    uv = None
    claves_uv = None
    for par in (("s", "t"), ("u", "v"), ("texture_u", "texture_v")):
        if par[0] in vertices[0] and par[1] in vertices[0]:
            claves_uv = par
            break
    if claves_uv:
        uv = np.array(
            [[fila[claves_uv[0]], fila[claves_uv[1]]] for fila in vertices], dtype=np.float32
        )

    indices = []
    for cara in caras:
        for posicion_cara in range(1, len(cara) - 1):
            indices.extend([cara[0], cara[posicion_cara], cara[posicion_cara + 1]])
    if not indices:
        raise ConversionError("El PLY no contiene caras.")

    malla = Mesh(
        nombre=nombre,
        posiciones=posiciones,
        indices=np.array(indices, dtype=np.uint32),
        normales=normales,
        uv=uv,
        material=None,
    )
    return Scene(mallas=[malla], materiales={}, imagenes={})
