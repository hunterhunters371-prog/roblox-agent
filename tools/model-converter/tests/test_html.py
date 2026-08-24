"""Pruebas de la extraccion de modelos incrustados en HTML."""

import base64
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
if str(RAIZ) not in sys.path:
    sys.path.insert(0, str(RAIZ))

from app import config  # noqa: E402

_TEMPORAL = tempfile.mkdtemp(prefix="mc-html-")
config.DATA_DIR = Path(_TEMPORAL)
config.JOBS_DIR = Path(_TEMPORAL) / "jobs"

from app import convert  # noqa: E402
from app.formats import gltf, html as formato_html, obj as formato_obj  # noqa: E402
from app.formats.mesh import ConversionError  # noqa: E402
from tests.generar_modelo_prueba import escena_cubo  # noqa: E402


def _pagina_con_uri(datos, mime="model/gltf-binary"):
    carga = base64.b64encode(datos).decode("ascii")
    return (
        "<!doctype html><html><head><title>Visor</title></head><body>"
        '<model-viewer src="data:' + mime + ";base64," + carga + '"></model-viewer>'
        "</body></html>"
    ).encode("utf-8")


class PruebasHtml(unittest.TestCase):
    def test_html_acepta_extension(self):
        self.assertIn(".html", config.extensiones_entrada())
        self.assertIn(".htm", config.extensiones_entrada())

    def test_uri_de_datos_con_glb(self):
        pagina = _pagina_con_uri(gltf.write_glb(escena_cubo()))
        datos, extension, origen = formato_html.extraer_modelo(pagina)
        self.assertEqual(extension, ".glb")
        self.assertTrue(datos.startswith(b"glTF"))
        self.assertIn("URI de datos", origen)

    def test_uri_de_datos_sin_mime_util(self):
        pagina = _pagina_con_uri(gltf.write_glb(escena_cubo()), "application/octet-stream")
        _datos, extension, _origen = formato_html.extraer_modelo(pagina)
        self.assertEqual(extension, ".glb")

    def test_obj_incrustado_en_script(self):
        archivos = formato_obj.write_obj(escena_cubo(), "cubo")
        texto = archivos["cubo.obj"].decode("utf-8")
        pagina = (
            '<html><body><script id="modelo" type="text/plain">'
            + texto
            + "</script></body></html>"
        ).encode("utf-8")
        datos, extension, _origen = formato_html.extraer_modelo(pagina)
        self.assertEqual(extension, ".obj")
        self.assertIn(b"f ", datos)

    def test_referencia_a_archivo_vecino(self):
        with tempfile.TemporaryDirectory() as directorio:
            base = Path(directorio)
            (base / "cubo.glb").write_bytes(gltf.write_glb(escena_cubo()))
            (base / "visor.html").write_bytes(
                b'<html><body><a-entity gltf-model="cubo.glb"></a-entity></body></html>'
            )
            datos, extension, origen = formato_html.extraer_modelo(
                (base / "visor.html").read_bytes(), base=base
            )
        self.assertEqual(extension, ".glb")
        self.assertTrue(datos.startswith(b"glTF"))
        self.assertIn("cubo.glb", origen)

    def test_html_sin_modelo_da_error_claro(self):
        with self.assertRaises(ConversionError) as contexto:
            formato_html.extraer_modelo(b"<html><body><h1>Hola</h1></body></html>")
        self.assertIn("no contiene ningun modelo", str(contexto.exception))

    def test_conversion_completa_desde_html(self):
        with tempfile.TemporaryDirectory() as directorio:
            base = Path(directorio)
            entrada = base / "escena.html"
            entrada.write_bytes(_pagina_con_uri(gltf.write_glb(escena_cubo())))
            info = convert.convertir(entrada, base / "salida", salidas=["glb", "obj", "zip"])
            archivos = set(info["archivos"])
        self.assertEqual(info["geometria"]["triangulos"], 12)
        self.assertEqual(info["formato_entrada"], "html")
        self.assertIn("escena.glb", archivos)
        self.assertIn("escena.obj", archivos)
        self.assertIn("escena_convertido.zip", archivos)

    def test_conversion_desde_zip_con_html_y_glb(self):
        with tempfile.TemporaryDirectory() as directorio:
            base = Path(directorio)
            entrada = base / "paquete.zip"
            with zipfile.ZipFile(entrada, "w") as paquete:
                paquete.writestr("visor/index.html", b'<html><body src="modelo.glb"></body></html>')
                paquete.writestr("visor/modelo.glb", gltf.write_glb(escena_cubo()))
            info = convert.convertir(entrada, base / "salida", salidas=["glb"])
        self.assertEqual(info["geometria"]["triangulos"], 12)


if __name__ == "__main__":
    unittest.main(verbosity=2)
