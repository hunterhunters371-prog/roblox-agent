# Delivery Bike — vehículo del jugador Tier 1 (v1.0.0)

Segundo objeto de la serie de modelado 3D por código. Comparte motor de render con
`01-paquete-normal.spec.md` y añade primitivas curvas.

## 1. Resumen

Bicicleta básica de reparto, desbloqueada al inicio de la partida. Ligera, rápida y
estrecha, pensada para atajos y caminos angostos. Lleva caja de reparto, faro delantero,
sillín acolchado y reflector trasero.

| Propiedad | Valor |
| --- | --- |
| Dimensiones | 4.74 × 2.78 × 1.16 studs (largo × alto × ancho) |
| Alto al manillar | 3.05 studs |
| Pivote | Centro del eje trasero |
| Piezas | 34 sólidos |
| Triángulos | ~1 164 (presupuesto 1 350) |
| Textura | 1024 × 1024, atlas de 9 islas |
| Mapas | Base color, normal, roughness, metallic, AO |
| Material slots | 2 (pintura, goma) |
| Rigging | No (vehículo estático) |

## 2. Stats de diseño (Tier 1)

| Stat | Valor | Lectura |
| --- | --- | --- |
| Speed | 4.0 / 5 | Rápida en recto pese a ser el vehículo inicial |
| Acceleration | 3.0 / 5 | Arranque correcto, sin ventaja especial |
| Handling | 4.5 / 5 | Punto fuerte: caminos estrechos y atajos |
| Durability | 2.0 / 5 | Penaliza el choque; obliga a conducir limpio |

Características declaradas en la hoja: aceleración rápida, buen manejo, durabilidad baja,
sin habilidad especial, desbloqueada al inicio.

## 3. Constantes del modelo

Todo el modelo se deriva de estas constantes. Cambiar una medida reconstruye la pieza
completa sin tocar el resto del código.

```
wheelR    0.92    radio de rueda
tire      0.10    grosor del neumático
axleY     0.92    altura de los ejes
rearZ    -1.45    eje trasero
frontZ    1.45    eje delantero
bb        [0, 0.80, -0.18]    pedalier
seatTop   [0, 2.10, -0.78]    tope del tubo del sillín
headTop   [0, 2.02,  0.95]    tope del tubo de dirección
headBot   [0, 1.28,  1.14]    base del tubo de dirección
barY      2.24    altura del manillar
barZ      0.80    avance del manillar
barW      1.16    ancho del manillar
boxSize   1.06 × 1.00 × 0.96  caja de reparto
boxCenter [0, 2.26, -1.42]
lightC    [0, 1.56,  1.24]    centro del faro
tubeR     0.072   radio de los tubos del cuadro
```

## 4. Estructura de piezas

1. **Cuadro**: un único sólido que agrupa todos los tubos. Los tubos se generan sin tapas
   porque sus extremos quedan dentro de otras piezas; las tapas serían caras invisibles
   que consumen presupuesto.
2. **Ruedas**: primitiva paramétrica que produce cuatro sólidos (neumático, llanta, radios,
   buje). 14 segmentos de contorno y 8 radios por rueda.
3. **Guardabarros**: arcos de 0.23 de ancho sobre la corona de cada rueda, con rango
   angular simétrico respecto de la vertical.
4. **Caja de reparto**: caja texturizada con tapa, más una bisagra y dos cierres.
5. **Faro**: carcasa opaca con lente saliente y soporte al tubo de dirección.
6. **Sillín**: asiento sobre tija.
7. **Reflector trasero**: pieza roja bajo el portaequipajes.
8. **Pedales y transmisión**: platos, bielas y pedales.

## 5. Texturas

Cada cara de la caja se pinta en un canvas por código, sin imágenes externas:

- Fondo de cartón con veteado y esquinas desgastadas.
- Logo `60 SEC` con cronómetro.
- Etiqueta roja `DELIVERY`.
- Código de variante (`BIKE-T1-DEF`, `BIKE-T1-BLU`, `BIKE-T1-RED`).
- Tornillos en las esquinas.

El atlas de 9 islas (caja, pintura, metal, buje, goma, rueda, sillín, faro, detalles)
alimenta los cinco mapas PBR. Normal, roughness, metallic y AO se derivan del base color:

| Material | Roughness | Metallic |
| --- | --- | --- |
| Metal | 0.22 | 235 |
| Goma y rueda | 0.86 | 12 |
| Pintura | 0.38 | 90 |
| Faro | 0.16 | 12 |
| Resto | 0.62 | 12 |

## 6. Variantes de color

| Variante | Pintura | Sombra | Caja | Acento | Código |
| --- | --- | --- | --- | --- | --- |
| Default | `#F2A81C` | `#C4820D` | `#F4AE23` | `#E03B2F` | `BIKE-T1-DEF` |
| Blue | `#2E6FD6` | `#1E4F9F` | `#3277DF` | `#F2C230` | `BIKE-T1-BLU` |
| Red | `#CE3A2E` | `#9E2A20` | `#D9412F` | `#F2C230` | `BIKE-T1-RED` |

## 7. Contradicción de escala en la hoja de referencia

La hoja marca la bici en **1.1 studs** y el avatar en **1.8 studs**. Esas cifras son metros
reales, no studs: un avatar de Roblox mide unos **5 studs**. Se conserva la proporción de la
hoja (bici = 0.61 × la altura del avatar) y se traduce a escala de Roblox: 3.05 studs hasta
el manillar y 4.74 studs de largo. Es la misma clase de contradicción detectada en el
Paquete Normal, donde la caja se marcaba en 1.25 studs con un avatar dibujado a 1.0.

**Regla general**: cuando una hoja de referencia mezcla unidades, respetar la proporción
entre objeto y avatar y recalcular en studs. Documentar la contradicción en lugar de
silenciarla.

## 8. Decisiones abiertas

- Confirmar la escala definitiva: proporción respetada (actual) o número literal de la hoja.
- Decidir si Blue y Red cambian solo la pintura o también el color de la caja.
- Definir si el Tier 2 reutiliza este cuadro con accesorios o parte de un modelo nuevo.
