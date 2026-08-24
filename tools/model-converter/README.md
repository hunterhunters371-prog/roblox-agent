# Conversor y extractor de modelos 3D

Servicio web que recibe un modelo 3D (o un ZIP con el modelo y sus texturas),
extrae la geometria y las texturas, y devuelve el resultado en GLB, en OBJ con
su MTL y sus imagenes, y en un ZIP con todo junto. Incluye una pagina web para
subir el archivo y descargar las salidas.

Solo necesita Python 3.12, NumPy y Pillow. `trimesh` es opcional y solo amplia
la lista de formatos de entrada.

## Puesta en marcha

```bash
cd tools/model-converter
pip install -r requirements.txt
python run.py
```

La pagina queda en `http://localhost:8080/`. El puerto se cambia con `PORT` o
`MC_PORT`. Arranca siempre con `run.py`, no con `python -m app.server`.

Con Docker:

```bash
docker compose up --build
```

En Render, el archivo `render.yaml` define el servicio: New > Blueprint, se
elige este repositorio y Render detecta el blueprint por si mismo.

## Formatos

| Direccion | Formatos |
|---|---|
| Entrada nativa | `.glb`, `.gltf`, `.obj`, `.stl`, `.ply`, `.zip` |
| Entrada con trimesh instalado | ademas `.dae`, `.off`, `.3mf`, `.xyz` |
| Salida | `glb`, `obj` (con `.mtl` y las texturas extraidas), `zip` |

Las texturas embebidas en un GLB se escriben como archivos PNG, JPG o WEBP
independientes. Las texturas referenciadas desde un OBJ dentro de un ZIP se
recuperan del propio paquete.

## API

| Metodo y ruta | Descripcion |
|---|---|
| `GET /` | pagina web de subida y descarga |
| `GET /api/health` | version, limites y formatos aceptados |
| `POST /api/jobs?filename=&outputs=` | crea un trabajo; el cuerpo es el archivo binario |
| `GET /api/jobs` | ultimos trabajos |
| `GET /api/jobs/<id>` | estado, cifras de geometria y archivos generados |
| `GET /api/jobs/<id>/log` | bitacora del trabajo |
| `GET /api/jobs/<id>/files/<nombre>` | descarga de un archivo de salida |
| `DELETE /api/jobs/<id>` | borra el trabajo y sus archivos |

Ejemplo:

```bash
curl -X POST --data-binary @modelo.glb \
  'http://localhost:8080/api/jobs?filename=modelo.glb&outputs=glb,obj,zip'
```

## Configuracion

| Variable | Valor por omision | Efecto |
|---|---|---|
| `MC_DATA_DIR` | `/data/model-converter` | raiz de los trabajos |
| `PORT` / `MC_PORT` | `8080` | puerto de escucha |
| `MC_HOST` | `0.0.0.0` | interfaz de escucha |
| `MC_MAX_UPLOAD_MB` | `100` | tamano maximo de subida |
| `MC_JOB_TIMEOUT` | `300` | limite en segundos por conversion |
| `MC_JOB_TTL_HOURS` | `24` | caducidad de los trabajos |
| `MC_WORKERS` | `2` | conversiones en paralelo |
| `MC_MAX_TRIANGLES` | `3000000` | limite de geometria |
| `MC_MAX_QUEUE` | `64` | trabajos en espera |
| `MC_MAX_ZIP_ENTRIES` | `500` | entradas por ZIP de entrada |
| `MC_MAX_ZIP_MB` | `400` | tamano descomprimido maximo |
| `MC_PREVIEW` | `1` | genera `vista_previa.png` |

## Pruebas

```bash
cd tools/model-converter
python -m unittest discover -s tests -t . -v
python tests/generar_modelo_prueba.py /tmp/cubo.glb
```

## Seguridad

- Los nombres de archivo recibidos se sanean y se reducen a su parte final.
- Las descargas se resuelven contra el directorio del trabajo; cualquier ruta
  que se salga devuelve 404.
- La extraccion de ZIP descarta rutas absolutas y componentes `..`, y aplica
  limites de numero de entradas y de tamano descomprimido.
- Las extensiones no soportadas se rechazan con 400 antes de escribir nada.
- Cada conversion corre en un proceso aparte con limite de tiempo.

## Limitaciones conocidas

- No se admite FBX ni otros formatos propietarios.
- Los materiales se simplifican a color base y textura de color.
- No se conservan animaciones ni esqueletos; la jerarquia de nodos se aplana.
- La vista previa es estatica, de una sola camara y con sombreado plano.
- En el plan gratuito de Render el disco es efimero: los trabajos se pierden en
  cada despliegue y caducan a las 24 horas.
- La cola vive en memoria; al reiniciar, los trabajos en vuelo se marcan como
  interrumpidos.
