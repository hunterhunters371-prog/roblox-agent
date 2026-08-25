# HANDOFF - DELIVERY: 60 SECONDS

> Estado del proyecto a **2026-08-25 15:20 (America/Bogota)**, cola verificada contra el repo.
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
comandos JSON en commands/pending/ que un plugin (RobloxAgentBridge v3.0.1) sincroniza
cada 60 s y ejecuta previa aprobacion manual del usuario en Studio. El plugin se
AUTO-ACTUALIZA: es un loader permanente (v2.1) que descarga el runtime de plugin/src/
segun plugin/version.json; para publicar una mejora basta subir los archivos y subir
la version en version.json. Solo cambiar plugin/src/init.server.lua exige reinstalar
(ruta principal: plugin/RobloxAgentBridge.rbxmx precompilado, boton Download raw file).

El plugin ademas PUBLICA SOLO (AutoSense, v3.0.1):
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
2. Si dudas del formato exacto de una operacion, lee plugin/src/Ops.lua y
   plugin/src/OpsExtra.lua (ops nuevas: insert_asset, lint_scripts, mirror_place).
3. NUNCA inventes el contenido de un script existente: set_script_source reemplaza
   el archivo entero. Lee el fuente verbatim desde commands/completed/.
4. Cada archivo que escribas debe pesar menos de 16 KB y usar JSON compacto.
5. Escrituras secuenciales, nunca en paralelo (409). Para varios archivos, una sola
   llamada push_files: es atomica.
6. Verifica en la documentacion oficial toda clase, propiedad o enum nueva.
7. ASCII puro en los comandos mientras la deuda 7 siga abierta.
8. NUNCA encoles un comando con ops nuevas mientras el plugin del usuario no este
   actualizado: el runtime viejo lo rechaza como "op desconocido" (le paso a
   cmd_000047). Primero confirmar la version en marcha, despues encolar.
9. Tras CADA push_files que escriba codigo Lua, relee uno de los archivos escritos y
   verifica que las comillas quedaron limpias (" y no \"): en 3.0.0 tres archivos
   subieron con las comillas escapadas, el require de prueba del loader fallaba y
   la actualizacion hacia rollback en silencio.

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
  mostrador, cinta y tableros, y exterior con parking, van y mobiliario. El HQ viejo fue demolido.
- Sistemas de servidor: `Config`, `Enums`, `PackageTypes`, `PackageFactory`, `DestinationRegistry`,
  `PlayerData`, `RewardService`, `DeliveryService`, mas el HUD de cliente `Delivery60HUD`.
- **Temporizador de 60 s** con bandas de aviso (`cmd_000039/040`).
- **Bucle de entregas encadenado** (`cmd_000041/042`): `NEXT_DELIVERY_DELAY = 3`.
- **Rutas alternativas v1** (`cmd_000044`): pasarela oeste, rampas a azoteas de tienda y
  `House_6`, callejon. Cubre `House_1`, `House_4`, `House_6` y el cruce N-S.
- **Autos funcionales** (`cmd_000046`, completado 2026-08-25): `ServerScriptService.VehicleFactory`
  (ModuleScript) + `VehicleSpawner` (Script). Dos autos conducibles en el parking del HQ
  (x=-84 y -76, z=-30, mirando al sur), traccion total con HingeConstraint Motor + direccion
  servo delantera, ~50 studs/s, reposicion automatica cada 5 s. Constantes tuneables arriba del
  modulo; si W va marcha atras -> `driveSign = 1`; si D gira al reves -> `steerSign = 1`.

### Cola real (verificada el 2026-08-25 15:20Z contra el repo)

`pending/`, `approved/` y `processing/` estan **vacias**.

- `cmd_000046` (autos): **completed** con su `.result.json`.
- `cmd_000047` (lint + espejo): **rejected** con `VALIDATION_FAILED / operacion #1 con op
  desconocido` — lo rechazo el runtime v2.0.1, que aun no conocia `lint_scripts`/`mirror_place`
  (el usuario aun no habia actualizado). No reencolar hasta que el plugin marque v3.0.1;
  con AutoSense el lint y el espejo salen solos a los ~10 min de arrancar el panel.

**Siguiente id libre: `cmd_000048`.**

### Lo que falta del diseno

**Los modificadores de paquete no estan en el juego.** `cmd_000043` fue **rechazado** con
`VALIDATION_FAILED`; ver deuda 7. En partida solo existen Normal, Heavy y Explosive.
`Modifiers.NoJump` existe en el codigo pero ningun PackageType lo referencia.

---

## 3. Como funciona el pipeline

No hay acceso directo a Roblox Studio. El ciclo es:

1. Se escribe un JSON en `commands/pending/`.
2. El plugin **RobloxAgentBridge** hace Sync cada 60 s (o al pulsar el boton) y lo baja.
3. El usuario lo **aprueba manualmente** en el panel COMANDOS del plugin.
4. El plugin ejecuta las operaciones y sube `commands/completed/cmd_XXXXXX.result.json`.

Arquitectura del plugin (v3.0.1): `init.server.lua` es un **loader** permanente (v2.1: toolbar,
widget, boton **Actualizar**); el runtime (`Main`, `UI`, `Inspect`, `Chat`, `Ops`, `OpsExtra`,
`Executor`, `Validator`, `GitHub`, `Config`, `Base64`, `PathResolver`, `Lint`, `AutoSense`)
se descarga de `plugin/src/` segun `plugin/version.json` y se reinicia en caliente con rollback
automatico (si el require de prueba falla, conserva la version anterior y el titulo muestra
"fallo la actualizacion": mirar View -> Output, linea `[RBX Bridge loader]`).

**AutoSense (v3.0+)**: con token guardado, comprueba el lint cada 10 min y el espejo cada 5 min,
y publica `lint/findings.json` y `place/mirror.json` **solo cuando algo cambia** (firma FNV-1a
en plugin settings). El workflow `lint-issues` abre/reabre/cierra issues con label `lint`.
Flags en `Config.lua`: `AUTO_LINT`, `AUTO_LINT_SECONDS`, `AUTO_MIRROR`, `AUTO_MIRROR_SECONDS`,
`MIRROR_MAX_NODES`.

Requisito en Studio: **Game Settings > Security > Enable Studio Access to API Services**.
Los objetos creados llevan el atributo `_RBX_Bridge` con el id del comando que los creo.
Place de trabajo: `Lugar de BosneSUS_V2: 08222026_3`.

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

- `[x, y, z]` -> `Vector3`; `[r, g, b]` -> `Color3.fromRGB`; cadena -> `EnumItem`.
- **La rotacion va en GRADOS.** `[0,90,0]` gira 90 grados sobre Y.
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

1. **Maximo ~16 KB por archivo escrito, y JSON compacto.** Un archivo de 28 KB se trunco a mitad
   y GitHub commiteo JSON invalido sin quejarse.
2. **Escrituras secuenciales, nunca en paralelo** (409). Para varios archivos, un solo
   `push_files`: es atomico.
3. **Los ids no se reutilizan ni se editan** una vez el comando sale de `pending/`.
4. **Nunca adivinar el contenido de un script**: leer el fuente verbatim desde
   `commands/completed/` antes de `set_script_source`.
5. **Nunca adivinar una coordenada**: leerla con `inspect_instance` primero. `cmd_000033` murio
   por esto.
6. **Si un archivo recien escrito en `pending/` "no existe", buscarlo en `completed/`,
   `failed/` y `rejected/`**: el plugin ya lo proceso.
7. **Puertas de 7 studs de alto como minimo.** El avatar R15 mide ~5 studs.
8. **Verificar en la documentacion oficial** toda clase/propiedad/enum nueva (REFERENCIAS.md).
9. **El siguiente id libre se comprueba listando el repo** (el plugin tambien consume ids).
10. **ASCII puro en los comandos** mientras la deuda 7 siga abierta.
11. **Tras cada push de codigo Lua, releer un archivo y verificar que las comillas quedaron
    limpias** (`"`, no `\"`). En v3.0.0, `Lint.lua`, `AutoSense.lua` y `Config.lua` subieron con
    las comillas escapadas: el require de prueba del loader fallaba y ⟳ Actualizar hacia
    rollback en silencio. Corregido en v3.0.1.
12. **Nunca encolar comandos con ops nuevas antes de que el plugin del usuario este
    actualizado**: el runtime viejo los rechaza como "op desconocido" en el sync automatico
    (le paso a `cmd_000047`). Primero version nueva en marcha, despues encolar.

---

## 5. Deudas y bugs abiertos

| # | Problema | Gravedad | Estado |
| --- | --- | --- | --- |
| 1 | **Solvencia de las entregas.** Un Heavy (crucero 13.52 studs/s) hacia `House_3` (786 studs) necesita ~58 s de 60: entrega imposible. OJO: los autos (~50 studs/s) vuelven todo muy holgado; decidir si limitan paquetes o pagan menos. | **Alta** | Fix disenado, sin aplicar. Ver seccion 6. |
| 2 | ~~Bug del plugin: PUT sin `sha`.~~ | ~~Alta~~ | **RESUELTA** (v1.9.4; loader v2.1 instalado via `.rbxmx` el 2026-08-25). |
| 3 | **`House_2_Door` cerrada** por la rotacion de `cmd_000029`. | Baja | Sin corregir. Leer antes su posicion con `inspect_instance`. |
| 4 | **Puertas de 5 studs** en `House_1`, `_2`, `_3`. | Media | Sin corregir. |
| 5 | `RunStateChanged is not a valid member of RunService`. | Nula | Verificar con el lint de v3.0.1. |
| 6 | **El espejo de Rojo no refleja el juego** (`project/src/` incompleto; `default.project.json` no mapea StarterPlayer). | Media | Parcialmente cubierta por `place/mirror.json` (AutoSense). |
| 7 | **`cmd_000043` rechazado con "JSON invalido"** (igual que `cmd_000032`). Sospecha: caracteres no ASCII. | **Alta** | Reemitir en dos comandos ASCII (ver seccion 6). |
| 8 | `cmd_000038` esta en `completed/` **sin** su `.result.json`. | Nula | Victima del bug viejo del `sha`. |

---

## 6. Proximos pasos, en orden

1. **Reemitir los modificadores de paquete (deuda 7)** como dos comandos ASCII: uno con
   `Modifiers.Fragile` y `Modifiers.Public`, otro con la reescritura de `Data.PackageTypes`
   (conservar Normal/Heavy/Explosive byte a byte). Leer antes `commands/completed/cmd_000021.json`.
2. **Confirmar plugin v3.0.1 en marcha** (titulo del panel). Entonces AutoSense publica solo
   lint/espejo; si se quiere inmediato, encolar `cmd_000048` (lint_scripts + mirror_place).
3. **Arreglar la solvencia (deuda 1)**. Releer `commands/completed/cmd_000024.json` antes:
   - `SPRINT_RATIO = 0.6`, `SAFETY = 0.75`; crucero **20.8** Normal / **13.52** Heavy;
     presupuesto 45 s. Filtrar destinos en `PackageFactory` por `distancia/velocidad <= 45`,
     fallback al mas cercano. Heavy queda fuera de `House_2` y `House_3`.
   - Con autos: valorar prohibir Explosive en auto o reducir paga en auto.
4. **Playtest guiado** (seccion 7 del Plan): cronometrar recorridos reales y validar las bandas
   de 25/35/45/55 s.
5. **Rutas alternativas v2**: `House_2`, `House_3`, `House_5`. Depende del paso 4.
6. **Sincronizar el espejo de Rojo y mapear `StarterPlayer`** (deuda 6).
7. Saldar las deudas 3 y 4 (puertas).
8. **Carroceria de Toolbox para los autos**: el usuario pasa `asset_id`(s); se inserta SIN
   scripts (`allow_scripts:false`) sobre el chasis de `VehicleFactory`. Nunca adivinar IDs.
9. **Pregunta abierta al usuario**: que hacia el boton "Replicar" de la v1.9.3 local (nunca se
   subio al repo). Reimplementarlo como op si se describe.
10. Sprint 2: detalle urbano, trafico y NPCs. Diferido: Round System de EGGBOUND.

---

## 7. Historial de la cola

Verificado contra el repo el 2026-08-25 15:20Z.

```
completed : cmd_000001..013, 015, 017..027, 029, 030, 031, 034, 035, 036, 037,
            038 (*), 039, 040, 041, 042, 044, 045, 046
failed    : cmd_000001, cmd_000016, cmd_000033
rejected  : cmd_000011, cmd_000012, cmd_000014, cmd_000032, cmd_000043, cmd_000047
pending   : vacia
retirado  : cmd_000028 (redundante, nunca ejecutado)

(*) cmd_000038 no tiene .result.json. Ver deuda 8.
```

`cmd_000046` (autos) completo; `cmd_000047` lo rechazo el runtime v2.0.1 por "op desconocido"
(aun no se habia actualizado a v3.0.x; regla 12). Los rechazos por "JSON invalido" son
`cmd_000032` y `cmd_000043`: deuda 7.

### Historial del plugin

- **v1.9.4** (2026-08-24): fix PUT sin sha en `GitHub.lua` (deuda 2).
- **v2.0.0** (2026-08-24): loader + runtime auto-actualizable; `insert_asset`.
- **v2.0.1 / loader v2.1** (2026-08-24): chip de version sincronizado, cache-bust,
  `RobloxAgentBridge.rbxmx` precompilado, `rokit.toml`.
- **v3.0.0** (2026-08-25): `Lint.lua` + `AutoSense.lua` + ops `lint_scripts`/`mirror_place` +
  workflow `lint-issues`. **Salio rota**: tres archivos subieron con comillas escapadas
  (`\"`), el require de prueba fallaba y el loader hacia rollback (sintoma: "no se actualiza").
- **v3.0.1** (2026-08-25): mismos contenidos con el escaping corregido. 14 archivos de runtime.
