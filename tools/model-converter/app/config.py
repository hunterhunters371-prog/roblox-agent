"""Configuracion del conversor de modelos 3D.

Todos los limites se leen de variables de entorno para poder ajustarlos en el
despliegue sin tocar el codigo.
"""

import os
from pathlib import Path


def _entero(nombre, defecto):
    valor = os.environ.get(nombre)
    if valor is None or valor.strip() == "":
        return defecto
    try:
        return int(valor)
    except ValueError:
        return defecto


def _booleano(nombre, defecto):
    valor = os.environ.get(nombre)
    if valor is None:
        return defecto
    return valor.strip().lower() not in ("0", "false", "no", "off")


DATA_DIR = Path(os.environ.get("MC_DATA_DIR", "/data/model-converter"))
JOBS_DIR = DATA_DIR / "jobs"

HOST = os.environ.get("MC_HOST", "0.0.0.0")
PORT = _entero("PORT", _entero("MC_PORT", 8080))

MAX_UPLOAD_MB = _entero("MC_MAX_UPLOAD_MB", 100)
JOB_TIMEOUT = _entero("MC_JOB_TIMEOUT", 300)
JOB_TTL_HOURS = _entero("MC_JOB_TTL_HOURS", 24)
WORKERS = _entero("MC_WORKERS", 2)
MAX_TRIANGLES = _entero("MC_MAX_TRIANGLES", 3000000)
MAX_QUEUE = _entero("MC_MAX_QUEUE", 64)
MAX_ZIP_ENTRIES = _entero("MC_MAX_ZIP_ENTRIES", 500)
MAX_ZIP_MB = _entero("MC_MAX_ZIP_MB", 400)

PREVIEW = _booleano("MC_PREVIEW", True)
PREVIEW_WIDTH = _entero("MC_PREVIEW_WIDTH", 640)
PREVIEW_HEIGHT = _entero("MC_PREVIEW_HEIGHT", 480)
PREVIEW_MAX_TRIANGLES = _entero("MC_PREVIEW_MAX_TRIANGLES", 200000)

HEADLESS = _booleano("MC_HEADLESS", True)
HEADLESS_ESPERA_MS = _entero("MC_HEADLESS_ESPERA_MS", 4000)
HEADLESS_TIMEOUT_MS = _entero("MC_HEADLESS_TIMEOUT_MS", 90000)

EXTENSIONES_NATIVAS = {".glb", ".gltf", ".obj", ".stl", ".ply"}
EXTENSIONES_INCRUSTADAS = {".html", ".htm"}
EXTENSIONES_TRIMESH = {".dae", ".off", ".3mf", ".xyz"}
SALIDAS_VALIDAS = ("glb", "obj", "zip")


def hay_trimesh():
    """Indica si el backend opcional trimesh esta disponible."""
    try:
        import trimesh  # noqa: F401
    except Exception:
        return False
    return True


def hay_navegador():
    """Indica si la exportacion headless esta activa y el navegador instalado."""
    if not HEADLESS:
        return False
    try:
        from app import headless
    except Exception:
        return False
    return headless.disponible()


def extensiones_entrada():
    """Extensiones aceptadas en la subida, incluyendo HTML y empaquetado ZIP."""
    extensiones = set(EXTENSIONES_NATIVAS) | set(EXTENSIONES_INCRUSTADAS)
    if hay_trimesh():
        extensiones |= EXTENSIONES_TRIMESH
    extensiones.add(".zip")
    return extensiones


def resumen():
    """Resumen de limites y formatos para el endpoint de salud."""
    return {
        "version": __import__("app").__version__,
        "directorio_datos": str(DATA_DIR),
        "trabajadores": WORKERS,
        "limite_subida_mb": MAX_UPLOAD_MB,
        "limite_tiempo_s": JOB_TIMEOUT,
        "caducidad_horas": JOB_TTL_HOURS,
        "limite_triangulos": MAX_TRIANGLES,
        "limite_cola": MAX_QUEUE,
        "vista_previa": PREVIEW,
        "backend_trimesh": hay_trimesh(),
        "navegador_headless": hay_navegador(),
        "formatos_entrada": sorted(extensiones_entrada()),
        "formatos_salida": list(SALIDAS_VALIDAS),
    }
