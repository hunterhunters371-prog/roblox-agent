# Pruebas de entorno para modelado 3D

Ejecutadas el 2026-08-24 en el sandbox de trabajo, antes de volver a modelar.
Motivo: el resultado de las primeras entregas quedo por debajo de las hojas de
referencia y habia que saber que herramientas existen de verdad antes de
elegir el pipeline.

## Comando

```bash
python3 -c "
import importlib
mods=['numpy','PIL','scipy','trimesh','pyrender','moderngl','pygltflib','OpenGL','vtk','open3d','matplotlib','skimage','shapely']
for m in mods:
    try:
        mod=importlib.import_module(m); print(' OK  ',m, getattr(mod,'__version__','?'))
    except Exception: print(' --  ',m)
"
for b in blender openscad meshlab meshlabserver assimp xvfb-run glxinfo convert ffmpeg; do command -v $b >/dev/null 2>&1 && echo " OK   $b" || echo " --   $b"; done
node -e "const m=['three','gl','canvas','sharp','playwright','gltf-pipeline','@gltf-transform/core'];for(const x of m){try{require.resolve(x);console.log(' OK  ',x)}catch(e){console.log(' --  ',x)}}"
ls /dev/dri
```

## Resultado

| Categoria | Disponible | Ausente |
|---|---|---|
| Python 3D | numpy 2.5.2, PIL 12.3.0, matplotlib 3.11.1 | scipy, trimesh, pyrender, moderngl, pygltflib, PyOpenGL, vtk, open3d, skimage, shapely |
| Binarios | ImageMagick (`convert`), ffmpeg | blender, openscad, meshlab, assimp, xvfb-run, glxinfo |
| Node | sharp, playwright | three, gl, canvas, gltf-pipeline, gltf-transform |
| GPU | ninguna (`/dev/dri` no existe) | |
| Red | ninguna (`Name or service not known`) | |

## Conclusiones que fijan el pipeline

1. No hay ninguna biblioteca 3D ni motor de render instalado, no hay GPU y no
   hay red para instalar nada. Cualquier plan que dependa de Blender, three.js
   o un visor WebGL esta descartado desde el principio.
2. El entorno cumple exactamente el requisito minimo del proceso del
   maximizador: Python 3 con NumPy y Pillow. Por tanto el pipeline correcto es
   el ya verificado en `roles/modelador-3d-proceso.md`: geometria escrita como
   codigo, atlas procedural, rasterizador propio con z-buffer y exportacion a
   glTF binario escrito byte a byte.
3. Escribir el GLB a mano no es una limitacion: es lo que permite anadir un
   rig completo (huesos, skin y animaciones) sin ninguna dependencia externa.

## Causa raiz del resultado inferior en las entregas anteriores

Las entregas del paquete, la bicicleta y la primera version del pollo se
hicieron con un motor propio en JavaScript sobre Canvas 2D, no con el pipeline
de este repositorio. Ese motor tenia tres defectos estructurales:

1. **Sin z-buffer.** Ordenaba las caras por la profundidad del centro de cada
   cara (algoritmo del pintor). Con piezas que se interpenetran, como alas y
   cola contra el cuerpo, el orden es incorrecto para parte de los pixeles y
   aparecen solapes imposibles. Es el defecto visible mas grave y no se puede
   corregir ajustando la camara.
2. **Entregable equivocado.** Producia un HTML con un visor, no un asset. Un
   HTML no se importa en Studio, no tiene escala, ni pivote, ni materiales, ni
   se puede riggear.
3. **Control de calidad no equivalente al motor.** El visor dibujaba caras a
   dos lados en algunos casos, que es exactamente la practica prohibida por el
   punto 14 del rol y por el fallo 12 del catalogo.

Correccion aplicada: se abandona el motor JavaScript para produccion de assets
y se usa el pipeline Python/GLB descrito en
`docs/modelado-3d/09-pipeline-python-glb-rig.md`.
