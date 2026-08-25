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

---

## Paso 1 — instalar el loader

### Opción A — sin terminal (usando lo que Rojo ya sincronizó)

1. Abre Studio y conecta Rojo como siempre.
2. En el **Explorador**, busca el objeto `RobloxAgentBridge` que Rojo dejó en el place.
3. Clic derecho sobre él → **Save as Local Plugin…** → nombre `RobloxAgentBridge` → Guardar.
4. **Rojo → Disconnect** y **borra** ese `RobloxAgentBridge` del place (si no, se guarda dentro
   del juego y acaba publicado como basura).

El plugin aparece al instante, sin reiniciar Studio.

### Opción B — con terminal (más limpia, 1 solo archivo)

```bash
cd <carpeta del repo>
rojo build plugin/loader.project.json -o RobloxAgentBridge.rbxm
```

Mueve `RobloxAgentBridge.rbxm` a la carpeta de plugins del Paso 0 y abre Studio.

`loader.project.json` construye **solo** `init.server.lua` (el loader). El resto del runtime
(`Main`, `UI`, `Ops`…) lo descarga el propio loader desde GitHub, así que no hay módulos
duplicados ni versiones mezcladas. `bridge.project.json` sigue existiendo para `rojo serve`,
pero **no** lo uses para instalar.

---

## Paso 2 — verificar que sí entró (30 segundos)

Deben cumplirse las cuatro:

1. En la barra de herramientas hay **dos** botones: `Agent Bridge` y **`⟳ Actualizar`**.
   Si falta `⟳ Actualizar`, sigues con el plugin viejo → repite el Paso 0.
2. El **título del panel** dice `Roblox Agent Bridge — v2.0.1` (la versión en marcha, siempre visible).
3. El **chip** de la cabecera dice `v2.0.1` (el loader lo reescribe; antes estaba fijo en el código
   de `UI.lua`, y por eso mostraba una versión antigua aunque hubiera actualizado).
4. En la **Output** de Studio: `[RBX Bridge] runtime v2.0.1 en marcha (loader v2.1)`.

Requisitos del place: **Game Settings → Security → Allow HTTP Requests** y **Enable Studio
Access to API Services** activados.

---

## A partir de ahora

- Publico una versión nueva → pulsas **`⟳ Actualizar`** (o abres el panel; también comprueba solo
  cada 5 min con el panel abierto). Se reinicia en caliente, sin reinstalar nada.
- Si no hay nada nuevo, el título avisa `v2.0.1 · ya al día` unos segundos.
- Si la versión nueva estuviera rota, el loader **vuelve sola a la anterior** (rollback) y lo
  escribe en la Output.
- **Solo** hay que reinstalar a mano si cambia `plugin/src/init.server.lua` (el loader). Se avisará
  en el README y en la nota de sesión.

---

## Nota sobre el botón «Replicar»

La v1.9.3 que tenías instalada mostraba un botón **Replicar** que **no existe en este repo**
(el `UI.lua` versionado es la v1.8 y no lo tiene, y no hay ninguna coincidencia de «Replicar»
en todo el código). Se añadió a mano en tu copia local y nunca se subió, así que al instalar el
loader ese botón desaparece. Si lo usabas, dime qué hacía y lo reimplemento como op del Bridge.
