"""Preparacion de paginas HTML que generan la geometria con JavaScript.

Cuando una pagina construye el modelo en tiempo de ejecucion (three.js con
`BoxGeometry`, grupos creados en bucle, etc.) no hay ningun modelo dentro del
archivo: solo instrucciones. El servidor no ejecuta JavaScript, asi que la unica
via honesta es devolver la misma pagina con un exportador inyectado, para que el
navegador del usuario haga la exportacion a GLB.

Este modulo detecta ese caso e inyecta el exportador dentro del ambito del
script que crea la escena, que es lo que permite alcanzar las variables locales
de un `<script type="module">`.
"""

import re

VERSION_THREE_POR_DEFECTO = "0.163.0"

_SCRIPT = re.compile(
    r"<script\b(?P<atributos>[^>]*)>(?P<cuerpo>.*?)</script\s*>",
    re.IGNORECASE | re.DOTALL,
)
_ESCENA = re.compile(
    r"(?:const|let|var)\s+([A-Za-z_$][\w$]*)\s*=\s*new\s+(?:[\w$]+\.)?Scene\s*\("
)
_VERSION = re.compile(r"three@([0-9]+(?:\.[0-9]+)*)")
_GEOMETRIA = re.compile(
    r"new\s+(?:[\w$]+\.)?(?:Box|Sphere|Cylinder|Cone|Torus|Plane|Capsule|"
    r"Icosahedron|Dodecahedron|Octahedron|Tetrahedron|Lathe|Extrude|Tube|Ring|"
    r"Circle|Buffer)Geometry\s*\("
)

_PLANTILLA = """
/* === Exportador GLB anadido por model-converter === */
(function () {
  var escena = ESCENA_OBJETIVO;
  if (!escena || escena.isObject3D !== true) return;
  window.__mcEscena = escena;
  var RESPALDO = "URL_RESPALDO";

  function cargarExportador() {
    return import("three/addons/exporters/GLTFExporter.js").catch(function () {
      return import(RESPALDO);
    });
  }

  function esDecorado(objeto) {
    if (!objeto) return true;
    if (objeto.isLight === true || objeto.isCamera === true) return true;
    if (objeto.isPoints === true || objeto.isSprite === true) return true;
    var tipo = String(objeto.type || "");
    if (tipo.indexOf("Helper") !== -1) return true;
    if (
      objeto.isMesh === true &&
      objeto.geometry &&
      String(objeto.geometry.type || "").indexOf("Plane") === 0
    ) {
      return true;
    }
    return false;
  }

  function soloModelo() {
    var hijos = (escena.children || []).filter(function (hijo) {
      return !esDecorado(hijo);
    });
    return hijos.length > 0 ? hijos : escena;
  }

  function estilo(arriba) {
    return (
      "position:fixed;z-index:99999;right:14px;top:" +
      arriba +
      "px;padding:12px 16px;font:700 14px sans-serif;background:#ffffff;" +
      "color:#111111;border:0;border-radius:10px;cursor:pointer;" +
      "box-shadow:0 4px 14px rgba(0,0,0,.4)"
    );
  }

  function exportar(entrada, nombre, boton) {
    var texto = boton.textContent;
    boton.disabled = true;
    boton.textContent = "Exportando...";
    cargarExportador()
      .then(function (modulo) {
        var exportador = new modulo.GLTFExporter();
        exportador.parse(
          entrada,
          function (resultado) {
            var blob = new Blob([resultado], { type: "model/gltf-binary" });
            var enlace = document.createElement("a");
            enlace.href = URL.createObjectURL(blob);
            enlace.download = nombre;
            document.body.appendChild(enlace);
            enlace.click();
            setTimeout(function () {
              URL.revokeObjectURL(enlace.href);
              enlace.remove();
            }, 2000);
            boton.disabled = false;
            boton.textContent = texto;
            console.log("model-converter: exportado " + nombre);
          },
          function (error) {
            console.error(error);
            boton.textContent = "Fallo, mira la consola";
          },
          { binary: true, onlyVisible: true }
        );
      })
      .catch(function (error) {
        console.error(error);
        boton.textContent = "Fallo, mira la consola";
      });
  }

  function anadirBotones() {
    if (!document.body || document.getElementById("mc-exportar")) return;
    var modelo = document.createElement("button");
    modelo.id = "mc-exportar";
    modelo.textContent = "Descargar GLB";
    modelo.style.cssText = estilo(14);
    modelo.addEventListener("click", function () {
      exportar(soloModelo(), "modelo.glb", modelo);
    });
    document.body.appendChild(modelo);

    var completa = document.createElement("button");
    completa.textContent = "Descargar escena completa";
    completa.style.cssText = estilo(62);
    completa.addEventListener("click", function () {
      exportar(escena, "escena.glb", completa);
    });
    document.body.appendChild(completa);
  }

  if (document.body) {
    anadirBotones();
  } else {
    document.addEventListener("DOMContentLoaded", anadirBotones);
  }
})();
"""


def _bloques_script(texto):
    """Devuelve los bloques <script> con su cuerpo y posiciones."""
    bloques = []
    for encontrado in _SCRIPT.finditer(texto):
        atributos = encontrado.group("atributos") or ""
        if "importmap" in atributos.lower():
            continue
        if "src=" in atributos.lower():
            continue
        bloques.append(
            {
                "cuerpo": encontrado.group("cuerpo"),
                "inicio_cuerpo": encontrado.start("cuerpo"),
                "fin_cuerpo": encontrado.end("cuerpo"),
                "modulo": "module" in atributos.lower(),
            }
        )
    return bloques


def _bloque_de_escena(texto):
    """Localiza el script que crea la escena y el nombre de su variable."""
    for bloque in _bloques_script(texto):
        encontrado = _ESCENA.search(bloque["cuerpo"])
        if encontrado:
            return bloque, encontrado.group(1)
    return None, None


def version_three(texto):
    """Extrae la version de three declarada en la pagina."""
    encontrado = _VERSION.search(texto)
    return encontrado.group(1) if encontrado else VERSION_THREE_POR_DEFECTO


def es_pagina_procedural(texto):
    """Indica si la pagina construye la geometria con codigo JavaScript."""
    bloque, _nombre = _bloque_de_escena(texto)
    if bloque is None:
        return False
    return bool(_GEOMETRIA.search(bloque["cuerpo"]))


def inyectar_exportador(texto):
    """Devuelve la pagina con el exportador GLB inyectado.

    Lanza ValueError si no se encuentra un script que cree una escena.
    """
    bloque, nombre = _bloque_de_escena(texto)
    if bloque is None:
        raise ValueError(
            "No se encontro ningun script que cree una escena 3D en la pagina."
        )
    respaldo = (
        "https://cdn.jsdelivr.net/npm/three@"
        + version_three(texto)
        + "/examples/jsm/exporters/GLTFExporter.js"
    )
    inyeccion = _PLANTILLA.replace("ESCENA_OBJETIVO", nombre).replace(
        "URL_RESPALDO", respaldo
    )
    corte = bloque["fin_cuerpo"]
    return texto[:corte] + "\n" + inyeccion + "\n" + texto[corte:]


def preparar(datos):
    """Prepara los bytes de una pagina y devuelve (bytes, nombre_variable)."""
    texto = datos.decode("utf-8", "replace")
    _bloque, nombre = _bloque_de_escena(texto)
    return inyectar_exportador(texto).encode("utf-8"), nombre
