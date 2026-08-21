# plugin/ — Roblox Agent Bridge (Studio)

Plugin ejecutor del protocolo RBX Bridge v0.1. Lee comandos declarativos del repo, los valida contra las listas blancas y los aplica sobre el árbol de instancias con las APIs nativas de Studio. **No usa ni consume la IA nativa de Roblox Studio.**

**v1.1** — botón **🔍 Selección**: inspecciona lo que tengas seleccionado con el mouse (o en el Explorer) y sube un informe detallado a `snapshots/` del repo (path, clase, atributos, tamaño/posición/material, hijos hasta 2 niveles y, si es un script, su código fuente completo con conteo de líneas).

## Requisitos

1. Roblox Studio actualizado.
2. **Game Settings → Security → "Enable Studio Access to API Services" (Allow HTTP Requests)** activado en el place donde trabajas. Sin esto el plugin no puede hablar con GitHub.
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
3. **⟳ Sync** — trae los comandos de `commands/pending/`, `approved/` y `processing/`.
4. **Aprobar** mueve el comando a `approved/`. **Ejecutar** lo aplica sobre Studio.
5. Si Studio se cierra a mitad, al volver aparece como `processing` con su progreso: **Continuar** retoma desde la última operación completada.
6. **↩ Deshacer** revierte el último comando vía `ChangeHistoryService`.
7. **🔍 Selección** (v1.1) — con algo seleccionado en el editor, sube su informe a `snapshots/seleccion_<timestamp>.json` para que el agente lo lea desde GitHub.

## Qué NO hace (por diseño)

Publicar el juego, ejecutar código arbitrario (`loadstring`), HTTP a dominios no aprobados, DataStore, Marketplace, teleports, cambios en Game Settings. Ver `schemas/` y la spec del protocolo en Notion.

## Notas del MVP

- Los checkpoints se escriben en GitHub tras cada operación (un commit por operación). En v0.2 se evaluará batching con la Git Trees API.
- Un comando que termina con errores va a `failed/`; la reanudación desde `failed/` no está soportada en el MVP (vuelve a enviarlo como comando nuevo).
