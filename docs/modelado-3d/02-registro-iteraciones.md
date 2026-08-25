# Registro de iteraciones — modelos 3D

Historial de entregas, rechazos y reglas nuevas. Cada rechazo del revisor se
anota aquí y se convierte en una línea permanente del checklist de la fase 10 de
`00-proceso-modelado-3d.md`, para que el mismo error no pueda repetirse en otro
modelo.

## `PaqueteNormal` 1.0.0 — primera entrega

**Fecha**: 2026-08-23
**Entregado por**: agente de Notion vía GitHub MCP
**Estado**: pendiente de revisión

**Qué incluye**

- Constructor procedimental parametrizado del paquete base.
- Cinta de embalar, etiqueta trasera, etiqueta de tapa, código de barras
  determinista, dirección, logo «60 SEC» y tres símbolos de manejo.
- Cinco variantes por color, atributos y sello, sin geometría nueva.
- Física, punto de agarre e interacción de recogida.
- Escena de revisión con las cinco variantes en fila.

**Decisiones tomadas**

| Decisión | Motivo |
|---|---|
| Marcado con `SurfaceGui` en vez de texturas | No hay assets subidos a Roblox; así el modelo se reconstruye entero desde el repositorio |
| Caja como `Part` en vez de `MeshPart` | Sin dependencia de Blender ni de subida de mallas; el bisel queda pendiente |
| Código de barras derivado del código del paquete | Dos paquetes distintos se ven distintos y el mismo código se repite igual siempre |
| Cinta con `Transparency = 0.15` | Imita el brillo del precinto sin necesidad de material especial |

**Dudas abiertas para el revisor**

1. **Escala**. Implementado `1.25 x 1.0 x 1.25` studs, tomado literalmente de la
   hoja de referencia. La misma hoja dibuja al avatar con 1 stud de altura,
   cuando mide unos 5. Si se quiere la proporción del dibujo, la caja debe pasar
   a `2.6 x 2.1 x 2.6` studs.
2. **Cara de la etiqueta grande**. La referencia la sitúa en la cara trasera.
   Para el jugador puede ser más útil verla al frente.
3. **Idioma del marcado**. Ahora está en inglés, igual que la referencia. El
   resto del juego usa español.

**Riesgos conocidos**

- Los símbolos de manejo son formas aproximadas, no iconografía normalizada.
- El texto pequeño de la dirección puede resultar ilegible si la caja se queda
  en `1.25` studs y la cámara no se acerca.

## `MochilaReparto` 1.0.0 — primera entrega

**Fecha**: 2026-08-25
**Entregado por**: agente de Notion vía GitHub MCP
**Estado**: sustituida por la 2.0.0

**Qué incluye**

- Constructor procedimental parametrizado de la mochila de reparto, siguiendo
  la lámina «DELIVERY BACKPACK» de formas cuadradas.
- Cuerpo con silueta escalonada, tapa con labio, asa de barras y logo «60 SEC»
  con cronómetro dibujado con `SurfaceGui`.
- Cesta frontal de rejilla de veintiocho piezas con tres paquetes kraft
  sobresaliendo del marco.
- Bolsillos laterales, correa de siete segmentos con hombrera escalonada y
  hebilla plateada.
- Tres variantes de color (Turquesa, Roja, Azul) sin geometría nueva.
- Escena de revisión con las tres variantes en fila, detrás de la de paquetes.

**Decisiones tomadas**

| Decisión | Motivo |
|---|---|
| Todo prismas rectos, cero cuñas ni mallas | El encargo pide formas cuadradas y la lámina es voxel; el escalonado se logra con piezas orgullosas `0.04` studs |
| Rejilla como barras reales de `0.05` | Una textura plana necesitaría un asset subido, y el proyecto exige reconstrucción completa desde el repositorio |
| Cara trasera de la cesta sin barras | Queda oculta contra el cuerpo; las caras invisibles consumen presupuesto, misma regla que los tubos sin tapas de la bici |
| Correa generada por curva paramétrica | Siete segmentos sobre un arco sinusoidal con giro derivado; cambiar `SEGMENTOS_CORREA` rehace la curva sin tocar nada más |
| Escala propuesta `2.6 x 3.0 x 1.6` | La lámina no declara medidas; se aplica la regla del proyecto y se respeta la proporción de mochila de reparto sobre un avatar de 5 studs |
| Logo desplazado hacia arriba de la tapa | El labio de la tapa cubre el 10 % inferior de la cara frontal |

**Dudas abiertas para el revisor**

1. **Escala**. Sin cifras en la referencia. Implementada como equipo del
   jugador (cuerpo de `2.6 x 3.0 x 1.6`). Si es un monumento o prop de tienda,
   basta pasar otro `tamano`.
2. **Uso**. ¿Accesorio del avatar o prop del mundo? Lleva
   `PuntoSujecionEspalda` por si se equipa, pero la conversión a `Accessory` es
   trabajo futuro.
3. **Lado de la correa**. Cuelga por `+X`, el lado derecho visto de frente,
   como en la lámina. Si se equipa al avatar atravesaría el brazo: haría falta
   una variante de correa trasera, que ya es geometría nueva.

**Riesgos conocidos**

- Las barras de `0.05` studs de la rejilla pueden producir aliasing a distancia;
  corrección prevista: subir a `0.07` o migrar la cesta a textura con assets.
- El logo se dibuja con GUI y desaparece a más de `60` studs por `MaxDistance`.
- No verificado en Studio: la escena de revisión está escrita pero aún no se ha
  ejecutado ni visto renderizada.

## `MochilaReparto` 2.0.0 — auditoría y reconstrucción

**Fecha**: 2026-08-25
**Pedido del revisor**: «rehaz el modelo, encuentra los errores en el actual
modelo y mejóralo»
**Estado**: entregada, pendiente de revisión en Studio

### Cómo se encontraron los errores

La 1.0.0 se declaró terminada sin haberla visto renderizada, lo que el propio
proceso prohíbe. Para esta iteración se construyó un visor HTML autocontenido
con rasterizador propio, se generaron capturas en tres vistas y se inspeccionó
una por una. Diez defectos salían de la 1.0.0 y cuatro más aparecieron al
revisar la primera reconstrucción, antes de escribir el módulo definitivo.

### Defectos encontrados y corregidos

| Id | Defecto | Causa raíz | Corrección |
|---|---|---|---|
| E1 | Cuatro rayas verticales oscuras que la lámina no tiene | Esquinas y zócalo pintados con el color de detalle | Ambos pasan al color del cuerpo; solo aportan volumen |
| E2 | Correa y hebilla atravesaban el suelo | Bajaban a `y = -1.86` con la base del cuerpo en `-1.50` | El segmento más bajo termina en `-1.40` |
| E3 | La correa parecía flotar | Hueco de `0.09` a `0.29` studs contra el costado | Saliente fijo de `0.15`, pegada a las esquinas |
| E4 | Los tres paquetes se leían como un bloque | Huecos reales de `0.008` y `0.042` studs | Separación de `0.09`, tres anchos y tres tonos |
| E5 | Rejilla demasiado gruesa frente a la lámina | Malla `5 x 4` con barra de `0.05` | Malla `8 x 6` con barra de `0.035` |
| E6 | Materiales ignorados | Las 68 piezas forzaban `SmoothPlastic` | Material por rol: `Fabric`, `Plastic`, `Metal`, `Cardboard` |
| E7 | Faltaba el broche metálico del costado | Omitido al leer la lámina | `BrocheLateral` y `BrochePasador` |
| E8 | El labio comía el 10 % inferior del logo | Sobresalía `0.029` studs delante de la cara | El labio cuelga por debajo del borde de la tapa |
| E9 | Logo descentrado | «6 + cronómetro» y «SEC» sin eje común | Un contenedor centrado gobierna los tres elementos |
| E10 | La tapa no se leía como solapa | Enrasada con el cuerpo | Sobresale `0.06` en X y Z, `0.046` en Y |
| E11 | La correa atravesaba el bolsillo lateral | Ambas piezas ocupaban `z` de `0.152` a `0.412` | La correa viaja por la espalda, en `z = 0.672` |
| E12 | Los paquetes no asomaban | El tercero sobresalía `0.036` studs | Alturas `1.35`, `1.48` y `1.24`; asoman `0.12` a `0.39` |
| E13 | La hebilla cruzaba la esquina escalonada | Hebilla en `x = 1.40`, esquina hasta `1.34` | Hebilla a `x = 1.45` |
| E14 | El broche quedaba en el centro del costado | Posición elegida sin mirar la lámina | Llevado a `z = -0.45`, junto al borde frontal |

E11, E12, E13 y E14 no existían en la 1.0.0 como tales: aparecieron o se
hicieron visibles al reconstruir, y se corrigieron antes de entregar. Se anotan
igual, porque la lección vale para cualquier modelo.

### Qué cambió en el constructor

- Cada pieza declara un rol, y el rol decide color y material. Ya no hay
  material único ni colores sueltos.
- Los materiales se resuelven con `pcall` y tienen alternativa, según la fase 5
  del proceso.
- Las alturas de la tapa se derivan de dos constantes, así que mover la tapa
  arrastra labio, rieles, asa y hombrera.
- El constructor cuenta sus piezas y avisa con `warn` si pasa de `70`.
- Nuevo `Attachment` `PuntoCesta` y nuevo atributo `CapacidadPaquetes`.

### Cifras

| Métrica | 1.0.0 | 2.0.0 |
|---|---|---|
| Piezas | 68 | 68 |
| Triángulos | 816 | 816 |
| Materiales distintos | 1 | 4 |
| Vistas verificadas por captura | 0 | 3 |

### Reglas nuevas para el checklist de la fase 10

1. Ninguna pieza por debajo de la base del volumen principal, salvo las que el
   spec declare como apoyo.
2. Comprobar por pares que no hay interpenetración entre piezas de familias
   distintas: correa contra bolsillo, hebilla contra esquina, labio contra la
   cara del logo.
3. Los elementos repetidos que deben leerse como varios llevan un hueco mínimo
   de `0.09` studs y variación de tamaño o tono.
4. Lo que debe asomar por encima de un borde asoma al menos `0.12` studs.
5. Ningún color de detalle en piezas que solo aportan volumen: el modelo no
   dibuja líneas que la referencia no tiene.
6. Si el spec declara una constante de material, ninguna pieza puede quedar con
   otro material sin que el spec lo diga.
7. Antes de declarar terminado, capturar el modelo en tres vistas e
   inspeccionarlas una por una.

### No verificado

- Apariencia en Roblox Studio: el visor aproxima la iluminación del motor, no
  la reproduce.
- Rendimiento con cincuenta instancias simultáneas.
- El visor HTML usado para la auditoría se entregó al revisor como archivo
  descargable y todavía no está versionado en este repositorio.

## Plantilla para el siguiente rechazo

```
## <modelo> <versión> — rechazo

Fecha:
Revisor:

Puntos rechazados
1. <qué se ve mal, en concreto>
2. ...

Causa raíz
- <por qué el proceso lo dejó pasar>

Corrección aplicada
- <qué cambió en el constructor>

Regla nueva añadida al checklist
- <línea exacta agregada a la fase 10 del proceso>
```
