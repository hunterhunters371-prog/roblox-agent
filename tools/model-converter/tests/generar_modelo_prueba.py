"""Genera un modelo de prueba con textura para las pruebas y la demo.

Crea un cubo texturizado en GLB, con normales, coordenadas de textura, un
material y una imagen PNG embebida.

Uso: python tests/generar_modelo_prueba.py salida.glb
"""

import io
import sys
from pathlib import Path

import numpy as np

RAIZ = Path(__file__).resolve().parent.parent
if str(RAIZ) not in sys.path:
    sys.path.insert(0, str(RAIZ))

from app.formats import gltf  # noqa: E402
from app.formats.mesh import Material, Mesh, Scene, calcular_normales  # noqa: E402

_CARAS = [
    ((0, 0, 1), [(-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)]),
    ((0, 0, -1), [(1, -1, -1), (-1, -1, -1), (-1, 1, -1), (1, 1, -1)]),
    ((1, 0, 0), [(1, -1, 1), (1, -1, -1), (1, 1, -1), (1, 1, 1)]),
    ((-1, 0, 0), [(-1, -1, -1), (-1, -1, 1), (-1, 1, 1), (-1, 1, -1)]),
    ((0, 1, 0), [(-1, 1, 1), (1, 1, 1), (1, 1, -1), (-1, 1, -1)]),
    ((0, -1, 0), [(-1, -1, -1), (1, -1, -1), (1, -1, 1), (-1, -1, 1)]),
]


def textura_png(lado=64):
    from PIL import Image

    rejilla = np.zeros((lado, lado, 3), dtype=np.uint8)
    tablero = ((np.arange(lado)[:, None] // 8 + np.arange(lado)[None, :] // 8) % 2) == 0
    rejilla[tablero] = (222, 176, 96)
    rejilla[~tablero] = (72, 96, 148)
    memoria = io.BytesIO()
    Image.fromarray(rejilla, "RGB").save(memoria, format="PNG")
    return memoria.getvalue()


def escena_cubo():
    posiciones = []
    uvs = []
    indices = []
    for _normal, esquinas in _CARAS:
        base = len(posiciones)
        posiciones.extend(esquinas)
        uvs.extend([(0.0, 1.0), (1.0, 1.0), (1.0, 0.0), (0.0, 0.0)])
        indices.extend([base, base + 1, base + 2, base, base + 2, base + 3])
    malla = Mesh(
        nombre="cubo",
        posiciones=np.array(posiciones, dtype=np.float32),
        indices=np.array(indices, dtype=np.uint32),
        normales=None,
        uv=np.array(uvs, dtype=np.float32),
        material="tablero",
    )
    malla.normales = calcular_normales(malla)
    material = Material(
        nombre="tablero", color_base=(1.0, 1.0, 1.0, 1.0), textura="tablero.png"
    )
    return Scene(
        mallas=[malla],
        materiales={"tablero": material},
        imagenes={"tablero.png": textura_png()},
    )


def main(argumentos):
    destino = Path(argumentos[0] if argumentos else "cubo_prueba.glb")
    datos = gltf.write_glb(escena_cubo())
    destino.write_bytes(datos)
    print("Escrito " + str(destino) + " (" + str(len(datos)) + " bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
