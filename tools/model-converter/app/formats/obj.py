"""Lector y escritor de Wavefront OBJ con su archivo de materiales MTL.

La coordenada V de las texturas esta invertida entre OBJ y glTF. Internamente
se guarda siempre el convenio glTF, asi que la inversion se aplica al leer y al
escribir; la doble inversion de una ida y vuelta da la identidad.
"""

from pathlib import Path

import numpy as np

from app.formats.mesh import ConversionError, Material, Mesh, Scene


def _flotantes(partes):
    valores = []
    for parte in partes:
        try:
            valores.append(float(parte))
        except ValueError:
            valores.append(0.0)
    return valores


def _indice(valor, total):
    if valor == "":
        return None
    numero = int(valor)
    if numero > 0:
        return numero - 1
    return total + numero


def _leer_mtl(texto, imagenes_disponibles):
    materiales = {}
    actual = None
    for linea in texto.splitlines():
        linea = linea.strip()
        if not linea or linea.startswith("#"):
            continue
        partes = linea.split()
        clave = partes[0].lower()
        if clave == "newmtl":
            nombre = " ".join(partes[1:]) or "material"
            actual = Material(nombre=nombre)
            materiales[nombre] = actual
        elif actual is None:
            continue
        elif clave == "kd" and len(partes) >= 4:
            r, g, b = _flotantes(partes[1:4])
            actual.color_base = (r, g, b, actual.color_base[3])
        elif clave == "d" and len(partes) >= 2:
            alfa = _flotantes(partes[1:2])[0]
            actual.color_base = actual.color_base[:3] + (alfa,)
        elif clave == "map_kd" and len(partes) >= 2:
            nombre_textura = Path(partes[-1].replace("\\", "/")).name
            actual.textura = nombre_textura
            imagenes_disponibles.add(nombre_textura)
    return materiales


def read_obj(texto, base=None):
    """Lee un OBJ y sus materiales. `base` es el directorio del paquete."""
    if isinstance(texto, (bytes, bytearray)):
        texto = bytes(texto).decode("utf-8", "replace")
    posiciones = []
    uvs = []
    normales = []
    grupos = {}
    material_actual = None
    objeto_actual = "malla"
    materiales = {}
    texturas_pedidas = set()

    def _grupo():
        clave = (objeto_actual, material_actual)
        if clave not in grupos:
            grupos[clave] = {"mapa": {}, "vertices": [], "indices": []}
        return grupos[clave]

    for linea in texto.splitlines():
        linea = linea.strip()
        if not linea or linea.startswith("#"):
            continue
        partes = linea.split()
        clave = partes[0].lower()
        if clave == "v" and len(partes) >= 4:
            posiciones.append(_flotantes(partes[1:4]))
        elif clave == "vt" and len(partes) >= 3:
            u, v = _flotantes(partes[1:3])
            uvs.append([u, 1.0 - v])
        elif clave == "vn" and len(partes) >= 4:
            normales.append(_flotantes(partes[1:4]))
        elif clave in ("o", "g") and len(partes) >= 2:
            objeto_actual = " ".join(partes[1:])
        elif clave == "usemtl" and len(partes) >= 2:
            material_actual = " ".join(partes[1:])
        elif clave == "mtllib" and base is not None:
            nombre = Path(" ".join(partes[1:]).replace("\\", "/")).name
            ruta = Path(base) / nombre
            if ruta.is_file():
                materiales.update(
                    _leer_mtl(ruta.read_text("utf-8", "replace"), texturas_pedidas)
                )
        elif clave == "f" and len(partes) >= 4:
            grupo = _grupo()
            esquinas = []
            for token in partes[1:]:
                campos = (token.split("/") + ["", "", ""])[:3]
                vi = _indice(campos[0], len(posiciones))
                ti = _indice(campos[1], len(uvs))
                ni = _indice(campos[2], len(normales))
                if vi is None or vi < 0 or vi >= len(posiciones):
                    continue
                llave = (vi, ti, ni)
                if llave not in grupo["mapa"]:
                    grupo["mapa"][llave] = len(grupo["vertices"])
                    grupo["vertices"].append(llave)
                esquinas.append(grupo["mapa"][llave])
            for indice in range(1, len(esquinas) - 1):
                grupo["indices"].extend(
                    [esquinas[0], esquinas[indice], esquinas[indice + 1]]
                )

    imagenes = {}
    if base is not None:
        for nombre in texturas_pedidas:
            ruta = Path(base) / nombre
            if ruta.is_file():
                imagenes[nombre] = ruta.read_bytes()

    escena = Scene(mallas=[], materiales=materiales, imagenes=imagenes)
    for (nombre_objeto, nombre_material), grupo in grupos.items():
        if not grupo["indices"]:
            continue
        vertices = grupo["vertices"]
        posicion_array = np.array(
            [posiciones[llave[0]] for llave in vertices], dtype=np.float32
        )
        uv_array = None
        if uvs and any(llave[1] is not None for llave in vertices):
            uv_array = np.array(
                [
                    uvs[llave[1]] if llave[1] is not None and llave[1] < len(uvs) else [0.0, 0.0]
                    for llave in vertices
                ],
                dtype=np.float32,
            )
        normal_array = None
        if normales and any(llave[2] is not None for llave in vertices):
            normal_array = np.array(
                [
                    normales[llave[2]]
                    if llave[2] is not None and llave[2] < len(normales)
                    else [0.0, 0.0, 1.0]
                    for llave in vertices
                ],
                dtype=np.float32,
            )
        escena.mallas.append(
            Mesh(
                nombre=nombre_objeto,
                posiciones=posicion_array,
                indices=np.array(grupo["indices"], dtype=np.uint32),
                normales=normal_array,
                uv=uv_array,
                material=nombre_material if nombre_material in materiales else None,
            )
        )
    if not escena.mallas:
        raise ConversionError("El archivo OBJ no contiene caras legibles.")
    return escena


def write_obj(escena, nombre_base="modelo"):
    """Devuelve un diccionario nombre de archivo -> bytes con OBJ, MTL y texturas."""
    archivo_obj = nombre_base + ".obj"
    archivo_mtl = nombre_base + ".mtl"
    lineas = [
        "# Generado por model-converter",
        "mtllib " + archivo_mtl,
    ]
    desplazamiento_v = 1
    desplazamiento_t = 1
    desplazamiento_n = 1
    for malla in escena.mallas:
        lineas.append("o " + str(malla.nombre).replace(" ", "_"))
        posiciones = np.asarray(malla.posiciones, dtype=np.float64).reshape(-1, 3)
        for x, y, z in posiciones:
            lineas.append("v %.6f %.6f %.6f" % (x, y, z))
        tiene_uv = malla.uv is not None
        if tiene_uv:
            for u, v in np.asarray(malla.uv, dtype=np.float64).reshape(-1, 2):
                lineas.append("vt %.6f %.6f" % (u, 1.0 - v))
        tiene_normales = malla.normales is not None
        if tiene_normales:
            for x, y, z in np.asarray(malla.normales, dtype=np.float64).reshape(-1, 3):
                lineas.append("vn %.6f %.6f %.6f" % (x, y, z))
        if malla.material:
            lineas.append("usemtl " + str(malla.material))
        indices = np.asarray(malla.indices, dtype=np.int64).reshape(-1, 3)
        for a, b, c in indices:
            esquinas = []
            for indice in (a, b, c):
                v = int(indice) + desplazamiento_v
                t = str(int(indice) + desplazamiento_t) if tiene_uv else ""
                n = str(int(indice) + desplazamiento_n) if tiene_normales else ""
                if tiene_normales:
                    esquinas.append(str(v) + "/" + t + "/" + n)
                elif tiene_uv:
                    esquinas.append(str(v) + "/" + t)
                else:
                    esquinas.append(str(v))
            lineas.append("f " + " ".join(esquinas))
        desplazamiento_v += len(posiciones)
        if tiene_uv:
            desplazamiento_t += len(posiciones)
        if tiene_normales:
            desplazamiento_n += len(posiciones)

    lineas_mtl = ["# Generado por model-converter"]
    for clave, material in escena.materiales.items():
        color = material.color_base
        lineas_mtl.append("newmtl " + str(clave))
        lineas_mtl.append("Kd %.6f %.6f %.6f" % (color[0], color[1], color[2]))
        lineas_mtl.append("Ka 0.000000 0.000000 0.000000")
        lineas_mtl.append("Ks 0.000000 0.000000 0.000000")
        lineas_mtl.append("d %.6f" % (color[3] if len(color) > 3 else 1.0))
        lineas_mtl.append("illum 2")
        if material.textura:
            lineas_mtl.append("map_Kd " + str(material.textura))

    archivos = {
        archivo_obj: ("\n".join(lineas) + "\n").encode("utf-8"),
        archivo_mtl: ("\n".join(lineas_mtl) + "\n").encode("utf-8"),
    }
    for nombre, datos in escena.imagenes.items():
        archivos[nombre] = datos
    return archivos
