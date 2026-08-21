# Nota de sesión — 2026-08-21 (traspaso para otro chat)

Lee esto primero si continúas la conversación. Contiene todo el contexto operativo.

## Quién y qué

- **Usuario**: Albionrpg (zona horaria America/Bogota). Habla español; respóndele en español.
- **Sistema construido**: Notion AI ↔ este repo (`roblox-agent`, GitHub user `hunterhunters371-prog`) ↔ plugin de Roblox Studio. El plugin lee comandos declarativos de `commands/pending/`, los valida y los ejecuta en Studio; reporta resultados al repo.
- **Otro repo del usuario**: `mi-juego-roblox` (su juego "el Pit" + `games/garden-defense/`). Ahí corren `check.py` antes de cada push, se citan REQ-…, y las referencias se tratan como hostiles por defecto (RULES 10-11). Nunca inventar asset IDs (RULE-013).

## Estado del plugin (versión actual: v1.8)

Archivo entregable: `RobloxAgentBridge.rbxmx` (se construye con `/data/build_rbxmx.py` en el sandbox desde `/data/roblox-plugin/src/`; fuente también en `plugin/src/`). Instalación: el usuario copia el archivo a la carpeta de plugins de Studio y reinicia; el token de GitHub persiste (plugin:SetSetting).

Funciones por versión: v1.1 botón 🔍 Selección (sube lo seleccionado a `snapshots/seleccion_<ts>.json`); v1.2 highlight cian del objeto bajo el cursor + GUI + `scripts_inside` + etiqueta `_RBX_Bridge` en lo que crea el plugin + `play_mode`; v1.3/1.3.1 scripts siempre completos a cualquier profundidad + GUI completa (ScreenGui/BillboardGui/SurfaceGui/ImageLabel con imagen) + `mesh_id`/`primary_part`/`shape`; v1.4 botón ⬆ Código (sube TODOS los scripts, un archivo por servicio: `snapshots/codigo_<Servicio>_<ts>.json`); v1.5 rediseño visual; v1.6 barra de progreso + log con colores; v1.7 pestaña 💬 CHAT (`chat/inbox/` ↔ `chat/outbox/`, sondeo 20s); v1.8 botón 🗺 Entorno (`snapshots/entorno_<ts>.json`) + hover con tamaño/hijos + saludo en el chat + auto-sync silencioso cada 60s.

## ⚠️ Lecciones duras (léelas antes de crear comandos)

1. **El plugin valida con su lista de clases LOCAL** (Validator.lua dentro del plugin instalado), NO con `schemas/allowed_classes.json` del repo. Actualizar el schema NO basta: hay que reinstalar el plugin para nuevas clases. **Alternativa preferida**: que los scripts del juego creen las instancias no listadas en runtime (así se corrigió cmd_000014 → cmd_000015: el Tendero crea su propio ProximityPrompt al arrancar).
2. **Raíces permitidas**: Workspace, ReplicatedStorage, ServerScriptService, ServerStorage, StarterPlayer, StarterGui, StarterPack, Lighting, Teams. `StarterPlayerScripts` NO es raíz — usa `StarterPlayer.StarterPlayerScripts.X` (cmd_000012 fue rechazado por esto: ROOT_NOT_ALLOWED).
3. **JSON de comandos**: los strings `source` no pueden llevar saltos de línea crudos (cmd_000011 rechazado por JSON inválido). Componer con `\n` escapados y validar SIEMPRE en sandbox (json.load + raíces + clases) antes de subir.
4. Los comandos rechazados/fallidos no se reanudan: se reenvían como comando NUEVO con id nuevo.
5. `delete_instance` siempre es borrado suave a `ServerStorage._RBX_Trash` (recuperable).
6. "Allow HTTP Requests" es POR PLACE — si el usuario cambia de juego, hay que activarlo ahí o las subidas fallan (el log del panel avisa).

## Estado de comandos (próximo libre: **cmd_000016**)

- cmd_000001–007: la arena (juego previo del usuario: DancerSpawner, ObjectiveGui, etc.).
- cmd_000008–012: entrega del juego garden-defense v2 a través del plugin (Script Garden + 8 ModuleScripts en ServerScriptService + GardenClient LocalScript). Completados.
- **cmd_000013: COMPLETADO** — Mercado Propio construido en Workspace.MercadoPropio (x≈140): suelo, 7 carriles en 2 filas, 3 stands, 3 teleports, EnemySpawn (túnel+camino+waypoints), 13 pads de placement, 4 plataformas, deco, tablón, puente, cajas, cartel de oferta, PuntoDelDueno, carpetas Plants/Enemies.
- cmd_000014: RECHAZADO (CLASS_NOT_ALLOWED · ProximityPrompt — ver lección 1).
- **cmd_000015: ENVIADO (pending)** — Tendero corregido. Si está en `completed/`, ya funcionó. Dummy NPC en el stand de semillas (172,·,-18) con tienda de compra 100% propia: RemoteEvents `ReplicatedStorage.TenderoAbrir/TenderoComprar`, script servidor dentro del modelo (stock de 4 semillas, leaderstats Monedas con 200 inicial, validación de distancia ≤16, entrega Tool) + LocalScript `StarterPlayer.StarterPlayerScripts.TenderoCliente` (menú GUI propio).

## ReferenceLab / Project_001 (límite de IP — MANTENER)

El usuario descargó un juego comercial ("Plants vs Brainrots", 54.780 instancias, watermark hamasecurity/LegendX) como referencia de estudio. Reglas aceptadas por el usuario: **analizar patrones y re-implementar con código propio; NUNCA copiar código, assets ni nombres al juego del usuario**. El Tendero sigue esa regla: patrón prompt→menú→validación servidor→entrega, código escrito de cero. Ya subió el codebase completo a `snapshots/codigo_*` (ReplicatedStorage 1,1 MB incluido) para análisis estático.

Lo aprendido de la referencia (para re-implementación propia): NPCs con ProximityPrompt + módulo de diálogo + Networker cliente/servidor; precios con multiplicador/mutación; PlotTemplate con Lanes/EnemySpawn/Stands/Teleports/Platforms; MoneyLeaderboard; DataStore via ProfileStore; Cmdr para admin.

## Canal chat del plugin

`chat/inbox/msg_<AAAAMMDD_HHMMSS>.json` (usuario → agente) y `chat/outbox/resp_<AAAAMMDD_HHMMSS>.json` (agente → plugin, se muestra en burbuja en ≤20s). El agente NO está siempre activo: el usuario escribe en el chat y avisa en Notion ("lee el chat"); el agente lee inbox/ y responde escribiendo outbox/. Si la respuesta incluye comandos, el auto-sync (60s) los muestra solos en COMANDOS.

## Sandbox (/data/) — útil si sigue la misma máquina

`build_rbxmx.py` (construye el plugin desde `roblox-plugin/src/`), `roblox-plugin/src/` (fuentes v1.8), `cmd_000013/14/15.json` (validados), `validate_cmd.py`, `mi-juego-roblox/` (reconstrucción parcial), `references/PlantsVsBrainrots.rbxl`.

## Próximos pasos sugeridos

1. Verificar `commands/completed/cmd_000015.result.json` cuando el usuario lo ejecute; si falla, leer `errors[]` y corregir.
2. El usuario querrá seguir expandiendo el mercado/jardín (más NPCs, vendedor que compre cosechas, enemigos por los carriles). Usar siempre código propio.
3. Pendientes históricos: persistencia con ProfileStore en garden-defense; limpiar el Script RobloxAgentBridge sobrante en la arena; evidencia en Studio de REQ-GAME-002.
4. Si se necesitan clases nuevas en comandos (p. ej. Humanoid para un dummy caminante), decidir: actualizar plugin (reinstalación) o crear en runtime desde un script (preferido, sin fricción).
