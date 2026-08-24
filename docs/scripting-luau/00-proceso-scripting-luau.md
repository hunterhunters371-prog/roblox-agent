# Proceso de scripting Luau para Roblox — versión 1.0

Proceso que se aplica siempre, en este orden, para producir cualquier mecánica
del juego. Está escrito para que otra IA lo ejecute sin contexto adicional y
pueda mejorarlo. Cada fase declara qué entra, qué sale y cómo se verifica.

## Principios

1. **Al pie de la letra.** La petición del usuario es un contrato. Cada frase se
   convierte en un requisito numerado con su prueba de aceptación. No se añade
   funcionalidad no pedida, aunque parezca obvia, y no se omite ninguna
   condición, aunque parezca menor. Si el enunciado es ambiguo, se pregunta.
2. **Servidor autoritativo.** El servidor decide y valida; el cliente pide y
   muestra. Toda regla que afecte al resultado del juego, al dinero o al progreso
   vive en `ServerScriptService`.
3. **Lógica en módulos, arranque en scripts.** La lógica va en `ModuleScript`
   sin efectos secundarios al requerir. El `Script` solo conecta y arranca. Así
   la mecánica se puede probar desde la Command Bar sin lanzar el juego entero.
4. **Los datos son datos.** Constantes en una tabla de configuración con nombre.
   Ningún número mágico en medio de la lógica. Los valores que el modelado deja
   en el mundo se leen como atributos, nunca por nombre de instancia ni por
   posición supuesta.
5. **Cero dependencias ocultas.** La mecánica funciona con lo que hay en el
   repositorio y en el árbol ya construido. Nada de assets no versionados,
   `loadstring`, HTTP a dominios no aprobados, DataStore, Marketplace ni
   teleports: están bloqueados por diseño en el protocolo del Bridge.
6. **Determinismo y limpieza.** Lo aleatorio se deriva de `Random.new(semilla)`.
   Toda conexión creada se guarda y se desconecta. Todo objeto temporal se
   destruye. Un bucle sin `task.wait` es un cuelgue.
7. **No verificado se dice con esas palabras.** Sin prueba en Studio, no hay
   mecánica terminada.

## Fase 1 — Leer el estado real

**Entra**: la petición del usuario.
**Sale**: contexto confirmado y lista de dudas bloqueantes.

1. Leer `memory/HANDOFF.md` y `memory/WORLD.md` enteros.
2. Listar `commands/pending/` y `commands/completed/` para conocer el estado de
   la cola y el siguiente id libre. Un comando pendiente que toque los mismos
   módulos se resuelve antes: el orden de aprobación importa.
3. Si la mecánica modifica un script existente, recuperar su fuente **verbatim**
   desde el comando de `commands/completed/` que lo creó. `set_script_source`
   reemplaza el archivo entero: escribir sin haber leído borra código que
   funcionaba.
4. Si hace falta saber qué existe en el árbol o dónde está algo, emitir un
   comando de solo lectura con `inspect_tree`, `inspect_instance` o
   `find_instances` y esperar su resultado. Nunca adivinar una ruta ni una
   coordenada.

**Verificación**: se pueden nombrar los módulos afectados y sus rutas reales,
leídas, no supuestas.

## Fase 2 — Traducir la petición a requisitos

**Entra**: petición del usuario y contexto de la fase 1.
**Sale**: tabla de requisitos numerados.

1. Partir el enunciado en frases. Cada frase que impone una condición es un
   requisito con identificador `R1`, `R2`, `R3`.
2. Cada requisito lleva su prueba de aceptación: una acción concreta en Studio y
   el resultado observable exacto que la confirma.
3. Marcar los requisitos que el enunciado deja abiertos. Estos no se rellenan por
   intuición: se preguntan en una lista numerada y corta, y no se programa nada de
   esa parte hasta tener respuesta.
4. Anotar de forma explícita lo que queda **fuera** de alcance, para que el
   revisor no espere lo que no se pidió.

**Verificación**: cada frase del enunciado original aparece en al menos un
requisito, y cada requisito tiene una prueba que otra persona puede ejecutar.

## Fase 3 — Escribir la especificación

**Entra**: tabla de requisitos.
**Sale**: archivo `NN-<mecanica>.spec.md` en esta carpeta.

Se copia [`01-plantilla-mecanica.spec.md`](01-plantilla-mecanica.spec.md) y se
rellena entera: requisitos, máquina de estados, contrato de datos, remotes,
valores de configuración, casos límite y criterios de aceptación. Si algo no
está en el spec, no se programa.

**Verificación**: otra IA puede implementar la mecánica leyendo solo el spec.

## Fase 4 — Diseñar la arquitectura

**Entra**: spec.
**Sale**: lista de instancias a crear, con clase, ruta y responsabilidad.

1. Un `ModuleScript` por responsabilidad, con nombre que dice qué hace. Sin
   módulos «Utils» que acaban siendo un cajón de sastre.
2. Un `Script` de arranque por sistema, en `ServerScriptService`, que solo
   requiere módulos y conecta eventos.
3. Comunicación cliente-servidor mediante `RemoteEvent` para avisos y
   `RemoteFunction` solo cuando se necesita respuesta. Se declaran en el spec con
   nombre, dirección y forma exacta de sus argumentos.
4. Estado del jugador en el servidor. El cliente recibe lo que necesita para
   dibujar, nunca la tabla completa de reglas.
5. Reutilizar lo que ya existe. Los sistemas de servidor construidos hasta ahora
   son `Config`, `Enums`, `PackageTypes`, `PackageFactory`, `DestinationRegistry`,
   `PlayerData`, `RewardService` y `DeliveryService`, más el HUD de cliente. Antes
   de crear un sistema nuevo hay que justificar por qué ninguno de estos sirve.

**Verificación**: el diagrama de responsabilidades cabe en una tabla y ninguna
instancia tiene dos dueños.

## Fase 5 — Escribir el código

**Entra**: arquitectura aprobada.
**Sale**: fuentes Luau completos, listos para `set_script_source`.

Reglas de estilo y corrección, obligatorias:

1. Primera línea `--!strict`. Los tipos se declaran en las firmas públicas del
   módulo.
2. Nada de variables globales. Todo `local`. Los servicios se toman una vez con
   `game:GetService("...")` al principio del archivo.
3. `task.wait`, `task.spawn`, `task.defer` y `task.delay`. Nunca `wait`, `spawn`
   ni `delay` heredados.
4. Ningún bucle sin punto de espera. Los bucles por fotograma van con
   `RunService.Heartbeat` o `RunService.PostSimulation` en servidor y
   `RunService.RenderStepped` solo en cliente y solo para cámara o interfaz.
5. Toda conexión se guarda en una tabla y se desconecta cuando el objeto muere o
   el jugador se va. Una conexión huérfana a `Players.PlayerRemoving` es una fuga
   de memoria garantizada.
6. Preferir eventos a sondeo. `ChildAdded`, `GetPropertyChangedSignal`,
   `GetAttributeChangedSignal` y `Touched` existen para no consultar cada
   fotograma.
7. **Validar todo lo que llega del cliente.** En cada `OnServerEvent` se
   comprueba el tipo de cada argumento, el rango de cada número, la existencia y
   la propiedad de cada instancia, y la distancia real entre el jugador y el
   objeto con el que dice interactuar. Un argumento inesperado se ignora y se
   registra; no se confía nunca.
8. Límite de frecuencia en cada remote: un tiempo mínimo entre llamadas por
   jugador, medido con `os.clock`.
9. `math.clamp` en todo valor que entre en una propiedad física o de interfaz.
10. Lo que puede fallar por causa externa va en `pcall`, y el fallo se maneja;
    no se traga en silencio.
11. Los datos del mundo se leen con `GetAttribute`. Si el atributo falta, la
    mecánica lo dice con un mensaje claro y no continúa con un valor inventado.
12. Comentarios que explican decisiones, no que narran la línea siguiente.
13. `warn` para lo anómalo, `print` con prefijo del sistema para las trazas de
    verificación. Nada de imprimir dentro de un bucle por fotograma.

## Fase 6 — Empaquetar en comandos del Bridge

**Entra**: fuentes Luau.
**Sale**: uno o varios archivos en `commands/pending/`.

1. Envelope versión `0.1`, id `cmd_XXXXXX` con el siguiente número libre, título
   de menos de 200 caracteres, `created_by`, `created_at` en formato ISO 8601 y
   `request` en prosa explicando qué hace y por qué.
2. `ensure_instance` para crear cada `Script`, `ModuleScript`, `LocalScript`,
   `RemoteEvent` o `RemoteFunction`. Es idempotente: reejecutar no duplica.
3. `set_script_source` para el fuente completo. Reemplaza el archivo entero.
4. Dejar `require_approval` y `create_waypoint` en `true`. La aprobación humana y
   el waypoint de Undo son la red de seguridad del proyecto.
5. **Presupuesto de tamaño**: máximo unos 16 KB por archivo escrito y JSON
   compacto, sin espacios tras `:` ni `,`. Un archivo de 28 KB se truncó a mitad
   de escritura y GitHub aceptó JSON inválido sin quejarse. Un módulo grande se
   parte en varios comandos, en orden, y se dice en qué orden hay que aprobarlos.
6. Escrituras de una en una. Dos escrituras simultáneas dan conflicto `409`.
7. Los ids no se reutilizan ni se editan una vez el comando sale de `pending/`.
8. Si al releer un archivo recién escrito en `pending/` parece no existir, se
   busca en `completed/`: el plugin ya lo procesó. No se reemite.

**Verificación**: el comando valida contra `schemas/command.schema.json`, usa
solo raíces y clases permitidas, y pesa menos de 16 KB.

## Fase 7 — Prueba en Studio

**Entra**: comando aprobado y ejecutado.
**Sale**: salida real pegada en el registro.

1. Leer `commands/completed/cmd_XXXXXX.result.json` y confirmar cero errores.
2. Ejecutar la prueba de aceptación de cada requisito del spec, una por una, y
   anotar la salida observada frente a la esperada.
3. Comprobar la consola de Studio: ningún error rojo nuevo, ningún `warn`
   inesperado.
4. Probar el caso límite obvio de cada mecánica: el jugador que se desconecta a
   mitad, la interacción repetida a toda velocidad, el objeto que ya no existe, el
   valor en cero y el valor en el máximo.
5. Si la salida no coincide con la esperada, se analiza **esa** salida antes de
   escribir el siguiente comando. Nunca se encadenan dos cambios sin validación
   intermedia.

**Verificación**: cada requisito del spec tiene marca de aprobado con la salida
que lo demuestra, o marca de fallo con la línea de error exacta.

## Fase 8 — Rendimiento y seguridad

1. Sin trabajo por fotograma que se pueda hacer por evento.
2. Sin `Instance:Destroy` diferido pendiente ni objetos temporales acumulándose
   en `Workspace`.
3. Ninguna regla del juego evaluada en cliente.
4. Ningún remote sin validación de argumentos ni límite de frecuencia.
5. Ningún secreto ni token en el código fuente. El token de GitHub vive en
   `plugin:SetSetting()` y jamás en un archivo del repositorio.

## Fase 9 — Control de calidad

Checklist que se ejecuta entero antes de entregar. Crece con cada fallo
registrado.

- [ ] Cada frase de la petición original tiene su requisito en el spec.
- [ ] Cada requisito tiene prueba ejecutada y salida pegada.
- [ ] Nada implementado que no esté en el spec.
- [ ] Fuente existente leído verbatim antes de reemplazarlo.
- [ ] Ninguna ruta ni coordenada supuesta; todas leídas con `inspect_*`.
- [ ] `--!strict` en todos los archivos nuevos.
- [ ] Cero variables globales.
- [ ] Todas las conexiones desconectadas al morir el objeto o salir el jugador.
- [ ] Todos los argumentos de remote validados en tipo, rango y pertenencia.
- [ ] Límite de frecuencia en cada remote.
- [ ] Ningún bucle sin `task.wait` o sin evento de `RunService`.
- [ ] Ningún número mágico fuera de la tabla de configuración.
- [ ] Atributos leídos con comprobación de ausencia.
- [ ] Comando por debajo de 16 KB y en JSON compacto.
- [ ] Consola de Studio sin errores nuevos.
- [ ] Casos límite probados: desconexión, repetición rápida, objeto ausente,
      valor mínimo y valor máximo.
- [ ] Entrada añadida a `02-registro-mecanicas.md`.

## Fase 10 — Iteración con el revisor

1. El revisor rechaza con una lista de puntos concretos.
2. Cada punto se registra en `02-registro-mecanicas.md` con fecha, versión y
   causa raíz.
3. Cada punto se convierte además en una línea permanente del checklist de la
   fase 9, para que el error no pueda repetirse en otra mecánica.
4. La corrección se sube con la versión incrementada. La historia no se
   sobrescribe.

## Contrato para otra IA

**Entrada mínima requerida**: descripción de la mecánica, qué la dispara, qué
efecto tiene, sobre quién actúa, cuánto dura y qué pasa cuando falla.

**Salida esperada**: un spec en esta carpeta, los fuentes Luau completos, los
comandos del Bridge en `commands/pending/` con su orden de aprobación, y la
entrada correspondiente en el registro.

**Definición de terminado**: el checklist de la fase 9 está completo y el
revisor aprueba la prueba en Studio.

**Prohibiciones**: suponer rutas, reescribir un script sin haberlo leído,
confiar en el cliente, declarar funcionando algo sin salida de Studio, añadir
funcionalidad no pedida y encadenar dos cambios sin validación intermedia.
