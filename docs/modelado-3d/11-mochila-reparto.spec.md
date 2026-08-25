# Especificación — `MochilaReparto`

**Versión**: 2.0.0
**Referencia**: lámina «DELIVERY BACKPACK», estilo voxel de formas cuadradas
**Constructor**: `project/src/ReplicatedStorage/Modelos/MochilaReparto.lua`
**Escena de revisión**: `project/src/ServerScriptService/DemoMochilas.server.lua`

La versión 2.0.0 rehace por completo la 1.0.0 después de auditar el modelo en
un visor 3D propio. La geometría de este documento es la que se vio
renderizada y se aprobó en tres vistas: tres cuartos, frente y lateral.

## Contrato de la referencia

| Característica de la lámina | Responsable en el modelo |
|---|---|
| Cuerpo cuadrado de esquinas escalonadas | `Cuerpo`, cuatro `EsquinaCuerpo`, `Zocalo` |
| Solapa superior que sobresale | `Tapa`, `LabioTapa`, dos `RielTapa` |
| Asa de dos postes y barra | dos `PosteAsa`, `BarraAsa` |
| Logotipo «60 SEC» con cronómetro | `LogoFrontal` (`SurfaceGui` sobre la tapa) |
| Cesta frontal de rejilla fina | `SueloCesta`, `MarcoCestaSuperior`, dos `ColumnaCesta`, barras `BarraCesta*` |
| Paquetes de cartón asomando | tres `PaqueteCesta` de tres tonos y tres alturas |
| Bolsillos laterales con solapa | `BolsilloLateral`, `SolapaBolsillo`, `PliegueBolsillo` |
| Correa de hombro con hebilla | siete `SegmentoCorrea`, `Hombrera`, `HombreraCresta`, `Hebilla`, `PasadorHebilla` |
| Broche metálico del costado | `BrocheLateral`, `BrochePasador` |

## Medidas

Todo en studs. El cuerpo se centra en el origen del modelo, el frente mira
hacia `-Z` y el pivote es el centro geométrico del cuerpo.

| Constante | Valor | Nota |
|---|---|---|
| `ANCHO` | `2.6` | eje X |
| `ALTO` | `3.0` | eje Y, sin contar asa ni correa |
| `FONDO` | `1.6` | eje Z |
| `HOLGURA` | `0.006` | separación anti z-fighting del proyecto |
| `ESCALON` | `0.04` | cuánto sobresale una pieza para leerse como voxel |
| `TAPA.alto` | `0.9` | |
| `TAPA_TOPE` | `1.546` | `ALTO / 2 + 0.046` |
| `TAPA_BASE` | `0.646` | `TAPA_TOPE - TAPA.alto` |
| Altura total con asa | `≈ 2.03` sobre el centro | barra del asa en `y = 1.954` |
| Altura total con correa | `≈ 3.9` | de `y = -1.40` a `y = 1.954` más hombrera |

### Cesta

| Constante | Valor | Derivado |
|---|---|---|
| `ancho` | `0.654` | `1.7004` studs |
| `alto` | `0.367` | `1.101` studs |
| `fondo` | `0.55` | |
| `centroY` | `-0.25` | `-0.75` studs |
| `barrasVerticales` | `8` | cara frontal |
| `barrasHorizontales` | `6` | cara frontal |
| `barrasLateralV` / `barrasLateralH` | `2` / `4` | por costado |
| `barra` | `0.035` | grosor de barra |

La cara trasera de la cesta no se construye: queda oculta contra el cuerpo.

### Paquetes de la cesta

| Paquete | X | Ancho | Alto relativo | Sobresale del marco |
|---|---|---|---|---|
| Izquierdo (`cartonB`) | `-0.46` | `0.44` | `1.35` | `0.246` |
| Central (`cartonA`) | `0.05` | `0.40` | `1.48` | `0.390` |
| Derecho (`cartonC`) | `0.51` | `0.34` | `1.24` | `0.125` |

Separación horizontal real entre paquetes: `0.09` studs.

### Correa

| Constante | Valor | Nota |
|---|---|---|
| `segmentos` | `7` | sobre un arco sinusoidal |
| `fraccionSuperior` | `0.42` | arranca en `y = 1.26` |
| `alturaInferior` | `-1.15` | el segmento más bajo llega a `y = -1.40` |
| `fraccionFondo` | `0.42` | `z = 0.672`, la correa va por la espalda |
| `saliente` | `0.15` | `x` base `1.45`, libra la esquina en `1.34` |
| `arco` | `0.10` | máximo alejamiento del cuerpo |
| `giro` | `10` | grados, derivada del arco |

## Paleta

| Rol | Turquesa | Roja | Azul |
|---|---|---|---|
| `cuerpo` | `56, 178, 169` | `196, 74, 62` | `64, 118, 206` |
| `detalle` | `34, 136, 128` | `148, 48, 40` | `44, 86, 160` |
| `rejilla` | `30, 122, 115` | `134, 42, 35` | `38, 76, 144` |

Colores fijos, iguales en las tres variantes:

| Rol | RGB |
|---|---|
| `correa` | `30, 30, 34` |
| `hebilla` | `150, 156, 160` |
| `metal` | `166, 171, 175` |
| `cartonA` | `206, 164, 112` |
| `cartonB` | `188, 145, 96` |
| `cartonC` | `172, 130, 84` |
| `crema` (logo) | `240, 238, 232` |
| `rojoLogo` | `198, 62, 52` |

## Material por rol

La 1.0.0 forzaba `SmoothPlastic` en las sesenta y ocho piezas. Ahora cada rol
declara el suyo y se resuelve con `pcall`, con alternativa si el `Enum` no
existe en una versión antigua del motor.

| Rol | Material | Alternativa |
|---|---|---|
| `cuerpo`, `correa` | `Fabric` | `SmoothPlastic` |
| `detalle`, `rejilla` | `Plastic` | `SmoothPlastic` |
| `hebilla`, `metal` | `Metal` | `SmoothPlastic` |
| `cartonA`, `cartonB`, `cartonC` | `Cardboard` | `Wood` |

## Atributos

| Atributo | Tipo | Valor |
|---|---|---|
| `VersionModelo` | string | `2.0.0` |
| `Variante` | string | `Estandar`, `Express` o `Refrigerado` |
| `Etiqueta` | string | texto legible de la variante |
| `CapacidadPaquetes` | número | `3` |
| `PiezasTotales` | número | contado al construir |
| `AnchoStuds`, `AltoStuds`, `FondoStuds` | número | `2.6`, `3.0`, `1.6` |

## Puntos de interacción

Todos como `Attachment` sobre el cuerpo, nunca como offsets calculados en el
código de gameplay.

| Punto | Posición | Para qué |
|---|---|---|
| `PuntoAgarreAsa` | barra del asa | llevar la mochila en la mano |
| `PuntoSujecionEspalda` | `(0, 0.30, 0.8)` | equiparla al avatar |
| `PuntoCesta` | borde superior de la cesta | insertar o sacar paquetes |

## Variantes

| Nombre | Paleta | Etiqueta |
|---|---|---|
| `Estandar` | Turquesa | Reparto estándar |
| `Express` | Roja | Reparto exprés |
| `Refrigerado` | Azul | Reparto refrigerado |

Añadir una variante son tres líneas y no toca geometría.

## Presupuesto

| Métrica | Presupuesto | Real |
|---|---|---|
| Piezas | `70` | `68` |
| Triángulos | `900` | `816` |
| Colisionadores | `1` | `1` (solo `Cuerpo`) |
| Assets externos obligatorios | `0` | `0` |

El constructor comprueba el presupuesto de piezas al terminar y avisa con
`warn` si se excede.

## Criterios de aceptación

1. Ninguna pieza queda por debajo de `y = -1.50`, la base del cuerpo, salvo el
   propio zócalo.
2. Ninguna pareja de piezas se interpenetra. En particular, correa contra
   bolsillo lateral, hebilla contra esquina escalonada y labio contra la cara
   del logo.
3. Los tres paquetes se distinguen entre sí a diez studs de distancia: huecos
   de `0.09`, tres alturas y tres tonos de cartón.
4. Los paquetes sobresalen del marco superior de la cesta al menos `0.12`
   studs.
5. El logotipo cabe entero en la cara frontal de la tapa, centrado, sin que
   ninguna pieza lo tape.
6. Las esquinas y el zócalo son del color del cuerpo: el modelo no dibuja
   rayas que la lámina no tiene.
7. La tapa se lee como solapa independiente: sobresale `0.06` en X y Z y
   `0.046` en Y.
8. Cada rol usa su material, y ninguno queda con el material por defecto.
9. `modelo:PivotTo(...)` mueve las sesenta y ocho piezas juntas.
10. Cambiar una fila de `PALETA` cambia el modelo entero sin tocar otra línea.

## Verificado y no verificado

**Verificado por captura de pantalla** en las vistas tres cuartos, frente y
lateral, con avatar de `5` studs como referencia de escala: silueta,
proporciones, escalonado, legibilidad del logo, separación de paquetes,
recorrido de la correa, posición del broche y ausencia de interpenetraciones.

**No verificado**: la apariencia dentro de Roblox Studio. El visor aproxima la
iluminación del motor, no la reproduce, y los materiales `Fabric`, `Cardboard`
y `Metal` solo se ven de verdad con la iluminación del juego. Tampoco se ha
medido el rendimiento con cincuenta instancias simultáneas.

## Dudas abiertas

1. **Uso final**. Sigue sin decidirse si es accesorio del avatar o prop del
   mundo. Lleva `PuntoSujecionEspalda` para lo primero, pero la conversión a
   `Accessory` es trabajo futuro.
2. **Lado de la correa**. Cuelga por `+X`. Ahora va por la espalda, con lo que
   estorba menos al brazo que en la 1.0.0, pero un modelo equipado pediría dos
   correas simétricas, y eso es geometría nueva.
3. **Rejilla contra textura**. Veintiocho barras reales cuestan presupuesto.
   Con assets subidos, la cesta podría ser una textura con transparencia.
