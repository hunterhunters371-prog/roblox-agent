# Documentación operativa — apartados del proyecto

Cada carpeta de `docs/` es un **apartado operativo**: un mini agente con su
proceso, sus especificaciones y su registro de iteraciones. Documentan **cómo**
se hace el trabajo, no solo el resultado, para que otro agente lo retome sin
contexto previo.

## Apartados disponibles

| Apartado | Rol | Entrega |
|---|---|---|
| [`modelado-3d/`](modelado-3d/README.md) | Modelador 3D. Construye la geometría del juego con constructores procedimentales, specs de medidas exactas y control de calidad visual. | Modelos parametrizados, variantes y escenas de revisión. |
| [`scripting-luau/`](scripting-luau/README.md) | Programador de gameplay en Luau para Roblox Studio. Implementa las mecánicas al pie de la letra, con servidor autoritativo y prueba obligatoria en Studio. | Módulos y scripts entregados por comandos del Bridge. |

## Frontera entre apartados

El apartado de modelado entrega instancias con atributos. El apartado de
scripting lee esos atributos y nunca depende de nombres de instancia ni de
posiciones supuestas. Ninguno de los dos modifica el trabajo del otro: si una
mecánica necesita geometría nueva, se abre un encargo en `modelado-3d/`; si un
modelo necesita comportamiento, se abre un spec en `scripting-luau/`.

## Reglas comunes a todos los apartados

1. El proceso se lee entero antes de actuar, junto con
   [`memory/HANDOFF.md`](../memory/HANDOFF.md) y
   [`memory/WORLD.md`](../memory/WORLD.md).
2. Nada se declara terminado sin la prueba que lo demuestra. Sin prueba, se dice
   «no verificado».
3. Cada rechazo o fallo se corrige en el proceso, no solo en la entrega, y queda
   como línea permanente del checklist del apartado.
4. Los archivos del repositorio se escriben en prosa completa y normal. La
   brevedad aplica a la conversación, nunca a la documentación persistida.

## Cómo agregar un apartado nuevo

1. Crear `docs/<nombre>/` en minúsculas y con guiones.
2. Escribir `README.md` con el rol del agente, el contexto de lectura
   obligatoria, dónde vive su trabajo y el prompt de arranque para un chat nuevo.
3. Escribir `00-proceso-<nombre>.md` con las fases, cada una declarando qué
   entra, qué sale y cómo se verifica, y cerrar con un checklist de calidad.
4. Escribir la plantilla de especificación del apartado y su registro de
   iteraciones.
5. Añadir la fila correspondiente a la tabla de apartados de este archivo.
