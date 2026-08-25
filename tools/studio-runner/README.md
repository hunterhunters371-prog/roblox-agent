# Studio Runner

Cierra el bucle. En lugar de "pulsa Sync y cópiame el log", tu PC ejecuta el
diagnóstico dentro de Roblox Studio, con **física real**, y sube el informe al
repositorio. El agente lo lee y corrige sin preguntarte nada.

## Qué mide

Con el motor de Roblox de verdad, no con suposiciones:

- **Masa del ensamblaje** (`AssemblyMass`) del vehículo. Es la cifra que decide
  cómo responde la suspensión. Un chasis ligero con muelles de camión rebota:
  las ruedas pierden contacto y la dirección deja de existir.
- **Piezas `Massless`** y cuánta masa se está ignorando. Carrocería que no pesa
  no estabiliza nada.
- **Constraints y soldaduras con referencias vacías** (`Attachment0`/`Part0` a
  `nil`). Es el fallo típico de un clon: el modelo se ve bien y no responde.
- **Contacto de cada rueda con el suelo** por raycast, y si hay hueco debajo.
- **Bamboleo**: inclinación máxima, mínima y media durante 6 segundos de
  simulación. Si un coche quieto bambolea más de 6 grados, algo está mal.
- **Deriva y hundimiento**: cuánto se mueve o se hunde sin conductor.

## Instalación (una sola vez)

### 1. Clona el repositorio

En CMD, en tu carpeta de usuario:

```
git clone https://github.com/hunterhunters371-prog/roblox-agent.git
```

Eso crea `C:\Users\<tu usuario>\roblox-agent`. Apunta la ruta exacta.

> Si antes te salió `fatal: not a git repository`, era por esto: estabas
> ejecutando `git pull` en una carpeta que no era el repositorio. El runner usa
> `git -C <ruta>` con ruta absoluta, así que ese error no puede repetirse.

### 2. Consigue el Universe ID

No es el mismo número que el Place ID.

Creator Dashboard → tu juego → los tres puntos sobre la miniatura →
**Copy Universe ID**.

### 3. Edita las tres primeras líneas de `run.cmd`

```
set "REPO=C:\Users\dayal\roblox-agent"
set "PLACE_ID=90800641570450"
set "UNIVERSE_ID=PON_AQUI_EL_UNIVERSE_ID"
```

Ajusta `REPO` si tu ruta es distinta y pega el Universe ID. Nada más.

## Uso

1. **Cierra Roblox Studio por completo.** Si el place está abierto, Studio no
   podrá cargarlo por línea de comandos y no habrá informe.
2. Doble clic en `run.cmd` (o ejecútalo desde CMD para ver los mensajes).
3. Tarda entre 40 y 90 segundos. Se abrirá una ventana de Studio que se cierra
   sola. No la toques.
4. Cuando termine, dile al agente: **"ya hay informe nuevo"**.

El informe queda en `informes/studio_<fecha>_<hora>.txt`, con el JSON entre las
marcas `===RBX_INFORME_INICIO===` y `===RBX_INFORME_FIN===`.

## Aviso importante: publica antes de diagnosticar

Al arrancar con `--placeId` y `--universeId`, Studio carga la versión
**publicada** del place, no los cambios que tengas sin publicar. Si acabas de
tocar algo en Studio y quieres que el diagnóstico lo vea, publica primero
(`File > Publish to Roblox`). Si no, el informe describirá una versión antigua y
el agente sacará conclusiones sobre algo que ya no existe.

## Por qué esto no puede estropear tu mundo

Dos protecciones, porque este proyecto ya se llevó un susto con esto:

1. La documentación de Roblox advierte que `RunService:Stop()` **no** deshace lo
   que la física movió: los cambios persisten al terminar la simulación. Eso es
   lo que dejó el camión rodado 62 studs y el coche de referencia volando a 30
   studs de altura, grabados en el archivo. El script fotografía el `CFrame` de
   cada pieza suelta del Workspace antes de simular y lo restaura al acabar.
2. `run.cmd` cierra Studio con `--quitAfterExecution`, **sin guardar**. Aunque
   la restauración fallara, nada de lo que ocurra durante la prueba llega a tu
   archivo.

La lección de fondo: si tú entras en modo Play, el coche se estrella y luego
guardas, ese destrozo queda permanente. Es la causa de buena parte de los
"fallos de modelado" de este proyecto.

## Automatizarlo del todo (opcional)

Para no tener que hacer ni el doble clic, crea una tarea programada:

```
schtasks /create /tn "RBX Diagnostico" /tr "C:\Users\dayal\roblox-agent\tools\studio-runner\run.cmd" /sc minute /mo 20
```

Cada 20 minutos habrá un informe fresco en el repositorio. Para quitarla:

```
schtasks /delete /tn "RBX Diagnostico" /f
```

## Límites honestos

- Corre en **tu** máquina. Nadie más puede ejecutar Studio; no existe versión en
  la nube ni máquina virtual con Studio disponible para el agente.
- Prueba el vehículo **en reposo**. Todavía no simula entradas de teclado, así
  que no mide aceleración ni giro bajo conducción. Se puede añadir después
  escribiendo en los atributos de `Inputs` (`throttleInput`, `steeringInput`).
- Los `MeshId` de modelos ajenos siguen sin poder recrearse. Esto diagnostica,
  no fabrica assets.
