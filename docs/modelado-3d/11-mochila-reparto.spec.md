# Spec — `MochilaReparto` (mochila de reparto)

- **Versión**: 1.0.0
- **Constructor**: `project/src/ReplicatedStorage/Modelos/MochilaReparto.lua`
- **Escena de revisión**: `project/src/ServerScriptService/DemoMochilas.server.lua`
- **Referencia**: lámina «DELIVERY BACKPACK», estilo voxel de formas cuadradas,
  entregada como imagen adjunta en el encargo del 2026-08-25.

## 1. Propósito

Mochila insignia del repartidor: la pieza de identidad visual del juego. La
referencia la muestra como monumento sobre bloques de piedra; este modelo es la
versión jugable, construida íntegramente con prismas rectos para respetar el
estilo voxel del encargo («rehazlo con formas cuadradas»).

## 2. Características obligatorias (de la referencia)

| Característica | Implementación |
|---|---|
| Cuerpo turquesa rectangular | `Cuerpo`, único sólido que colisiona y tiene masa |
| Silueta escalonada voxel | Cuatro `Esquina*` orgullosas `0.04` studs y `BaseInferior` orgullosa `0.03` |
| Tapa superior con labio | `Tapa` sobredimensionada `+0.12` studs y `LabioTapa` en el borde frontal |
| Asa de barras cuadradas | `AsaPosteIzq/Der` y `AsaBarra` sobre la tapa |
| Logo «6 + cronómetro + SEC» en la tapa | `SurfaceGui` `LogoFrontal` con `TextLabel`, `UICorner`, `UIStroke` y manecillas de `Frame` |
| Cesta frontal de rejilla | Veintiocho piezas `Rejilla*`: barras de `0.05` studs, marcos gruesos y fondo sólido |
| Tres paquetes kraft en la cesta | `PaqueteCesta1..3`, con las tapas sobresaliendo del marco |
| Bolsillo lateral derecho con solapa | `BolsilloDerecho` + `SolapaDerecha` en la cara `+X` |
| Protuberancia lateral izquierda | `BolsilloIzquierdo` + `SolapaIzquierda`, más plano, en `-X` |
| Correa negra segmentada | Siete `CorreaSegmento*` sobre un arco sinusoidal por el lado `+X` |
| Hombrera escalonada y hebilla plateada | `Hombrera` + `HombreraPaso`, `Hebilla` + `HebillaPasador` |
| Solo formas cuadradas | Cero cuñas, esferas, cilindros ni mallas importadas |

## 3. Escala propuesta (la referencia no declara medidas)

La lámina no indica ni studs ni metros. Se aplica la regla general del proyecto
(la misma del delivery bike): respetar la proporción objeto-avatar y recalcular
sobre un avatar de 5 studs.

- **Valor implementado**: cuerpo de `2.6 x 3.0 x 1.6` studs. Alto total con el
  asa `≈ 3.55` studs; la correa con hebilla cuelga hasta `≈ 3.9` studs bajo el
  pivote. Una mochila de repartidor real (unos 45 cm) a escala Roblox queda
  algo mayor que el torso (2 x 2 x 1), que es justo la lectura de la lámina.
- **Alternativa**: si la mochila es un monumento o prop de tienda en vez de
  equipo del jugador, escalar con `tamano` sin tocar nada más; toda la
  geometría deriva del cuerpo.

Pendiente de decisión del revisor. Ver `02-registro-iteraciones.md`.

## 4. Jerarquía

```
MochilaReparto (Model)                PrimaryPart = Cuerpo
├── Cuerpo (Part)                     volumen principal, único que colisiona
│   ├── PuntoAgarreAsa (Attachment)   centro de la barra del asa
│   ├── PuntoSujecionEspalda (Attachment)  centro de la cara trasera
│   └── Recoger (ProximityPrompt)     solo si conProximityPrompt = true
├── Tapa (Part)
│   └── LogoFrontal (SurfaceGui)      «6», cronómetro y «SEC»
├── LabioTapa (Part)
├── AsaPosteIzq / AsaPosteDer / AsaBarra (Part)
├── EsquinaIzqFront .. EsquinaDerBack (Part x4)
├── BaseInferior (Part)
├── BolsilloDerecho / SolapaDerecha (Part)
├── BolsilloIzquierdo / SolapaIzquierda (Part)
├── Rejilla* (Part x28)               barras, marcos y fondo de la cesta
├── PaqueteCesta1 .. 3 (Part)
├── CorreaSegmento1 .. 7 (Part)
├── Hombrera / HombreraPaso (Part)
└── Hebilla / HebillaPasador (Part)
```

Cincuenta y siete sólidos en total, todos soldados al `Cuerpo` con
`WeldConstraint`, `Massless = true` y colisiones desactivadas salvo el cuerpo.

## 5. Parámetros de configuración

| Parámetro | Por defecto | Qué controla |
|---|---|---|
| `nombre` | `"MochilaReparto"` | Nombre del `Model` |
| `variante` | `"Turquesa"` | Valor del atributo `Variante` |
| `tamano` | `Vector3.new(2.6, 3.0, 1.6)` | Dimensiones del cuerpo en studs |
| `colorCuerpo` | `56, 178, 169` | Cuerpo, tapa y bolsillos |
| `colorDetalle` | `34, 136, 128` | Esquinas, base, asa, solapas y marcos |
| `colorRejilla` | `34, 136, 128` | Barras de la cesta |
| `colorCorrea` | `30, 30, 34` | Correa, hombrera y pasador |
| `colorCarton` | `198, 154, 102` | Paquetes de la cesta |
| `conPaquetes` | `true` | Crea o omite los tres paquetes kraft |
| `capacidadPaquetes` | `3` | Atributo de gameplay |
| `densidad` | `0.4` | Densidad física del cuerpo |
| `anclado` | `false` | `Anchored` del cuerpo |
| `colisiona` | `true` | `CanCollide` del cuerpo |
| `conProximityPrompt` | `false` | Añade la interacción «Recoger» |
| `pixelesPorStud` | `340` | Nitidez del logo |
| `distanciaGui` | `60` | Distancia máxima a la que se dibuja el logo |

## 6. Paleta

| Nombre | RGB | Uso |
|---|---|---|
| `turquesa` | `56, 178, 169` | Cuerpo de la referencia |
| `turquesaOscura` | `34, 136, 128` | Escalones, asa, solapas, rejilla |
| `turquesaClara` | `94, 206, 195` | Reservada para acentos futuros |
| `correa` | `30, 30, 34` | Correa y hombrera |
| `hebilla` | `150, 156, 160` | Hebilla plateada |
| `carton` | `198, 154, 102` | Paquetes kraft de la cesta |
| `crema` | `240, 238, 232` | Texto y trazo del logo |
| `rojo` | `198, 62, 52` | Centro del cronómetro |

## 7. Tolerancias y convenciones

- Separación entre piezas: `0.006` studs (`HOLGURA`).
- Piezas de la silueta orgullosas `0.04` studs (`ESCALON`); la base, `0.03`.
- Grosor de barra de la rejilla: `0.05` studs. Marcos: `0.08` studs.
- Frente del modelo: `-Z` (la cesta y el logo miran a `-Z`).
- La cara trasera de la cesta no lleva barras: queda oculta contra el cuerpo.
- La correa se genera por código: `SEGMENTOS_CORREA` segmentos sobre un arco
  sinusoidal con giro derivado de `cos`. Cambiar la constante rehace la curva.
- Solo `Cuerpo` tiene `CanCollide`, `CanQuery`, `CanTouch` y masa.
- Física: `PhysicalProperties.new(densidad, 0.6, 0.1, 1, 1)`.

## 8. Atributos publicados en el `Model`

| Atributo | Tipo | Ejemplo |
|---|---|---|
| `VersionModelo` | string | `"1.0.0"` |
| `TipoModelo` | string | `"MochilaReparto"` |
| `Variante` | string | `"Turquesa"` |
| `CapacidadPaquetes` | number | `3` |

El gameplay lee estos atributos. No debe leer nombres de piezas ni posiciones.

## 9. Variantes incluidas

| Variante | Cambios respecto a la base |
|---|---|
| `Turquesa` | Ninguno. Es la de la referencia. |
| `Roja` | Cuerpo `196, 74, 62`, detalle y rejilla `148, 48, 40` |
| `Azul` | Cuerpo `64, 118, 206`, detalle y rejilla `44, 86, 160` |

## 10. Presupuesto

| Métrica | Objetivo | Estado en 1.0.0 |
|---|---|---|
| Sólidos (`Part`) | ≤ 70 | 57 |
| Triángulos | ≤ 900 | ~684 |
| `SurfaceGui` | ≤ 2 | 1 |
| Instancias totales | ≤ 180 | ~135 con soldaduras y GUI |
| Assets externos | 0 | 0 |

## 11. Criterios de aceptación

- [ ] Se lee como la mochila de la lámina desde la cámara de juego.
- [ ] La silueta escalonada se percibe sin z-fighting desde ocho ángulos.
- [ ] El logo «60 SEC» se reconoce a simple vista; el cronómetro se distingue
      del texto.
- [ ] La rejilla deja ver los paquetes y estos sobresalen del marco.
- [ ] La correa cuelga del lado derecho visto de frente, con hebilla abajo.
- [ ] `PivotTo` mueve las cincuenta y siete piezas como un solo objeto.
- [ ] Escala aprobada por el revisor junto a un avatar de 5 studs.
- [ ] Veinte mochilas en pantalla no hunden los frames.

## 12. Trabajo pendiente conocido

1. **Escala y uso sin confirmar**: la referencia no da cifras y no declara si la
   mochila es equipo del avatar o prop del mundo. Lleva `PuntoSujecionEspalda`
   por si se convierte en accesorio; esa conversión (Accessory + `Attachment`
   del torso) es trabajo futuro.
2. La rejilla son barras de `0.05` studs: a distancia larga puede producirse
   aliasing. Si molesta, subir el grosor a `0.07` o pasar la cesta a textura
   cuando existan los assets.
3. La correa es rígida y cuelga por el lado `+X`, como en la lámina. Si la
   mochila se equipa al avatar, la correa colgaría atravesando el brazo: haría
   falta una variante de correa trasera, que ya es geometría nueva (fase 1).
4. El logo desaparece a más de `60` studs por `MaxDistance`. Es deliberado,
   pero el monumento de la lámina querría un alcance mayor si se construye.
5. Falta LOD y la sustitución del logo por textura cuando haya assets subidos.
