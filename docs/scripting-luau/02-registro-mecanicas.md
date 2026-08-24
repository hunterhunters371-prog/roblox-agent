# Registro de mecánicas — scripting Luau

Historial de entregas, fallos en Studio y reglas nuevas. Cada fallo se anota
aquí y se convierte en una línea permanente del checklist de la fase 9 de
`00-proceso-scripting-luau.md`, para que el mismo error no pueda repetirse en
otra mecánica.

## Apartado creado — 2026-08-24

**Estado**: base operativa creada, sin mecánicas entregadas todavía.

**Qué incluye**

- `README.md` con el rol del agente, el contexto de lectura obligatoria y el
  prompt de arranque para un chat nuevo.
- `00-proceso-scripting-luau.md` con las diez fases del proceso, las reglas de
  estilo Luau obligatorias y el checklist de control de calidad.
- `01-plantilla-mecanica.spec.md` con la plantilla de especificación que traduce
  cada frase de la petición en un requisito con prueba de aceptación.

**Decisiones tomadas**

| Decisión | Motivo |
|---|---|
| Apartado separado de `docs/modelado-3d/` | El modelado entrega geometría con atributos; el scripting solo lee esos atributos. Fronteras claras evitan que dos agentes se pisen el trabajo. |
| La petición original se pega verbatim en el spec | Es la única forma de comprobar al final que la mecánica se implementó al pie de la letra, sin añadidos ni omisiones. |
| Cada requisito exige prueba ejecutable | Un requisito sin prueba no se puede declarar cumplido, solo suponer cumplido. |
| Entrega por comandos del Bridge, nunca código suelto | El protocolo del repositorio ya garantiza aprobación humana, waypoint de Undo y auditoría en git. |
| Servidor autoritativo como principio, no como recomendación | Cualquier regla evaluada en cliente es explotable por el jugador. |

**Reglas heredadas del handoff que el proceso incorpora**

Estas reglas ya costaron errores en el proyecto y quedan integradas en las fases
1, 6 y 9 del proceso:

1. Máximo unos 16 KB por archivo escrito y JSON compacto.
2. Escrituras secuenciales, nunca en paralelo.
3. Los ids de comando no se reutilizan ni se editan una vez salen de `pending/`.
4. Nunca adivinar el contenido de un script: `set_script_source` reemplaza el
   archivo entero.
5. Nunca adivinar una coordenada ni una ruta: se leen con `inspect_*`.
6. Un archivo recién escrito en `pending/` que parece no existir está en
   `completed/`. No se reemite.

**Pendiente de decidir con el usuario**

1. Cuál es la primera mecánica que implementa este agente.
2. Si la deuda técnica de solvencia de las entregas, descrita en
   `memory/HANDOFF.md`, pasa a ser propiedad de este agente. El diseño del
   arreglo ya está cerrado en el handoff y encaja en su alcance.

## Plantilla para el siguiente fallo

```
## <mecanica> <version> — fallo

Fecha:
Revisor:

Sintoma observado
1. <que hizo el juego, en concreto, y que se esperaba>

Linea de error exacta
- <mensaje verbatim de la consola de Studio>

Causa raiz
- <por que el proceso lo dejo pasar>

Correccion aplicada
- <que cambio en el codigo y en que comando se entrego>

Regla nueva anadida al checklist
- <linea exacta agregada a la fase 9 del proceso>
```
