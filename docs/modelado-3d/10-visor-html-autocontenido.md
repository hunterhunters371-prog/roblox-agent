# 10. Visor HTML autocontenido

Regla del proyecto: todo asset 3D se entrega con un visor `.html` de un solo
archivo, sin recursos externos. El `.py` que genera el modelo y el `.glb` son
material de trabajo; el entregable que se abre y se mira es el HTML.

Motivo: un `.py` no se abre, se ejecuta, y exige Python, dependencias, los
modulos vecinos y una terminal. El HTML se abre con doble clic en cualquier
maquina, tambien en un movil.

## 10.1 Que va dentro del archivo

| Contenido | Formato |
| --- | --- |
| Geometria de cada pieza | JSON en `<script type="application/json">`: `P`, `N`, `UV`, `I` |
| Hueso de cada pieza | nombre del hueso en el JSON de la pieza |
| Esqueleto | nombre, padre, posicion global y cadena de raiz a hoja |
| Animaciones | lista de claves `(tiempo, {hueso: [rx, ry, rz]})` |
| Atlas de textura | PNG en base64, `data:` URI |
| Tiras de control de calidad | JPEG en base64, reducidas al 60 por ciento |
| CSS y JavaScript | en linea |

Prohibido: `<script src="https://...">`, `<link rel="stylesheet">` externo,
rutas relativas a archivos vecinos, fuentes descargadas y bibliotecas 3D de un
CDN. El generador aborta si detecta `src="http`, `href="http`, `<link`,
`src="./` o `src="/` en la salida.

Dos motivos: el entorno de construccion no tiene red, asi que un archivo con
dependencias externas no se puede ni probar; y un CDN que cambia una ruta deja
el entregable roto sin que nadie haya tocado nada.

## 10.2 Dos dibujantes

WebGL no esta garantizado. Comprobado en este entorno: sin GPU real, el
proceso grafico de Chromium muere con `exit_code=11`, `GPU process exited
unexpectedly`, y `getContext("webgl")` devuelve `null`.

1. **WebGL** cuando el navegador lo concede. Dos shaders; posiciones y
   normales se transforman en la CPU cada cuadro y se suben como
   `DYNAMIC_DRAW`. Con 1080 vertices el coste es irrelevante y ahorra el
   skinning en el shader.
2. **Rasterizador de software** en canvas 2D cuando WebGL falla. Z-buffer por
   pixel, baricentricas corregidas por perspectiva, descarte de caras traseras
   por el signo del area en pantalla, muestreo del atlas reducido a 512 y luz
   plana por triangulo. Resolucion interna a la mitad del lienzo.

El camino de software no es un adorno: es lo que permite comprobar el archivo
en un entorno sin GPU. El visor indica en pantalla el camino en uso y acepta
`?software=1` para forzar el segundo. Sin ese conmutador el respaldo no se
prueba nunca.

## 10.3 Trampas concretas

- **Nada de painter's algorithm.** Con piezas que se interpenetran a
  proposito, ordenar por profundidad media produce solapes segun el orden de
  dibujo. Z-buffer por pixel en los dos caminos.
- **Signo del area.** Con el eje Y hacia abajo, un triangulo antihorario en el
  mundo sale con area negativa: esa es la cara frontal. Con el criterio
  invertido se ve el interior del modelo.
- **Cadena de huesos de raiz a hoja.** `M = M * local(hueso)` recorriendo la
  cadena en ese orden, y cada local gira alrededor de su pivote con
  `t = pivote - R * pivote`. Al reves, el modelo gira alrededor del hijo.
- **UV sin voltear.** El atlas viene de Pillow, con el origen arriba a la
  izquierda, igual que una textura cargada sin `UNPACK_FLIP_Y`.
- **Interpolacion suavizada** con `u*u*(3-2*u)`; la lineal tironea en cada
  clave y se confunde con un defecto del rig.
- **Descarte de caras traseras activado por defecto**, como el motor. La
  casilla existe para diagnosticar, no para tapar caras mal orientadas.

## 10.4 Comprobacion obligatoria

En un entorno sin GPU, con el Chromium del sistema:

```
chromium --headless=new --no-sandbox --disable-dev-shm-usage --disable-gpu \
  --hide-scrollbars --window-size=1280,900 --virtual-time-budget=9000 \
  --screenshot=qa_visor.png file:///ruta/asset.html

chromium --headless=new --no-sandbox --disable-dev-shm-usage --disable-gpu \
  --hide-scrollbars --window-size=1280,900 --virtual-time-budget=12000 \
  --screenshot=qa_visor_soft.png "file:///ruta/asset.html?software=1"
```

Notas del entorno: `npx playwright install` no sirve porque no hay red, y el
navegador de Playwright no esta descargado. El Chromium del sistema esta en
`/usr/local/bin/chromium`. Con `--disable-gpu` se obtiene WebGL por
SwiftShader; sin esa bandera el proceso grafico se cae.

Las dos capturas se revisan a ojo antes de entregar. Si una de las dos sale
vacia, el entregable no esta listo.

## 10.5 Registro: Base Chicken de la hoja "EGGBOUND ASSET GUIDE"

Segunda hoja de referencia del pollo, distinta de la anterior. Diferencias
aplicadas al modelo:

| Elemento | Hoja anterior | Hoja nueva |
| --- | --- | --- |
| Cresta | roja, tres cubos | rosa, tres bloques anchos escalonados |
| Cola | del color del cuerpo | marron, dos tonos, modular |
| Ojos | placa plana sobre la cara | cubo saliente gris claro con pupila negra al frente |
| Alas | lisas, color del cuerpo | gris claro con moteado de pixeles |
| Patas | pie de un bloque | tres dedos delanteros y espolon trasero |
| Barbilla | roja pequena | roja, bajo el pico naranja |

Paleta declarada en la hoja: blanco, rosa, naranja, rojo, gris claro y marron.

Cifras del asset validadas sobre el binario:

```
mallas: 20  vertices: 1080  triangulos: 864   (presupuesto 1500: OK)
bbox studs: X 2.40  Y 4.34  Z 3.20 | base en Y=0.000 | centro XZ: (0.0, 0.0)
caras invertidas: 0 | sin normales: 0 | sin UV: 0 | aristas abiertas: 0
materiales: 2 | imagenes embebidas: 1 | GLB: 186612 bytes
huesos: 13 | animaciones: 10 -> Walk, Run, Dance, Idle, Jump, Fall, Attack,
                               Hurt, Death, Happy
```

El visor pesa 287191 bytes con el atlas y las dos tiras de control dentro.

Dos rondas de control de calidad, no una. En la primera la cresta salio
pequena y estrecha frente a la hoja, y la cola corta. El moteado de las alas
usa bloques de 20 pixeles: por debajo de 16 el rasgo parpadea al minificar.

Animacion nueva `Dance`: cadera inclinada, un ala arriba y otra abajo, cabeza
ladeada y una pata levantada, con el compas espejado para que el bucle cierre
sin salto.

## 10.6 Artefactos de entrega

1. `<asset>.html`, visor autocontenido, entregable principal
2. `<asset>.glb` validado
3. las tiras de control de calidad
4. `visor.py`, `kit.py` y el generador del asset, como material de trabajo
5. las cifras de validacion en el mensaje de entrega

`visor.py` es independiente del asset y recibe el modulo por `--modulo`. Un
visor escrito a mano para un solo asset se queda desactualizado en la
siguiente iteracion.
