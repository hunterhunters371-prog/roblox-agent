# Scripting Luau — base operativa

Carpeta donde vive **cómo** se programan las mecánicas del juego, no solo el
resultado. Cualquier agente (humano o IA) que tenga que crear, corregir o
ampliar una mecánica de gameplay empieza aquí.

Es el apartado hermano de [`docs/modelado-3d/`](../modelado-3d/README.md). Ese
produce geometría; este produce comportamiento. La frontera es estricta: el
modelado entrega instancias con atributos, y el scripting solo lee esos
atributos. Ninguno de los dos toca el trabajo del otro.

## Rol del agente

Programador de gameplay senior en **Luau para Roblox Studio**. Se encarga de las
tareas más importantes del proyecto: la lógica que decide si el juego funciona o
no. Su compromiso es implementar la mecánica pedida **al pie de la letra**, sin
añadir comportamiento que nadie pidió y sin omitir ninguna condición del
enunciado.

Tres reglas lo definen:

1. **Traducción literal.** Cada frase de la petición se convierte en una fila de
   la tabla de requisitos del spec, con su prueba de aceptación. Lo que no está
   en la tabla no se programa. Lo que está, se programa completo.
2. **Servidor autoritativo.** El cliente pide y muestra; el servidor decide y
   valida. Ninguna regla del juego vive en un `LocalScript`.
3. **Nada se declara listo sin prueba.** Una mecánica está terminada cuando el
   checklist de la fase 9 del proceso está ejecutado y su salida está pegada en
   el registro. Antes de eso se dice «no verificado».

## Índice

| Documento | Contenido |
|---|---|
| [`00-proceso-scripting-luau.md`](00-proceso-scripting-luau.md) | Pipeline completo por fases. Es el proceso que se aplica siempre, para cualquier mecánica. |
| [`01-plantilla-mecanica.spec.md`](01-plantilla-mecanica.spec.md) | Plantilla de especificación. Se copia una vez por mecánica y se numera a partir de `02-`. |
| [`02-registro-mecanicas.md`](02-registro-mecanicas.md) | Historial de entregas, fallos en Studio y reglas nuevas que salieron de cada fallo. |

## Contexto obligatorio antes de escribir una línea

| Documento | Por qué es obligatorio |
|---|---|
| [`memory/HANDOFF.md`](../../memory/HANDOFF.md) | Estado real de la cola de comandos, siguiente id libre, deudas técnicas abiertas y reglas que ya costaron errores. |
| [`memory/WORLD.md`](../../memory/WORLD.md) | Geometría construida con coordenadas exactas y contratos del código existente. |
| [`schemas/command.schema.json`](../../schemas/command.schema.json) | Formato exacto del comando que el plugin acepta. |
| [`schemas/allowed_classes.json`](../../schemas/allowed_classes.json) | Clases que el validador permite crear. |
| [`plugin/src/Ops.lua`](../../plugin/src/Ops.lua) | Comportamiento real de cada operación cuando el schema no basta. |

## Dónde vive el código

El juego se construye a distancia: no hay acceso directo a Roblox Studio. El
código llega a Studio como operaciones `ensure_instance` y `set_script_source`
dentro de un comando escrito en `commands/pending/`, que el plugin
**RobloxAgentBridge** sincroniza y el usuario aprueba a mano.

| Ruta | Qué es |
|---|---|
| `ServerScriptService` | Arranque y sistemas de servidor. Manda aquí la autoridad. |
| `ReplicatedStorage` | Módulos compartidos, datos de configuración y `RemoteEvent` / `RemoteFunction`. |
| `StarterPlayer` | Código de cliente: entrada del jugador y presentación. |
| `project/src/...` | Espejo del código en el repositorio, sincronizable con Rojo. |

La ruta `ReplicatedStorage.Delivery60.Data.Destinations` es la única ruta de
datos citada de forma literal en el handoff. El resto del árbol real se lee con
`inspect_tree` antes de tocarlo; escribir sobre una ruta supuesta es la forma más
rápida de destruir un módulo que funcionaba.

## Arranque rápido — pegar esto en un chat nuevo

```
Eres el agente de scripting Luau del proyecto DELIVERY: 60 SECONDS.

Lee enteros, antes de actuar, estos archivos del repo hunterhunters371-prog/roblox-agent
en la rama main:
  docs/scripting-luau/README.md
  docs/scripting-luau/00-proceso-scripting-luau.md
  memory/HANDOFF.md
  memory/WORLD.md

Reglas que no se negocian:
1. Implementas la mecanica al pie de la letra. Cada frase de mi peticion es una fila
   de la tabla de requisitos del spec, con su prueba. Nada extra, nada omitido.
2. Si falta un dato para implementar, te detienes y preguntas. No supones.
3. Servidor autoritativo. El cliente nunca decide una regla del juego.
4. Nunca inventas el contenido de un script existente: set_script_source reemplaza
   el archivo entero, asi que primero lees el fuente verbatim desde el comando de
   commands/completed/ que lo creo.
5. Antes de escribir un comando, listas commands/pending/ y commands/completed/
   para saber el estado real de la cola y el siguiente id libre.
6. Maximo ~16 KB por archivo escrito, JSON compacto, escrituras de una en una.
7. No declaras nada funcionando sin la prueba en Studio pegada en el registro.

Habla en espanol.

Mecanica a implementar: [ESCRIBE AQUI LA MECANICA]
```

## Regla de oro de esta carpeta

Cada vez que una mecánica falla en Studio, la corrección se aplica **al
proceso**, no solo al script. El fallo se anota en `02-registro-mecanicas.md` y
se convierte en una línea permanente del checklist de la fase 9 de
`00-proceso-scripting-luau.md`. Así, el siguiente agente que tome el trabajo no
repite el error.
