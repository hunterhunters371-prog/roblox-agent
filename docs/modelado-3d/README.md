# Modelado 3D — base operativa

Carpeta donde vive **cómo** se construyen los modelos del juego, no solo el
resultado. Cualquier agente (humano o IA) que tenga que crear, replicar o
mejorar un modelo empieza aquí.

## Índice

| Documento | Contenido |
|---|---|
| [`00-proceso-modelado-3d.md`](00-proceso-modelado-3d.md) | Pipeline completo paso a paso. Es el proceso que se aplica siempre, para cualquier modelo. |
| [`01-paquete-normal.spec.md`](01-paquete-normal.spec.md) | Especificación del modelo base `PaqueteNormal`: medidas, jerarquía, atributos, variantes y criterios de aceptación. |
| [`02-registro-iteraciones.md`](02-registro-iteraciones.md) | Historial de versiones, rechazos del revisor y reglas nuevas que salieron de cada rechazo. |
| [`04-motor-render-v2.md`](04-motor-render-v2.md) | Motor de render propio para previsualizar modelos: rasterizador con z-buffer, normales y verificación de texturas. |
| [`10-visor-html-autocontenido.md`](10-visor-html-autocontenido.md) | Cómo construir el visor HTML de un solo archivo con el que se auditan los modelos antes de entregarlos. |
| [`11-mochila-reparto.spec.md`](11-mochila-reparto.spec.md) | Especificación del modelo `MochilaReparto` (lámina «DELIVERY BACKPACK»): medidas, jerarquía, atributos, variantes y criterios de aceptación. |

## Estado de los modelos

| Modelo | Versión | Estado |
|---|---|---|
| `PaqueteNormal` | 1.0.0 | pendiente de revisión en Studio |
| `MochilaReparto` | 2.0.0 | reconstruida tras auditoría de catorce defectos; verificada por render, pendiente de revisión en Studio |

## Dónde vive el modelo

| Ruta | Qué es |
|---|---|
| `project/src/ReplicatedStorage/Modelos/PaqueteNormal.lua` | Constructor procedimental del paquete. Fuente de verdad de su geometría. |
| `project/src/ServerScriptService/DemoPaquetes.server.lua` | Escena de revisión con las cinco variantes del paquete. |
| `project/src/ReplicatedStorage/Modelos/MochilaReparto.lua` | Constructor procedimental de la mochila. Fuente de verdad de su geometría. |
| `project/src/ServerScriptService/DemoMochilas.server.lua` | Escena de revisión con las tres variantes de la mochila. |

## Arranque rápido en Studio

Con Rojo, sincroniza `project/` y ejecuta el juego: el script de demostración
crea la fila de paquetes en `workspace.PaquetesDemo` y la de mochilas en
`workspace.MochilasDemo`.

Sin Rojo:

1. En `ReplicatedStorage`, crea una carpeta `Modelos`.
2. Dentro, crea un `ModuleScript` llamado `PaqueteNormal` y pega el contenido de
   `project/src/ReplicatedStorage/Modelos/PaqueteNormal.lua`.
3. Abre la Command Bar y ejecuta:

```lua
local P = require(game.ReplicatedStorage.Modelos.PaqueteNormal)
P.crearEn(workspace, CFrame.new(0, 5, 0), { anclado = true })
```

Para ver todas las variantes de una vez:

```lua
local P = require(game.ReplicatedStorage.Modelos.PaqueteNormal)
local i = 0
for nombre in pairs(P.VARIANTES) do
	P.crearEn(workspace, CFrame.new(i * 2.2, 5, 0), { anclado = true })
	i = i + 1
end
```

Lo mismo aplica a la mochila con el módulo `MochilaReparto` y separación `3.4`:

```lua
local M = require(game.ReplicatedStorage.Modelos.MochilaReparto)
M.crearEn(workspace, CFrame.new(0, 2.4, -8), { anclado = true })
```

## Regla de oro de esta carpeta

Cada vez que un modelo se rechaza, la corrección se aplica **al proceso**, no
solo al modelo. El rechazo se anota en `02-registro-iteraciones.md` y se
convierte en un punto permanente del checklist de calidad. Así, la siguiente IA
que tome el trabajo no repite el error.

Y antes de entregar, el modelo se mira: se renderiza en el visor de
`10-visor-html-autocontenido.md` y se inspeccionan las capturas una por una.
Catorce de los defectos de `MochilaReparto` 1.0.0 eran visibles a simple vista y
ninguno se detectó leyendo código.
