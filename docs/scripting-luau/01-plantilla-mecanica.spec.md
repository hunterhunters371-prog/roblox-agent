# Plantilla de especificación de mecánica

Se copia este archivo una vez por mecánica, con el nombre
`NN-<mecanica>.spec.md` y numeración correlativa a partir de `02-`. Se rellena
entero antes de escribir código. Los campos sin dato se marcan con
`[pendiente]`, y un campo pendiente que bloquee la implementación se pregunta al
usuario antes de continuar; no se rellena por intuición.

---

# Mecánica: `<Nombre>`

**Versión**: 1.0.0
**Fecha**: `<YYYY-MM-DD>`
**Estado**: borrador | en implementación | en revisión | verificada
**Autor**: agente de scripting Luau

## 1. Petición original, verbatim

> Se pega aquí, palabra por palabra, lo que pidió el usuario. No se corrige, no
> se resume, no se interpreta. Es la fuente de verdad contra la que se comprueba
> la entrega.

## 2. Requisitos

Cada frase de la petición que impone una condición es una fila. Cada fila tiene
prueba ejecutable. Si una fila no se puede probar, no es un requisito: es un
deseo, y hay que reescribirla.

| Id | Requisito | Frase de origen | Prueba de aceptación | Resultado esperado |
|---|---|---|---|---|
| R1 | | | | |
| R2 | | | | |
| R3 | | | | |

## 3. Fuera de alcance

Lo que esta mecánica **no** hace, declarado de forma explícita para que el
revisor no espere lo que no se pidió.

- 

## 4. Dudas bloqueantes

Preguntas cuya respuesta hace falta antes de programar. Mientras existan, la
parte afectada no se implementa.

1. 

## 5. Máquina de estados

Estados posibles, transición que lleva de uno a otro y quién la dispara.

| Estado | Se entra cuando | Se sale cuando | Dueño |
|---|---|---|---|
| | | | servidor / cliente |

## 6. Instancias y rutas

Todo lo que la mecánica crea o toca, con su clase exacta y su ruta real,
verificada con `inspect_tree` o `inspect_instance`, no supuesta.

| Ruta | Clase | Nueva o existente | Responsabilidad |
|---|---|---|---|
| | | | |

## 7. Contrato de datos

Atributos que la mecánica lee o escribe. El gameplay lee atributos, nunca
nombres de instancia ni posiciones mágicas.

| Atributo | Instancia | Tipo | Quién escribe | Quién lee | Valor por defecto |
|---|---|---|---|---|---|
| | | | | | |

## 8. Remotes

| Nombre | Clase | Dirección | Argumentos y tipos | Validación en el receptor | Límite de frecuencia |
|---|---|---|---|---|---|
| | RemoteEvent / RemoteFunction | cliente a servidor / servidor a cliente | | | |

Regla fija: todo argumento que llega del cliente se valida en tipo, en rango y
en pertenencia, y se comprueba la distancia real entre el jugador y el objeto con
el que dice interactuar.

## 9. Configuración

Todos los números de la mecánica, con nombre y unidad. Ningún valor mágico
suelto en el código.

| Constante | Valor | Unidad | Motivo |
|---|---|---|---|
| | | studs / segundos / porcentaje | |

## 10. Casos límite

Qué debe pasar exactamente en cada situación anómala.

| Caso | Comportamiento esperado |
|---|---|
| El jugador se desconecta a mitad | |
| La interacción se repite a máxima velocidad | |
| El objeto ya no existe | |
| El valor está en el mínimo | |
| El valor está en el máximo | |
| Falta un atributo obligatorio | |

## 11. Interacción con sistemas existentes

Qué módulos ya construidos toca esta mecánica y cómo. Si reemplaza el fuente de
alguno, se anota el comando de `commands/completed/` desde el que se leyó su
contenido verbatim.

| Sistema | Tipo de interacción | Fuente leído desde |
|---|---|---|
| | lee / escribe / reemplaza | `cmd_XXXXXX.json` |

## 12. Plan de entrega

Comandos del Bridge que implementan la mecánica, en el orden exacto en que hay
que aprobarlos en Studio.

| Orden | Comando | Contenido | Tamaño aproximado |
|---|---|---|---|
| 1 | `cmd_XXXXXX` | | KB |

## 13. Criterios de aceptación

La mecánica está verificada cuando todas estas casillas están marcadas con su
salida real pegada al lado.

- [ ] Cada requisito de la sección 2 probado, con la salida observada.
- [ ] Ningún error nuevo en la consola de Studio.
- [ ] Todos los casos límite de la sección 10 probados.
- [ ] Checklist de la fase 9 de `00-proceso-scripting-luau.md` completo.
- [ ] Resultado de cada comando leído desde `commands/completed/` con cero
      errores.
- [ ] Entrada añadida a `02-registro-mecanicas.md`.

## 14. Registro de verificación

```
Requisito: R1
Accion ejecutada:
Salida observada:
Coincide con lo esperado: si / no
```
