# plugin/ — Roblox Agent Bridge (Studio)

Plugin ejecutor del protocolo RBX Bridge v0.1. Lee comandos declarativos del repo, los valida contra las listas blancas y los aplica sobre el árbol de instancias con las APIs nativas de Studio. **No usa ni consume la IA nativa de Roblox Studio.**

**v2.0** — **auto-actualización sin reinstalar** y **acceso a la Toolbox**:

- **⟳ Actualizar**: el plugin ahora es un *loader* permanente + un *runtime* que se descarga de este repo. Al arrancar Studio (o al pulsar ⟳ Actualizar, o al abrir el panel tras 5 min) el loader comprueba `plugin/version.json`, descarga los módulos nuevos y reinicia el plugin **en caliente**, con rollback automático si la versión nueva fallara. Ya no hay que reinstalar el `.rbxm` con cada versión — solo si algún día cambia el propio loader (`src/init.server.lua`), cosa rara y anunciada.
- **📦 Nueva op `insert_asset`**: el agente puede insertar modelos y herramientas de la Toolbox/Creator Store por su ID (`InsertService:LoadAsset`). **Seguridad: todos los scripts del asset se eliminan por defecto** (la Toolbox es el vector clásico de malware); conservarlos exige `allow_scripts: true` y eso fuerza aprobación humana aunque el comando sea automático. Limitación conocida: no hay *búsqueda* por nombre desde el plugin (HttpService no puede llamar a roblox.com); se trabaja con IDs exactos.
- Internamente el runtime se dividió en `Main.lua` + `Inspect.lua` + `Chat.lua` y las ops nuevas viven en `OpsExtra.lua` (regla del repo: máx. ~16 KB por archivo).

**v1.9.4** — fix del cliente GitHub: antes de cada PUT se consulta el `sha` actual del archivo (adiós al `422 "sha" wasn't supplied` y al `404` en cascada al aprobar), con un reintento único si el `sha` quedó obsoleto.

**v1.8** — botón **🗺 Entorno** (sube `snapshots/entorno_<ts>.json`: servicios, árbol ligero del Workspace, iluminación, nº de jugadores), hover con **tamaño o nº de hijos**, saludo de bienvenida en el chat y **auto-sync silencioso cada 60 s** (y tras cada respuesta del agente).

**v1.7** — **💬 Chat con el agente**: pestaña CHAT junto a COMANDOS. Escribes tu mensaje (Enter o Enviar) → sube a `chat/inbox/`; el plugin revisa `chat/outbox/` cada 20 s y muestra las respuestas en burbujas. Incluye lo de la v1.6: barra de progreso, registro con colores (✓ verde / ERROR rojo), efecto de presión en botones y fila del cursor con la clase del objeto.

**v1.5** — interfaz rediseñada: paleta oscura, hover en botones, franja de color por estado (ámbar = pendiente, azul = auto, verde = aprobado, violeta = procesando), secciones etiquetadas y chip de versión.

**v1.4** — botón **⬆ Código**: sube todos los scripts del juego de una vez, un archivo por servicio (`snapshots/codigo_<Servicio>_<ts>.json`).

**v1.3** — los scripts suben siempre con su código completo; GUI completas; `mesh_id`/`primary_part`/`shape` en el mundo 3D. *(v1.3.1: profundidad base 3.)*

**v1.2** — contorno cian brillante sobre el objeto bajo el cursor y su path en el panel; la inspección reconoce GUI, modelos con lógica (`scripts_inside`), lo creado por el agente (atributo `_RBX_Bridge`) y marca `play_mode`.

**v1.1** — botón **🔍 Selección**: informe detallado a `snapshots/` de lo seleccionado.

## Requisitos

1. Roblox Studio actualizado.
2. **Game Settings → Security → "Enable Studio Access to API Services" (Allow HTTP Requests)** activado en el place donde trabajas — **es un ajuste POR PLACE**: sin él ni el runtime puede descargarse ni los comandos sincronizan (el panel te avisa).
3. Un token de GitHub *fine-grained* con permiso **Contents: Read and write** limitado **solo** al repo `roblox-agent`. (GitHub → Settings → Developer settings → Personal access tokens → Fine-grained tokens.) El token se pide dentro del plugin; la descarga del runtime NO lo necesita (el repo es público para lectura).

## Instalación (v2.0 — una sola vez)

> ⚠️ Si tenías el plugin viejo (v1.x) instalado, **bórralo primero** de la carpeta de plugins para que no queden dos toolbars.

### Opción A — Rojo (recomendada)

```bash
cd plugin
rojo build bridge.project.json --output RobloxAgentBridge.rbxm
```

Copia `RobloxAgentBridge.rbxm` a la carpeta de plugins de Studio (Plugins → **Plugins Folder**) y reinicia Studio.

### Opción B — Manual (sin Rojo)

Mucho más simple que antes: el plugin instalado es **un único script** (el loader).

1. En Studio, crea un `Script` llamado `RobloxAgentBridge` en ServerScriptService.
2. Copia dentro el contenido de `src/init.server.lua`.
3. Clic derecho sobre el Script → **Save as Local Plugin…** y guárdalo.

Al abrir un place, el loader descarga solo el runtime (Main, UI, Ops…) desde GitHub. Si falla (sin internet, HTTP desactivado), verás un panel mínimo con el error y un botón **Reintentar**.

## Uso

1. Abre el place de tu juego y pulsa **Agent Bridge** en la toolbar.
2. Pega el token y **Guardar** (se almacena local con `plugin:SetSetting`, nunca en el código).
3. **⟳ Sync** — trae los comandos de `commands/pending/`, `approved/` y `processing/` (también se sincroniza solo cada 60 s mientras el panel esté abierto).
4. **Aprobar** mueve el comando a `approved/`. **Ejecutar** lo aplica sobre Studio.
5. Si Studio se cierra a mitad, al volver aparece como `processing` con su progreso: **Continuar** retoma desde la última operación completada.
6. **↩ Deshacer** revierte el último comando vía `ChangeHistoryService`.
7. **🔍 Selección** — inspecciona lo seleccionado y sube el informe a `snapshots/`.
8. **⬆ Código** — sube TODOS los scripts del juego, un archivo por servicio.
9. **🗺 Entorno** — sube un mapa del place a `snapshots/entorno_<ts>.json`.
10. **💬 Chat** — escribe al agente (Enter o Enviar); las respuestas aparecen solas.
11. **⟳ Actualizar** (toolbar, v2.0) — descarga y aplica la última versión del plugin sin reinstalar ni reiniciar Studio. Si ya estás en la última, no hace nada.

### insert_asset (v2.0) — Toolbox/Creator Store

Operación nueva para comandos del agente:

```json
{ "op": "insert_asset", "id": "op_1", "asset_id": 123456789,
  "path": "Workspace", "position": [0, 5, 0], "name": "Arbol_rosa" }
```

- `asset_id` (obligatorio): el ID numérico del asset (el de la URL de la Toolbox).
- `path` (opcional, default `Workspace`): dónde se inserta. Validado contra las raíces permitidas.
- `position` (opcional): `[x, y, z]`; usa `PivotTo` en modelos.
- `name` (opcional): renombra lo insertado.
- `allow_scripts` (opcional, default `false`): si es `true` conserva los scripts del asset y **fuerza aprobación humana**. Por defecto se eliminan todos y el resultado indica cuántos.
- El asset debe ser gratuito/público o propiedad de la cuenta; si no, la op falla con `OP_FAILED` explicando el motivo.
- Lo insertado queda etiquetado con `_RBX_Bridge` como todo lo del bridge.

## Qué NO hace (por diseño)

Publicar el juego, ejecutar código arbitrario enviado por el agente (`loadstring`), HTTP a dominios no aprobados, DataStore, Marketplace, teleports, cambios en Game Settings, búsqueda de la Toolbox por nombre. Ver `schemas/` y la spec del protocolo en Notion.

## Notas

- Los checkpoints se escriben en GitHub tras cada operación (un commit por operación). En v0.2 se evaluará batching con la Git Trees API.
- Un comando que termina con errores va a `failed/`; la reanudación desde `failed/` no está soportada (reenvíalo como comando nuevo).
- Todo lo que el plugin crea queda etiquetado con el atributo `_RBX_Bridge` (id del comando).
- Auto-update: el loader descarga de `raw.githubusercontent.com` (lectura pública, sin token) y prueba la versión nueva en *staging* antes de apagar la que funciona; si algo falla, vuelve a la anterior. Solo un cambio en `src/init.server.lua` (el loader) exigiría reinstalar a mano.
