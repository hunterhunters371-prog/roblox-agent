# HANDOFF - DELIVERY: 60 SECONDS

> Estado del proyecto a **2026-08-25 09:45 (America/Bogota)**, cola verificada contra el repo.
> Este archivo existe para que un chat nuevo, sin memoria de la conversacion anterior,
> pueda retomar el trabajo sin que haya que explicarle nada.
> Complementos obligatorios: [`memory/WORLD.md`](./WORLD.md) (geometria exacta y contratos del
> codigo) y [`memory/REFERENCIAS.md`](./REFERENCIAS.md) (donde verificar clases, propiedades y
> buenas practicas en la documentacion oficial **antes** de escribir un comando).

---

## 0. Arranque rapido - pegar esto en el chat nuevo

```
Retomo el proyecto DELIVERY: 60 SECONDS, un juego de Roblox.

Todo el contexto esta en el repo de GitHub hunterhunters371-prog/roblox-agent,
rama main, en memory/HANDOFF.md, memory/WORLD.md y memory/REFERENCIAS.md. Leelos
ENTEROS antes de actuar: contienen la geometria ya construida con coordenadas exactas,
la cola de comandos, las deudas tecnicas abiertas y las reglas de trabajo que ya
costaron errores.

El juego se construye a distancia. Los cambios en Roblox Studio se hacen escribiendo
comandos JSON en commands/pending/ que un plugin (RobloxAgentBridge v3.0.0) sincroniza
cada 60 s y ejecuta previa aprobacion manual del usuario en Studio. El plugin se
AUTO-ACTUALIZA: es un loader permanente (v2.1) que descarga el runtime de plugin/src/
segun plugin/version.json; para publicar una mejora del plugin basta subir los archivos
y subir la version en version.json. Solo un cambio en plugin/src/init.server.lua (el
loader) exige reinstalar a mano (ruta principal: plugin/RobloxAgentBridge.rbxmx
precompilado, boton Download raw file; rokit.toml ya existe en la raiz para compilar).

El plugin ademas PUBLICA SOLO (AutoSense, v3.0.0):
- lint/findings.json: lint estatico de todos los scripts, cada 10 min si algo cambio.
  Un workflow (.github/workflows/lint-issues.yml) convierte hallazgos en issues con
  el arreglo sugerido (label lint) y los cierra solos al resolverse.
- place/mirror.json: espejo compacto del estado actual del place, cada 5 min si algo
  cambio. LEERLO para conocer el estado real de Studio sin adivinar nada.

Antes de escribir cualquier comando nuevo:
1. Lista commands/pending/, completed/, failed/ y rejected/ para ver el estado real de
   la cola y cual es el siguiente id libre. El plugin TAMBIEN consume ids: sus
   inspecciones se guardan como comandos. Nunca deduzcas el id del ultimo que
   escribiste tu.
2. Si dudas del formato exacto de una operacion, lee plugin/src/Ops.lua (y
   plugin/src/OpsExtra.lua para las ops nuevas: insert_asset, lint_scripts,
   mirror_place).
3. NUNCA inventes el contenido de un script existente. set_script_source reemplaza
   el archivo entero, asi que primero hay que leer el fuente verbatim desde el
   comando de commands/completed/ que lo creo.
4. Cada archivo que escribas debe pesar menos de 16 KB y usar JSON compacto.
5. Escribe los comandos de uno en uno, nunca en paralelo (da conflictos 409). Para
   varios archivos a la vez, una sola llamada push_files: es atomica.
6. Verifica en la documentacion oficial toda clase, propiedad o enum que el proyecto
   no haya usado antes. El mapa de rutas esta en memory/REFERENCIAS.md.
7. Escribe los comandos en ASCII puro mientras la deuda 7 siga abierta.

Habla en espanol.

Siguiente tarea: [ESCRIBE AQUI LO QUE QUIERES HACER]
```

---

## 1. El proyecto en cinco lineas

**DELIVERY: 60 SECONDS** es un juego de Roblox de repartos contrarreloj. Recoges un paquete
en la tienda, tienes 60 segundos para llegar al destino, y el tipo de paquete cambia como te
mueves: el Normal es libre, el **Heavy** te frena un 35 %, el **Explosive** estalla si recibes
golpes. Esta en fase de prototipo jugable, construido con bloques primitivos que despues se
sustituyen, pieza a pieza, por modelos 3D sin tocar una linea de Lua.

### Documentacion en Notion

Workspace **"Espacio de Albionrpg"**. Buscar por titulo:

| Pagina | Para que sirve |
| --- | --- |
| `DELIVERY: 60 SECONDS - Game Design Document` | El diseno del juego. Fuente de verdad. |
| `Plan de desarrollo - Procesos y metodos` | Como se construye, 13 secciones. La 13 es el registro de ejecucion del Sprint 1. |
| `Asset Pack 3D - Encargo para IA generadora` | El encargo de los modelos 3D, con las medidas que el codigo ya da por supuestas. |
| `Protocolo Bridge v0.1` | El protocolo de comunicacion con Roblox Studio. |
| `EGGBOUND - Etapa 1: Core del Juego` | **Otro proyecto. PAUSADO, no cancelado.** |
| `Round System v1` | Sistema de rondas de EGGBOUND. Diferido. |

El otro repo del usuario, `hunterhunters371-prog/maximizador-ia`, no forma parte de este proyecto.

---

## 2. Estado actual

### Construido y verificado en Studio

- Terreno, dos calles en cruz y aceras.
- **Seis casas** (`House_1` a `House_6`) con tejado a dos aguas, ventanas, puerta, porche, buzon
  y arbol, mas marcadores y prompts de entrega. Las tres nuevas llegaron con `cmd_000034/035/036`.
- **Tienda de 40 x 28**: estructura, escaparate, fachada, pad de recogida, spawn, interior con
  mostrador, cinta y tableros, y exterior con parking, van y mobiliario. El HQ viejo de 20 x 20
  fue demolido.
- Sistemas de servidor: `Config`, `Enums`, `PackageTypes`, `PackageFactory`, `DestinationRegistry`,
  `PlayerData`, `RewardService`, `DeliveryService`, mas el HUD de cliente `Delivery60HUD`.
- **Temporizador de 60 s** con bandas de aviso (`cmd_000039` y `cmd_000040`): warn a 20 s,
  critico a 10 s, cuenta atras final de 5 s, pulso a 2 Hz.
- **Bucle base de entregas encadenado** (`cmd_000041` servidor + `cmd_000042` cliente): al
  completar o fallar, el panel anuncia `NEXT DELIVERY en 3 s` y el servidor encola la siguiente
  entrega. `NEXT_DELIVERY_DELAY = 3`, espejado en el cliente. Salvaguardas: jugador desconectado,
  estado distinto de Idle, personaje muerto.
- **Rutas alternativas v1** (`cmd_000044`, 6/6 sin errores): carpeta `Workspace.Delivery60.Routes`
  con pasarela oeste (plataforma y dos rampas de 30 grados), rampa a la azotea de la tienda,
  rampa a la azotea de `House_6` y un callejon de tres muros. Cubre `House_1`, `House_4`,
  `House_6` y el cruce N-S. Paleta Metal 70,74,82 y Concrete 150,150,155. Las rampas van a 30
  grados para que sigan siendo subibles sin salto.

### Cola real (verificada el 2026-08-25 14:45Z contra el repo)

`commands/pending/` tiene DOS comandos esperando aprobacion en Studio:

- **`cmd_000046`** — autos funcionales: `VehicleFactory` + `VehicleSpawner` en
  ServerScriptService; 2 autos conducibles (HingeConstraint Motor traccion total + direccion
  servo) en el parking del HQ (x=-84 y -76, z=-30). Se reponen solos. Constantes tuneables
  arriba del modulo; `driveSign`/`steerSign` = -1 por defecto (poner a 1 si va invertido).
- **`cmd_000047`** — lint de todos los scripts + espejo de Workspace (solo lectura).

**Siguiente id libre: `cmd_000048`.**

`cmd_000045` no lo escribio el agente: es un `inspect_tree` de `Workspace` lanzado desde el
plugin el 2026-08-25 a las 04:09Z. Las inspecciones del plugin consumen ids de la secuencia.

### Lo que falta del diseno

**Los modificadores de paquete no estan en el juego.** `cmd_000043` (modificador Fragile,
modificador Public y la reescritura de `Data.PackageTypes` con seis tipos) fue **rechazado**
con `VALIDATION_FAILED`; ver deuda 7. En partida siguen existiendo solo Normal, Heavy y
Explosive. Ademas `Modifiers.NoJump` existe en el codigo pero **ningun PackageType lo
referencia**, asi que nunca aparece en una entrega.

---

## 3. Como funciona el pipeline

No hay acceso directo a Roblox Studio. El ciclo es:

1. Se escribe un JSON en `commands/pending/`.
2. El plugin **RobloxAgentBridge v3.0.0** hace Sync cada 60 s (o al pulsar el boton) y lo baja.
3. El usuario lo **aprueba manualmente** en el panel COMANDOS del plugin.
4. El plugin ejecuta las operaciones y sube `commands/completed/cmd_XXXXXX.result.json`.

Arquitectura del plugin (v3.0.0): `init.server.lua` es un **loader** permanente (v2.1: toolbar,
widget, boton **Actualizar**); el runtime (`Main`, `UI`, `Inspect`, `Chat`, `Ops`, `OpsExtra`,
`Executor`, `Validator`, `GitHub`, `Config`, `Base64`, `PathResolver`, **`Lint`, `AutoSense`**)
se descarga de `plugin/src/` segun `plugin/version.json` y se reinicia en caliente con rollback
automatico.

**AutoSense (v3.0.0)**: con el panel abierto y token guardado, el plugin comprueba cada 10 min
el lint de todos los scripts y cada 5 min el espejo del place, y publica `lint/findings.json` y
`place/mirror.json` **solo cuando algo cambia** (firma FNV-1a en plugin settings). El workflow
`lint-issues` abre/reabre/cierra issues con label `lint` y el arreglo sugerido. Flags en
`Config.lua`: `AUTO_LINT`, `AUTO_LINT_SECONDS`, `AUTO_MIRROR`, `AUTO_MIRROR_SECONDS`,
`MIRROR_MAX_NODES`.

Requisito en Studio: **Game Settings > Security > Enable Studio Access to API Services**.
Los objetos creados llevan el atributo `_RBX_Bridge` con el id del comando que los creo.
Botones del plugin: Sync, Seleccion, Codigo, Entorno, Deshacer, COMANDOS, CHAT y, en la
toolbar, **Actualizar**. Place de trabajo: `Lugar de BosneSUS_V2: 08222026_3`.

### Envelope de comando (version 0.1)

```json
{
  "version": "0.1",
  "id": "cmd_000048",
  "title": "maximo 200 caracteres",
  "created_by": "notion-agent",
  "created_at": "2026-08-25T00:00:00Z",
  "request": "explicacion en prosa de que hace y por que",
  "options": { "require_approval": true, "create_waypoint": true },
  "operations": [ { "op": "...", "id": "op_1" } ]
}
```

El id cumple `^cmd_[0-9]{6}$` y los de operacion `^op_[0-9]+$`. Maximo 500 operaciones.
Raices permitidas: `Workspace`, `ReplicatedStorage`, `ServerStorage`, `ServerScriptService`,
`StarterGui`, `StarterPack`, `StarterPlayer`, `Lighting`, `SoundService`, `Teams`.

### Operaciones disponibles

```
inspect_tree      { path, max_depth 1-10, class_filter }
inspect_instance  { path, include_children, include_attributes }
find_instances    { path, class, name_pattern, attribute { name, value } }
ensure_instance   { path, class, properties, create_parents }   <- idempotente
create_instance   { path, class, properties }
set_property      { path, property, value }
set_attribute     { path, name, value }
set_transform     { path, position, rotation, size }
apply_material    { path, material, color }
move_instance     { path, new_parent }
rename_instance   { path, new_name }
clone_instance    { path, new_parent, new_name }
delete_instance   { path }              <- borrado SUAVE a ServerStorage._RBX_Trash
set_script_source { path, source }      <- reemplaza el archivo ENTERO
group_instances   { paths, model_name, parent }
build_structure   { structure, params }
build_from_spec   { parts[ { class*, name, properties, position, rotation, size, parent, anchored } ] }
insert_asset      { asset_id*, path?, position?, name?, allow_scripts? }   <- v2.0: Toolbox
lint_scripts      { path?, max_findings? }                               <- v3.0: solo lectura
mirror_place      { path?, max_depth?, max_instances? }                  <- v3.0: solo lectura
```

`insert_asset` inserta de la Toolbox por ID exacto (no hay busqueda por nombre) y **elimina los
scripts del asset** por defecto; `allow_scripts: true` los conserva y fuerza aprobacion humana.
`lint_scripts`/`mirror_place` devuelven sus resultados en `data` del result.json y no crean
waypoint (son solo lectura).

### Codificacion de valores

- `[x, y, z]` -> `Vector3`
- `[r, g, b]` -> `Color3.fromRGB`
- Cadena -> `EnumItem` (materiales, etc.)
- **La rotacion va en GRADOS.** `[0,90,0]` gira 90 grados sobre Y.
  `[30,0,0]` inclina el extremo +z hacia abajo; `[0,0,-30]` inclina el extremo +x hacia abajo.
- En `build_from_spec`, `anchored` **es true por defecto**. Solo se escribe para desanclar.
- `build_from_spec` **omite silenciosamente los nombres que ya existen**: reejecutar no duplica.
- `set_transform` sin `rotation` conserva la rotacion actual.

### Clases permitidas (`allowed_classes.json`)

Part, WedgePart, CornerWedgePart, MeshPart, UnionOperation, Model, Folder, Script, ModuleScript,
LocalScript, ScreenGui, BillboardGui, SurfaceGui, Frame, TextLabel, TextButton, UICorner, UIStroke,
UIGradient, SpawnLocation, Seat, ProximityPrompt, Attachment, Weld, WeldConstraint, PointLight,
SpotLight, SurfaceLight, ParticleEmitter, Trail, Beam, Fire, Smoke, Sparkles, Sound, Decal, Texture,
Highlight, *Value, RemoteEvent, RemoteFunction, BindableEvent, Atmosphere, Sky, Clouds.

Materiales usados hasta ahora: Grass, Concrete, SmoothPlastic, Neon, Wood, WoodPlanks, Slate,
Brick, Glass, Metal.

### Codigos de error del validador

`VALIDATION_FAILED` `UNSUPPORTED_VERSION` `ROOT_NOT_ALLOWED` `PATH_NOT_FOUND` `PATH_EXISTS`
`PROPERTY_NOT_WRITABLE` `OP_LIMIT_EXCEEDED` `ABORTED_BY_USER` `OP_FAILED` `CLASS_NOT_ALLOWED`

---

## 4. Reglas de trabajo que ya costaron errores

1. **Maximo ~16 KB por archivo escrito, y JSON compacto.** Un `create_or_update_file` de 28 KB
   se trunco a mitad de operacion y GitHub commiteo 27168 bytes de JSON invalido sin quejarse.
   Comprimir: sin espacios tras `:` y `,`, una pieza por linea, y omitir `"Anchored": true`
   porque ya es el valor por defecto.
2. **Escrituras secuenciales, nunca en paralelo.** Dos PUT simultaneos dan `409 is at <sha> but
   expected <sha>`. Para varios archivos, una sola llamada `push_files`: es atomica.
3. **Los ids no se reutilizan ni se editan** una vez el comando sale de `pending/`.
4. **Nunca adivinar el contenido de un script.** `set_script_source` reemplaza el archivo entero;
   hay que leer el fuente verbatim desde el comando de `commands/completed/` que lo creo.
5. **Nunca adivinar una coordenada.** Si hace falta la posicion actual de una pieza, se lee con
   `inspect_instance` en un comando previo. `cmd_000033` murio justo por esto.
6. **Si al releer un archivo recien escrito en `pending/` da "no existe", buscarlo en
   `completed/`, `failed/` y `rejected/`.** No es un fallo: el plugin ya lo proceso.
7. **Puertas de 7 studs de alto como minimo.** El avatar R15 mide ~5 studs.
8. **Verificar en la documentacion oficial antes de usar una clase, propiedad o enum que el
   proyecto no haya usado antes.** El mapa de rutas de `Roblox/creator-docs` esta en
   `memory/REFERENCIAS.md`. Ocho comandos se han perdido por dar cosas por supuestas.
9. **El siguiente id libre se comprueba siempre listando el repo.** El plugin genera comandos
   propios cuando el usuario inspecciona algo (`cmd_000045`), asi que la secuencia avanza sola.
10. **ASCII puro en los comandos** mientras la deuda 7 siga abierta: sin emojis ni acentos
    dentro del JSON, ni en los fuentes de los scripts que viajan en el.

---

## 5. Deudas y bugs abiertos

| # | Problema | Gravedad | Estado |
| --- | --- | --- | --- |
| 1 | **Solvencia de las entregas.** El juego sortea tipo de paquete y destino de forma independiente. Un Heavy (crucero 13.52 studs/s) hacia `House_3` (786 studs) necesita ~58 s de 60: entrega imposible. OJO: los autos de `cmd_000046` (~50 studs/s) vuelven todo muy holgado; decidir si limitan paquetes o pagan menos. | **Alta** | Fix disenado, sin aplicar. Ver seccion 6. |
| 2 | ~~Bug del plugin: PUT sin `sha`.~~ | ~~Alta~~ | **RESUELTA** (v1.9.4; loader v2.1 instalado via `.rbxmx` el 2026-08-25). |
| 3 | **`House_2_Door` cerrada.** `cmd_000029` aplico `rotation [0,90,0]` a todas las puertas; en `House_2` el hueco esta en un muro de normal X y la hoja tapa el hueco con `CanCollide` true. | Baja | Sin corregir. Leer antes su posicion con `inspect_instance`. |
| 4 | **Puertas de 5 studs** en `House_1`, `_2`, `_3`. El avatar mide ~5: no se puede entrar. Las casas nuevas ya van de 7. | Media | Sin corregir. |
| 5 | `RunStateChanged is not a valid member of RunService`. | Nula | Inofensivo. No aparece en el codigo del repo; verificar con el lint de v3.0.0. |
| 6 | **El espejo de Rojo no refleja el juego.** `project/src/` solo contiene `ReplicatedStorage/Modelos/PaqueteNormal.lua` y `ServerScriptService/DemoPaquetes.server.lua`: falta todo `Delivery60`. Ademas `project/default.project.json` no mapea `StarterPlayer`. La fuente de verdad del codigo es `commands/completed/`. | Media | Parcialmente cubierta por `place/mirror.json` (AutoSense v3.0.0). Sin corregir el mapeo de Rojo. |
| 7 | **`cmd_000043` rechazado con `VALIDATION_FAILED` / "JSON invalido"** (2026-08-25T03:58:55Z), el mismo sintoma que `cmd_000032` (2026-08-22). El plugin no pudo decodificar el archivo, asi que los modificadores estrella (Fragile, Public) y los seis tipos de paquete no llegaron al juego. | **Alta** | Sin corregir. Sospecha principal: caracteres no ASCII. Al reemitir: partirlo en dos comandos, iconos en ASCII y comprobar el peso. |
| 8 | `cmd_000038` esta en `completed/` **sin** su `.result.json`. | Nula | Victima del bug viejo del `sha`. Se puede escribir un recibo marcado como recuperado. |

---

## 6. Proximos pasos, en orden

1. **Reemitir los modificadores de paquete (deuda 7).** Es el bloqueante de diseno: sin ellos el
   juego no tiene su mecanica distintiva. Reescribir `cmd_000043` como dos comandos ASCII:
   uno con los modulos `Modifiers.Fragile` y `Modifiers.Public`, otro con la reescritura de
   `Data.PackageTypes` (conservando Normal, Heavy y Explosive byte a byte y anadiendo Fragile,
   NoJump y Public). Leer antes los fuentes verbatim de `commands/completed/cmd_000021.json`.
2. **Ejecutar en Studio `cmd_000046` (autos) y `cmd_000047` (lint + espejo)**: Sync, Aprobar,
   Ejecutar. Despues el auto-lint y el espejo quedan corriendo solos (AutoSense).
3. **Arreglar la solvencia (deuda 1).** Diseno cerrado, pendiente de releer los fuentes de
   `commands/completed/cmd_000024.json` (`PackageFactory`, `DestinationRegistry`, `PlayerData`,
   `RewardService`, `DeliveryService`):
   - `SPRINT_RATIO = 0.6`, `SAFETY = 0.75`.
   - `cruiseSpeed = (WalkSpeed * 0.4 + SprintSpeed * 0.6) * multiplicador` = **20.8** Normal,
     **13.52** Heavy. Presupuesto = `Config.DeliveryTimeSeconds * 0.75` = **45 s**.
   - En `PackageFactory`, filtrar `DestinationRegistry.ListIds()` por `distancia / velocidad <= 45`,
     sortear entre los solventes, con fallback al destino mas cercano. `table.sort(typeIds)` para
     que el orden sea estable.
   - Multiplicadores en una constante local de `PackageFactory` (espejo documentado de
     `Modifiers.Heavy.SpeedMultiplier = 0.65`) para no reescribir `PackageTypes`.
   - Resultado esperado: Heavy queda excluido de `House_2` (46.3 s) y `House_3` (58.2 s).
   - Mas urgente cuando existan seis tipos de paquete: hacerlo despues del paso 1.
   - Con autos: valorar prohibir paquete Explosive en auto o reducir paga en auto.
4. **Playtest guiado** (Plan de desarrollo, seccion 7): cronometrar el recorrido real a cada
   destino, por ruta segura y por atajo, y validar `pathDistanceStuds` y las bandas de
   25/35/45/55 s.
5. **Rutas alternativas v2**: cubrir `House_2`, `House_3` y `House_5`, que quedaron fuera de
   `cmd_000044`. Depende del playtest del paso 4.
6. **Sincronizar el espejo de Rojo y mapear `StarterPlayer`** (deuda 6). Guia oficial en
   `projects/external-tools.md` de `Roblox/creator-docs`.
7. Saldar las deudas 3 y 4 (puertas).
8. **Carroceria de Toolbox para los autos**: el usuario pasa `asset_id`(s) del modelo que le
   guste; se inserta SIN scripts (`allow_scripts:false`) y se suelda sobre el chasis de
   `VehicleFactory`. Nunca adivinar IDs.
9. **Pregunta abierta al usuario**: que hacia el boton "Replicar" de la v1.9.3 local (nunca se
   subio al repo; la UI del repo es v1.8 y no lo tiene). Reimplementarlo como op si se describe.
10. Sprint 2: mas detalle urbano (semaforos, cruces, obras, vallas), trafico y NPCs.
11. Diferido: Round System de EGGBOUND.

---

## 7. Historial de la cola

Verificado contra el repo el 2026-08-25 14:45Z.

```
completed : cmd_000001..013, 015, 017..027, 029, 030, 031, 034, 035, 036, 037,
            038 (*), 039, 040, 041, 042, 044, 045
failed    : cmd_000001, cmd_000016, cmd_000033
rejected  : cmd_000011, cmd_000012, cmd_000014, cmd_000032, cmd_000043
pending   : cmd_000046 (autos), cmd_000047 (lint + espejo)
retirado  : cmd_000028 (redundante, nunca ejecutado)

(*) cmd_000038 no tiene .result.json. Ver deuda 8.
```

El Sprint 1 (`cmd_000020` a `cmd_000027`) se ejecuto con 0 errores. Despues: `cmd_000029` fix de
entorno (29/29), `cmd_000030` detalle de casas (10/10), `cmd_000031` fix de spawn y auditoria
(8/8), `cmd_000033` **fallido** en op_6 con `PATH_NOT_FOUND` en
`Workspace.Delivery60.Destinations.House_5_Chimney.Smoke` y 8 de 9 ops ya aplicadas,
`cmd_000034/035/036` casas nuevas y tienda, `cmd_000037` (6/6), `cmd_000039/040` temporizador,
`cmd_000041/042` bucle encadenado, `cmd_000044` rutas (6/6), `cmd_000045` inspeccion (1/1).

Los dos rechazos por `VALIDATION_FAILED` con el mensaje "JSON invalido" son `cmd_000032` y
`cmd_000043`: mismo sintoma, deuda 7.

### Historial del plugin

- **v1.9.4** (2026-08-24): fix PUT sin sha en `GitHub.lua` (deuda 2).
- **v2.0.0** (2026-08-24): loader + runtime auto-actualizable (boton Actualizar, rollback
  automatico); runtime dividido en `Main`/`Inspect`/`Chat`; ops nuevas en `OpsExtra`; nueva op
  `insert_asset`; `Executor` fusiona `OpsExtra`.
- **v2.0.1 / loader v2.1** (2026-08-24): chip de version sincronizado, cache-bust en la
  descarga, `ClickableWhenViewportHidden`; `plugin/RobloxAgentBridge.rbxmx` precompilado (ruta
  principal de instalacion) y `rokit.toml` en la raiz (`rojo-rbx/rojo@7.4.4`).
- **v3.0.0** (2026-08-25): `Lint.lua` (analisis estatico propio: balance de bloques y pares,
  globals no declarados, APIs deprecadas, con arreglo sugerido por hallazgo), `AutoSense.lua`
  (auto-lint a `lint/findings.json` cada 10 min y espejo a `place/mirror.json` cada 5 min, solo
  cuando algo cambia), ops `lint_scripts` y `mirror_place` (solo lectura), workflow
  `.github/workflows/lint-issues.yml` + `tools/lint-issues.mjs` (issues automaticos con label
  `lint`: crea, reabre si reaparece, cierra si se resuelve). 14 archivos de runtime en
  `version.json`.
