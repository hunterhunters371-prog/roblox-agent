# plugin/ — Roblox Agent Bridge (Studio)

Plugin ejecutor del protocolo RBX Bridge v0.1. Lee comandos declarativos del repo, los valida contra las listas blancas y los aplica sobre el árbol de instancias con las APIs nativas de Studio. **No usa ni consume la IA nativa de Roblox Studio.**

**v1.8** — más amigable y con más contexto del entorno: botón **🗺 Entorno** (sube `snapshots/entorno_<ts>.json`: servicios con sus hijos, árbol ligero del Workspace, iluminación, nº de jugadores), el hover muestra **tamaño o nº de hijos** además de clase y path, **saludo de bienvenida** en el chat explicando cómo pedir cosas, y **auto-sync silencioso cada 60 s** (y tras cada respuesta del agente): si pides «agrega una caja» por el chat, el comando que prepara el agente aparece solo en COMANDOS para que pulses Ejecutar.

**v1.7** — **💬 Chat con el agente**: pestaña CHAT junto a COMANDOS. Escribes tu mensaje (Enter o botón Enviar) → sube a `chat/inbox/`; el plugin revisa `chat/outbox/` cada 20 s y muestra las respuestas del agente en burbujas. Incluye lo de la v1.6: **barra de progreso** durante la ejecución, **registro con colores** (✓ verde / ERROR rojo), efecto de presión en los botones y la fila del cursor con la **clase** del objeto.

**v1.5** — interfaz rediseñada: paleta oscura refinada, botones con efecto hover, filas de comandos con **franja de color según su estado** (ámbar = pendiente, azul = auto, verde = aprobado, violeta = procesando), secciones etiquetadas (Comandos / Registro), log más amplio y chip de versión en la cabecera.

**v1.4** — botón **⬆ Código**: sube **todos los scripts del juego de una vez**, un archivo por servicio (`snapshots/codigo_ServerScriptService_<ts>.json`, `codigo_ReplicatedStorage_...`, `StarterPlayer`, `StarterGui`, `StarterPack`, `Workspace` — incluye los scripts que viven dentro de modelos del mapa). El log confirma por servicio cuántos scripts subieron.

**v1.3** — los **scripts suben siempre con su código completo**, sin importar la profundidad (selecciona una carpeta entera como ServerScriptService y llegan todos); **GUI completas** (árboles a profundidad completa, `ScreenGui`/`BillboardGui`/`SurfaceGui` con sus propiedades, `ImageLabel` con su imagen); `mesh_id`/`primary_part`/`shape` en el mundo 3D; y el log confirma cada subida con el número de instancias y scripts. *(v1.3.1: profundidad base 3 — alcanza scripts dentro de modelos.)*

**v1.2** — mientras el panel está abierto, el objeto bajo el cursor se rodea de un **contorno cian brillante** y su path aparece en el panel (sabes qué vas a subir antes de pulsar Selección). La inspección reconoce **GUI** (UDim2 legible, texto, colores, fuente, z-index), **modelos con lógica** (`scripts_inside`), lo **creado por el agente** (atributo `_RBX_Bridge` con el id del comando) y marca si la captura fue en modo Play (`play_mode`).

**v1.1** — botón **🔍 Selección**: inspecciona lo que tengas seleccionado con el mouse (o en el Explorer) y sube un informe detallado a `snapshots/` del repo (path, clase, atributos, tamaño/posición/material, hijos y, si es un script, su código fuente completo con conteo de líneas).

## Requisitos

1. Roblox Studio actualizado.
2. **Game Settings → Security → "Enable Studio Access to API Services" (Allow HTTP Requests)** activado en el place donde trabajas — **es un ajuste POR PLACE**: si entras a otro juego, actívalo ahí también, o las subidas fallarán (el log del panel te avisa).
3. Un token de GitHub *fine-grained* con permiso **Contents: Read and write** limitado **solo** al repo `roblox-agent`. (GitHub → Settings → Developer settings → Personal access tokens → Fine-grained tokens.)

## Instalación

### Opción A — Rojo (recomendada)

```bash
cd plugin
rojo build bridge.project.json --output RobloxAgentBridge.rbxm
```

Copia `RobloxAgentBridge.rbxm` a la carpeta de plugins de Studio (Plugins → **Plugins Folder**) y reinicia Studio.

### Opción B — Manual (sin Rojo)

1. En Studio, crea un `Script` llamado `RobloxAgentBridge` en ServerScriptService.
2. Copia dentro el contenido de `src/init.server.lua`.
3. Crea como hijos los `ModuleScript`: `Config`, `Base64`, `GitHub`, `Validator`, `PathResolver`, `Ops`, `Executor`, `UI`, cada uno con el contenido de su `src/<nombre>.lua`.
4. Clic derecho sobre el Script → **Save as Local Plugin…** y guárdalo.

## Uso

1. Abre el place de tu juego y pulsa **Agent Bridge** en la toolbar.
2. Pega el token y **Guardar** (se almacena local con `plugin:SetSetting`, nunca en el código).
3. **⟳ Sync** — trae los comandos de `commands/pending/`, `approved/` y `processing/` (también se sincroniza solo cada 60 s mientras el panel esté abierto).
4. **Aprobar** mueve el comando a `approved/`. **Ejecutar** lo aplica sobre Studio.
5. Si Studio se cierra a mitad, al volver aparece como `processing` con su progreso: **Continuar** retoma desde la última operación completada.
6. **↩ Deshacer** revierte el último comando vía `ChangeHistoryService`.
7. **🔍 Selección** — con algo seleccionado (mouse, Explorer, o multi-selección con Ctrl/Shift), sube su informe a `snapshots/seleccion_<timestamp>.json`; el log confirma con `✓ Subida: … — N instancia(s), M script(s)`. El highlight del cursor es del mundo 3D; la GUI 2D se elige en el Explorer.
8. **⬆ Código** (v1.4) — sube TODOS los scripts del juego en un click, un archivo por servicio en `snapshots/codigo_<Servicio>_<timestamp>.json`.
9. **🗺 Entorno** (v1.8) — sube un mapa del place a `snapshots/entorno_<timestamp>.json` para que el agente entienda dónde está parado (servicios, árbol del Workspace, iluminación).
10. **💬 Chat** (v1.7) — pestaña CHAT: escribe al agente (Enter o Enviar). Tu mensaje sube a `chat/inbox/`; las respuestas del agente aparecen solas (sondeo cada 20 s desde `chat/outbox/`). Como el agente no está siempre activo, avísale en Notion («lee el chat») para que responda. Si pides construir algo, el comando aparecerá en COMANDOS (se sincroniza solo) y pulsas **Ejecutar**.

## Qué NO hace (por diseño)

Publicar el juego, ejecutar código arbitrario (`loadstring`), HTTP a dominios no aprobados, DataStore, Marketplace, teleports, cambios en Game Settings. Ver `schemas/` y la spec del protocolo en Notion.

## Notas del MVP

- Los checkpoints se escriben en GitHub tras cada operación (un commit por operación). En v0.2 se evaluará batching con la Git Trees API.
- Un comando que termina con errores va a `failed/`; la reanudación desde `failed/` no está soportada en el MVP (vuelve a enviarlo como comando nuevo).
- Desde la v1.2, todo lo que el plugin crea queda etiquetado con el atributo `_RBX_Bridge` (id del comando) — útil para distinguirlo de lo que ya estaba en el juego.
