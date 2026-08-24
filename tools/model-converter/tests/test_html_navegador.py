"""Pruebas de la preparacion de paginas que generan geometria con JavaScript."""

import sys
import tempfile
import unittest
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
if str(RAIZ) not in sys.path:
    sys.path.insert(0, str(RAIZ))

from app import config  # noqa: E402

_TEMPORAL = tempfile.mkdtemp(prefix="mc-nav-")
config.DATA_DIR = Path(_TEMPORAL)
config.JOBS_DIR = Path(_TEMPORAL) / "jobs"

from app import convert, headless  # noqa: E402
from app.formats import gltf, html_navegador  # noqa: E402
from tests.generar_modelo_prueba import escena_cubo  # noqa: E402

PAGINA_MODULO = """<!doctype html>
<html><head>
<script type="importmap">
{ "imports": {
  "three": "https://cdn.jsdelivr.net/npm/three@0.163.0/build/three.module.js",
  "three/addons/": "https://cdn.jsdelivr.net/npm/three@0.163.0/examples/jsm/"
} }
</script>
</head><body>
<script type="module">
import * as THREE from 'three';
const escenaPrincipal = new THREE.Scene();
const grupo = new THREE.Group();
const geo = new THREE.BoxGeometry(1, 1, 1);
grupo.add(new THREE.Mesh(geo, new THREE.MeshStandardMaterial()));
escenaPrincipal.add(grupo);
animate();
</script>
</body></html>
"""

PAGINA_SIN_3D = "<html><body><h1>Hola</h1><script>console.log(1);</script></body></html>"


class PruebasHtmlNavegador(unittest.TestCase):
    def test_detecta_pagina_procedural(self):
        self.assertTrue(html_navegador.es_pagina_procedural(PAGINA_MODULO))

    def test_pagina_sin_3d_no_es_procedural(self):
        self.assertFalse(html_navegador.es_pagina_procedural(PAGINA_SIN_3D))

    def test_detecta_version_de_three(self):
        self.assertEqual(html_navegador.version_three(PAGINA_MODULO), "0.163.0")
        self.assertEqual(
            html_navegador.version_three("<html></html>"),
            html_navegador.VERSION_THREE_POR_DEFECTO,
        )

    def test_inyecta_dentro_del_modulo(self):
        resultado = html_navegador.inyectar_exportador(PAGINA_MODULO)
        self.assertIn("Exportador GLB anadido por model-converter", resultado)
        self.assertIn("var escena = escenaPrincipal;", resultado)
        self.assertIn("Descargar GLB", resultado)
        posicion_inyeccion = resultado.index("Exportador GLB anadido")
        posicion_cierre = resultado.index("</script>", posicion_inyeccion)
        self.assertLess(posicion_inyeccion, posicion_cierre)
        self.assertEqual(resultado.count("<script"), PAGINA_MODULO.count("<script"))

    def test_preparar_devuelve_nombre_de_escena(self):
        datos, nombre = html_navegador.preparar(PAGINA_MODULO.encode("utf-8"))
        self.assertEqual(nombre, "escenaPrincipal")
        self.assertIn(b"GLTFExporter", datos)

    def test_pagina_sin_escena_da_error(self):
        with self.assertRaises(ValueError):
            html_navegador.inyectar_exportador(PAGINA_SIN_3D)

    def test_conversion_devuelve_html_exportable(self):
        with tempfile.TemporaryDirectory() as directorio:
            base = Path(directorio)
            entrada = base / "visor.html"
            entrada.write_text(PAGINA_MODULO, "utf-8")
            salida = base / "salida"
            info = convert.convertir(entrada, salida, salidas=["glb"])
            self.assertTrue((salida / "visor_exportable.html").is_file())
        self.assertTrue(info["requiere_navegador"])
        self.assertEqual(info["escena_detectada"], "escenaPrincipal")
        self.assertEqual(info["paso_siguiente"], "visor_exportable.html")
        self.assertIn("visor_exportable.html", info["archivos"])
        self.assertIn("info.json", info["archivos"])

    def test_headless_desactivado_devuelve_exportable(self):
        original = config.HEADLESS
        config.HEADLESS = False
        try:
            with tempfile.TemporaryDirectory() as directorio:
                base = Path(directorio)
                entrada = base / "visor.html"
                entrada.write_text(PAGINA_MODULO, "utf-8")
                info = convert.convertir(entrada, base / "salida", salidas=["glb"])
            self.assertTrue(info["requiere_navegador"])
        finally:
            config.HEADLESS = original

    def test_headless_sin_resultado_cae_al_plan_b(self):
        original_disponible = headless.disponible
        original_exportar = headless.exportar_glb
        try:
            headless.disponible = lambda: True
            headless.exportar_glb = lambda datos, registrar=lambda m: None: None
            with tempfile.TemporaryDirectory() as directorio:
                base = Path(directorio)
                entrada = base / "visor.html"
                entrada.write_text(PAGINA_MODULO, "utf-8")
                info = convert.convertir(entrada, base / "salida", salidas=["glb"])
            self.assertTrue(info["requiere_navegador"])
        finally:
            headless.disponible = original_disponible
            headless.exportar_glb = original_exportar

    def test_headless_convierte_sin_plan_b(self):
        original_disponible = headless.disponible
        original_exportar = headless.exportar_glb
        original_headless = config.HEADLESS
        try:
            config.HEADLESS = True
            headless.disponible = lambda: True
            headless.exportar_glb = (
                lambda datos, registrar=lambda m: None: gltf.write_glb(escena_cubo())
            )
            with tempfile.TemporaryDirectory() as directorio:
                base = Path(directorio)
                entrada = base / "visor.html"
                entrada.write_text(PAGINA_MODULO, "utf-8")
                info = convert.convertir(
                    entrada, base / "salida", salidas=["glb", "obj", "zip"]
                )
            self.assertNotIn("requiere_navegador", info)
            self.assertEqual(info["geometria"]["triangulos"], 12)
            self.assertEqual(info["formato_entrada"], "html")
            self.assertIn("visor.glb", info["archivos"])
            self.assertIn("visor.obj", info["archivos"])
            self.assertIn("visor_convertido.zip", info["archivos"])
        finally:
            config.HEADLESS = original_headless
            headless.disponible = original_disponible
            headless.exportar_glb = original_exportar


if __name__ == "__main__":
    unittest.main(verbosity=2)
