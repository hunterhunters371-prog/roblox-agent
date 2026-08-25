# REFERENCIAS - donde verificar antes de escribir un comando

> Creado 2026-08-25. Complemento de `HANDOFF.md` y `WORLD.md`.
> Esto es un indice: no se lee entero, se abre la ruta que toca y se cierra.
> Lo exige la regla 8 de la seccion 4 del HANDOFF.

---

## 0. Por que existe este archivo

Ocho comandos del proyecto se perdieron por dar algo por supuesto en vez de verificarlo:
`cmd_000011`, `012`, `014`, `032` y `043` rechazados; `001`, `016` y `033` fallidos.

El caso mas claro es `cmd_000033`: murio con `PATH_NOT_FOUND` en
`Workspace.Delivery60.Destinations.House_5_Chimney.Smoke` (op_6) porque se asumio que esa pieza
existia. Ocho de sus nueve operaciones si se aplicaron, asi que dejo el mundo a medias: lo peor
de los dos escenarios.

Toda la documentacion oficial de Roblox vive en GitHub, en Markdown, y el agente la puede leer en
vivo sin clonar nada. Verificar cuesta una llamada. Equivocarse cuesta un comando, una sesion de
Studio y, a veces, un mundo a medio construir.

---

## 1. Fuente principal: Roblox/creator-docs

| Dato | Valor |
| --- | --- |
| Repo | `Roblox/creator-docs`, oficial de Roblox (816 estrellas, 4047 forks, se actualiza a diario) |
| Rama | `main` |
| Raiz de contenido | `content/en-us/` |
| Formato | Markdown puro, el mismo texto que publica create.roblox.com/docs |
| Como se lee | herramienta de GitHub `get_file_contents` con owner `Roblox`, repo `creator-docs`, path `content/en-us/...` |
| Clonar o copiar | NO hace falta. Se lee bajo demanda, archivo a archivo. |

La version del motor que documenta esa copia esta en
`content/en-us/reference/engine/STUDIO_VERSION`.

En las tablas siguientes, todas las rutas son relativas a `content/en-us/`.

---

## 2. Mapa: que necesito -> que ruta abro

### 2.1 Verificar el motor antes de escribir un comando (el uso mas frecuente)

| Necesito | Ruta |
| --- | --- |
| Que una clase existe y que propiedades acepta | `reference/engine/classes/` (indice en `reference/engine/classes.md`) |
| Si una propiedad se puede escribir, para no comerse `PROPERTY_NOT_WRITABLE` | la ficha de la clase, en `reference/engine/classes/` |
| Valores validos de un enum: `Material`, `Font`, `EasingStyle`, `HumanoidStateType`... | `reference/engine/enums/` (indice en `reference/engine/enums.md`) |
| Tipos de dato: `Vector3`, `Color3`, `CFrame`, `UDim2`, `NumberSequence` | `reference/engine/datatypes/` |
| Funciones globales: `task`, `warn`, `require`, `tick` | `reference/engine/globals/` |
| Librerias estandar: `math`, `string`, `table`, `os` | `reference/engine/libraries/` |

### 2.2 Calidad y rendimiento

| Necesito | Ruta |
| --- | --- |
| Disenar el rendimiento desde el principio | `performance-optimization/design.md` |
| Localizar que va lento | `performance-optimization/identify.md` y `performance-optimization/microprofiler/` |
| Arreglarlo | `performance-optimization/improve.md` |
| Vigilarlo con jugadores reales | `performance-optimization/monitor.md` |
| Auditar la escena: numero de piezas, mallas, luces | `performance-optimization/scene-analysis.md` |
| Probar en movil y consola | `performance-optimization/test-on-hardware.md` |

### 2.3 Arquitectura

| Necesito | Ruta |
| --- | --- |
| Autoridad del servidor y defensa contra exploits | `projects/server-authority/index.md` y `projects/server-authority/techniques.md` |
| Reparto cliente/servidor y RemoteEvents | `projects/client-server.md` |
| Donde vive cada cosa en el data model | `projects/data-model.md` |
| Rojo, Git y herramientas externas | `projects/external-tools.md` |
| Place files, historial de versiones, publicar | `projects/place-files.md`, `projects/version-history.md`, `projects/update-games.md` |
| Movil y gamepad | `projects/cross-platform.md` |

### 2.4 Codigo

| Necesito | Ruta |
| --- | --- |
| Tipado estricto de Luau | `luau/type-checking.md` |
| Tablas, colas, pilas, metatablas, ambito | `luau/tables.md`, `luau/queues.md`, `luau/stacks.md`, `luau/metatables.md`, `luau/scope.md` |
| Compilacion nativa para codigo caliente | `luau/native-code-gen.md` |
| Patrones de scripting del motor | `scripting/` |

### 2.5 Resto del motor

| Area | Ruta |
| --- | --- |
| HUD e interfaz | `ui/` |
| Fisica, movimiento, personajes, jugadores | `physics/`, `characters/`, `players/`, `input/` |
| Piezas, materiales, entorno, efectos | `parts/`, `environment/`, `effects/` |
| Studio, y el MCP integrado en Studio | `studio/` |
| IA de Roblox: Assistant, flujos acelerados | `ai/`, `assistant/`, `generative-AI.md` |
| Publicar, monetizar, marketplace, nube | `production/`, `marketplace/`, `cloud-services/`, `reference/cloud/` |
| Tutoriales guiados de principio a fin | `tutorials/` |

---

## 3. Aplicacion directa a DELIVERY: 60 SECONDS

| Pieza del proyecto | Doc que la valida |
| --- | --- |
| `DeliveryService` como autoridad, con el cliente solo pintando el HUD | `projects/server-authority/techniques.md` |
| `Remotes.DeliveryEvent` | `projects/client-server.md` |
| Modificadores que tocan el `Humanoid` (`WalkSpeed`, `JumpPower`, `UseJumpPower`) | `reference/engine/classes/` (ficha de `Humanoid`) y `characters/` |
| El `Highlight` del modificador Public (`FillColor`, `FillTransparency`, `OutlineTransparency`) | `reference/engine/classes/` (ficha de `Highlight`) |
| Los `ProximityPrompt` de recogida y entrega | `reference/engine/classes/` (ficha de `ProximityPrompt`) |
| `Delivery60HUD`: `ScreenGui`, `TextLabel`, `UICorner`, `UIStroke` | `ui/` y las fichas de esas clases |
| Materiales y colores de rutas y casas | `reference/engine/enums/` (ficha de `Material`) |
| Coste en rendimiento de las piezas del mapa compacto | `performance-optimization/scene-analysis.md` |
| El Asset Pack 3D que sustituira los bloques | `art/`, `assets/` |

---

## 4. Otros repos que sirven, y los que no

| Repo | Estrellas | Para que |
| --- | --- | --- |
| `Roblox/creator-docs` | 816 | La fuente de la seccion 1. Documentacion oficial en Markdown. |
| `Roblox/cube` | 1240 | Generador 3D de Roblox, de texto a malla. Candidato para el Asset Pack. |
| `Roblox/foreman` | 255 | Gestor de herramientas de linea de comandos (rojo, wally...). Fija versiones por proyecto. |
| `Roblox/roblox-blender-plugin` | 236 | Puente Blender - Roblox para exportar los modelos del Asset Pack. |
| MCP integrado en Studio | - | Documentado en `studio/` y `ai/accelerated-workflows.md`. Carril en vivo, complementario al bridge. |

No usar:

- `Roblox/studio-rust-mcp-server` (481 estrellas) esta **archivado**. Lo sustituye el MCP
  integrado en Studio.
- `boshyxd/robloxstudio-mcp` (483 estrellas) **se archiva en junio de 2026**. Si hiciera falta,
  el fork mantenido es `Chrrxs/robloxstudio-mcp`.
- Los `awesome-roblox` de la comunidad estan abandonados o son testimoniales (13 y 1 estrellas).
- **No existe** repo oficial de guia de estilo de Luau: esa guia esta dentro de `creator-docs`,
  en `luau/`.

---

## 5. Como se deja constancia

Cuando un comando use una clase, propiedad o enum que el proyecto no haya usado antes, se anota
la ruta consultada en el campo `request` del envelope. Asi el chat siguiente sabe que se verifico
y donde, y no repite la consulta. Ejemplo:

```
"request": "Anade el Highlight del modificador Public. FillTransparency y OutlineTransparency
verificados en reference/engine/classes (ficha de Highlight)."
```
