# Instalar el plugin (una sola vez)

## Por qué «no se actualizó»

**Conectar Rojo NO instala un plugin.** `rojo serve` + *Connect* copia el código **dentro del
place** (por eso apareció un `RobloxAgentBridge` en el Explorador, dentro de Workspace). Ahí
es código inerte: un `Script` en el DataModel no corre con permisos de plugin, no crea barra
de herramientas y no puede escribir en GitHub.

El plugin que se estaba ejecutando seguía siendo el `.rbxm` viejo de la **carpeta de plugins**
de Studio (de ahí el `v1.9.3` y la ausencia del botón `⟳ Actualizar`).

> Regla para el futuro: **la carpeta de plugins manda**. Rojo sirve para editar el código del
> juego, no para instalar el Bridge.

---

## Paso 0 — borrar el plugin viejo (importante)

Si no lo borras tendrás **dos** paneles y dos barras a la vez.

1. En Studio: pestaña **PLUGINS → Plugins Folder** (abre la carpeta en el explorador de archivos).
   - Windows: `%LOCALAPPDATA%\Roblox\Plugins`
   - macOS: `~/Documents/Roblox/Plugins`
2. Borra cualquier `RobloxAgentBridge*.rbxm` / `.rbxmx` que haya ahí.
3. **Cierra Studio** (así suelta el archivo y no lo vuelve a escribir al salir).

Comprueba también **PLUGINS → Manage Plugins** por si hubiera una copia instalada desde la
Creator Store.

---

## Paso 1 — instalar el loader

### Opción A — sin Rojo ni terminal (recomendada, 30 segundos)

1. Activa **Game Settings → Security → Allow HTTP Requests** (y *Enable Studio Access to API
   Services*). El Bridge los necesita igual.
2. Abre la **Command Bar** (View → Command Bar) y pega esta línea:

```lua
local s = Instance.new("Script") s.Name = "RobloxAgentBridge" s.Source = game:GetService("HttpService"):GetAsync("https://raw.githubusercontent.com/hunterhunters371-prog/roblox-agent/main/plugin/src/init.server.lua") s.Parent = game:GetService("ServerStorage")
```

3. En el Explorador, **clic derecho** sobre `ServerStorage → RobloxAgentBridge` →
   **Save as Local Plugin…** → nombre `RobloxAgentBridge` → Guardar.
4. **Borra** ese Script de `ServerStorage` (ya no hace falta; si lo dejas se guarda dentro del juego).

Si el paso 2 falla por HTTP, abre `plugin/src/init.server.lua` en tu editor, copia todo y pégalo
a mano en el `Source` de un `Script` nuevo llamado `RobloxAgentBridge`; luego sigue en el paso 3.

### Opción B — desde lo que Rojo ya sincronizó

Con Rojo conectado, clic derecho sobre el `RobloxAgentBridge` que aparece en el place →
**Save as Local Plugin…**. Después **Disconnect** y **borra** ese objeto del place.

### Opción C — con terminal

```bash
cd <carpeta del repo>
rokit install
rojo build plugin/loader.project.json -o RobloxAgentBridge.rbxm
```

Mueve `RobloxAgentBridge.rbxm` a la carpeta de plugins del Paso 0 y abre Studio.

**Si ves `ERROR Failed to find tool 'rojo' in any project manifest file`:** el `rojo` de tu PATH
es un atajo de **Rokit**, que exige un `rokit.toml` que declare la herramienta. Dos salidas:

- ejecutar el comando **desde la raíz del repo** (ya incluye `rokit.toml`) tras `rokit install`; o
- instalarlo global: `rokit add --global rojo-rbx/rojo`.

Y recuerda que las rutas son relativas al repo: en `C:\Users\dayal\` no existe
`plugin/loader.project.json`.

`loader.project.json` construye **solo** `init.server.lua` (el loader). El resto del runtime
(`Main`, `UI`, `Ops`…) lo descarga el propio loader desde GitHub, así que no hay módulos
duplicados ni versiones mezcladas. `bridge.project.json` sigue existiendo para `rojo serve`,
pero **no** lo uses para instalar.

---

## Paso 2 — verificar que sí entró (30 segundos)

La primera vez Studio pedirá permiso de **inyección de scripts** (el loader escribe el `Source`
de los módulos que descarga) y de **HTTP**: aceptar ambos, o no podrá construir el runtime.

Deben cumplirse las cuatro:

1. En la barra de herramientas hay **dos** botones: `Agent Bridge` y **`⟳ Actualizar`**.
   Si falta `⟳ Actualizar`, sigues con el plugin viejo → repite el Paso 0.
2. El **título del panel** dice `Roblox Agent Bridge — v2.0.1` (la versión en marcha, siempre visible).
3. El **chip** de la cabecera dice `v2.0.1` (el loader lo reescribe; antes estaba fijo en el código
   de `UI.lua`, y por eso mostraba una versión antigua aunque hubiera actualizado).
4. En la **Output** de Studio: `[RBX Bridge] runtime v2.0.1 en marcha (loader v2.1)`.

---

## A partir de ahora

- Publico una versión nueva → pulsas **`⟳ Actualizar`** (o abres el panel; también comprueba solo
  cada 5 min con el panel abierto). Se reinicia en caliente, sin reinstalar nada.
- Si no hay nada nuevo, el título avisa `v2.0.1 · ya al día` unos segundos.
- Si la versión nueva estuviera rota, el loader **vuelve solo a la anterior** (rollback) y lo
  escribe en la Output.
- **Solo** hay que reinstalar a mano si cambia `plugin/src/init.server.lua` (el loader). Se avisará
  en el README y en la nota de sesión.

---

## Nota sobre el botón «Replicar»

La v1.9.3 que tenías instalada mostraba un botón **Replicar** que **no existe en este repo**
(el `UI.lua` versionado es la v1.8 y no lo tiene, y no hay ninguna coincidencia de «Replicar»
en todo el código). Se añadió a mano en tu copia local y nunca se subió, así que al instalar el
loader ese botón desaparece. Si lo usabas, dime qué hacía y lo reimplemento como op del Bridge.
