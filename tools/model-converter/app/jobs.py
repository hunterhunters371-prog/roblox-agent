"""Cola de trabajos en memoria con ejecucion en subprocesos.

La cola es deliberadamente simple: no hay base de datos ni broker externo. El
estado duradero de cada trabajo vive en su directorio, asi que un reinicio solo
pierde los trabajos que estaban en vuelo, y esos se marcan como interrumpidos.
"""

import queue
import subprocess
import sys
import threading
import time
from pathlib import Path

from app import config, storage


class ColaLlena(Exception):
    """La cola ha alcanzado el maximo de trabajos pendientes."""


class Cola:
    def __init__(self, trabajadores=None, maximo=None):
        self._cola = queue.Queue(maxsize=int(maximo or config.MAX_QUEUE))
        self._trabajadores = int(trabajadores or config.WORKERS)
        self._hilos = []
        self._activo = False
        self._candado = threading.Lock()

    def iniciar(self):
        with self._candado:
            if self._activo:
                return
            self._activo = True
            for numero in range(self._trabajadores):
                hilo = threading.Thread(
                    target=self._bucle, name="conversor-" + str(numero), daemon=True
                )
                hilo.start()
                self._hilos.append(hilo)

    def encolar(self, identificador):
        directorio = storage.directorio_trabajo(identificador)
        try:
            self._cola.put_nowait(identificador)
        except queue.Full:
            storage.actualizar_estado(
                directorio, estado="fallido", error="La cola de conversion esta llena"
            )
            raise ColaLlena("La cola de conversion esta llena")
        storage.actualizar_estado(
            directorio, estado="en_cola", posicion=self._cola.qsize()
        )
        return identificador

    def pendientes(self):
        return self._cola.qsize()

    def _bucle(self):
        while True:
            identificador = self._cola.get()
            try:
                self._ejecutar(identificador)
            except Exception:  # noqa: BLE001
                pass
            finally:
                self._cola.task_done()

    def _ejecutar(self, identificador):
        directorio = storage.directorio_trabajo(identificador)
        raiz = Path(__file__).resolve().parent.parent
        orden = [sys.executable, "-m", "app.worker", str(directorio)]
        try:
            proceso = subprocess.run(
                orden,
                cwd=str(raiz),
                capture_output=True,
                timeout=config.JOB_TIMEOUT,
            )
        except subprocess.TimeoutExpired:
            storage.registrar(
                directorio,
                "ERROR: tiempo limite de " + str(config.JOB_TIMEOUT) + " s superado",
            )
            storage.actualizar_estado(
                directorio,
                estado="fallido",
                error="Tiempo limite de conversion superado",
                fin=time.time(),
            )
            return
        if proceso.returncode != 0:
            salida = (proceso.stderr or b"").decode("utf-8", "replace").strip()
            if salida:
                storage.registrar(directorio, "Salida del proceso: " + salida[-2000:])
            estado = storage.leer_estado(directorio)
            if estado.get("estado") != "fallido":
                storage.actualizar_estado(
                    directorio,
                    estado="fallido",
                    error="El proceso de conversion termino con codigo "
                    + str(proceso.returncode),
                    fin=time.time(),
                )


def marcar_interrumpidos():
    """Al arrancar, cierra los trabajos que quedaron a medias en el reinicio."""
    marcados = 0
    for estado in storage.listar_trabajos(limite=500):
        if estado.get("estado") in ("en_cola", "procesando"):
            try:
                directorio = storage.directorio_trabajo(estado["id"])
            except storage.TrabajoNoEncontrado:
                continue
            storage.actualizar_estado(
                directorio,
                estado="fallido",
                error="Interrumpido por un reinicio del servicio",
            )
            marcados += 1
    return marcados
