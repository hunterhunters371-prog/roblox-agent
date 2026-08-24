# Conversor y extractor de modelos 3D en Cloud Shell

## Que vas a hacer

Arrancar el servicio que extrae geometria y texturas de un modelo 3D y lo
convierte a GLB, a OBJ con su MTL y a un ZIP con todo junto.

## Paso 1: arrancar el servicio

Ejecuta en la terminal:

```bash
cd tools/model-converter
chmod +x arrancar.sh
./arrancar.sh
```

El script crea `.venv`, instala NumPy y Pillow, corre las 13 pruebas y deja el
servidor escuchando en el puerto `8080`.

## Paso 2: abrir la pagina de extraccion

Pulsa el boton **Vista previa web** (icono de ojo, arriba a la derecha de Cloud
Shell) y elige **Vista previa en el puerto 8080**. Se abre la pagina de subida.

Si el boton pide otro puerto: **Cambiar puerto** y escribe `8080`.

## Paso 3: convertir un modelo

Arrastra un `.glb`, `.gltf`, `.obj`, `.stl`, `.ply` o un `.zip` con el modelo y
sus texturas. Marca las salidas que quieras y descarga el resultado.

Sin archivo a mano, genera un cubo de prueba en otra pestana de la terminal:

```bash
cd tools/model-converter
source .venv/bin/activate
python tests/generar_modelo_prueba.py ~/cubo.glb
```

Descarga `~/cubo.glb` desde el menu de tres puntos del editor y subelo a la
pagina.

## Paso 4: usar la API sin navegador

```bash
curl -X POST --data-binary @~/cubo.glb \
  'http://localhost:8080/api/jobs?filename=cubo.glb&outputs=glb,obj,zip'
curl http://localhost:8080/api/jobs
```

## Limites de Cloud Shell

- La maquina se apaga tras un rato sin uso y el disco `$HOME` se borra a los
  120 dias de inactividad.
- Los trabajos caducan a las 24 horas por configuracion del propio servicio.
- Cloud Shell no admite FBX ni formatos propietarios; eso es limitacion del
  conversor, no del entorno.

## Detener

`Ctrl+C` en la terminal donde corre `arrancar.sh`.
