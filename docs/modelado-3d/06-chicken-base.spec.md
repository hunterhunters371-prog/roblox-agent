# Chicken base — personaje principal EGGBOUND (v1.0.0)

Tercer objeto de la serie de modelado 3D por código. Comparte el motor de render v2
con la Delivery Bike y añade dos técnicas nuevas: huevo escalonado y fusión de cajas.

## 1. Resumen

Pollo cartoon, personaje más importante de EGGBOUND. Reconocible a distancia por tres
lecturas: silueta de huevo blanco, cresta roja, cola en abanico. Preparado para las 12
animaciones previstas y para variantes/accesorios sin remodelar.

| Propiedad | Valor |
| --- | --- |
| Dimensiones | 2.10 × 3.47 × 1.24 studs (largo × alto × ancho) |
| Altura total | 3.47 studs (0.69 × avatar de Roblox de 5 studs) |
| Pivote | Centro del cuerpo |
| Partes lógicas | 15 (presupuesto de la hoja EGGBOUND: 12–20) |
| Triángulos | ~570 |
| Textura | 1024 × 1024, atlas de 8 islas |
| Mapas | Base color, normal, roughness, metallic, AO |
| Material slots | 2 (plumaje, detalles) |
| Rigging | Preparado: rotación por partes (patas + pico inferior) |

## 2. Idioma visual heredado de la hoja EGGBOUND

La hoja del huevo común define el idioma del juego, y el pollo lo respeta:

- **Huevo escalonado**: cuerpo y cabeza son huevos de bloques con escalones visibles.
- **Marcas sutiles** a nivel o ligeramente extruidas (los ojos son placas extruidas).
- **12–20 partes lógicas**.
- **Preparado para flotar, rotar y romperse**: las partes son independientes.
- **Recoloreable** para variantes.

## 3. Constantes del modelo (SPEC)

Todo el pollo se deriva de estas constantes; cambiar una reconstruye la pieza completa.

```
cuerpo   centro Y 1.30 · 7 anillos (y, ancho, fondo):
         (-0.78, .52, .56) (-0.55, .82, .88) (-0.27, 1.02, 1.08) (0.03, 1.08, 1.14)
         ( 0.33, .98, 1.04) ( 0.61, .78, .84) ( 0.86, .50, .54) · rebanada 0.30
cabeza   centro Y 2.62, Z 0.55 · 5 anillos:
         (-0.52, .46, .48) (-0.30, .68, .70) (-0.06, .78, .80)
         ( 0.19, .72, .74) ( 0.43, .52, .54) · rebanada 0.26
cresta   3 lóbulos: (0, 3.16, 0.48, tam .20) (0, 3.24, 0.64, tam .24)
         (0, 3.12, 0.78, tam .18) · fondo 0.18
pico     superior (0, 2.66, 1.10) 0.42×0.20×0.34
         inferior (0, 2.47, 1.05) 0.30×0.12×0.22  ← articulable
barbilla (0, 2.29, 0.94) 0.16×0.24×0.14
ojo      x ±0.30, y 2.80, z 0.98 · placa 0.10×0.30×0.22 · brillo 0.052³
ala      x ±0.66, y 1.52, z 0.02 · placa 0.24×0.70×0.86 · punta caída 0.30 en acento
cola     3 plumas tubo: central y lateral ±0.22 con apertura 0.50/±0.72 rad
pata     x ±0.28 · muslo y 0.72→0.34 r 0.083 · caña 0.34→0.10 r 0.055
pie      y 0.045 · 3 dedos 0.09×0.07×0.26 + espolón trasero
```

### Huevo escalonado (técnica nueva)

Cada anillo es una caja cuya anchura y fondo interpolan hacia el anillo siguiente, más
tapas superior e inferior. Las rebanadas apiladas producen la silueta de huevo con
escalones de bloque, exactamente el acabado de la hoja EGGBOUND, con ~6 quads por
rebanada.

## 4. Partes lógicas (15)

cuerpo · cabeza · cresta · barbilla · pico · ojos · brillos de ojo · alas · cola ·
muslo izq · caña izq · pie izq · muslo der · caña der · pie der

Las 6 piezas de patas y la mitad inferior del pico son sólidos independientes a
propósito: se rotan solos en las animaciones.

## 5. Paleta y variantes

| Variante | Plumaje | Sombra | Marcas | Cresta | Pico | Patas | Código |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Común | `#F2F0E6` | `#C8C6B8` | `#A5A190` | `#D8452E` | `#F2A81C` | `#E8961C` | `CHKN-BASE-COM` |
| Raro | `#E9F0E4` | `#AFC7A6` | `#8AA883` | `#D8452E` | `#F2A81C` | `#E8961C` | `CHKN-BASE-RAR` |
| Dorado | `#F2C230` | `#C99A1B` | `#A87F12` | `#E03B2F` | `#F28E1C` | `#D8841A` | `CHKN-BASE-DOR` |

Las variantes solo cambian `VARIANTS`: la malla no se toca. Los mapas PBR se derivan
del base color (normal plano; roughness alto en plumaje, bajo en ojo; metallic casi
nulo; AO por luminancia).

## 6. Animaciones previstas y pivotes

Idle · Walk · Run · Jump · Fall · Attack · Hurt · Dodge · Death · Happy · Angry ·
Special Ability.

- **Pivotes listos**: muslo, caña y pie de cada pata; mitad inferior del pico; alas y
  cola como sólidos propios.
- **Walk/Run/Jump/Fall/Dodge/Attack** dependen directamente de las patas.
- **Death/romper**: las partes se separan estilo EGGBOUND sin efectos de malla.
- **Happy/Angry**: cresta + pico inferior + brillo de ojos, sin huesos faciales.

## 7. Accesorios intercambiables

Anclajes documentados, sin tocar la malla:

- **Cabeza**: sombreros y gafas se anclan sobre la cresta o entre ojos.
- **Cuerpo**: mochilas y caparazones sobre la espalda (z negativo).
- **Patas**: espuelas sobre la caña.
- Cada accesorio es un sólido añadido al final de la lista; ocultarlo no afecta al resto.

## 8. Escala

La hoja EGGBOUND no da medidas del pollo. Se fija contra el avatar de Roblox (5 studs):
3.47 studs de alto = 0.69 × avatar. Un pollo grande de protagonista, no una mascota al
pie. Decisión pendiente de confirmación.

## 9. Decisiones abiertas

- Confirmar la escala definitiva (3.47 studs o versión mascota más pequeña).
- Lista de accesorios del lanzamiento y anclajes exactos.
- Si Raro/Dorado cambian también las marcas del plumaje o solo los colores.
- Color definitivo de las puntas de ala (acento gris o sombra de plumaje).
