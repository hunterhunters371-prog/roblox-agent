"""Exportacion headless: ejecuta la pagina en un Chrome sin ventana y saca el GLB.

Las paginas que construyen la geometria con JavaScript (three.js con
`BoxGeometry`, etc.) no contienen ningun modelo en el archivo: la geometria solo
existe al ejecutar el codigo. En lugar de pedir al usuario que abra la pagina y
exporte a mano, aqui se carga la pagina en un navegador headless dentro del
servidor y se exporta la escena a GLB de forma automatica.

Playwright y el navegador son opcionales: si no estan instalados, `disponible`
devuelve False y el conversor cae al plan B (devolver un HTML con exportador).
"""

import base64
import tempfile
from pathlib import Path

from app import config
from app.formats import html_navegador

_CACHE_DISPONIBLE = {"valor": None}

_JS_EXPORTAR = r"""
async (esperaMs) => {
  const dormir = (ms) => new Promise((r) => setTimeout(r, ms));
  let escena = null;
  const limite = Math.max(1, Math.floor(esperaMs / 100));
  for (let i = 0; i < limite; i++) {
    if (window.__mcEscena) { escena = window.__mcEscena; break; }
    await dormir(100);
  }
  if (!escena) return null;

  const T = await import('three');
  let modulo;
  try {
    modulo = await import('three/addons/exporters/GLTFExporter.js');
  } catch (error) {
    modulo = await import('URL_RESPALDO');
  }

  function esDecorado(objeto) {
    if (!objeto) return true;
    if (objeto.isLight === true || objeto.isCamera === true) return true;
    if (objeto.isPoints === true || objeto.isSprite === true) return true;
    const tipo = String(objeto.type || '');
    if (tipo.indexOf('Helper') !== -1) return true;
    if (
      objeto.isMesh === true &&
      objeto.geometry &&
      String(objeto.geometry.type || '').indexOf('Plane') === 0
    ) {
      return true;
    }
    return false;
  }

  if (typeof escena.updateMatrixWorld === 'function') escena.updateMatrixWorld(true);

  const hijos = (escena.children || []).filter((hijo) => !esDecorado(hijo));
  let objetivo = escena;
  if (hijos.length > 0) {
    const raiz = new T.Group();
    for (const hijo of hijos) raiz.add(hijo);
    objetivo = raiz;
  }

  const exportador = new modulo.GLTFExporter();
  const buffer = await new Promise((resolver, rechazar) => {
    exportador.parse(objetivo, resolver, rechazar, { binary: true, onlyVisible: true });
  });

  const bytes = new Uint8Array(buffer);
  const TROZO = 0x8000;
  let binario = '';
  for (let i = 0; i < bytes.length; i += TROZO) {
    binario += String.fromCharCode.apply(null, bytes.subarray(i, i + TROZO));
  }
  return btoa(binario);
}
"""


def _playwright():
    """Importa Playwright; devuelve None si no esta instalado."""
    try:
        from playwright.sync_api import sync_playwright
    except Exception:
        return None
    return sync_playwright


def disponible():
    """Indica si hay un Chrome headless utilizable en este equipo."""
    if _CACHE_DISPONIBLE["valor"] is not None:
        return _CACHE_DISPONIBLE["valor"]
    sync_playwright = _playwright()
    if sync_playwright is None:
        _CACHE_DISPONIBLE["valor"] = False
        return False
    try:
        with sync_playwright() as p:
            ejecutable = Path(p.chromium.executable_path)
            _CACHE_DISPONIBLE["valor"] = ejecutable.is_file()
    except Exception:
        _CACHE_DISPONIBLE["valor"] = False
    return _CACHE_DISPONIBLE["valor"]


def exportar_glb(datos_html, registrar=lambda mensaje: None):
    """Ejecuta la pagina en headless y devuelve el GLB, o None si no se puede.

    Nunca lanza excepciones hacia el llamador: cualquier fallo (sin navegador,
    sin escena, tiempo agotado) se traduce en None para que el conversor use el
    plan B.
    """
    sync_playwright = _playwright()
    if sync_playwright is None:
        registrar("Playwright no instalado: no se puede ejecutar la pagina.")
        return None

    try:
        preparada, nombre_escena = html_navegador.preparar(datos_html)
    except ValueError as error:
        registrar(str(error))
        return None

    respaldo = (
        "https://cdn.jsdelivr.net/npm/three@"
        + html_navegador.version_three(datos_html.decode("utf-8", "replace"))
        + "/examples/jsm/exporters/GLTFExporter.js"
    )
    script = _JS_EXPORTAR.replace("URL_RESPALDO", respaldo)

    with tempfile.TemporaryDirectory(prefix="mc-headless-") as directorio:
        pagina = Path(directorio) / "index.html"
        pagina.write_bytes(preparada)
        try:
            with sync_playwright() as p:
                navegador = p.chromium.launch(
                    headless=True,
                    args=[
                        "--enable-unsafe-swiftshader",
                        "--use-angle=swiftshader",
                        "--disable-gpu-sandbox",
                        "--no-sandbox",
                    ],
                )
                try:
                    contexto = navegador.new_context()
                    hoja = contexto.new_page()
                    hoja.set_default_timeout(config.HEADLESS_TIMEOUT_MS)
                    hoja.goto(pagina.as_uri())
                    registrar(
                        "Ejecutando la pagina en Chrome headless (escena: "
                        + str(nombre_escena)
                        + ")..."
                    )
                    resultado = hoja.evaluate(script, config.HEADLESS_ESPERA_MS)
                finally:
                    navegador.close()
        except Exception as error:  # noqa: BLE001
            registrar("Fallo el navegador headless: " + str(error))
            return None

    if not resultado:
        registrar("La pagina no expuso ninguna escena en el navegador.")
        return None

    glb = base64.b64decode(resultado)
    registrar(
        "Exportado GLB desde la pagina en el navegador ("
        + str(len(glb))
        + " bytes)."
    )
    return glb
