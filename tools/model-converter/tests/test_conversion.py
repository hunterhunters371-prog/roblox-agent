"""Pruebas del conversor: formatos, seguridad y conversion completa."""

import json
import os
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

import numpy as np

RAIZ = Path(__file__).resolve().parent.parent
if str(RAIZ) not in sys.path:
    sys.path.insert(0, str(RAIZ))

from app import config  # noqa: E402

_TEMPORAL = tempfile.mkdtemp(prefix="mc-pruebas-")
config.DATA_DIR = Path(_TEMPORAL)
config.JOBS_DIR = Path(_TEMPORAL) / "jobs"

from app import convert, storage  # noqa: E402
from app.formats import gltf, obj as formato_obj, ply as formato_ply, stl as formato_stl  # noqa: E402
from app.formats.mesh import ConversionError, stats, validar  # noqa: E402
from tests.generar_modelo_prueba import escena_cubo  # noqa: E402


class PruebasFormatos(unittest.TestCase):
    def setUp(self):
        self.escena = escena_cubo()

    def test_glb_ida_y_vuelta(self):
        datos = gltf.write_glb(self.escena)
        leida = gltf.read_gltf(datos, formato="glb")
        self.assertEqual(stats(leida)["triangulos"], stats(self.escena)["triangulos"])
        self.assertEqual(stats(leida)["vertices"], stats(self.escena)["vertices"])
        self.assertEqual(len(leida.imagenes), 1)
        self.assertEqual(len(leida.materiales), 1)

    def test_glb_conserva_posiciones(self):
        leida = gltf.read_gltf(gltf.write_glb(self.escena), formato="glb")
        original = np.sort(self.escena.mallas[0].posiciones.reshape(-1))
        copia = np.sort(leida.mallas[0].posiciones.reshape(-1))
        self.assertTrue(np.allclose(original, copia, atol=1e-6))

    def test_obj_doble_inversion_uv_es_identidad(self):
        with tempfile.TemporaryDirectory() as directorio:
            base = Path(directorio)
            for nombre, datos in formato_obj.write_obj(self.escena, "cubo").items():
                (base / nombre).write_bytes(datos)
            leida = formato_obj.read_obj((base / "cubo.obj").read_bytes(), base=base)
        original = np.sort(self.escena.mallas[0].uv.reshape(-1))
        copia = np.sort(np.concatenate([m.uv.reshape(-1) for m in leida.mallas]))
        self.assertTrue(np.allclose(original, copia, atol=1e-6))

    def test_obj_arrastra_material_y_textura(self):
        with tempfile.TemporaryDirectory() as directorio:
            base = Path(directorio)
            archivos = formato_obj.write_obj(self.escena, "cubo")
            self.assertIn("cubo.mtl", archivos)
            self.assertIn("tablero.png", archivos)
            for nombre, datos in archivos.items():
                (base / nombre).write_bytes(datos)
            leida = formato_obj.read_obj((base / "cubo.obj").read_bytes(), base=base)
        self.assertIn("tablero", leida.materiales)
        self.assertEqual(leida.materiales["tablero"].textura, "tablero.png")
        self.assertIn("tablero.png", leida.imagenes)

    def test_stl_binario_ida_y_vuelta(self):
        datos = formato_stl.write_stl(self.escena)
        leida = formato_stl.read_stl(datos)
        self.assertEqual(stats(leida)["triangulos"], stats(self.escena)["triangulos"])

    def test_ply_ascii(self):
        texto = (
            "ply\nformat ascii 1.0\nelement vertex 3\n"
            "property float x\nproperty float y\nproperty float z\n"
            "element face 1\nproperty list uchar int vertex_indices\nend_header\n"
            "0 0 0\n1 0 0\n0 1 0\n3 0 1 2\n"
        )
        leida = formato_ply.read_ply(texto.encode("utf-8"))
        self.assertEqual(stats(leida)["triangulos"], 1)
        self.assertEqual(stats(leida)["vertices"], 3)


class PruebasSeguridad(unittest.TestCase):
    def test_nombre_seguro_descarta_rutas(self):
        self.assertEqual(storage.nombre_seguro("../../estado.json"), "estado.json")
        self.assertEqual(storage.nombre_seguro("C:\\temp\\a b.glb"), "a b.glb")
        self.assertEqual(storage.nombre_seguro(""), "modelo")

    def test_ruta_descarga_bloquea_travesia(self):
        identificador, directorio = storage.crear_trabajo()
        storage.escribir_estado(directorio, {"id": identificador, "estado": "completado"})
        (directorio / "salida" / "modelo.glb").write_bytes(b"x")
        self.assertTrue(storage.ruta_descarga(identificador, "modelo.glb").is_file())
        with self.assertRaises(storage.TrabajoNoEncontrado):
            storage.ruta_descarga(identificador, "../estado.json")

    def test_zip_slip_saneado(self):
        with tempfile.TemporaryDirectory() as directorio:
            base = Path(directorio)
            ruta_zip = base / "malicioso.zip"
            with zipfile.ZipFile(ruta_zip, "w") as paquete:
                paquete.writestr("../../fuera.txt", "no deberia salir")
                paquete.writestr("modelo.stl", formato_stl.write_stl(escena_cubo()))
            extraidos = convert.extraer_zip(ruta_zip, base / "salida")
            for archivo in extraidos:
                self.assertIn((base / "salida").resolve(), Path(archivo).resolve().parents)
            self.assertFalse((base.parent / "fuera.txt").exists())

    def test_limite_de_triangulos(self):
        escena = escena_cubo()
        with self.assertRaises(ConversionError):
            validar(escena, maximo_triangulos=1)


class PruebasConversion(unittest.TestCase):
    def test_conversion_completa_desde_glb(self):
        with tempfile.TemporaryDirectory() as directorio:
            base = Path(directorio)
            entrada = base / "cubo.glb"
            entrada.write_bytes(gltf.write_glb(escena_cubo()))
            info = convert.convertir(entrada, base / "salida", salidas=["glb", "obj", "zip"])
            archivos = set(info["archivos"])
            self.assertIn("cubo.glb", archivos)
            self.assertIn("cubo.obj", archivos)
            self.assertIn("cubo.mtl", archivos)
            self.assertIn("tablero.png", archivos)
            self.assertIn("info.json", archivos)
            self.assertIn("cubo_convertido.zip", archivos)
            self.assertEqual(info["geometria"]["triangulos"], 12)
            guardado = json.loads((base / "salida" / "info.json").read_text("utf-8"))
            self.assertEqual(guardado["paquete"], "cubo_convertido.zip")

    def test_conversion_desde_zip_extrae_texturas(self):
        with tempfile.TemporaryDirectory() as directorio:
            base = Path(directorio)
            entrada = base / "paquete.zip"
            with zipfile.ZipFile(entrada, "w") as paquete:
                for nombre, datos in formato_obj.write_obj(escena_cubo(), "cubo").items():
                    paquete.writestr("modelo/" + nombre, datos)
            info = convert.convertir(entrada, base / "salida", salidas=["glb"])
            self.assertEqual(info["modelo_leido"], "cubo.obj")
            self.assertEqual(info["texturas"], ["tablero.png"])
            self.assertEqual(info["geometria"]["triangulos"], 12)

    def test_vista_previa_sin_caras_traseras(self):
        from app import preview

        imagen, metricas = preview.renderizar(escena_cubo(), 240, 200)
        self.assertTrue(metricas["generada"])
        self.assertTrue(imagen.startswith(b"\x89PNG"))
        self.assertEqual(metricas["pixeles_traseros"], 0.0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
