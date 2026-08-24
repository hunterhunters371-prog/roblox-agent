# 🌉 Roblox Agent Bridge

Canal de órdenes entre un **agente** (Notion Custom Agent vía GitHub MCP) y un **plugin de Roblox Studio** que ejecuta operaciones declarativas, idempotentes y auditables sobre el árbol de instancias del juego.

> 📐 Spec completa del protocolo: página «Roblox Agent Bridge — Protocolo de Comandos v0.1» en Notion.

## Cómo funciona

```
┌─────────────┐      ┌───────────────────┐      ┌────────────────────┐      ┌────────────┐
│ Notion Agent │ ───▶ │ commands/pending/ │ ───▶ │ Plugin (Sync)       │ ───▶ │ Studio      │
│              │      │                   │      │ valida → aprueba →  │      │ instancias  │
└─────────────┘      └───────────────────┘      │ ejecuta → reporta   │      └────────────┘
                                                  └─────────────────────┘
```

### Principios

- **Declarativo**: el agente describe *qué* debe existir; el plugin decide *cómo* construirlo con las APIs nativas de Studio. Nunca se envía código arbitrario para ejecutar.
- **Idempotente**: toda operación es segura de repetir (semántica `ensure`). Reanudar un build a la mitad no duplica instancias.
- **Lista blanca**: raíces y clases permitidas viven en `schemas/`. Lo no listado se rechaza antes de tocar Studio.
- **Auditable**: cada comando deja su definición, sus checkpoints y su resultado en git.
- **Reanudable**: checkpoints por operación (`processing/*.state.json`). Cerrar Studio o cambiar de cuenta no pierde progreso.
- **Reversible**: cada comando registra un waypoint de `ChangeHistoryService` — Undo/Redo nativo funciona sobre los cambios del agente.

## Estructura

```
roblox-agent/
├── commands/           # Estados del ciclo de vida de un comando
│   ├── pending/        #   escritos por el agente (única carpeta donde escribe)
│   ├── approved/       #   aprobados por el usuario en Studio
│   ├── processing/     #   en ejecución (+ .state.json de checkpoint)
│   ├── completed/      #   comando + resultado
│   ├── failed/         #   comando + reporte de error
│   └── rejected/       #   no pasaron validación
├── schemas/            # JSON Schemas del protocolo (validan AMBOS lados)
│   ├── command.schema.json
│   ├── result.schema.json
│   ├── allowed_roots.json
│   └── allowed_classes.json
├── docs/               # Apartados operativos: cómo se hace el trabajo
│   ├── modelado-3d/    #   proceso, specs y registro de los modelos 3D
│   └── scripting-luau/ #   proceso, specs y registro de las mecánicas Luau
├── memory/             # Handoff y estado del proyecto entre sesiones
├── chat/               # Mensajería con el plugin (inbox / outbox)
├── tools/              # Utilidades fuera de Studio (model-converter)
├── snapshots/          # inspect_tree guardados como referencia
├── logs/
├── project/            # Código del juego (sincronizado con Rojo)
└── plugin/             # Plugin de Roblox Studio (Fase 3)
```

## Apartados operativos

Cada carpeta de `docs/` es un mini agente con su proceso, sus especificaciones y su registro de iteraciones. Índice completo en [`docs/README.md`](docs/README.md).

| Apartado | Rol | Entrega |
|---|---|---|
| [`docs/modelado-3d/`](docs/modelado-3d/README.md) | Modelador 3D: geometría procedimental, medidas exactas, control de calidad visual. | Modelos parametrizados, variantes y escenas de revisión. |
| [`docs/scripting-luau/`](docs/scripting-luau/README.md) | Programador de gameplay en Luau: implementa las mecánicas al pie de la letra, con servidor autoritativo y prueba obligatoria en Studio. | Módulos y scripts entregados por comandos del Bridge. |

Frontera entre ambos: el modelado entrega instancias con atributos y el scripting solo lee esos atributos. Ninguno modifica el trabajo del otro.

## Ciclo de vida

`pending → approved → processing → completed | failed | rejected`

1. El agente escribe `commands/pending/cmd_XXXXXX.json` (validado contra `schemas/command.schema.json`).
2. El plugin hace **Sync**, valida schema + listas blancas. Si falla → `rejected/`.
3. Si `require_approval` es `true` (default), el usuario aprueba en la UI del plugin → `approved/`.
4. El plugin ejecuta en orden, actualizando el checkpoint tras cada operación → `processing/`.
5. Al terminar → `completed/` con resultado, o `failed/` con reporte de error.
6. Si Studio se cierra a mitad: al abrir, el plugin ofrece **Continue build** desde la última operación completada.

**Regla de oro**: el plugin nunca edita el contenido de un comando, solo lo mueve de estado.

## Seguridad

- `delete_instance` **siempre** exige aprobación humana, y el borrado es suave (a `ServerStorage._RBX_Trash`).
- `set_script_source` solo aplica a `Script` / `ModuleScript` / `LocalScript`.
- Bloqueado por diseño: publicar el juego, `loadstring`, HTTP a dominios no aprobados, DataStore, Marketplace, teleports, Game Settings.
- Token de GitHub *fine-grained* con `contents: read/write` **solo sobre este repo**, guardado con `plugin:SetSetting()`. Jamás en el código fuente.

## Roadmap

- [x] **v0.1** — Estructura del repo + schemas del protocolo
- [ ] **v0.1** — MVP del plugin: Sync, Inspect, Apply, Undo, Logs
- [ ] **v0.1** — Primer comando end-to-end (Notion → GitHub → Studio)
- [ ] **v0.2** — Terrain, push en tiempo real (webhook → worker), `validate_build`, firmas de integridad
