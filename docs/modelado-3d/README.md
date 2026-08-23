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

## Dónde vive el modelo

| Ruta | Qué es |
|---|---|
| `project/src/ReplicatedStorage/Modelos/PaqueteNormal.lua` | Constructor procedimental. Fuente de verdad de la geometría. |
| `project/src/ServerScriptService/DemoPaquetes.server.lua` | Escena de revisión con las cinco variantes. |

## Arranque rápido en Studio

Con Rojo, sincroniza `project/` y ejecuta el juego: el script de demostración
crea la fila de paquetes en `workspace.PaquetesDemo`.

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

## Regla de oro de esta carpeta

Cada vez que un modelo se rechaza, la corrección se aplica **al proceso**, no
solo al modelo. El rechazo se anota en `02-registro-iteraciones.md` y se
convierte en un punto permanente del checklist de calidad. Así, la siguiente IA
que tome el trabajo no repite el error.
