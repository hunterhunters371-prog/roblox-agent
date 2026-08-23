# HANDOFF - DELIVERY: 60 SECONDS

> Estado del proyecto a **2026-08-22 19:00 (America/Bogota)**.
> Este archivo existe para que un chat nuevo, sin memoria de la conversacion anterior,
> pueda retomar el trabajo sin que haya que explicarle nada.
> Complemento obligatorio: [`memory/WORLD.md`](./WORLD.md) (geometria exacta y contratos del codigo).

---

## 0. Arranque rapido - pegar esto en el chat nuevo

```
Retomo el proyecto DELIVERY: 60 SECONDS, un juego de Roblox.

Todo el contexto esta en el repo de GitHub hunterhunters371-prog/roblox-agent,
rama main, en memory/HANDOFF.md y memory/WORLD.md. Leelos ENTEROS antes de actuar:
contienen la geometria ya construida con coordenadas exactas, la cola de comandos,
las deudas tecnicas abiertas y las reglas de trabajo que ya costaron errores.

El juego se construye a distancia. Los cambios en Roblox Studio se hacen escribiendo
comandos JSON en commands/pending/ que un plugin (RobloxAgentBridge v1.9.3) sincroniza
cada 60 s y ejecuta previa aprobacion manual del usuario en Studio.

Antes de escribir cualquier comando nuevo:
1. Lista commands/pending/ y commands/completed/ para ver el estado real de la cola
   y cual es el siguiente id libre.
2. Si dudas del formato exacto de una operacion, lee plugin/src/Ops.lua.
3. NUNCA inventes el contenido de un script existente. set_script_source reemplaza
   el archivo entero, asi que primero hay que leer el fuente verbatim desde el
   comando de commands/completed/ que lo creo.
4. Cada archivo que escribas debe pesar menos de 16 KB y usar JSON compacto.
   Un archivo mas grande se trunca a mitad de escritura y GitHub lo acepta roto.
5. Escribe los comandos de uno en uno, nunca en paralelo (da conflictos 409).

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
- **Tres casas** (`House_1`, `House_2`, `House_3`) con tejado a dos aguas, ventanas, puerta,
  porche, buzon y arbol.
- **HQ antiguo** de 20 x 20 en el origen, con pad de recogida y punto de aparicion.
  *(Lo demuele `cmd_000035`.)*
- Sistemas de servidor completos: `Config`, `Enums`, `PackageTypes`, `PackageFactory`,
  `DestinationRegistry`, `PlayerData`, `RewardService`, `DeliveryService`, mas HUD de cliente.
- Sprint 1 ejecutado en 8 comandos con **0 errores**.

### En cola, escrito pero sin ejecutar

> **Deben aprobarse en orden numerico.** El 33 decora lo que construye el 32,
> y el 36 amuebla lo que construye el 35.

| Comando | Que hace | Ops |
| --- | --- | --- |
| `cmd_000032` | Estructura de `House_4`, `House_5`, `House_6` + marcadores + prompts de entrega | 8 |
| `cmd_000033` | Detalle decorativo de las tres casas nuevas: ventanas, porches, faroles con luz, humo | 9 |
| `cmd_000034` | Reescribe `ReplicatedStorage.Delivery60.Data.Destinations` con los 6 destinos | 2 |
| `cmd_000035` | Demuele el HQ viejo y levanta la tienda de 40 x 28: estructura, escaparate, fachada, pad, spawn | 10 |
| `cmd_000036` | Interior de la tienda (mostrador, cinta, tableros) y exterior (parking, van, mobiliario) | 7 |

**Siguiente id libre: `cmd_000037`.**

---

## 3. Como funciona el pipeline

No hay acceso directo a Roblox Studio. El ciclo es:

1. Se escribe un JSON en `commands/pending/`.
2. El plugin **RobloxAgentBridge v1.9.3** hace Sync cada 60 s (o al pulsar el boton) y lo baja.
3. El usuario lo **aprueba manualmente** en el panel COMANDOS del plugin.
4. El plugin ejecuta las operaciones y sube `commands/completed/cmd_XXXXXX.result.json`.

Requisito en Studio: **Game Settings > Security > Enable Studio Access to API Services**.
Los objetos creados llevan el atributo `_RBX_Bridge` con el id del comando que los creo.
Botones del plugin: Sync, Seleccion, Codigo, Replicar, Entorno, Deshacer, COMANDOS, CHAT.
Place de trabajo: `Lugar de BosneSUS_V2: 08222026_3`.

### Envelope de comando (version 0.1)

```json
{
  "version": "0.1",
  "id": "cmd_000037",
  "title": "maximo 200 caracteres",
  "created_by": "notion-agent",
  "created_at": "2026-08-23T00:00:00Z",
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
```

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
   El plugin lo habria rechazado con `VALIDATION_FAILED`. Comprimir: sin espacios tras `:` y `,`,
   una pieza por linea, y omitir `"Anchored": true` porque ya es el valor por defecto.
2. **Escrituras secuenciales, nunca en paralelo.** Dos PUT simultaneos dan `409 is at <sha> but
   expected <sha>`.
3. **Los ids no se reutilizan ni se editan** una vez el comando sale de `pending/`.
4. **Nunca adivinar el contenido de un script.** `set_script_source` reemplaza el archivo entero;
   hay que leer el fuente verbatim desde el comando de `commands/completed/` que lo creo.
5. **Nunca adivinar una coordenada.** Si hace falta la posicion actual de una pieza, se lee con
   `inspect_instance` en un comando previo.
6. **Si al releer un archivo recien escrito en `pending/` da "no existe", buscarlo en
   `completed/`.** No es un fallo: el plugin ya lo proceso. No reemitir el comando.
7. **Puertas de 7 studs de alto como minimo.** El avatar R15 mide ~5 studs.

---

## 5. Deudas y bugs abiertos

| # | Problema | Gravedad | Estado |
| --- | --- | --- | --- |
| 1 | **Solvencia de las entregas.** El juego sortea tipo de paquete y destino de forma independiente. Un Heavy (crucero 13.52 studs/s) hacia `House_3` (786 studs) necesita ~58 s de 60: entrega imposible. | **Alta** | Fix disenado, sin aplicar. Ver seccion 6. |
| 2 | **Bug del plugin: PUT sin `sha`.** Al reescribir un archivo existente el plugin no manda el `sha` y GitHub responde `422 "sha" wasn't supplied`. En cascada, al aprobar da `404 Not Found`. | **Alta** | Mitigado a mano borrando los archivos atascados de la cola. **No parcheado.** Arreglo: en `plugin/src/GitHub.lua`, pedir el `sha` actual antes de cada PUT. Requiere reinstalar el plugin en Studio. |
| 3 | **`House_2_Door` cerrada.** `cmd_000029` aplico `rotation [0,90,0]` a todas las puertas; en `House_2` el hueco esta en un muro de normal X y la hoja queda dentro del hueco, tapandolo con `CanCollide` true. | Baja (cosmetico) | Sin corregir. Hay que leer antes su posicion exacta con `inspect_instance`. |
| 4 | **Puertas de 5 studs** en `House_1`, `_2`, `_3`. El avatar mide ~5: no se puede entrar. Las casas nuevas ya van de 7. | Media | Sin corregir. |
| 5 | `RunStateChanged is not a valid member of RunService`, en `RobloxAgentBridge` linea 1099. | Nula | Inofensivo, ruido en consola. |
| 6 | `project/default.project.json` **no mapea `StarterPlayer`** en la configuracion de Rojo. | Baja | Sin corregir. |

---

## 6. Proximos pasos, en orden

1. **Aprobar `cmd_000032` a `cmd_000036` en Studio, en orden numerico.** Leer despues cada
   `commands/completed/cmd_00003X.result.json` para confirmar 0 errores.
2. **Arreglar la solvencia (deuda 1).** Diseno ya cerrado, pendiente solo de releer los fuentes:
   - Releer `commands/completed/cmd_000024.json` (contiene `PackageFactory`, `DestinationRegistry`,
     `PlayerData`, `RewardService`, `DeliveryService`) y `cmd_000021.json` (contiene `PackageTypes`).
   - Constantes: `SPRINT_RATIO = 0.6`, `SAFETY = 0.75`.
   - `cruiseSpeed = (WalkSpeed * 0.4 + SprintSpeed * 0.6) * multiplicador` = **20.8** Normal,
     **13.52** Heavy. Presupuesto = `Config.DeliveryTimeSeconds * 0.75` = **45 s**.
   - En `PackageFactory`, filtrar `DestinationRegistry.ListIds()` por `distancia / velocidad <= 45`,
     sortear entre los solventes, con fallback al destino mas cercano. `table.sort(typeIds)` para
     que el orden sea estable.
   - Poner los multiplicadores en una constante local de `PackageFactory` (espejo documentado de
     `Modifiers.Heavy.SpeedMultiplier = 0.65`) para no tener que reescribir `PackageTypes`.
   - Resultado esperado: Heavy queda excluido de `House_2` (46.3 s) y `House_3` (58.2 s).
     Normal y Explosive alcanzan los 6 destinos. `DestinationRegistry` no se toca.
3. **Playtest guiado** (Plan de desarrollo, seccion 7): cronometrar el recorrido real a cada
   destino y validar `pathDistanceStuds` y las bandas de 25/35/45/55 s.
4. Saldar las deudas 3 y 4 (puertas).
5. Decidir si se parchea el plugin (deuda 2).
6. Sprint 2: mas detalle urbano (semaforos, cruces, obras, vallas), trafico y NPCs,
   rutas alternativas por destino.
7. Diferido: Round System de EGGBOUND.

---

## 7. Historial de la cola

```
completed : cmd_000001..013, 015, 017..027, 029, 030, 031
failed    : cmd_000001, cmd_000016
rejected  : cmd_000011, cmd_000012, cmd_000014
pending   : cmd_000032, 033, 034, 035, 036
retirado  : cmd_000028 (redundante, nunca ejecutado)
```

El Sprint 1 (`cmd_000020` a `cmd_000027`) se ejecuto con 0 errores. Despues:
`cmd_000029` fix de entorno (29/29), `cmd_000030` detalle de casas (10/10),
`cmd_000031` fix de spawn y auditoria (8/8).
