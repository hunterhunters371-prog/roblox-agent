# Registro de iteraciones — Chicken base

Tercer modelo de la serie. Tres rondas de QA visual hasta el pase. Complementa
`05-registro-delivery-bike.md`.

## Ronda 1

| # | Defecto | Causa | Corrección |
| --- | --- | --- | --- |
| 1 | Cuerpo, cabeza, cresta y alas no se dibujaban | `box()` del motor ignora la fusión en sólido existente (`into`); cada caja creaba su propio sólido y las caras se perdían | Fusión manual de caras tras cada caja (`boxInto`): las caras sin color propio heredan el color del sólido destino |
| 2 | Cresta desproporcionada, tipo torre sobre la cabeza | Lóbulos de 0.30–0.34, demasiado grandes y altos | Lóbulos ~30 % más pequeños (0.18–0.24) y asentados sobre la cabeza |
| 3 | Alas invisibles contra el cuerpo | Mismo tono que el plumaje en sombra y solo 0.06 studs de saliente | Saliente de 0.23 studs, placa más larga y punta en tono acento (sólido propio) |
| 4 | Plumaje grisáceo | Ambiente 0.36 apagaba el blanco | Ambiente del visor a 0.40 |
| 5 | Comparación con avatar distorsionada | Cámara cercana (dist 14): la perspectiva inflaba al avatar | Cámara casi ortográfica: dist 26, focal 3.1 |
| 6 | Turnaround con hueco vacío bajo las vistas | Celdas de 196 px dentro de una sección de 460 px | Celdas de 330 px y focal reajustado (6.4) |

## Lecciones nuevas

1. **`box()` no fusiona**: solo `tube` y `torus` aceptan `into`. Para agrupar cajas en un
   sólido hay que fusionar caras a mano. Documentado en el propio código (`boxInto`).
2. **Las comparaciones de escala necesitan cámara casi ortográfica**: con perspectiva
   cercana, el objeto más próximo a la cámara parece mayor aunque no lo sea. Distancia
   larga + focal compensado, como en las vistas técnicas.
3. **La cresta se dimensiona contra la cabeza, no en absoluto**: lóbulos de ~0.3 sobre
   cabeza de 0.78 leen como torre; ~0.2 leen como cresta.
4. **Un ala se diferencia por silueta y por tono a la vez**: ni saliente pequeño ni
   contraste solo bastan; hacen falta ambos.
5. **Los blancos cartoon piden ambiente alto**: con ambiente bajo el blanco se lee gris
   y el modelo parece sin texturizar.

## Lista de comprobación (acumulada, próximo modelo)

- [ ] ¿El texto de las texturas se lee sin espejar? (normales hacia fuera)
- [ ] ¿`box()` fusionado con `boxInto` cuando comparte sólido?
- [ ] ¿Cada cámara de detalle encuadra su pieza y no la vecina?
- [ ] ¿Focales distintas para vistas anchas y estrechas?
- [ ] ¿La comparación de escala usa cámara casi ortográfica?
- [ ] ¿Las piezas expresivas (cresta, pico, ojos) están dimensionadas contra su pieza
      padre y no en absoluto?
- [ ] ¿Las partes que se diferencian lo hacen por silueta Y por tono?
- [ ] ¿El lienzo iguala la altura de la columna de controles?
- [ ] ¿El paquete final se verificó por huella de píxeles?
- [ ] ¿El código está en el repositorio?
