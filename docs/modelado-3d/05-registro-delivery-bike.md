# Registro de iteraciones — Delivery Bike

Historial de defectos detectados por inspección visual y sus correcciones. Sirve como
lista de comprobación para el próximo modelo.

## Ronda 1

| # | Defecto | Causa | Corrección |
| --- | --- | --- | --- |
| 1 | Guardabarros flotando por delante de la rueda | Rango angular del arco medido desde cero en lugar de desde la vertical | Rango simétrico alrededor de cero |
| 2 | Faro como mancha clara e informe sobre la rueda | Cilindro con tapas: abanico de quads casi degenerados | Sustituido por una caja con lente |
| 3 | Presupuesto de triángulos excedido | Demasiados segmentos en ruedas y tubos | Reducidos segmentos y radios; tubos sin tapas |
| 4 | Pose del avatar sin pies y flotando | Falta de piezas y altura base incorrecta | Añadidos pies y corregida la altura |
| 5 | Sombra demasiado ancha | Plano de suelo más ancho que el vehículo | Plano estrechado al ancho real |

## Ronda 2

| # | Defecto | Causa | Corrección |
| --- | --- | --- | --- |
| 6 | Logo `60 SEC` espejado en todas las caras visibles | Normales calculadas hacia dentro: el recorte de caras ocultas pintaba las caras traseras | Invertido el producto vectorial que genera la normal |
| 7 | Hueco blanco bajo el visor | Lienzo más corto que la columna de controles | Altura del lienzo igualada a la columna |

La detección del defecto 6 requirió un recorte ampliado ×4 sobre la caja. A tamaño completo
el texto era ilegible y el modelo parecía correcto.

## Ronda 3

| # | Defecto | Causa | Corrección |
| --- | --- | --- | --- |
| 8 | Faro como rectángulo plano sin volumen | Cara frontal de la carcasa pintada en tono claro | Carcasa opaca y lente más pequeña y saliente |
| 9 | Vistas Arriba y Abajo diminutas | Una sola distancia focal para vistas anchas y estrechas | Focal por tipo de vista |
| 10 | Detalle del sillín encuadrando la caja | Pivote de cámara mal situado | Reencuadre sobre el asiento |
| 11 | Guardabarros visualmente pesados | Más anchos que el neumático | Ancho reducido de 0.26 a 0.23 |

## Ronda 4

| # | Defecto | Causa | Corrección |
| --- | --- | --- | --- |
| 12 | Correcciones perdidas y archivos revertidos a versiones anteriores | El entorno de trabajo es efímero y revierte archivos entre operaciones | Script de parcheo idempotente con verificación obligatoria, empaquetado autocontenido y verificación por huella de píxeles |

## Comprobaciones para el próximo modelo

- [ ] ¿El texto de las texturas se lee correctamente, sin espejar, en todas las caras?
- [ ] ¿Las normales apuntan hacia fuera en cajas, tubos y toros?
- [ ] ¿Los arcos cubren la zona prevista con rango angular simétrico?
- [ ] ¿Cada cámara de detalle encuadra su pieza y no la vecina?
- [ ] ¿Las vistas estrechas y las largas usan focales distintas?
- [ ] ¿El recuento de triángulos está dentro del presupuesto?
- [ ] ¿El lienzo iguala la altura de la columna de controles?
- [ ] ¿El paquete final se ha verificado por huella de píxeles?
- [ ] ¿El código está subido al repositorio antes de seguir iterando?
