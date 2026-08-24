"""Servidor HTTP del conversor: API JSON y pagina web de extraccion.

Solo biblioteca estandar. El servicio se arranca con run.py, que prepara la
cola y los directorios antes de abrir el puerto.
"""

import json
import mimetypes
import time
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

from app import config, jobs, storage

_ESTATICO = Path(__file__).resolve().parent / "static"
_COLA = jobs.Cola()


class Manejador(BaseHTTPRequestHandler):
    server_version = "model-converter"
    protocol_version = "HTTP/1.1"

    def log_message(self, formato, *argumentos):
        return None

    # -- utilidades de respuesta -------------------------------------------

    def _enviar(self, codigo, cuerpo, tipo="application/octet-stream", descarga=None):
        if isinstance(cuerpo, str):
            cuerpo = cuerpo.encode("utf-8")
        self.send_response(codigo)
        self.send_header("Content-Type", tipo)
        self.send_header("Content-Length", str(len(cuerpo)))
        self.send_header("Cache-Control", "no-store")
        if descarga:
            self.send_header(
                "Content-Disposition", 'attachment; filename="' + descarga + '"'
            )
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(cuerpo)

    def _json(self, codigo, datos):
        cuerpo = json.dumps(datos, ensure_ascii=False, indent=2)
        self._enviar(codigo, cuerpo, "application/json; charset=utf-8")

    def _error(self, codigo, mensaje):
        self._json(codigo, {"error": mensaje})

    # -- rutas -------------------------------------------------------------

    def do_GET(self):
        ruta, _, consulta = self.path.partition("?")
        parametros = urllib.parse.parse_qs(consulta)
        try:
            if ruta in ("/", "/index.html"):
                return self._pagina()
            if ruta == "/api/health":
                return self._salud()
            if ruta == "/api/jobs":
                limite = int((parametros.get("limit") or [25])[0])
                return self._json(200, {"trabajos": storage.listar_trabajos(limite)})
            partes = [p for p in ruta.split("/") if p]
            if len(partes) == 3 and partes[0] == "api" and partes[1] == "jobs":
                return self._estado(partes[2])
            if len(partes) == 4 and partes[:2] == ["api", "jobs"] and partes[3] == "log":
                directorio = storage.directorio_trabajo(partes[2])
                return self._enviar(
                    200, storage.leer_registro(directorio), "text/plain; charset=utf-8"
                )
            if len(partes) == 5 and partes[:2] == ["api", "jobs"] and partes[3] == "files":
                return self._descarga(partes[2], urllib.parse.unquote(partes[4]))
        except storage.TrabajoNoEncontrado as error:
            return self._error(404, str(error))
        except ValueError:
            return self._error(400, "Parametros invalidos")
        return self._error(404, "Ruta no encontrada")

    def do_HEAD(self):
        return self.do_GET()

    def do_POST(self):
        ruta, _, consulta = self.path.partition("?")
        if ruta != "/api/jobs":
            return self._error(404, "Ruta no encontrada")
        return self._crear(urllib.parse.parse_qs(consulta))

    def do_PUT(self):
        return self.do_POST()

    def do_DELETE(self):
        partes = [p for p in self.path.partition("?")[0].split("/") if p]
        if len(partes) != 3 or partes[:2] != ["api", "jobs"]:
            return self._error(404, "Ruta no encontrada")
        try:
            storage.borrar_trabajo(partes[2])
        except storage.TrabajoNoEncontrado as error:
            return self._error(404, str(error))
        return self._json(200, {"borrado": partes[2]})

    # -- implementacion de cada ruta ---------------------------------------

    def _pagina(self):
        archivo = _ESTATICO / "index.html"
        if not archivo.is_file():
            return self._error(500, "Falta la pagina estatica")
        return self._enviar(
            200, archivo.read_bytes(), "text/html; charset=utf-8"
        )

    def _salud(self):
        datos = config.resumen()
        datos["estado"] = "ok"
        datos["pendientes"] = _COLA.pendientes()
        datos["hora"] = time.time()
        return self._json(200, datos)

    def _estado(self, identificador):
        directorio = storage.directorio_trabajo(identificador)
        estado = storage.leer_estado(directorio)
        estado["archivos"] = storage.listar_salidas(directorio)
        return self._json(200, estado)

    def _descarga(self, identificador, nombre):
        archivo = storage.ruta_descarga(identificador, nombre)
        tipo = mimetypes.guess_type(archivo.name)[0] or "application/octet-stream"
        return self._enviar(200, archivo.read_bytes(), tipo, descarga=archivo.name)

    def _crear(self, parametros):
        longitud = int(self.headers.get("Content-Length") or 0)
        maximo = config.MAX_UPLOAD_MB * 1024 * 1024
        if longitud <= 0:
            return self._error(400, "Cuerpo vacio: envia el archivo como binario")
        if longitud > maximo:
            return self._error(
                413,
                "El archivo supera el limite de " + str(config.MAX_UPLOAD_MB) + " MB",
            )
        nombre = storage.nombre_seguro((parametros.get("filename") or ["modelo"])[0])
        extension = Path(nombre).suffix.lower()
        aceptadas = config.extensiones_entrada()
        if extension not in aceptadas:
            return self._error(
                400,
                "Extension no soportada: "
                + (extension or "sin extension")
                + ". Aceptadas: "
                + ", ".join(sorted(aceptadas)),
            )
        pedidas = (parametros.get("outputs") or [",".join(config.SALIDAS_VALIDAS)])[0]
        salidas = [s.strip().lower() for s in pedidas.split(",") if s.strip()]
        salidas = [s for s in salidas if s in config.SALIDAS_VALIDAS]
        if not salidas:
            return self._error(
                400,
                "Salidas invalidas. Validas: " + ", ".join(config.SALIDAS_VALIDAS),
            )

        datos = self.rfile.read(longitud)
        identificador, directorio = storage.crear_trabajo()
        (directorio / "entrada" / nombre).write_bytes(datos)
        storage.escribir_estado(
            directorio,
            {
                "id": identificador,
                "archivo": nombre,
                "bytes": len(datos),
                "salidas": salidas,
                "estado": "en_cola",
                "creado": time.time(),
                "actualizado": time.time(),
                "error": None,
            },
        )
        storage.registrar(directorio, "Recibido " + nombre + " (" + str(len(datos)) + " bytes)")
        try:
            _COLA.encolar(identificador)
        except jobs.ColaLlena as error:
            return self._error(503, str(error))
        return self._json(
            202,
            {
                "id": identificador,
                "estado": "en_cola",
                "consultar": "/api/jobs/" + identificador,
            },
        )


def crear_servidor(host=None, puerto=None):
    config.JOBS_DIR.mkdir(parents=True, exist_ok=True)
    storage.limpiar_expirados()
    jobs.marcar_interrumpidos()
    _COLA.iniciar()
    direccion = (host or config.HOST, int(puerto or config.PORT))
    return ThreadingHTTPServer(direccion, Manejador)


def servir():
    servidor = crear_servidor()
    host, puerto = servidor.server_address[0], servidor.server_address[1]
    print("Conversor de modelos escuchando en http://" + str(host) + ":" + str(puerto))
    try:
        servidor.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        servidor.server_close()
