# Spec — `PaqueteNormal` (modelo base de paquete)

- **Versión**: 1.0.0
- **Constructor**: `project/src/ReplicatedStorage/Modelos/PaqueteNormal.lua`
- **Escena de revisión**: `project/src/ServerScriptService/DemoPaquetes.server.lua`
- **Referencia**: hoja de arte «PACKAGE: NORMAL — BASE MODEL — DELIVERY: 60 SECONDS»

## 1. Propósito

Modelo base reutilizable del objeto protagonista del juego. Todas las cajas del
juego salen de este constructor. No se modelan cajas independientes: las
diferencias se consiguen con color, marcado, atributos y accesorios pequeños.

## 2. Características obligatorias (de la referencia)

| Característica | Implementación |
|---|---|
| Material cartón | `Enum.Material.Cardboard`, con alternativa segura vía `pcall` |
| Cinta adhesiva | Piezas `CintaSuperior` y `CintaLateral*`, ligeramente translúcidas |
| Etiqueta | Placa de papel `EtiquetaPrincipal` en la cara trasera y `EtiquetaSuperior` en la tapa |
| Código de barras | Generado con `Random.new(semilla)` derivada del código del paquete |
| Dirección | Tres líneas configurables, impresas bajo `TO:` |
| Logo «60 SEC» | Cronómetro dibujado con `Frame` + `UICorner` + texto, en la cara frontal y en la etiqueta |
| Símbolos de manejo | Este lado arriba, frágil y mantener seco, dibujados con primitivas de GUI |
| Pivote centrado | `PrimaryPart = Caja`, pivote en el centro geométrico |
| Bajo conteo | Seis a diez `Part` por paquete, entre 72 y 120 triángulos |

## 3. Discrepancia de escala detectada

La hoja de referencia indica una caja de `1.25 x 1.0 x 1.25` studs y dibuja al
avatar con `1.0` studs de altura. Un avatar de Roblox mide alrededor de 5 studs,
así que ambas cifras no pueden ser ciertas a la vez.

- **Valor implementado**: `1.25 x 1.0 x 1.25` studs, equivalente a unos
  35 x 28 x 35 cm. Es una caja de paquetería pequeña realista.
- **Alternativa si se busca la proporción que sugiere el dibujo**, con la caja a
  media altura del personaje: `2.6 x 2.1 x 2.6` studs, pasando `tamano` en la
  configuración.

Pendiente de decisión del revisor. Ver `02-registro-iteraciones.md`.

## 4. Jerarquía

```
PaqueteNormal (Model)                 PrimaryPart = Caja
├── Caja (Part)                       volumen principal, único que colisiona
│   ├── JuntaSuperior (SurfaceGui)    línea de cierre de solapas
│   ├── JuntaInferior (SurfaceGui)    cruz de la base
│   ├── Frontal (SurfaceGui)          logo, símbolos de manejo, sello
│   ├── PuntoAgarre (Attachment)      centro de la tapa
│   ├── PuntoApoyoBase (Attachment)   centro de la base
│   └── Recoger (ProximityPrompt)
├── CintaSuperior (Part)
├── CintaLateralFront (Part)
├── CintaLateralBack (Part)
├── EtiquetaPrincipal (Part)
│   └── Etiqueta (SurfaceGui)         cabecera, TO:, dirección, barras, serie
└── EtiquetaSuperior (Part)
    └── EtiquetaCompacta (SurfaceGui)
```

Con `cintaDoble = true` las piezas de cinta se duplican con sufijo `1` y `2`.

## 5. Parámetros de configuración

| Parámetro | Por defecto | Qué controla |
|---|---|---|
| `nombre` | `"PaqueteNormal"` | Nombre del `Model` |
| `variante` | `"Normal"` | Valor del atributo `TipoPaquete` |
| `tamano` | `Vector3.new(1.25, 1, 1.25)` | Dimensiones en studs: ancho, alto, fondo |
| `anchoCinta` | `0.18` | Ancho de la cinta como fracción del ancho de la caja |
| `caidaCinta` | `0.32` | Cuánto baja la cinta por los laterales |
| `cintaDoble` | `false` | Dos tiras de cinta en vez de una |
| `colorCarton` | `176, 132, 84` | Color del cartón |
| `colorCinta` | `186, 138, 84` | Color de la cinta |
| `codigo` | `"60SEC-DEL-00017"` | Serie impresa y semilla del código de barras |
| `direccion` | `{ "House #17", "Sunset Street 12", "Delivery City" }` | Destinatario impreso |
| `segundosEntrega` | `60` | Cabecera de la etiqueta y atributo |
| `fragil` | `false` | Atributo de gameplay |
| `mantenerSeco` | `true` | Muestra el símbolo del paraguas |
| `esteLadoArriba` | `true` | Muestra el símbolo de las flechas |
| `sello` | `nil` | Texto diagonal opcional en la cara frontal |
| `densidad` | `0.55` | Densidad física, define el peso percibido |
| `anclado` | `false` | `Anchored` de la caja |
| `colisiona` | `true` | `CanCollide` de la caja |
| `conProximityPrompt` | `true` | Añade la interacción «Recoger» |
| `pixelesPorStud` | `340` | Nitidez del marcado impreso |
| `distanciaGui` | `60` | Distancia máxima a la que se dibuja el marcado |

## 6. Paleta

| Nombre | RGB | Uso |
|---|---|---|
| `carton` | `176, 132, 84` | Cuerpo de la caja |
| `cintaBase` | `186, 138, 84` | Cinta de embalar |
| `papel` | `240, 238, 232` | Etiquetas |
| `tinta` | `58, 44, 32` | Texto principal, barras, símbolos |
| `tintaSuave` | `104, 84, 64` | Texto secundario, juntas |
| `selloRojo` | `178, 58, 46` | Sellos de variante |

## 7. Tolerancias y convenciones

- Separación entre superficie y pieza pegada: `0.006` studs (`HOLGURA`).
- Grosor de cinta: `0.012` studs. Grosor de etiqueta: `0.010` y `0.008` studs.
- Frente del modelo: `-Z` (`Enum.NormalId.Front`).
- Solo `Caja` tiene `CanCollide`, `CanQuery`, `CanTouch` y masa. El resto va
  `Massless = true` y unido con `WeldConstraint`.
- Física: `PhysicalProperties.new(densidad, 0.7, 0.15, 1, 1)`.

## 8. Atributos publicados en el `Model`

| Atributo | Tipo | Ejemplo |
|---|---|---|
| `VersionModelo` | string | `"1.0.0"` |
| `TipoPaquete` | string | `"Normal"` |
| `Codigo` | string | `"60SEC-DEL-00017"` |
| `Direccion` | string | `"House #17, Sunset Street 12, Delivery City"` |
| `SegundosEntrega` | number | `60` |
| `Fragil` | boolean | `false` |
| `MantenerSeco` | boolean | `true` |
| `EsteLadoArriba` | boolean | `true` |

El gameplay lee estos atributos. No debe leer nombres de piezas ni posiciones.

## 9. Variantes incluidas

| Variante | Cambios respecto a la base |
|---|---|
| `Normal` | Ninguno. Es la referencia. |
| `Fragil` | Cinta roja, atributo `Fragil = true`, sello `FRAGILE` |
| `Pesado` | Cartón más oscuro, cinta doble, densidad `1.6`, sello `HEAVY` |
| `Express` | Cinta amarilla, entrega en `45` segundos, sello `EXPRESS` |
| `Refrigerado` | Cartón claro, cinta azul, entrega en `40` segundos, sello `COLD` |

Añadir una variante es añadir una tabla de sobrescrituras en
`PaqueteNormal.VARIANTES`. Si una variante necesita geometría nueva, deja de ser
variante y vuelve a la fase 1 del proceso.

## 10. Presupuesto

| Métrica | Objetivo | Estado en 1.0.0 |
|---|---|---|
| `Part` por paquete | ≤ 10 | 6 (8 con cinta doble) |
| Triángulos | ≤ 550 | ~72 sin contar el marcado |
| `SurfaceGui` por paquete | ≤ 6 | 5 |
| Instancias totales | ≤ 120 | ~90, según longitud del código de barras |
| Assets externos | 0 | 0 |

## 11. Criterios de aceptación

- [ ] La caja se lee como cartón, no como plástico marrón.
- [ ] La cinta se ve pegada a la caja, sin z-fighting ni separación visible.
- [ ] La etiqueta es legible desde la distancia de juego.
- [ ] El código de barras cambia con el código del paquete y se repite igual
      para el mismo código.
- [ ] El logo «60 SEC» se reconoce a simple vista.
- [ ] Los tres símbolos de manejo se distinguen entre sí.
- [ ] El paquete cae y se apoya con peso creíble.
- [ ] Cincuenta paquetes en pantalla no hunden los frames.
- [ ] Escala aprobada por el revisor junto a un avatar.

## 12. Trabajo pendiente conocido

1. Los símbolos de manejo son aproximaciones geométricas. La versión definitiva
   debería usar `Decal` o `SurfaceAppearance` con texturas PBR una vez subidas.
2. Falta biselado real de aristas: `Part` no lo permite. Requiere `MeshPart`
   importado desde Blender, con el mismo pivote y las mismas dimensiones.
3. Faltan las variantes por textura de desgaste (`albedo` sucio, esquinas
   golpeadas), que dependen de los mapas 2048x2048 de la referencia.
4. Falta LOD: a partir de cierta distancia conviene ocultar el marcado, ya
   parcialmente cubierto con `MaxDistance`.
