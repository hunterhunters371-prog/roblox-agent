# WORLD - Geometria construida y contratos del codigo

> Complemento de [`memory/HANDOFF.md`](./HANDOFF.md).
> Todo se mide en **studs**. La superficie del suelo esta en **y = 0**.
> Estado a 2026-08-22. Las secciones marcadas *(en cola)* corresponden a `cmd_000032` a `cmd_000036`,
> escritos pero aun no ejecutados en Studio.

---

## 1. Terreno y calles

| Pieza | Tamano | Posicion |
| --- | --- | --- |
| `City.Ground` | 1700 x 4 x 1000 | (160, -2, 250). Abarca x de -690 a 1010, z de -250 a 750 |
| `City.RoadX` | 1120 x 0.12 x 14 | (160, 0.06, 0) |
| `City.RoadZ` | 14 x 0.12 x 560 | (0, 0.06, 280) |
| `Sidewalk_X_N` | - | centrada en z = -9 |
| `Sidewalk_X_S` | - | centrada en z = 9 |
| `Sidewalk_Z_W` | - | centrada en x = -9 |
| `Sidewalk_Z_E` | - | centrada en x = 9 |

La calzada mide **14 studs de ancho**. Cualquier modulo de carretera que se genere debe
respetar ese ancho para embaldosar sin costuras.

---

## 2. Casa base (patron de `House_1`, `House_2`, `House_3`)

```
Floor     12 x 1 x 12          y = 0.5
Muros     12 x 6 x 1  y  1 x 6 x 12    y = 4
Roof      13 x 1 x 13          y = 7.5     (alero en y = 8)
Losas     13.5 x 0.4 x 7.51    y = 9.876,  z = centro +/- 3.25
Cumbrera                       y = 11.754
```

Las losas del tejado llevan rotacion en grados: `[30,0,0]` y `[-30,0,0]` para cumbrera
en direccion X, o `[0,0,30]` y `[0,0,-30]` para cumbrera en direccion Z.

**Regla de la puerta:** si el hueco esta en un muro de normal Z, la hoja necesita
`rotation [0,90,0]`. Si esta en un muro de normal X, va **sin rotacion**. Confundirlo deja
la puerta metida dentro del hueco, tapandolo (es la deuda 3 del HANDOFF, en `House_2`).

---

## 3. Los seis destinos

| Destino | Centro | Marcador | Entrada | Rasgo distintivo | Distancia | Banda |
| --- | --- | --- | --- | --- | --- | --- |
| `House_4` | (-200, ., -20) | (-200, 0.3, -12.2) | Sur | Dos plantas, cornisa, chimenea | 154 | 25 s |
| `House_5` | (-20, ., 300) | (-12.2, 0.3, 300) | Este | Cumbrera girada 90 grados, anexo lateral | 346 | 25 s |
| `House_1` | (-400, ., 16) | (-400, 0.15, 8) | Norte | Casa base | 374 | 25 s |
| `House_6` | (400, ., -20) | (400, 0.3, -12.2) | Sur | Techo plano, parapetos, aire acondicionado | 446 | 35 s |
| `House_2` | (16, ., 560) | (8, 0.15, 560) | Oeste | Casa base | 626 | 45 s |
| `House_3` | (720, ., 16) | (720, 0.15, 8) | Norte | Casa base | 786 | 55 s |

Las distancias son **Manhattan medidas sobre las coordenadas construidas**, desde el pad de
recogida nuevo en (-46, ., -12). Estan **sin validar en playtest**: hay que cronometrar el
recorrido real antes de fiarse de las bandas.

Los marcadores son uniformes: `4 x 0.2 x 4`, material Neon, color `255,220,40`, `CanCollide false`.
Se llaman siempre `<id>_Marker` y contienen un `ProximityPrompt` llamado `DeliveryPrompt`
(ActionText "Deliver", ObjectText "House #N").

### Detalles de las casas nuevas *(en cola)*

**`House_4`** - centro (-200, ., -20), dos plantas. Muros de altura 7 (y de 1 a 13), cornisa en
y = 7.25, tejado en y = 13.5, losas en y = 15.876 con z = -16.75 y -23.25, hastiales en
y = 14.626 / 15.877 / 17.128, chimenea en (-196, 16, -23), ventanas en y = 4.2 y y = 10.2.
Paleta: `186,200,176` muros, `58,92,70` tejado, `140,230,90` acento.

**`House_5`** - centro (-20, ., 300), entrada al este (`WallE_N` y `WallE_S` de 1 x 6 x 4 en
z = 296 y 304, `Lintel` de 1 x 1 x 4 en y = 6.5). Cumbrera norte-sur: `RoofE` en x = -16.75 con
rotacion `[0,0,-30]`, `RoofW` en x = -23.25 con `[0,0,30]`. Anexo de 6 x 4 x 7 en (-20, 3, 290.5)
con techo de 7 x 0.5 x 8 en y = 5.25. Chimenea en (-23, 10, 303).
Paleta: `235,220,190` muros, `180,90,70` tejado, `255,120,180` acento.

**`House_6`** - centro (400, ., -20), techo plano. Muros de altura 7 en y = 4.5 (de 1 a 8),
tejado en y = 8.5, parapetos en y = 9.8, unidad de aire acondicionado en (403, 9.8, -24),
marquesina de 6 x 0.4 x 2.6 en y = 8.2 sobre dos postes.
Paleta: `228,228,232` muros, `95,95,105` tejado, `255,90,90` acento.

---

## 4. La tienda / Delivery HQ *(en cola)*

```
Centro (-46, ., -30)   Footprint 40 x 28   x de -66 a -26,  z de -44 a -16
Suelo          40 x 1 x 28      y = 0.5
Muros          altura 13        y de 1 a 14
Cubierta       42 x 1 x 30      y = 14.5
Parapetos                       y = 16
Escaparate sur en z = -16.5, con dos cristaleras y montantes
Puerta         8 ancho x 9 alto,  x de -50 a -42
Rotulo de tejado 22 x 6 x 0.8   en (-46, 19.5, -16.2), Neon naranja
Marquesina     26 x 0.5 x 4.5   en y = 11.4, sobre dos postes
PickupPad      8 x 0.25 x 8     en (-46, 0.15, -12)   Neon 255,150,40
SpawnLocation  6 x 1 x 6        en (-46, 1.5, -22)    dentro de la tienda
Parking y Delivery Van          alrededor de (-80, ., -30)
```

Se movio al solar noroeste porque el HQ viejo de 20 x 20 estaba **encima del cruce de las dos
calles**, lo que impediria meter trafico despues. El HQ viejo no se borra del todo: `delete_instance`
es un borrado suave y la carpeta queda recuperable en `ServerStorage._RBX_Trash`.

Interior: mostrador en L con terminal, tres estanterias con cajas, casilleros, cinta transportadora
con paquetes, maquina de upgrades, incubadora, Contract Board y tablero de rankings.
Es el unico edificio que se pisa por dentro.

---

## 5. Contratos del codigo que no se pueden romper

- El paquete es un `Part` de **2 x 2 x 2** soldado al `HumanoidRootPart` con
  `C0 = CFrame.new(0, 0.5, 1.2)`. Cambiar la escala hace que flote o atraviese al avatar.
- `DeliveryService` localiza los prompts **por nombre**: `PickupPrompt` y `DeliveryPrompt`.
  Y el marcador por `marker.Name == destinationId .. "_Marker"`.
  **No hay coordenadas escritas a fuego**, por eso mover la tienda es seguro.
- `DestinationRegistry.RandomId()` recorre **todas** las entradas de `Data.Destinations`.
  Anadir un destino ahi lo pone en juego automaticamente, sin tocar nada mas.
- Eventos al cliente: `DeliveryEvent:FireClient(player, "REVEAL" | "COMPLETE" | "FAILED", payload)`.
- Atributos de estado en el jugador: `D60_SpeedMultiplier`, `D60_JumpDisabled`, `D60_Stability`.
- `HIT_FLOOR_SPEED = 8`.
- Colores de paquete: `PACKAGE_COLORS = { Normal = 154,108,60 ; Heavy = 90,90,100 ; Explosive = 200,40,40 }`.
- Prompt de recogida: `HQ.PickupPad.PickupPrompt`, ActionText "Pick up", ObjectText "DELIVERY HQ",
  HoldDuration 0.3, MaxActivationDistance 12.

### Constantes de gameplay (`Config`)

```
DeliveryTimeSeconds     60        WalkSpeed                16
BasePay                100        SprintSpeed              24
SpeedBonusMax           50        StaminaMax              100
PerfectBonus           100        StaminaDrainPerSecond    20
ConsolationPay         100        StaminaRegenPerSecond    15
```

### Enums y tipos

```
Enums.DeliveryState  = { Idle, Offer, Reveal, Carry, Resolve, Payout }
Enums.DeliveryResult = { Success, Timeout, Exploded, Broken, Dropped }

PackageTypes  payMultiplier  1.0 / 2.0 / 3.0     stars  1 / 2 / 2
Modifiers.Heavy.SpeedMultiplier   = 0.65
Modifiers.Explosive.ImpulseThreshold = 12
Modifiers.Explosive.StabilityMax     = 100
Modifiers.Explosive.StabilityLossPerHit = 20
Modifiers.Explosive.HitCooldownSeconds  = 0.3

RewardService.Compute(delivery, timeLeft, tookHit)
RewardService.Consolation()
```

---

## 6. Paleta del proyecto

| Uso | RGB |
| --- | --- |
| Naranja de marca (rotulos, marquesina, pad de recogida) | `255, 150, 40` |
| Amarillo de entrega - **reservado al marcador, no usar en decoracion** | `255, 220, 40` |
| Carton (Normal Package) | `154, 108, 60` |
| Gris pesado (Heavy Package) | `90, 90, 100` |
| Rojo peligro (Explosive Package) | `200, 40, 40` |
| Metal / estructura | `70, 74, 82` |

Si el amarillo de entrega aparece en adornos, el jugador confunde decoracion con objetivos.
Es una regla de legibilidad, no de gusto.

---

## 7. Escala

- **1 stud = 0,28 m aproximadamente.** Un avatar R15 mide unos **5 studs**.
- Puertas de **7 studs de alto como minimo**. Las tres primeras casas se hicieron con 5 y no se
  puede entrar: es la deuda 4 del HANDOFF.
- Techos a 9 o mas, mostradores a 3-4, bancos a 1,6.

---

## 8. Sustitucion por modelos 3D

Todo el mundo esta construido con bloques primitivos que respetan estas medidas a proposito.
Cuando lleguen los modelos del Asset Pack, cada uno sustituye a su bloque equivalente **sin tocar
una linea de Lua**:

| Modelo | Sustituye a |
| --- | --- |
| `DEL_Environment_Road_Straight` | `City.RoadX`, `City.RoadZ` |
| `DEL_Environment_Road_Intersection` | El cruce en el origen |
| `DEL_Environment_Sidewalk` | `Sidewalk_X_N/S`, `Sidewalk_Z_W/E` |
| `DEL_Environment_House_A` / `_B` | `House_1`, `House_2`, `House_3` |
| `DEL_Environment_Store` | La carpeta `HQ` completa |
| `DEL_Package_Normal` / `_Heavy` / `_Explosive` | El `Part` de 2x2x2 que crea el servidor |
| `DEL_System_DeliveryPoint` | `House_N_Marker` |

La especificacion completa esta en la pagina de Notion `Asset Pack 3D - Encargo para IA generadora`,
incluido el prompt maestro en ingles listo para pegar en otra IA.
