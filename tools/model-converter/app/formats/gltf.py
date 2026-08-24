"""Lector de glTF 2.0 y GLB, y escritor de GLB con texturas embebidas.

La implementacion es propia y solo depende de NumPy. Da control exacto sobre
coordenadas de textura, materiales e imagenes, que es justamente lo que hay que
preservar al convertir entre formatos.
"""

import base64
import json
import struct
import urllib.parse
from pathlib import Path

import numpy as np

from app.formats.mesh import ConversionError, Material, Mesh, Scene

_MAGIC = 0x46546C67
_JSON_CHUNK = 0x4E4F534A
_BIN_CHUNK = 0x004E4942

_DTYPE = {
    5120: "<i1",
    5121: "<u1",
    5122: "<i2",
    5123: "<u2",
    5125: "<u4",
    5126: "<f4",
}
_NORM_MAX = {5120: 127.0, 5121: 255.0, 5122: 32767.0, 5123: 65535.0}
_NCOMP = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT2": 4, "MAT3": 9, "MAT4": 16}
_EXT = {"image/png": ".png", "image/jpeg": ".jpg", "image/webp": ".webp"}


def _parse_glb(datos):
    if len(datos) < 12:
        raise ConversionError("El archivo GLB es demasiado corto.")
    magia, _version, longitud = struct.unpack("<III", datos[:12])
    if magia != _MAGIC:
        raise ConversionError("El archivo no empieza por la firma glTF binaria.")
    fin = min(longitud, len(datos))
    desplazamiento = 12
    documento = None
    binario = None
    while desplazamiento + 8 <= fin:
        tamano, tipo = struct.unpack("<II", datos[desplazamiento : desplazamiento + 8])
        cuerpo = datos[desplazamiento + 8 : desplazamiento + 8 + tamano]
        if tipo == _JSON_CHUNK:
            documento = json.loads(cuerpo.decode("utf-8"))
        elif tipo == _BIN_CHUNK:
            binario = bytes(cuerpo)
        desplazamiento += 8 + tamano
        desplazamiento += (4 - desplazamiento % 4) % 4
    if documento is None:
        raise ConversionError("El GLB no contiene el fragmento JSON.")
    return documento, binario


def _resolve_uri(uri, base):
    if uri.startswith("data:"):
        cabecera, _, carga = uri.partition(",")
        if ";base64" in cabecera:
            return base64.b64decode(carga)
        return urllib.parse.unquote_to_bytes(carga)
    if base is None:
        raise ConversionError("El archivo referencia recursos externos: " + uri)
    relativa = urllib.parse.unquote(uri)
    destino = (Path(base) / relativa).resolve()
    raiz = Path(base).resolve()
    if raiz not in destino.parents and destino != raiz:
        raise ConversionError("Referencia externa fuera del paquete: " + uri)
    if not destino.is_file():
        raise ConversionError("Falta el recurso referenciado: " + uri)
    return destino.read_bytes()


def _buffers(documento, binario, base):
    resultado = []
    for buffer in documento.get("buffers", []):
        uri = buffer.get("uri")
        if uri is None:
            if binario is None:
                raise ConversionError("Falta el fragmento binario del GLB.")
            resultado.append(binario)
        else:
            resultado.append(_resolve_uri(uri, base))
    return resultado


def _read_accessor(documento, buffers, indice):
    accesor = documento["accessors"][indice]
    componentes = _NCOMP[accesor["type"]]
    tipo_componente = accesor["componentType"]
    cuenta = int(accesor["count"])
    dtype = np.dtype(_DTYPE[tipo_componente])
    ancho = dtype.itemsize * componentes
    if "bufferView" not in accesor:
        datos = np.zeros((cuenta, componentes), dtype=dtype)
    else:
        vista = documento["bufferViews"][accesor["bufferView"]]
        bruto = np.frombuffer(buffers[vista.get("buffer", 0)], dtype=np.uint8)
        inicio = int(vista.get("byteOffset", 0)) + int(accesor.get("byteOffset", 0))
        paso = int(vista.get("byteStride") or ancho)
        posiciones = (np.arange(cuenta, dtype=np.int64) * paso)[:, None]
        posiciones = posiciones + np.arange(ancho, dtype=np.int64)[None, :]
        recorte = bruto[inicio + posiciones]
        datos = np.ascontiguousarray(recorte).view(dtype).reshape(cuenta, componentes)
    if accesor.get("normalized") and tipo_componente in _NORM_MAX:
        datos = np.maximum(
            datos.astype(np.float32) / _NORM_MAX[tipo_componente], -1.0
        )
    return datos


def _to_triangles(indices, modo):
    indices = np.asarray(indices, dtype=np.uint32).reshape(-1)
    if modo == 4:
        return indices[: (len(indices) // 3) * 3]
    if modo == 5:
        if len(indices) < 3:
            return np.zeros(0, dtype=np.uint32)
        primeros = indices[:-2]
        segundos = indices[1:-1]
        terceros = indices[2:]
        impares = np.arange(len(primeros)) % 2 == 1
        a = np.where(impares, segundos, primeros)
        b = np.where(impares, primeros, segundos)
        return np.stack([a, b, terceros], axis=1).reshape(-1).astype(np.uint32)
    if modo == 6:
        if len(indices) < 3:
            return np.zeros(0, dtype=np.uint32)
        centro = np.full(len(indices) - 2, indices[0], dtype=np.uint32)
        return np.stack([centro, indices[1:-1], indices[2:]], axis=1).reshape(-1)
    raise ConversionError("Modo de primitiva no soportado: " + str(modo))


def _quat_matrix(q):
    x, y, z, w = [float(v) for v in q]
    return np.array(
        [
            [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w), 0.0],
            [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w), 0.0],
            [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y), 0.0],
            [0.0, 0.0, 0.0, 1.0],
        ],
        dtype=np.float64,
    )


def _node_matrix(nodo):
    if "matrix" in nodo:
        return np.array(nodo["matrix"], dtype=np.float64).reshape(4, 4).T
    matriz = np.eye(4)
    if "rotation" in nodo:
        matriz = _quat_matrix(nodo["rotation"])
    if "scale" in nodo:
        escala = np.eye(4)
        escala[0, 0], escala[1, 1], escala[2, 2] = [float(v) for v in nodo["scale"]]
        matriz = matriz.dot(escala)
    if "translation" in nodo:
        matriz[0, 3], matriz[1, 3], matriz[2, 3] = [
            float(v) for v in nodo["translation"]
        ]
    return matriz


def _mesh_instances(documento):
    nodos = documento.get("nodes", [])
    escenas = documento.get("scenes", [])
    indice_escena = documento.get("scene", 0)
    if escenas and 0 <= indice_escena < len(escenas):
        raices = escenas[indice_escena].get("nodes", [])
    else:
        hijos = set()
        for nodo in nodos:
            hijos.update(nodo.get("children", []))
        raices = [i for i in range(len(nodos)) if i not in hijos]
    instancias = []
    pendientes = [(indice, np.eye(4)) for indice in raices]
    visitados = 0
    while pendientes:
        indice, padre = pendientes.pop()
        visitados += 1
        if visitados > 100000:
            raise ConversionError("Jerarquia de nodos demasiado profunda o ciclica.")
        nodo = nodos[indice]
        global_ = padre.dot(_node_matrix(nodo))
        if "mesh" in nodo:
            instancias.append((int(nodo["mesh"]), global_, nodo.get("name")))
        for hijo in nodo.get("children", []):
            pendientes.append((int(hijo), global_))
    if not instancias:
        for indice in range(len(documento.get("meshes", []))):
            instancias.append((indice, np.eye(4), None))
    return instancias


def _sniff_ext(datos):
    if datos[:8] == b"\x89PNG\r\n\x1a\n":
        return ".png"
    if datos[:2] == b"\xff\xd8":
        return ".jpg"
    if datos[:4] == b"RIFF" and datos[8:12] == b"WEBP":
        return ".webp"
    return ".bin"


def _images(documento, buffers, base):
    nombres = []
    imagenes = {}
    for indice, imagen in enumerate(documento.get("images", [])):
        if "bufferView" in imagen:
            vista = documento["bufferViews"][imagen["bufferView"]]
            bruto = buffers[vista.get("buffer", 0)]
            inicio = int(vista.get("byteOffset", 0))
            datos = bytes(bruto[inicio : inicio + int(vista["byteLength"])])
            extension = _EXT.get(imagen.get("mimeType", ""), _sniff_ext(datos))
            nombre = imagen.get("name") or ("textura_" + str(indice))
            nombre = Path(nombre).stem + extension
        elif "uri" in imagen:
            datos = _resolve_uri(imagen["uri"], base)
            if imagen["uri"].startswith("data:"):
                nombre = "textura_" + str(indice) + _sniff_ext(datos)
            else:
                nombre = Path(urllib.parse.unquote(imagen["uri"])).name
        else:
            nombres.append(None)
            continue
        while nombre in imagenes and imagenes[nombre] != datos:
            nombre = "_" + nombre
        imagenes[nombre] = datos
        nombres.append(nombre)
    return imagenes, nombres


def _materiales(documento, nombres_imagen):
    materiales = {}
    claves = []
    for indice, material in enumerate(documento.get("materials", [])):
        clave = material.get("name") or ("material_" + str(indice))
        original = clave
        contador = 1
        while clave in materiales:
            clave = original + "_" + str(contador)
            contador += 1
        pbr = material.get("pbrMetallicRoughness", {})
        color = tuple(pbr.get("baseColorFactor", [1.0, 1.0, 1.0, 1.0]))
        textura = None
        referencia = pbr.get("baseColorTexture")
        if referencia is not None:
            texturas = documento.get("textures", [])
            posicion = int(referencia.get("index", 0))
            if 0 <= posicion < len(texturas):
                fuente = texturas[posicion].get("source")
                if fuente is not None and 0 <= fuente < len(nombres_imagen):
                    textura = nombres_imagen[fuente]
        materiales[clave] = Material(
            nombre=clave,
            color_base=color,
            metalicidad=float(pbr.get("metallicFactor", 0.0)),
            rugosidad=float(pbr.get("roughnessFactor", 0.9)),
            textura=textura,
        )
        claves.append(clave)
    return materiales, claves


def read_gltf(datos, base=None, formato="glb"):
    """Lee GLB o glTF y devuelve una escena con la jerarquia ya aplanada."""
    if formato == "glb":
        documento, binario = _parse_glb(datos)
    else:
        documento, binario = json.loads(bytes(datos).decode("utf-8")), None
    buffers = _buffers(documento, binario, base)
    imagenes, nombres_imagen = _images(documento, buffers, base)
    materiales, claves_material = _materiales(documento, nombres_imagen)
    escena = Scene(mallas=[], materiales=materiales, imagenes=imagenes)

    for indice_malla, matriz, nombre_nodo in _mesh_instances(documento):
        malla_json = documento["meshes"][indice_malla]
        base_nombre = nombre_nodo or malla_json.get("name") or ("malla_" + str(indice_malla))
        lineal = matriz[:3, :3]
        determinante = float(np.linalg.det(lineal))
        try:
            normal_matriz = np.linalg.inv(lineal).T
        except np.linalg.LinAlgError:
            normal_matriz = np.eye(3)
        for posicion, primitiva in enumerate(malla_json.get("primitives", [])):
            atributos = primitiva.get("attributes", {})
            if "POSITION" not in atributos:
                continue
            posiciones = _read_accessor(documento, buffers, atributos["POSITION"])
            posiciones = posiciones.astype(np.float64)[:, :3]
            posiciones = posiciones.dot(lineal.T) + matriz[:3, 3]
            normales = None
            if "NORMAL" in atributos:
                normales = _read_accessor(documento, buffers, atributos["NORMAL"])
                normales = normales.astype(np.float64)[:, :3].dot(normal_matriz.T)
                longitudes = np.linalg.norm(normales, axis=1)
                longitudes[longitudes == 0.0] = 1.0
                normales = (normales / longitudes[:, None]).astype(np.float32)
            uv = None
            if "TEXCOORD_0" in atributos:
                uv = _read_accessor(documento, buffers, atributos["TEXCOORD_0"])
                uv = uv.astype(np.float32)[:, :2]
            if "indices" in primitiva:
                indices = _read_accessor(documento, buffers, primitiva["indices"])
                indices = indices.reshape(-1).astype(np.uint32)
            else:
                indices = np.arange(len(posiciones), dtype=np.uint32)
            indices = _to_triangles(indices, int(primitiva.get("mode", 4)))
            if determinante < 0 and len(indices):
                caras = indices.reshape(-1, 3)[:, [0, 2, 1]]
                indices = caras.reshape(-1).astype(np.uint32)
            material = None
            if "material" in primitiva:
                posicion_material = int(primitiva["material"])
                if 0 <= posicion_material < len(claves_material):
                    material = claves_material[posicion_material]
            nombre = base_nombre if posicion == 0 else base_nombre + "_" + str(posicion)
            escena.mallas.append(
                Mesh(
                    nombre=nombre,
                    posiciones=posiciones.astype(np.float32),
                    indices=indices,
                    normales=normales,
                    uv=uv,
                    material=material,
                )
            )
    if not escena.mallas:
        raise ConversionError("El archivo glTF no contiene mallas con geometria.")
    return escena


def write_glb(escena):
    """Serializa la escena a GLB con un unico buffer y texturas embebidas."""
    buffer = bytearray()
    vistas = []
    accesores = []

    def _vista(datos, destino=None):
        while len(buffer) % 4:
            buffer.append(0)
        inicio = len(buffer)
        buffer.extend(datos)
        entrada = {"buffer": 0, "byteOffset": inicio, "byteLength": len(datos)}
        if destino is not None:
            entrada["target"] = destino
        vistas.append(entrada)
        return len(vistas) - 1

    def _accesor(array, tipo_componente, tipo, destino=None, extremos=False):
        array = np.ascontiguousarray(array)
        indice_vista = _vista(array.tobytes(), destino)
        entrada = {
            "bufferView": indice_vista,
            "componentType": tipo_componente,
            "count": int(array.shape[0]),
            "type": tipo,
        }
        if extremos:
            entrada["min"] = [float(v) for v in array.min(axis=0)]
            entrada["max"] = [float(v) for v in array.max(axis=0)]
        accesores.append(entrada)
        return len(accesores) - 1

    nombres_imagen = list(escena.imagenes.keys())
    indice_imagen = {nombre: i for i, nombre in enumerate(nombres_imagen)}
    imagenes_json = []
    texturas_json = []
    for nombre in nombres_imagen:
        datos = escena.imagenes[nombre]
        extension = Path(nombre).suffix.lower()
        mime = "image/png"
        if extension in (".jpg", ".jpeg"):
            mime = "image/jpeg"
        elif extension == ".webp":
            mime = "image/webp"
        imagenes_json.append(
            {"bufferView": _vista(datos), "mimeType": mime, "name": Path(nombre).stem}
        )
        texturas_json.append({"sampler": 0, "source": len(texturas_json)})

    materiales_json = []
    indice_material = {}
    for clave, material in escena.materiales.items():
        pbr = {
            "baseColorFactor": [float(v) for v in material.color_base],
            "metallicFactor": float(material.metalicidad),
            "roughnessFactor": float(material.rugosidad),
        }
        if material.textura and material.textura in indice_imagen:
            pbr["baseColorTexture"] = {"index": indice_imagen[material.textura]}
        indice_material[clave] = len(materiales_json)
        materiales_json.append(
            {"name": material.nombre, "pbrMetallicRoughness": pbr, "doubleSided": False}
        )

    mallas_json = []
    nodos_json = []
    for malla in escena.mallas:
        posiciones = np.asarray(malla.posiciones, dtype=np.float32).reshape(-1, 3)
        atributos = {
            "POSITION": _accesor(posiciones, 5126, "VEC3", 34962, extremos=True)
        }
        if malla.normales is not None:
            normales = np.asarray(malla.normales, dtype=np.float32).reshape(-1, 3)
            atributos["NORMAL"] = _accesor(normales, 5126, "VEC3", 34962)
        if malla.uv is not None:
            uv = np.asarray(malla.uv, dtype=np.float32).reshape(-1, 2)
            atributos["TEXCOORD_0"] = _accesor(uv, 5126, "VEC2", 34962)
        indices = np.asarray(malla.indices, dtype=np.uint32).reshape(-1, 1)
        primitiva = {
            "attributes": atributos,
            "indices": _accesor(indices, 5125, "SCALAR", 34963),
            "mode": 4,
        }
        if malla.material in indice_material:
            primitiva["material"] = indice_material[malla.material]
        mallas_json.append({"name": malla.nombre, "primitives": [primitiva]})
        nodos_json.append({"mesh": len(mallas_json) - 1, "name": malla.nombre})

    documento = {
        "asset": {"version": "2.0", "generator": "model-converter"},
        "scene": 0,
        "scenes": [{"nodes": list(range(len(nodos_json)))}],
        "nodes": nodos_json,
        "meshes": mallas_json,
        "accessors": accesores,
        "bufferViews": vistas,
        "buffers": [{"byteLength": len(buffer)}],
    }
    if materiales_json:
        documento["materials"] = materiales_json
    if imagenes_json:
        documento["images"] = imagenes_json
        documento["textures"] = texturas_json
        documento["samplers"] = [{"magFilter": 9729, "minFilter": 9987}]

    json_bytes = json.dumps(documento, separators=(",", ":")).encode("utf-8")
    json_bytes += b" " * ((4 - len(json_bytes) % 4) % 4)
    binario = bytes(buffer)
    binario += b"\x00" * ((4 - len(binario) % 4) % 4)
    longitud = 12 + 8 + len(json_bytes) + 8 + len(binario)
    salida = bytearray()
    salida.extend(struct.pack("<III", _MAGIC, 2, longitud))
    salida.extend(struct.pack("<II", len(json_bytes), _JSON_CHUNK))
    salida.extend(json_bytes)
    salida.extend(struct.pack("<II", len(binario), _BIN_CHUNK))
    salida.extend(binario)
    return bytes(salida)
