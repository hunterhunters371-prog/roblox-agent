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
**Estado**: pendiente de revisión

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
