# Motor de render v2 — mejoras y proceso replicable

Ampliación del motor descrito en `00-proceso-modelado-3d.md`. Este documento recoge lo
que cambió al pasar del Paquete Normal a la Delivery Bike, para que otra IA pueda
reproducir el resultado y mejorarlo.

## 1. Mejoras del motor

| Mejora | Motivo |
| --- | --- |
| Color por cara (`faceColors`) | Una caja puede llevar cartón, tapa y etiqueta sin dividirse en varios sólidos |
| Primitivas `tube`, `cylinder`, `torus`, `wheel`, `arc` | Formas curvas con control directo del número de segmentos |
| Iluminación Blinn-Phong con especular y ambiente | Sustituye el sombreado plano; da volumen a superficies pintadas |
| Subdivisión selectiva | Solo se subdividen las caras texturizadas; el resto se dibuja de una pieza |
| Recorte de caras ocultas con excepción `twoSided` | Arcos y radios necesitan verse por ambos lados |
| Sombra de contacto desenfocada | Ancla el vehículo al suelo |
| Avatar paramétrico en pose de pie y montada | Verifica escala y encaje sin importar modelos externos |
| Modo wireframe | Permite documentar la malla en la hoja de modelo |

## 2. Reglas de geometría aprendidas

1. **La normal debe salir del sólido.** Con el orden de vértices usado por caja, tubo y
   toro, el producto vectorial `(q1-q0) × (q3-q0)` apunta hacia dentro. El recorte de caras
   ocultas descarta entonces las caras frontales y pinta las traseras: el modelo parece
   correcto de lejos, pero **todo texto de las texturas aparece espejado** y la iluminación
   corresponde al lado opuesto. El orden correcto es `(q3-q0) × (q1-q0)`.
2. **Verificar siempre las normales con una cara que lleve texto.** Un logo legible es la
   prueba más barata de que la orientación es correcta. Una esfera o un cubo de color plano
   no revelan el error.
3. **Los ángulos de un arco se miden desde la vertical.** Cubrir la corona de una rueda pide
   un rango simétrico alrededor de cero, no un rango que empiece en cero.
4. **Tubos sin tapas cuando los extremos quedan ocultos.** Las tapas de un cilindro embebido
   en otra pieza son caras invisibles que gastan presupuesto y generan quads degenerados.
5. **Evitar abanicos de triángulos muy estrechos.** El faro se resolvió con una caja porque
   un cilindro con tapas producía quads casi degenerados que el algoritmo del pintor
   dibujaba como una mancha clara.

## 3. Reglas de presentación aprendidas

1. **Focal por tipo de vista.** Las vistas estrechas (frente, atrás) admiten mucha más
   distancia focal que las largas (lateral, superior). Un valor único deja unas vistas
   diminutas y otras cortadas.
2. **Carcasa oscura y lente clara.** Pintar de claro la cara frontal completa de una pieza
   luminosa la convierte en un rectángulo plano sin volumen.
3. **El lienzo debe igualar la altura de la columna de controles.** Si es más corto, aparece
   un hueco; si es más largo, aparece scroll.
4. **Comprobar el pivote de cada cámara de detalle.** Un pivote mal situado encuadra la pieza
   vecina; se detecta solo mirando la imagen.

## 4. Proceso paso a paso

1. **Leer la hoja de referencia** y extraer descripción, features, stats, vistas, detalles,
   variantes, presupuesto de triángulos y mapas. Anotar contradicciones antes de modelar.
2. **Definir el SPEC numérico** con todas las medidas. El modelo se deriva de esas constantes.
3. **Construir por primitivas**, agrupando en un mismo sólido las piezas del mismo material.
4. **Generar las texturas por código** y derivar de ellas los mapas PBR.
5. **Medir el presupuesto** en cada build y mostrarlo en la ficha del visor.
6. **QA visual por captura**: renderizar en navegador headless e inspeccionar cada imagen.
   Nada se da por bueno sin mirarlo. Usar recortes ampliados para verificar el texto de las
   texturas.
7. **Corregir en el código y volver a capturar** hasta que la imagen pase.
8. **Empaquetar** en un HTML autocontenido y un PNG de hoja de modelo.

## 5. Limitaciones del enfoque

- El render ordena caras por profundidad sin z-buffer: en cruces de tubos muy cercanos puede
  aparecer un orden incorrecto. Se mitiga uniendo los tubos del mismo color en un sólido.
- Las siluetas son poligonales por diseño; el número de segmentos se elige para respetar el
  presupuesto de triángulos.

## 6. Lección de infraestructura

El entorno de trabajo es efímero y puede revertir archivos entre operaciones. Durante esta
sesión se perdieron capturas y correcciones ya aplicadas, y un archivo volvió a una versión
anterior sin aviso.

**Reglas que se derivan:**

1. Subir el código al repositorio antes de iterar, no al final.
2. Empaquetar en un archivo autocontenido en cuanto el resultado sea válido; el paquete deja
   de depender de los archivos sueltos.
3. Mantener un script de parcheo idempotente que reaplique todas las correcciones validadas
   y falle si alguna no queda aplicada, en lugar de confiar en ediciones acumuladas.
4. Verificar el resultado por huella de píxeles: permite comprobar que el paquete final
   renderiza exactamente lo aprobado.
