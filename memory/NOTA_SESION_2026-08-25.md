# Nota de sesión — 2026-08-25

## Plugin v3.0.0 (commits 682979f9, 737ff92b, 51e50e65)

Pedido del usuario: "copia de mi repositorio que acceda a mi Roblox Studio y reconozca su estado actual" + "el plugin haga pruebas en automático de los scripts en busca de errores y lo mande o ponga cómo arreglarlo".

**Limitación física comunicada:** ni el agente (GitHub Actions) ni ningún proceso externo puede abrir Studio; Studio no expone acceso entrante. La vía real es el plugin publicando el estado → eso se implementó.

### Qué se entregó

1. **`plugin/src/Lint.lua`** — análisis estático 100% Luau puro (Roblox no expone `loadstring` ni parser a plugins):
   - Balance de bloques propio: `function/if/for/while/do/repeat` contra `end/until` (el `do` de `for`/`while` no cuenta doble).
   - Balance de pares `()`, `{}`, `[]`.
   - Globals no declarados con rastreo de `local`, nombres de función, parámetros y for-vars (evita falsos positivos); lista blanca de builtins y ~50 servicios.
   - `math.floor(a/b)` → sugiere `//`; `wait()/spawn()/delay()` → sugiere `task.*`.
   - Hallazgo: `{ path, line, severity, code, message, fix }`. Cap 25/script.
2. **`plugin/src/AutoSense.lua`** — sondeo continuo (30 s de tick, arranca a los 15 s):
   - Auto-lint cada 600 s → `lint/findings.json`.
   - Espejo del place cada 300 s → `place/mirror.json` (árbol compacto: nombre, clase, pos/size de BasePart, pivot de Model, líneas de scripts; cap 2500 nodos, 40 hijos/nodo).
   - **Solo escribe cuando algo cambia** (firma FNV-1a guardada en `plugin:SetSetting`), para no inundar commits.
   - Flags en `Config.lua`: `AUTO_LINT`, `AUTO_LINT_SECONDS`, `AUTO_MIRROR`, `AUTO_MIRROR_SECONDS`, `MIRROR_MAX_NODES`; `PATHS.lint` y `PATHS.place`.
3. **Ops nuevas (solo lectura, sin waypoint):**
   - `lint_scripts { path?, max_findings? }` — lint bajo demanda; hallazgos viajan en `data` del result.json.
   - `mirror_place { path?, max_depth?, max_instances? }` — espejo bajo demanda.
   - Registradas en `Validator.REQUIRED` ({}), `Executor.isReadOnly`, `schemas/command.schema.json`.
4. **CI:** `.github/workflows/lint-issues.yml` + `tools/lint-issues.mjs` — al publicarse `lint/**`, sincroniza issues: crea con el arreglo sugerido (label `lint` + `lint:error|warn|info`, clave `<!-- lint-key: path::code -->`), reabre si reaparece, cierra si se resuelve. Cap 50 creaciones/corrida. Permisos: `issues: write`.
5. **`cmd_000047`** en pending: lint de todo el place + espejo de Workspace (profundidad 4). Aprobar → Ejecutar.

### Verificación esperada

- Tras `⟳ Actualizar`: título `v3.0.0`, log `AutoSense activo: lint cada 600s y espejo cada 300s`.
- A los ~5 min de abrir el panel con token: commit `espejo del place (N nodos)` en `place/mirror.json` y, si hay hallazgos, `lint: N hallazgo(s)` + issues automáticos con label `lint`.
- Output limpio si el place está sano: findings.json con `total: 0` y el workflow no crea nada.

## Autos funcionales (cmd_000046, commit 5f7c02c)

- `ServerScriptService.VehicleFactory` (ModuleScript) + `VehicleSpawner` (Script): 2 autos conducibles en el parking del HQ (x=-84 y -76, z=-30, mirando al sur). Tracción total con `HingeConstraint` Motor + dirección servo delantera (bujes + NoCollision). ~50 studs/s. Se reponen solos cada 5 s.
- **Por qué no de la Toolbox:** `insert_asset` exige `asset_id` exacto (un plugin no puede buscar en roblox.com) y sus scripts se borran por seguridad → quedaría inerte. Vía buena: el usuario pasa `asset_id`(s), se inserta SIN scripts como carrocería sobre el chasis propio.
- Constantes tuneables arriba del módulo; si W va marcha atrás → `driveSign = 1`; si D gira al revés → `steerSign = 1`.
- **Pendiente usuario:** ¿limitar paquetes Explosive en auto / pago menor en auto? (afecta deuda 1, balance de entregas).

## Pendientes (sin cambios de prioridad)

- **Pregunta sin responder:** qué hacía el botón "Replicar" de la v1.9.3 local (nunca se subió; la UI del repo es v1.8).
- Prueba de humo `cmd_000045` (inspect_tree) sigue pendiente de ejecutar.
- Deudas del juego: 1 (balance sprint/entregas), 4 (puertas 5→7 studs), 5 (verificar RunStateChanged línea 1099), 6 (`project/default.project.json` no mapea StarterPlayer).
- Recordar al usuario borrar el `RobloxAgentBridge` que Rojo metió en Workspace del place.
- Instalación plugin: ruta del `.rbxmx` precompilado (`plugin/RobloxAgentBridge.rbxmx`) sigue siendo la principal; `rokit.toml` ya está en raíz para quien compile.
