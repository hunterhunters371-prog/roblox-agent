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
