# Proceso de modelado 3D para Roblox — versión 1.1

Proceso que se aplica siempre, en este orden, para producir cualquier modelo del
juego. Está escrito para que otra IA lo ejecute sin contexto adicional y pueda
mejorarlo. Cada fase declara qué entra, qué sale y cómo se verifica.

La versión 1.1 incorpora las reglas que salieron de la auditoría de
`MochilaReparto` 1.0.0, donde catorce defectos pasaron el checklist anterior
porque el modelo se declaró terminado sin haberlo visto renderizado.

## Principios

1. **Un modelo base, muchas variantes.** Nunca se modelan veinte objetos
   distintos cuando uno parametrizado cubre el caso. Las variantes cambian
   color, textura, atributos y accesorios pequeños, jamás la geometría base.
2. **Procedimental antes que manual.** El modelo se construye por código, así
   que es reproducible, diffeable en git y editable por otra IA. Un archivo
   `.rbxm` binario no es revisable.
3. **Cero dependencias ocultas.** Si el modelo necesita un asset subido a
   Roblox, no se puede reconstruir desde el repositorio. Mientras no existan las
   texturas definitivas, el marcado se dibuja con `SurfaceGui`.
4. **Presupuesto antes que detalle.** Triángulos, instancias y draw calls se
   fijan al principio y se comprueban al final.
5. **Todo dato del modelo es un atributo.** El gameplay lee atributos, nunca
   nombres de instancias ni posiciones mágicas.
6. **Determinismo.** Los detalles aleatorios (patrón del código de barras,
   desgaste) se derivan de una semilla estable, no de `math.random` global.
7. **Nada se entrega sin verlo.** Un modelo que nadie ha visto renderizado no
   está terminado, por limpio que sea el código. El visor de
   `10-visor-html-autocontenido.md` existe para eso.

## Fase 1 — Leer la referencia y extraer el contrato

**Entra**: imagen de referencia, brief del usuario.
**Sale**: lista de características obligatorias, medidas, presupuesto y dudas.

1. Enumerar las características que la referencia marca como obligatorias.
2. Anotar las medidas declaradas, el punto de pivote, el conteo de triángulos y
   la resolución de textura.
3. Buscar contradicciones entre la referencia y la realidad del motor. Ejemplo
   real: una hoja de referencia que dibuja el avatar de Roblox con 1 stud de
   altura, cuando un avatar mide unos 5 studs.
4. Las contradicciones se reportan antes de modelar, con la interpretación
   propuesta y su alternativa. No se resuelven en silencio.
5. Cada elemento visible de la referencia entra en la tabla del contrato, con
   la pieza que lo va a construir. Si un elemento no tiene fila, se olvidará:
   así desapareció el broche lateral de la mochila en la 1.0.0.

**Verificación**: la lista de características cabe en una tabla y cada fila
tiene un responsable en el modelo final.

## Fase 2 — Escribir la especificación

**Entra**: contrato de la fase 1.
**Sale**: archivo `NN-<modelo>.spec.md` en esta carpeta.

La especificación fija nombre del modelo, jerarquía de instancias, tamaño en
studs, pivote, paleta con valores RGB exactos, atributos, variantes previstas y
criterios de aceptación. Si algo no está en la especificación, no se construye.

**Verificación**: otra IA puede reconstruir el modelo leyendo solo el spec.

## Fase 3 — Blockout

**Entra**: spec.
**Sale**: volumen principal con el tamaño final, sin detalle.

1. Crear la forma dominante con primitivas (`Part`, `WedgePart`).
2. Comprobar la escala contra una referencia humana de 5 studs de altura, no
   contra la intuición.
3. Fijar el pivote antes de añadir detalle. Cambiarlo después rompe todo el
   posicionamiento.

**Verificación**: el volumen colocado junto a un avatar se lee correctamente en
tamaño desde la cámara de juego.

## Fase 4 — Detalle geométrico

**Entra**: blockout aprobado.
**Sale**: piezas secundarias soldadas al volumen principal.

1. Cada pieza pegada a una superficie se separa `0.006` studs para evitar
   z-fighting, y no más, para que no se vea despegada.
2. Las piezas secundarias van `Massless = true`, `CanCollide = false`,
   `CanQuery = false`, `CanTouch = false`. Solo el volumen principal colisiona.
3. Unión con `WeldConstraint`, nunca con `Weld` manual ni posiciones absolutas.
4. Nombres en español, descriptivos y estables: el gameplay y las herramientas
   dependen de ellos.
5. Antes de añadir una pieza nueva, comprobar con qué vecinos comparte volumen.
   Dos familias distintas que ocupan el mismo hueco es un defecto, no un
   detalle: en la 1.0.0 de la mochila la correa atravesaba el bolsillo lateral.
6. Las medidas derivadas se calculan a partir de constantes con nombre, no se
   copian a mano. Mover la tapa debe arrastrar labio, rieles, asa y hombrera.

**Verificación**: mover el modelo con `PivotTo` arrastra todas las piezas y el
conteo de triángulos sigue dentro del presupuesto.

## Fase 5 — Material y color

**Entra**: modelo detallado.
**Sale**: paleta aplicada.

1. Materiales del motor primero (`Cardboard`, `Plastic`, `Fabric`). Son gratis y
   responden a la iluminación.
2. Todo color se declara una sola vez en una tabla `PALETA` y se referencia
   desde ahí. Ningún `Color3` suelto en medio del código.
3. Los materiales que podrían no existir en versiones antiguas del motor se
   consultan con `pcall` y tienen alternativa.
4. El material se decide por rol de pieza, no por modelo. Un solo material para
   todo delata el atajo: tela, rígido, metal y cartón se ven distintos bajo la
   misma luz.
5. El color oscuro de detalle se reserva para lo que la referencia dibuja como
   línea. Una pieza que solo aporta volumen va del color del cuerpo, o el modelo
   acaba con rayas inventadas.

**Verificación**: cambiar un valor de la paleta cambia el modelo entero sin
tocar otra línea.

## Fase 6 — Marcado e impresión

**Entra**: modelo con material.
**Sale**: etiquetas, logotipos, códigos y símbolos.

1. Mientras no haya texturas subidas, el marcado se dibuja con `SurfaceGui`
   sobre placas finas o directamente sobre la cara.
2. `LightInfluence = 1` para que la impresión reciba la luz de la escena y no
   parezca una pegatina emisiva.
3. `MaxDistance` acotado para que el marcado no se dibuje a lo lejos.
4. Los códigos de barras y demás patrones se generan con `Random.new(semilla)`
   derivada del identificador del objeto, así el mismo identificador produce
   siempre el mismo dibujo.
5. El texto que el jugador debe leer se prueba a la distancia real de juego, no
   con la cámara pegada al objeto.
6. Ninguna pieza geométrica puede invadir la cara donde vive el marcado, y los
   elementos de un mismo logotipo comparten un contenedor centrado en vez de
   posicionarse uno a uno.

**Verificación**: dos paquetes con códigos distintos se ven distintos; el mismo
código produce siempre el mismo patrón.

## Fase 7 — Pivote, orientación y anclaje

**Entra**: modelo marcado.
**Sale**: modelo orientable.

1. `PrimaryPart` apunta al volumen principal.
2. Convención del proyecto: el frente del objeto mira hacia `-Z`, el pivote va
   en el centro geométrico salvo que el spec diga lo contrario.
3. Puntos de interacción como `Attachment` con nombre, nunca offsets calculados
   en el código de gameplay.

**Verificación**: `modelo:PivotTo(CFrame.new(0, 5, 0))` deja el objeto centrado
y derecho.

## Fase 8 — Física y gameplay

**Entra**: modelo orientable.
**Sale**: modelo jugable.

1. `CustomPhysicalProperties` explícitas: densidad, fricción y elasticidad. Un
   paquete que rebota como pelota rompe la sensación de peso.
2. `ProximityPrompt` u otra interacción declarada en el modelo, con textos en el
   idioma del juego.
3. Atributos con todos los datos que el gameplay necesita leer.

**Verificación**: el objeto cae, se apoya y se recoge sin código extra.

## Fase 9 — Variantes

**Entra**: modelo base terminado.
**Sale**: tabla de variantes.

1. Una variante es una tabla de sobrescrituras, no una función nueva.
2. Permitido en una variante: color, transparencia, textura, atributos,
   accesorios pequeños, masa.
3. Prohibido en una variante: cambiar las dimensiones base, renombrar piezas,
   duplicar el constructor.
4. Si una variante necesita geometría propia, es un modelo nuevo y vuelve a la
   fase 1.

**Verificación**: añadir una variante son menos de diez líneas.

## Fase 10 — Control de calidad

Checklist que se ejecuta entero antes de entregar:

- [ ] Escala comprobada junto a un avatar de 5 studs.
- [ ] Pivote en el sitio declarado por el spec.
- [ ] Sin z-fighting en ninguna cara, mirando desde ocho ángulos.
- [ ] Conteo de triángulos e instancias dentro del presupuesto.
- [ ] Solo el volumen principal colisiona.
- [ ] El modelo se puede recrear desde cero ejecutando el constructor.
- [ ] Nombres y atributos coinciden exactamente con el spec.
- [ ] Texto legible a la distancia real de juego.
- [ ] Cincuenta instancias simultáneas sin caída de frames perceptible.
- [ ] Ningún asset externo obligatorio para reconstruirlo.

Añadido en la versión 1.1, de la auditoría de `MochilaReparto` 1.0.0:

- [ ] El modelo se ha capturado en tres vistas como mínimo (tres cuartos,
      frente y lateral) y las capturas se han inspeccionado una por una.
- [ ] Ninguna pieza queda por debajo de la base del volumen principal, salvo
      las que el spec declare como apoyo.
- [ ] Comprobada por pares la ausencia de interpenetración entre familias de
      piezas distintas (correa contra bolsillo, hebilla contra esquina, labio
      contra la cara del logotipo).
- [ ] Ninguna pieza que deba verse pegada al cuerpo deja un hueco mayor que
      `0.05` studs.
- [ ] Los elementos repetidos que deben leerse como varios tienen un hueco
      mínimo de `0.09` studs y variación de tamaño o de tono.
- [ ] Lo que debe asomar por encima de un borde asoma al menos `0.12` studs.
- [ ] Ninguna pieza que solo aporta volumen usa el color de detalle.
- [ ] Cada rol declarado en el spec usa su material; ninguna pieza se queda con
      el material por defecto.
- [ ] Todos los elementos de la referencia tienen su pieza; se recorre la tabla
      del contrato de la fase 1 una última vez.

## Fase 11 — Entrega y versionado

1. El constructor vive en `project/src/...` y se versiona con `VERSION` dentro
   del propio módulo.
2. El modelo escribe su versión en el atributo `VersionModelo`, de modo que una
   instancia vieja en el mundo se detecta al instante.
3. El commit describe qué cambió del modelo, no solo el nombre del archivo.
4. La entrega dice qué está verificado y cómo, y qué no lo está. «No verificado
   en Studio» es una frase válida; «terminado» sin prueba, no.

## Fase 12 — Iteración con el revisor

1. El revisor rechaza con una lista de puntos concretos.
2. Cada punto se registra en `02-registro-iteraciones.md` con fecha, versión y
   causa.
3. Cada punto se convierte además en una línea permanente del checklist de la
   fase 10, para que el error no pueda repetirse en otro modelo.
4. Se sube la corrección con la versión incrementada. Nunca se sobrescribe la
   historia.
5. Cuando el rechazo es genérico («encuentra los errores y mejóralo»), la
   auditoría la hace el agente: renderiza, enumera defectos con su causa raíz y
   entrega la lista junto a la corrección.

## Contrato para otra IA

**Entrada mínima requerida**: imagen o descripción de referencia, uso en el
juego, presupuesto de triángulos y escala relativa a un avatar de 5 studs.

**Salida esperada**: un constructor procedimental comentado, un spec en esta
carpeta, una escena de revisión, capturas del modelo renderizado y la entrada
correspondiente en el registro de iteraciones.

**Definición de terminado**: el checklist de la fase 10 está completo y el
revisor aprueba la escena de revisión.

**Prohibiciones**: subir binarios sin fuente, dejar valores mágicos sin nombre,
depender de assets no versionados, declarar terminado un modelo sin haberlo
visto renderizado.
