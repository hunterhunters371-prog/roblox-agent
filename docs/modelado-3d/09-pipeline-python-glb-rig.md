# Pipeline de modelado 3D por script, con rig, para EGGBOUND

Documento operativo autosuficiente. Describe como producir un asset 3D
texturizado, riggeado y verificado usando solo Python 3, NumPy y Pillow, sin
red, sin GPU y sin ninguna herramienta grafica. Esta escrito para que otra
inteligencia artificial lo ejecute de principio a fin sin conocimiento previo
del proyecto.

Extiende `roles/modelador-3d-proceso.md` del repositorio `maximizador-ia`
anadiendo la parte que ese documento no cubria: el rig.

Verificado el 2026-08-24 produciendo `chicken_base.glb`: 20 mallas, 790
vertices, 632 triangulos, 13 huesos, 12 animaciones, atlas de 1024 x 1024
embebido, 191 972 bytes, 0 caras invertidas.

## 1. Estructura de archivos

Todo el asset vive en dos archivos de texto y se reconstruye entero con un
solo comando. Nunca se edita el binario a mano.

| Archivo | Responsabilidad |
|---|---|
| `kit.py` | primitivas, atlas, rig, rasterizador, exportador GLB, validador. No conoce ningun asset. |
| `<asset>.py` | contrato, paleta, medidas, esqueleto, poses. Solo llama al kit. |

```bash
cd <directorio del asset> && python3 chicken.py --poses
```

## 2. Fase 0 - Contrato del asset

Sin cifras acordadas no hay criterio de aceptacion. Contrato verificado del
Chicken base:

| Dato | Valor |
|---|---|
| Destino | Roblox Studio, tiempo real |
| Unidad y escala | studs; 2,28 ancho x 4,20 alto x 3,07 largo |
| Eje vertical | Y positivo |
| Origen | centrado en X y Z, base apoyada en Y = 0 |
| Presupuesto de triangulos | 1 500 |
| Resolucion de textura | 1024 x 1024, atlas unico de 16 celdas |
| Formato de entrega | glTF 2.0 binario con PNG embebido |
| Rig | 13 huesos, skinning rigido de una pieza por hueso |
| Estilo | voxel / low poly, sin biseles |

Regla de origen: se construye en coordenadas de diseno comodas y al final se
recentra todo con un unico desplazamiento aplicado a las mallas **y a los
huesos**. Si se recentran las mallas y no el esqueleto, el rig queda desfasado
respecto a la geometria y las rotaciones pivotan en el aire.

```python
def recentrar(meshes, rig):
    lo, hi = kit.bbox(meshes)
    dx = -(lo[0] + hi[0]) / 2.0
    dy = -lo[1]
    dz = -(lo[2] + hi[2]) / 2.0
    for m in meshes:
        m.P = [(x + dx, y + dy, z + dz) for (x, y, z) in m.P]
    for n in rig.nombres:
        x, y, z = rig.pos[n]
        rig.pos[n] = (x + dx, y + dy, z + dz)
    return (dx, dy, dz)
```

## 3. Fase 1 - Vistas de referencia

**Si el humano puede entregar la hoja de vistas ortograficas, hay que pedirla
siempre.** No es un lujo: es lo que fija la silueta y las proporciones antes
de gastar esfuerzo en geometria. Modelar contra una referencia incompleta es
la causa mas comun de rehacer el asset entero.

Lo minimo util por asset:

1. Frente ortografico, sin perspectiva.
2. Lateral ortografico.
3. Espalda, aunque sea esquematica. Es la vista que la IA inventa cuando falta.
4. Tres cuartos, para la lectura de silueta a distancia.
5. Rejilla de unidades con la equivalencia declarada, por ejemplo
   `1 u = 1 bloque base` y el alto total en unidades.
6. Paleta con codigos hexadecimales exactos.
7. Desglose de partes con nombre, si el modelo debe ser modular.

Con las cuatro vistas ortograficas la exactitud sube mucho porque cada medida
se lee directamente en vez de estimarse desde una perspectiva. Sin la vista
trasera y sin la rejilla de unidades, lo que se pierde primero es la
proporcion entre volumenes y la profundidad de las piezas que sobresalen
(pico, cola, alas).

## 4. Fase 2 - Atlas procedural

Rejilla de 4 x 4 celdas de 256 px sobre un lienzo de 1024 x 1024, con
`PAD = 10` px de margen interno por celda.

```python
def uv_celda(nombre):
    col, fila = _CELDAS[nombre]
    u0 = (col * CELDA + PAD) / float(ATLAS)
    v0 = (fila * CELDA + PAD) / float(ATLAS)
    u1 = ((col + 1) * CELDA - PAD) / float(ATLAS)
    v1 = ((fila + 1) * CELDA - PAD) / float(ATLAS)
    return u0, v0, u1, v1
```

Reglas verificadas:

1. Solo rasgos grandes y suaves. El ruido se genera en 8 x 8 y se amplia por
   interpolacion bicubica a 256 x 256. El detalle de alta frecuencia
   desaparece por moire de minificacion.
2. Para oscurecer, un unico factor para los tres canales RGB.
3. Nada de iluminacion horneada en el albedo.
4. **No usar una celda oscura de "sombra" en las caras traseras de las
   piezas.** Es tentador para dar volumen y es un error: el motor ya oscurece
   esas caras con su propia luz, y el resultado es un modelo que se ve gris
   sucio desde atras. Defecto observado y corregido en la ronda 1 del Chicken
   base.

## 5. Fase 3 - Primitivas

```python
caja(nombre, cel, w, h, d, centro, mat="general", hueso=None, cel_caras=None)
placa(nombre, cel, w, h, centro, eje="z", flip=False, mat="general", hueso=None)
fusionar(nombre, cel, mat, hueso, piezas)   # varias cajas en una pieza logica
```

Cada cuadrilatero se triangula en abanico desde el **centroide**, no desde una
esquina: cinco vertices y cuatro triangulos por cara. Una caja cuesta 24
triangulos. El abanico desde esquina genera triangulos largos y finos que
aparecen como costuras diagonales de sombreado.

`fusionar` permite que un racimo de cubos (cresta, cola, ala con escalon) sea
una sola pieza logica movida por un solo hueso, respetando el presupuesto de
15 a 20 partes de la hoja de referencia.

Reglas de composicion: las piezas que se solapan deben **interpenetrarse** de
verdad, no quedar coplanares ni separadas. Dos caras coplanares producen
z-fighting; una pieza que solo toca el borde se lee como flotante. En el
Chicken base las alas penetran 0,05 studs en el cuerpo y el primer cubo de la
cola penetra 0,35 studs.

Sellado del interior obligatorio: `Relleno_Interior`, una caja maciza oscura
algo menor que el cuerpo. Cuesta 24 triangulos y elimina la clase entera de
defectos de interior visible.

## 6. Fase 4 - Rig

Esta fase es la ampliacion nueva del proceso. Un rig es posible sin ninguna
herramienta externa porque el GLB se escribe byte a byte.

### Esqueleto

```python
class Rig:
    def hueso(self, nombre, pos, padre=None)   # pos en coordenadas globales
    def local(self, nombre)                    # traslacion relativa al padre
    def hijos(self, nombre)
```

Esqueleto verificado del Chicken base, 13 huesos:

| Hueso | Posicion (studs, antes de recentrar) | Padre | Piezas que mueve |
|---|---|---|---|
| `Root` | 0,00  0,00  0,00 | - | (raiz) |
| `Torso` | 0,00  1,05  0,00 | Root | Cuerpo, Relleno_Interior |
| `Head` | 0,00  2,56  0,20 | Torso | Cabeza, Cresta, Ojos, Brillos, Pico_Superior, Barbilla |
| `Beak` | 0,00  2,86  1,00 | Head | Pico_Inferior |
| `WingL` | -0,93  2,20  -0,05 | Torso | Ala_Izq |
| `WingR` | 0,93  2,20  -0,05 | Torso | Ala_Der |
| `Tail` | 0,00  2,00  -0,85 | Torso | Cola |
| `ThighL` | -0,44  0,95  0,00 | Root | Muslo_Izq |
| `ShinL` | -0,44  0,58  0,00 | ThighL | Cana_Izq |
| `FootL` | -0,44  0,22  0,00 | ShinL | Pie_Izq |
| `ThighR` | 0,44  0,95  0,00 | Root | Muslo_Der |
| `ShinR` | 0,44  0,58  0,00 | ThighR | Cana_Der |
| `FootR` | 0,44  0,22  0,00 | ShinR | Pie_Der |

Criterio de diseno del esqueleto: un hueso por cada parte que la hoja de
referencia declara como modular, mas los intermedios que exigen las
animaciones. El pico inferior tiene hueso propio porque abrir el pico aparece
en Attack, Angry, Happy, Death y Special.

### Skinning rigido

En un modelo voxel cada pieza es solida y no se deforma, asi que cada vertice
recibe un unico hueso con peso 1,0. Es la forma mas simple de skin valido y
evita por completo los artefactos de deformacion en articulaciones.

```python
J = np.zeros((len(P), 4), dtype=np.uint16)
J[:, 0] = indice_del_hueso_en_el_array_joints
W = np.zeros((len(P), 4), dtype=np.float32)
W[:, 0] = 1.0
attrs["JOINTS_0"] = acc(J, 5123, "VEC4")
attrs["WEIGHTS_0"] = acc(W, 5126, "VEC4")
```

Detalle que rompe el rig si se equivoca: `JOINTS_0` guarda el indice del hueso
**dentro del array `joints` del skin**, no el indice del nodo en `nodes`. Si se
usa el indice de nodo, el modelo se deforma de forma absurda al reproducir
cualquier animacion.

### Matrices inversas de bind

En bind pose los huesos solo tienen traslacion, asi que la matriz global de un
hueso es una traslacion y su inversa es la traslacion negada. glTF almacena
las matrices en orden por columnas.

```python
M = np.eye(4, dtype=np.float32)
M[0, 3], M[1, 3], M[2, 3] = -x, -y, -z
ibm.append(M.T.reshape(-1))   # transponer: glTF es column-major
```

### Animaciones

Cada canal apunta a `node.rotation` de un hueso, con un sampler LINEAR de
quaterniones. Las poses se declaran como angulos de Euler por hueso y se
convierten a quaternion.

```python
def quat_eje(eje, ang):
    s, c = math.sin(ang / 2.0), math.cos(ang / 2.0)
    return {"x": (s, 0, 0, c), "y": (0, s, 0, c), "z": (0, 0, s, c)}[eje]
```

Doce animaciones exportadas y verificadas en el binario: `Idle`, `Walk`,
`Run`, `Jump`, `Fall`, `Attack`, `Hurt`, `Dodge`, `Death`, `Happy`, `Angry`,
`Special`. Los ciclos de locomocion se construyen con la pose y su espejo
izquierda/derecha, para que el bucle cierre:

```python
claves = [(0.0, reposo), (0.25, pose), (0.5, reposo), (0.75, espejo(pose)), (1.0, reposo)]
```

Al reflejar, los ejes Y y Z de la rotacion cambian de signo y los huesos
izquierda/derecha se intercambian; el eje X se conserva.

### Convenciones de ejes de las poses

| Movimiento | Hueso | Eje | Signo positivo |
|---|---|---|---|
| inclinar el cuerpo adelante | Torso | X | hacia adelante |
| levantar la pata | ThighL/R | X | adelante |
| doblar la rodilla | ShinL/R | X | atras |
| abrir el ala | WingL/R | Z | signos opuestos entre lados |
| abrir el pico | Beak | X | abajo |
| girar la cabeza | Head | Y | a su izquierda |
| caer de lado (muerte) | Root | Z | 1,58 rad ~ 90 grados |

## 7. Fase 5 - Orientacion de las caras

Obligatoria y sin excepciones. Se llama una vez sobre la lista completa, justo
antes de exportar, y se imprime el numero de caras giradas.

```python
def arreglar_winding(meshes):
    total = 0
    for m in meshes:
        P, N = np.array(m.P, float), np.array(m.N, float)
        for i in range(0, len(m.I), 3):
            a, b, c = m.I[i], m.I[i+1], m.I[i+2]
            cr = np.cross(P[b]-P[a], P[c]-P[a])
            if float(np.dot(cr, N[a]+N[b]+N[c])) < 0:
                m.I[i+1], m.I[i+2] = c, b
                total += 1
    return total
```

En el Chicken base devolvio 0 porque los constructores del kit ya emiten los
quads en sentido antihorario visto desde fuera. Se ejecuta igualmente: cubre
cualquier primitiva futura sin volver a razonar sobre el orden de vertices.

## 8. Fase 6 - Control de calidad con z-buffer

El rasterizador es la unica forma de ver el asset antes de entregarlo, y debe
parecerse al motor, no ser mas permisivo que el motor.

Requisitos no negociables:

1. **Z-buffer por pixel.** Un buffer de profundidad del tamano del lienzo y
   una comparacion por pixel. Ordenar caras por profundidad de su centro no
   basta: con piezas que se interpenetran el orden es incorrecto para parte de
   los pixeles y aparecen solapes imposibles. Este era el defecto principal de
   las entregas anteriores.
2. **Backface culling en espacio de mundo**, contra el vector del vertice a la
   camara, no con el signo del area en pantalla:

   ```python
   if float(np.dot(np.cross(B0 - A0, C0 - A0), ojo - A0)) <= 0:
       continue
   ```
3. **Interpolacion de UV con correccion de perspectiva.** Se interpola u/z,
   v/z y 1/z y se multiplica por la z reconstruida; interpolar u y v
   directamente curva la textura en caras vistas en angulo.
4. Luz direccional con la normal de la cara y un ambiente de 0,42.

Parametros verificados: lienzo de 460 x 520 por vista, fondo (150, 152, 158),
campo de vision 34 grados, objetivo en el centro vertical del bbox, distancia
base 9,6 studs para un modelo de 4,2 studs de alto.

Juego de ocho vistas. Las cuatro primeras muestran el diseno; las cuatro
siguientes delatan los defectos de orientacion e interior y no se pueden
omitir:

| Vista | Azimut | Elevacion | Factor de distancia |
|---|---|---|---|
| frente | 22 | 12 | 1,00 |
| tres cuartos | 40 | 16 | 1,00 |
| perfil | 90 | 8 | 1,00 |
| espalda | 180 | 12 | 1,00 |
| cenital | 20 | 52 | 0,95 |
| alto trasero | 200 | 46 | 0,95 |
| picado | 34 | 34 | 0,89 |
| contrapicado | 10 | -20 | 0,95 |

Ademas, con rig se anade una segunda tira: **una vista por animacion**,
aplicando la pose en CPU con las mismas matrices jerarquicas que usara el
motor. Sin esta tira el rig se entrega sin comprobar y las poses extremas
(Death, Special) revelan errores de pivote solo dentro del motor.

```python
def aplicar_pose(meshes, rig, pose):
    # L = rotar alrededor del pivote propio; global = global(padre) . L
    L[:3, :3] = R
    L[:3, 3] = pivote - R.dot(pivote)
```

Criterio de aprobacion: en ninguna vista se ve el interior, ninguna pieza
flota, ninguna pieza se solapa de forma imposible, todos los elementos de la
hoja de referencia son reconocibles y la silueta se lee a tamano pequeno.

## 9. Fase 7 - Exportacion a GLB

Cabecera de 12 bytes con magia `0x46546C67`, fragmento JSON `0x4E4F534A`
relleno con espacios hasta multiplo de 4, fragmento binario `0x004E4942`
relleno con ceros. Un unico buffer con los datos de todas las mallas, las
matrices inversas de bind, los samplers de animacion y, al final, los bytes
del PNG del atlas.

El nodo de cada malla riggeada lleva `"skin": 0`. Los nodos raiz del esqueleto
y los nodos de malla se listan en la escena; el nodo de la malla no debe ser
hijo de un hueso.

Materiales del Chicken base: `general` y `interior`, ambos opacos, rugosidad
0,90 y 0,95, metalicidad 0, `doubleSided: false`. Mezcla declarada solo en
materiales translucidos; declararla en opacos activa ordenacion por
transparencia y produce parpadeos de orden de dibujado.

## 10. Fase 8 - Validacion del binario entregado

Se valida el archivo que se entrega, reabriendolo y leyendo sus accessors. El
modelo intermedio puede estar bien y el exportador estropearlo.

Salida verificada del Chicken base:

```
caras reorientadas: 0
mallas: 20  vertices: 790  triangulos: 632
recentrado (dx, dy, dz): -0.000 -0.000 0.115
caras invertidas tras corregir: 0
bbox studs: X 2.28  Y 4.20  Z 3.07 | base en Y=0.000
GLB: 191972 bytes
magic: glTF | version: 2 | bytes: 191972 | coincide: True
primitivas: 20 | triangulos: 632 | presupuesto 1500: OK
caras invertidas en el GLB: 0
sin normales: 0 | sin UV: 0
materiales: 2 | imagenes embebidas: 1
huesos: 13 | animaciones: 12 -> Walk, Run, Idle, Jump, Fall, Attack, Hurt, Dodge, Death, Happy, Angry, Special
bbox studs: (2.28, 4.2, 3.07) | base en Y=0.000 | centro XZ: (0.0, 0.0)
aristas abiertas (soldadas): 8
```

Las 8 aristas abiertas son las dos placas planas de brillo de los ojos, que
son superficies por diseno. Cualquier otro valor exige investigacion.

Comprobaciones anadidas al validador respecto al proceso original:

- `huesos`: numero de joints del skin, mayor que cero si el asset lleva rig.
- `animaciones` y sus nombres, leidos del binario.
- `centrado_xz`: debe ser (0,0) exacto.

## 11. Lista de verificacion final

- [ ] Vistas de referencia disponibles y aprobadas antes de modelar.
- [ ] Escala, eje vertical y origen conformes al contrato.
- [ ] Base apoyada exactamente en Y = 0 y modelo centrado en X y Z.
- [ ] Recentrado aplicado tambien al esqueleto.
- [ ] Triangulos dentro del presupuesto.
- [ ] Caras invertidas en el binario: 0.
- [ ] Interior sellado con bloque macizo.
- [ ] Primitivas sin normales: 0. Sin coordenadas de textura: 0.
- [ ] Atlas con margen por celda, sin iluminacion horneada, sin celdas de
      sombra en caras traseras.
- [ ] Piezas interpenetradas, no coplanares ni flotantes.
- [ ] Ocho vistas renderizadas con z-buffer y culling, aprobadas.
- [ ] Una vista por animacion, aprobada.
- [ ] `JOINTS_0` con indices del array joints, no de nodes.
- [ ] Imagen embebida en el GLB: al menos 1.

## 12. Catalogo de fallos nuevos verificados

Se anaden a los catorce del proceso original.

15. **`AttributeError: 'numpy.ndarray' object has no attribute 'ptp'`.**
    Correccion: `float(np.ptp(x))` en vez de `x.ptp()`. Ocurrio en la primera
    ejecucion de este pipeline.
16. **`RuntimeWarning: invalid value encountered in cast` al muestrear UVs.**
    El z reconstruido valia infinito en pixeles degenerados y `inf * 0` daba
    NaN al convertir a indice de textura. Correccion: sustituir el infinito
    por un valor finito grande (`1e9`) en el buffer de profundidad.
17. **Modelo gris sucio visto desde atras.** Se habia asignado una celda de
    atlas oscura a las caras traseras. Correccion: una sola celda de color por
    volumen; el sombreado lo aporta la luz.
18. **Pieza que se lee como flotante aunque toque el cuerpo.** Contacto
    tangente en vez de interpenetracion. Correccion: penetrar entre 0,05 y
    0,35 studs segun el tamano de la pieza.
19. **Cola o apendice que se lee como escalera desconectada.** Cubos
    consecutivos con demasiado desplazamiento respecto a su tamano.
    Correccion: el desplazamiento entre cubos consecutivos no debe superar la
    mitad del lado del cubo mas pequeno de los dos.
20. **Rig desfasado respecto a la geometria.** Se recentro la malla y no el
    esqueleto. Correccion: un unico desplazamiento aplicado a ambos.

## 13. Bucle de iteracion

Regenerar con un solo comando, mirar las dos tiras de control de calidad,
anotar los defectos concretos, corregir el script, repetir. No se pasa a la
siguiente fase con defectos abiertos. Tras cada edicion encadenada, comprobar
con `grep -n` que el cambio sigue presente.

## 14. Entrega

Se entregan cinco cosas, nunca el `.glb` a secas:

1. El archivo `.glb` con textura embebida.
2. La tira de ocho vistas de control de calidad.
3. La tira de una vista por animacion.
4. Las cifras de la validacion del binario.
5. Los dos scripts, `kit.py` y `<asset>.py`, que reconstruyen todo.

Importacion en Roblox Studio: borrar la version anterior antes de importar (el
importador no reemplaza en sitio) y activar «Anclado» en el dialogo, que viene
desactivado. Para un asset riggeado, importar como malla con esqueleto: los 13
huesos entran como `Bone` dentro del `MeshPart` y las animaciones se
reproducen con un `Animator`.
