# Spec — `PaqueteNormal` (modelo base de paquete)

- **Versión**: 1.0.0
- **Constructor**: `project/src/ReplicatedStorage/Modelos/PaqueteNormal.lua`
- **Escena de revisión**: `project/src/ServerScriptService/DemoPaquetes.server.lua`
- **Referencia**: hoja de arte «PACKAGE: NORMAL — BASE MODEL — DELIVERY: 60 SECONDS»

## 1. Propósito

Modelo base reutilizable del objeto protagonista del juego. Todas las cajas del
juego salen de este constructor. No se modelan cajas independientes.

## 2. Características obligatorias (de la referencia)

| Característica | Implementación |
|---|---|
| Material cartón | `Enum.Material.Cardboard` con alternativa segura vía `pcall` |
| Cinta de embalar | Piezas `CintaSuperior` y `CintaLateral*`, ligeramente translúcidas |
| Etiqueta | Placa de papel `EtiquetaPrincipal` en la cara trasera y `EtiquetaSuperior` en la tapa |
| Código de barras | Generado con `Random.new(semilla)` derivada del código del paquete |
| Dirección | Tres líneas configurables, impresas bajo `TO:` |
| Logo «60 SEC» | Cronómetro dibujado con `Frame` + `UICorner` + texto, en la cara frontal y en la etiqueta |
| Símbolos de manejo | Este lado arriba, frágil y mantener seco, dibujados con primitivas de GUI |
| Pivote centrado | `PrimaryPart = Caja`, pivote en el centro geométrico |
| Bajo conteo | Seis a diez `Part` por paquete, unas 72 a 120 caras triangulares |

## 3. Discrepancia de escala detectada

La hoja de referencia indica caja de `1.25 x 1.0 x 1.25` studs y dibuja al
avatar con `1.0` studs de altura. Un avatar de Roblox mide alrededor de 5 studs,
así que ambas cifras no pueden ser ciertas a la vez.

- **Valor implementado**: `1.25 x 1.0 x 1.25` studs, que equivale a unos
  35 x 28 x 35 cm y es una caja de paquetería pequeña realista.
- **Alternativa si se busca la proporción que sugiere el dibujo** (caja a media
  altura del personaje): `2.6 x 2.1 x 2.6` studs, pasando `tamano` en la
  configuración.

Pendiente de decisión del revisor. Ver `02-registro-iteraciones.md`.

## 4. Jerarquía

```
PaqueteNormal (Model)                 PrimaryPart = Caja
├── Caja (Part)                       volumen principal, unico que colisiona
│   ├── JuntaSuperior (SurfaceGui)    linea de cierre de solapas
│   ├── JuntaInferior (SurfaceGui)    cruz de la base
│   ├── Frontal (SurfaceGui)          logo, simbolos de manejo, sello
│   ├── PuntoAgarre (Attachment)      centro de la tapa
│   ├── PuntoApoyoBase (Attachment)   centro de la base
│   └── Recoger (ProximityPrompt)
├── CintaSuperior (Part)
├── CintaLateralFront (Part)
├── CintaLateralBack (Part)
├── EtiquetaPrincipal (Part)
│   └── Etiqueta (SurfaceGui)         cabecera, TO:, direccion, barras, serie
└── EtiquetaSuperior (Part)
    └── EtiquetaCompacta (SurfaceGui)
```

Con `cintaDoble = true` las piezas de cinta se duplican con sufijo `1` y `2`.

## 5. Parámetros de configuración

| Parámetro | Por defecto | Qué controla |
|---|---|---|
| `nombre` | `"PaqueteNormal"` | Nombre del `Model` |
| `variante` | `"Normal"` | Valor del atributo `TipoPaquete` |
| `tamano` | `Vector3.new(1.25, 1, 1.25)` | Dimensiones en studs |
| `anchoCinta` | `0.18` | Ancho de la cinta como fracción del ancho de la caja |
| `caidaCinta` | `0.32` | Cuánto baja la cinta por los laterales |
| `cintaDoble` | `false` | Dos tiras de cinta en vez de una |
| `colorCarton` | `176, 132, 84` | Color del cartón |
| `colorCinta` | `186, 138, 84` | Color de la cinta |
| `codigo` | `"60SEC-DEL-00017"` | Serie impresa y semilla del código de barras |
| `direccion` | tres líneas | Destinatario impreso |
| `segundosEntrega` | `60` | Cabecera de la etiqueta y atributo |
| `fragil` | `false` | Atributo de gameplay |