# Camion de reparto MK2 - nota de diseno (2026-08-25)

## Por que se rehizo

El camion MK1 se generaba por script (una factory que creaba piezas y ruedas
con HingeConstraint). Fallaba en todo lo que importa: se tambaleaba, la
direccion no se podia controlar a baja velocidad, no tenia animaciones,
ni gasolina, ni turbo. Causa raiz: ruedas rigidas sin suspension y sin barras
antivuelco, y caja de carga alta que subia el centro de masa.

## Decision de fondo

No se vuelve a construir la fisica desde cero. El MK2 es un CLON del modelo
`Workspace["Dusty Trip Car With Auto Flip and NITRO"].Car`, que ya tiene
fisica probada, y sobre el se trabaja por encima:

- Hereda tal cual: suspension real (SpringConstraint), cremallera de
  direccion, barras antivuelco, auto-flip (Redress), nitro completo y la
  carpeta `Animations` (por eso las animaciones ya no faltan: vienen dentro).
- Se le anade chapa de camion como piezas cosmeticas y sistemas nuevos como
  hijos del modelo. NUNCA se edita un script heredado del Dusty.

## Geometria medida (rotacion identidad, frente = -Z)

- `Chassis` Part 6 x 0.5 x 14 en (-67, 2.24, -30); cara superior y = 2.495.
- Ruedas radio 1.5, tope superior y = 3.145, via 8 studs.
- Ejes: delantero z = -35.3, trasero z = -24.4 -> wheelbase 10.9.
- `DriverSeat` en (-68.35, 2.24, -30.6).
- Altura libre al suelo: 2 studs. Hueco entre ruedas: 5 studs.

## Regla de oro de la carroceria

Todas las piezas de `Body` van con `anchored=false`, `CanCollide=false` y
`Massless=true`. Asi la chapa no aporta masa, no sube el centro de gravedad
y no puede rozar las ruedas: la fisica queda identica a la del chasis Dusty
desnudo. Esta es la garantia anti-tambaleo.

## Sistemas anadidos

- **Gasolina**: Configuration `Fuel` + `FuelSystem` (servidor). Al llegar a 0
  aplica DOBLE SEGURO: pone a 0 los atributos de par/velocidad del `Engine`
  y tambien `MotorMaxTorque` de cada CylindricalConstraint. Cubre las dos
  formas posibles en que el nucleo del Dusty pueda aplicar el par, asi que
  el corte funciona sin haber tenido que leer su codigo.
- **Turbo (buster)**: no se construye un motor de boost paralelo, porque
  competiria con la gasolina por los mismos atributos. Reutiliza el nitro
  heredado, reajustado a cifras de camion. `TruckHUD` es un Script con
  `RunContext = Client` (un LocalScript en Workspace no se ejecutaria) y
  dibuja las barras de gasolina y turbo.
- **Destruccion**: `DamageSystem` con Touched + AssemblyLinearVelocity.
  Desprende piezas cosmeticas de fuera hacia dentro. Al morir pone
  `Fuel.level = 0` y deja que FuelSystem apague: un solo sistema toca el
  Engine, cero carreras entre sistemas.
- **Surtidor**: `Workspace.FuelStation` en (-74, y, -16), fuera del HQ
  (x >= -66), fuera del camion aparcado (z -37..-23) y fuera del parking.
  Reposta cualquier modelo con Configuration `Fuel` en 45 studs y tambien
  repara. No re-suelda piezas ya desprendidas (recrear welds en caliente
  podria alterar la fisica).

## Cadena de comandos

| id | contenido | requiere |
| --- | --- | --- |
| cmd_000051 | retirar MK1, clonar chasis Dusty -> DeliveryTruck_MK2 | ejecutado OK |
| cmd_000052 | carroceria: 16 piezas + 16 soldaduras | plugin v3.1.0 (weld_parts) |
| cmd_000053 | 29 atributos de camion (motor, suspension, antivuelco, direccion) | v3.0.1 |
| cmd_000054 | sistema de gasolina | v3.0.1 |
| cmd_000055 | turbo + HUD | v3.0.1 |
| cmd_000056 | destruccion por impacto | v3.0.1 |
| cmd_000057 | surtidor del HQ | v3.0.1 |

Orden obligatorio: 52 antes de 56 (el DamageSystem necesita `Body`) y 54
antes de 57 (el surtidor necesita `Fuel`).

## Correccion concreta del sintoma "no se controla en primera"

- `steeringRackSpeed` 10 -> 6.5 (cremallera menos brusca)
- `steeringRackResponsiveness` 30 -> 20
- `steeringReduction` 0.3 -> 0.45 (mas reduccion de angulo con velocidad)
- barras antivuelco 16000 -> 24000/26000 (mata el balanceo lateral)
- suspension 6000 -> 9000/9500 con amortiguacion 200 -> 320/340

NO se tocan `frontSuspensionLength` / `rearSuspensionLength`
(3.801726818084717) ni el camber: cambiar la geometria de los muelles es
precisamente lo que romperia la estabilidad heredada.
