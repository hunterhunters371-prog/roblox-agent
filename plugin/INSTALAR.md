# Instalar el plugin (una sola vez)

## Por qué «no se actualizó»

**Conectar Rojo NO instala un plugin.** `rojo serve` + *Connect* copia el código **dentro del
place** (por eso apareció un `RobloxAgentBridge` en el Explorador). Ahí es código inerte: un
`Script` en el DataModel no corre con permisos de plugin, no crea barra de herramientas y no
puede escribir en GitHub.

El plugin que se ejecutaba seguía siendo el `.rbxm` viejo de la **carpeta de plugins** de
Studio (de ahí el `v1.9.3` y la ausencia del botón `⟳ Actualizar`).

> Regla: **la carpeta de plugins manda**. Rojo sirve para editar el código del juego, no para
> instalar el Bridge.

---

## Paso 0 — borrar el plugin viejo (importante)

Si no lo borras tendrás **dos** paneles y dos barras a la vez.

1. En Studio: pestaña **PLUGINS → Plugins Folder** (abre la carpeta en el explorador de archivos).
   - Windows: `%LOCALAPPDATA%\Roblox\Plugins`
   - macOS: `~/Documents/Roblox/Plugins`
2. Borra cualquier `RobloxAgentBridge*.rbxm` / `.rbxmx` que haya ahí.
3. **Cierra Studio** (así suelta el archivo y no lo reescribe al salir).

Revisa también **PLUGINS → Manage Plugins** por si hubiera una copia de la Creator Store.

---

## Paso 1 — instalar el loader

### Opción A — descargar el plugin ya construido (recomendada, sin terminal)

1. Abre <https://github.com/hunterhunters371-prog/roblox-agent/blob/main/plugin/RobloxAgentBridge.rbxmx>
2. Botón **Download raw file** (el icono de la flecha, arriba a la derecha del archivo).
3. Mueve `RobloxAgentBridge.rbxmx` a la carpeta de plugins del Paso 0.
4. Abre Studio.

Ese `.rbxmx` es texto (XML) y contiene solo el loader; el runtime lo descarga él mismo.

### Opción B — Command Bar de Studio

⚠️ La **Command Bar es una barra dentro de Roblox Studio** (`View → Command Bar`, aparece
abajo junto a la Output), **no** la consola de Windows: si pegas Lua en `cmd.exe` obtienes
`"local" no se reconoce como un comando interno o externo`.

Con **Game Settings → Security → Allow HTTP Requests** activado, pega en la Command Bar:

```lua
local s = Instance.new("Script") s.Name = "RobloxAgentBridge" s.Source = game:GetService("HttpService"):GetAsync("https://raw.githubusercontent.com/hunterhunters371-prog/roblox-agent/main/plugin/src/init.server.lua") s.Parent = game:GetService("ServerStorage")
```

Luego clic derecho en `ServerStorage → RobloxAgentBridge` → **Save as Local Plugin…**, y borra
el Script de `ServerStorage`.

### Opción C — desde lo que Rojo ya sincronizó

Con Rojo conectado, clic derecho sobre el `RobloxAgentBridge` del place → **Save as Local
Plugin…**. Después **Disconnect** y **borra** ese objeto del place (si no, se guarda dentro del juego).

### Opción D — con terminal

```bash
cd C:\ruta\real\del\repo
rokit install
rojo build plugin/loader.project.json -o RobloxAgentBridge.rbxm
```

Errores típicos:

- `ERROR Failed to find tool 'rojo' in any project manifest file` → el `rojo` del PATH es un
  atajo de **Rokit**, que exige un `rokit.toml` con la herramienta declarada. Ejecútalo **desde
  la raíz del repo** (ya incluye `rokit.toml`) tras `rokit install`, o instala global:
  `rokit add --global rojo-rbx/rojo`.
- `rokit install` → `Installed and created links for 0 tools`: no estabas en el repo.
- `fatal: not a git repository` → tampoco estabas en el repo. `cd <carpeta...>` con los signos
  `<>` no es un comando válido: hay que escribir la ruta real. Para localizarla en Windows:
  `where /r C:\Users\%USERNAME% bridge.project.json`

`loader.project.json` construye **solo** `init.server.lua`. `bridge.project.json` es para
`rojo serve`; **no** lo uses para instalar.

---

## Paso 2 — verificar que sí entró

La primera vez Studio pedirá permiso de **inyección de scripts** (el loader escribe el `Source`
de los módulos que descarga) y de **HTTP**: acepta ambos o no podrá construir el runtime.

Deben cumplirse las cuatro:

1. En la barra hay **dos** botones: `Agent Bridge` y **`⟳ Actualizar`**. Si falta el segundo,
   sigues con el plugin viejo → repite el Paso 0.
2. El **título del panel** dice `Roblox Agent Bridge — v2.0.1`.
3. El **chip** de la cabecera dice `v2.0.1` (el loader lo reescribe; en `UI.lua` va escrito a mano,
   y por eso antes mostraba una versión antigua aunque hubiera actualizado).
4. En la **Output**: `[RBX Bridge] runtime v2.0.1 en marcha (loader v2.1)`.

---

## A partir de ahora

- Publico una versión nueva → pulsas **`⟳ Actualizar`** (o abres el panel; también comprueba solo
  cada 5 min con el panel abierto). Reinicio en caliente, sin reinstalar.
- Si no hay nada nuevo, el título avisa `v2.0.1 · ya al día` unos segundos.
- Si la versión nueva estuviera rota, el loader **vuelve solo a la anterior** (rollback) y lo
  escribe en la Output.
- **Solo** hay que reinstalar a mano si cambia `plugin/src/init.server.lua` (el loader). En ese caso
  hay que regenerar también `plugin/RobloxAgentBridge.rbxmx`, que lleva una copia embebida.

---

## Nota sobre el botón «Replicar»

La v1.9.3 que tenías instalada mostraba un botón **Replicar** que **no existe en este repo**
(el `UI.lua` versionado es la v1.8 y no lo tiene, y no hay ninguna coincidencia de «Replicar» en
todo el código). Se añadió a mano en tu copia local y nunca se subió, así que al instalar el
loader ese botón desaparece. Si lo usabas, dime qué hacía y lo reimplemento como op del Bridge.
