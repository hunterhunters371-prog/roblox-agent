# NOTA DE SESION — 2026-08-24 (noche)

Sesion de mejora del plugin RobloxAgentBridge (repo `roblox-agent`).

## Hecho

1. **v1.9.4 — fix deuda 2 (bug PUT sin sha).** `plugin/src/GitHub.lua`: nuevo
   `_currentSha(path)`; `WriteFile` consulta el sha actual antes de cada PUT cuando no
   lo recibe, y reintenta una vez con sha fresco si hay conflicto. Cubre todas las rutas
   del bug (verificado leyendo `Executor.lua` e `init.server.lua`): aprobar, ejecutar,
   cerrar, rechazar, snapshots, chat y checkpoints.
2. **v2.0.0 — auto-actualizacion del plugin (pedida por el usuario).**
   - `init.server.lua` ahora es un **loader** permanente (~el unico archivo que se
     instala a mano): toolbar (Agent Bridge + ⟳ Actualizar), widget, descarga de
     `plugin/version.json` + los modulos de `plugin/src/` via raw.githubusercontent
     (repo publico → sin token), montaje en un Folder `Runtime`, require de prueba en
     staging ANTES de apagar el runtime viejo y **rollback automatico** si la version
     nueva falla al arrancar. Recheck automatico al abrir el panel (>5 min).
   - El runtime se dividio: `Main.lua` (antes init.server.lua: sync, ciclo de vida,
     token, arranque, stop()), `Inspect.lua` (seleccion, codigo, entorno, hover),
     `Chat.lua` (chat inbox/outbox). Motivo del split: limite de ~16 KB por escritura.
   - Si no hay runtime (sin internet), el loader muestra un fallback con Reintentar.
3. **v2.0.0 — acceso a la Toolbox (pedido por el usuario).**
   - Nueva op `insert_asset { asset_id, path?, position?, name?, allow_scripts? }` en
     `plugin/src/OpsExtra.lua` (Ops.lua estaba en el limite de tamano). Usa
     `InsertService:LoadAsset`. **Elimina todos los scripts del asset por defecto**;
     `allow_scripts: true` los conserva y fuerza aprobacion (Validator.NeedsApproval).
   - `Executor.lua` fusiona `OpsExtra` en el registro de `Ops`.
   - `Validator.lua` valida `asset_id` y el path opcional contra las raices.
   - `schemas/command.schema.json` actualizado. Sin busqueda por nombre: HttpService
     no puede llamar a roblox.com; solo IDs exactos.
4. Docs: `plugin/README.md` reescrito (v2.0 + instalacion de un solo script),
   `memory/HANDOFF.md` al dia.

## Commits (main)

`97dda87` fix sha · `2b567bc1` Main+Chat · `9f15ea3` Inspect · `50e2cc2` OpsExtra+Executor ·
`9207f68` Validator+schema · `3660e6d` loader+version.json · `5f51ad8` README · (este) memoria.

## Pendiente para la proxima sesion

- **El usuario debe instalar el loader UNA vez** (borrar el plugin viejo de la carpeta
  de plugins; opciones en `plugin/README.md`). Sin eso, Studio sigue con la v1.9.3 local.
- Tras instalar: probar ⟳ Actualizar (debe decir "ya estas en la ultima") y un comando
  con `insert_asset` de un asset gratuito conocido.
- Cola del juego: al hacer memoria existian `cmd_000032..036` pendientes (22-08) y
  `cmd_000040` (24-08); `cmd_000037` ya completo. Verificar con ListFiles.
- Deuda 1 (solvencia de entregas) sigue siendo el siguiente fix de fondo del juego.
