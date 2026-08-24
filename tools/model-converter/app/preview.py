"""Vista previa por software: rasterizador con z-buffer sobre NumPy.

No hay GPU ni ninguna biblioteca grafica disponible en el servidor, asi que la
imagen se calcula a mano. El rasterizador tambien mide la fraccion de pixeles
visibles que provienen de caras traseras, que es la senal mas fiable de una
malla con orientacion invertida.
"""

import io
import math

import numpy as np

from app import config
from app.formats.mesh import caja_envolvente, triangulos_totales

_FONDO = (150, 152, 158)
_AMBIENTE = 0.42


def _camara(minimo, maximo, azimut=35.0, elevacion=20.0):
    minimo = np.array(minimo, dtype=np.float64)
    maximo = np.array(maximo, dtype=np.float64)
    centro = (minimo + maximo) / 2.0
    radio = float(np.linalg.norm(maximo - minimo)) / 2.0
    if radio <= 0.0:
        radio = 1.0
    distancia = radio * 3.0
    a = math.radians(azimut)
    e = math.radians(elevacion)
    ojo = centro + distancia * np.array(
        [math.cos(e) * math.sin(a), math.sin(e), math.cos(e) * math.cos(a)]
    )
    return ojo, centro, radio


def _base_vista(ojo, centro):
    frente = centro - ojo
    frente = frente / max(float(np.linalg.norm(frente)), 1e-9)
    arriba_mundo = np.array([0.0, 1.0, 0.0])
    if abs(float(np.dot(frente, arriba_mundo))) > 0.999:
        arriba_mundo = np.array([0.0, 0.0, 1.0])
    derecha = np.cross(frente, arriba_mundo)
    derecha = derecha / max(float(np.linalg.norm(derecha)), 1e-9)
    arriba = np.cross(derecha, frente)
    return derecha, arriba, frente


def _textura_rgb(datos):
    try:
        from PIL import Image
    except Exception:
        return None
    try:
        with Image.open(io.BytesIO(datos)) as imagen:
            return np.asarray(imagen.convert("RGB"), dtype=np.float32) / 255.0
    except Exception:
        return None


def renderizar(escena, ancho=None, alto=None):
    """Devuelve (bytes PNG o None, metricas)."""
    ancho = int(ancho or config.PREVIEW_WIDTH)
    alto = int(alto or config.PREVIEW_HEIGHT)
    metricas = {
        "generada": False,
        "motivo": None,
        "pixeles_traseros": 0.0,
        "triangulos_dibujados": 0,
    }
    total = triangulos_totales(escena)
    if total == 0:
        metricas["motivo"] = "escena sin triangulos"
        return None, metricas
    if total > config.PREVIEW_MAX_TRIANGLES:
        metricas["motivo"] = (
            "modelo con " + str(total) + " triangulos, por encima del limite de vista previa"
        )
        return None, metricas
    try:
        from PIL import Image
    except Exception:
        metricas["motivo"] = "Pillow no disponible"
        return None, metricas

    minimo, maximo = caja_envolvente(escena)
    ojo, centro, radio = _camara(minimo, maximo)
    derecha, arriba, frente = _base_vista(ojo, centro)
    foco = 1.0 / math.tan(math.radians(34.0) / 2.0)

    color = np.zeros((alto, ancho, 3), dtype=np.float32)
    color[:, :, 0] = _FONDO[0] / 255.0
    color[:, :, 1] = _FONDO[1] / 255.0
    color[:, :, 2] = _FONDO[2] / 255.0
    profundidad = np.full((alto, ancho), 1e9, dtype=np.float64)
    trasera = np.zeros((alto, ancho), dtype=bool)
    cubierto = np.zeros((alto, ancho), dtype=bool)

    luz = np.array([0.4, 0.8, 0.45])
    luz = luz / float(np.linalg.norm(luz))
    texturas = {}
    dibujados = 0

    for malla in escena.mallas:
        posiciones = np.asarray(malla.posiciones, dtype=np.float64).reshape(-1, 3)
        indices = np.asarray(malla.indices, dtype=np.int64).reshape(-1, 3)
        if not len(indices):
            continue
        uv = None if malla.uv is None else np.asarray(malla.uv, dtype=np.float64)
        material = escena.materiales.get(malla.material) if malla.material else None
        base = np.array(material.color_base[:3]) if material else np.array([0.78, 0.78, 0.80])
        mapa = None
        if material and material.textura and material.textura in escena.imagenes:
            if material.textura not in texturas:
                texturas[material.textura] = _textura_rgb(escena.imagenes[material.textura])
            mapa = texturas[material.textura]

        relativo = posiciones - ojo
        vista_x = relativo.dot(derecha)
        vista_y = relativo.dot(arriba)
        vista_z = relativo.dot(frente)
        seguro = np.maximum(vista_z, 1e-6)
        pantalla_x = (vista_x / seguro) * foco * (alto / 2.0) + ancho / 2.0
        pantalla_y = -(vista_y / seguro) * foco * (alto / 2.0) + alto / 2.0

        for triangulo in indices:
            a, b, c = int(triangulo[0]), int(triangulo[1]), int(triangulo[2])
            if min(vista_z[a], vista_z[b], vista_z[c]) <= 1e-4:
                continue
            x0, y0 = pantalla_x[a], pantalla_y[a]
            x1, y1 = pantalla_x[b], pantalla_y[b]
            x2, y2 = pantalla_x[c], pantalla_y[c]
            area = (x1 - x0) * (y2 - y0) - (x2 - x0) * (y1 - y0)
            if abs(area) < 1e-12:
                continue
            es_trasera = area > 0
            minimo_x = max(int(math.floor(min(x0, x1, x2))), 0)
            maximo_x = min(int(math.ceil(max(x0, x1, x2))), ancho - 1)
            minimo_y = max(int(math.floor(min(y0, y1, y2))), 0)
            maximo_y = min(int(math.ceil(max(y0, y1, y2))), alto - 1)
            if minimo_x > maximo_x or minimo_y > maximo_y:
                continue
            rejilla_x = np.arange(minimo_x, maximo_x + 1) + 0.5
            rejilla_y = np.arange(minimo_y, maximo_y + 1) + 0.5
            px, py = np.meshgrid(rejilla_x, rejilla_y)
            w0 = ((x1 - px) * (y2 - py) - (x2 - px) * (y1 - py)) / area
            w1 = ((x2 - px) * (y0 - py) - (x0 - px) * (y2 - py)) / area
            w2 = 1.0 - w0 - w1
            dentro = (w0 >= 0) & (w1 >= 0) & (w2 >= 0)
            if not dentro.any():
                continue
            inverso_z = w0 / vista_z[a] + w1 / vista_z[b] + w2 / vista_z[c]
            inverso_z = np.where(inverso_z <= 0, 1e-9, inverso_z)
            z = 1.0 / inverso_z
            z = np.where(np.isfinite(z), z, 1e9)
            ventana_profundidad = profundidad[minimo_y : maximo_y + 1, minimo_x : maximo_x + 1]
            visible = dentro & (z < ventana_profundidad)
            if not visible.any():
                continue
            normal = np.cross(posiciones[b] - posiciones[a], posiciones[c] - posiciones[a])
            longitud = float(np.linalg.norm(normal))
            normal = normal / longitud if longitud else np.array([0.0, 0.0, 1.0])
            intensidad = _AMBIENTE + (1.0 - _AMBIENTE) * abs(float(np.dot(normal, luz)))
            tono = np.clip(base * intensidad, 0.0, 1.0).astype(np.float32)
            parche = np.zeros(z.shape + (3,), dtype=np.float32)
            parche[:, :, 0] = tono[0]
            parche[:, :, 1] = tono[1]
            parche[:, :, 2] = tono[2]
            if mapa is not None and uv is not None:
                u = (w0 * uv[a, 0] / vista_z[a] + w1 * uv[b, 0] / vista_z[b] + w2 * uv[c, 0] / vista_z[c]) * z
                v = (w0 * uv[a, 1] / vista_z[a] + w1 * uv[b, 1] / vista_z[b] + w2 * uv[c, 1] / vista_z[c]) * z
                u = np.clip(np.nan_to_num(u, nan=0.0, posinf=1.0, neginf=0.0), 0.0, 1.0)
                v = np.clip(np.nan_to_num(v, nan=0.0, posinf=1.0, neginf=0.0), 0.0, 1.0)
                filas = np.clip((v * (mapa.shape[0] - 1)).astype(np.int64), 0, mapa.shape[0] - 1)
                columnas = np.clip((u * (mapa.shape[1] - 1)).astype(np.int64), 0, mapa.shape[1] - 1)
                parche = mapa[filas, columnas] * intensidad
            ventana_color = color[minimo_y : maximo_y + 1, minimo_x : maximo_x + 1]
            ventana_color[visible] = np.clip(parche[visible], 0.0, 1.0)
            ventana_profundidad[visible] = z[visible]
            trasera[minimo_y : maximo_y + 1, minimo_x : maximo_x + 1][visible] = es_trasera
            cubierto[minimo_y : maximo_y + 1, minimo_x : maximo_x + 1][visible] = True
            dibujados += 1

    visibles = int(cubierto.sum())
    if visibles:
        metricas["pixeles_traseros"] = round(float(trasera[cubierto].mean()), 6)
    metricas["triangulos_dibujados"] = dibujados
    metricas["generada"] = True
    imagen = Image.fromarray((np.clip(color, 0.0, 1.0) * 255.0).astype(np.uint8), "RGB")
    memoria = io.BytesIO()
    imagen.save(memoria, format="PNG", optimize=True)
    return memoria.getvalue(), metricas
