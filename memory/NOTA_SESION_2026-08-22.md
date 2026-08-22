# Nota de sesion 2026-08-22 — Importacion de mallas 3D en Studio

Lecciones verificadas al llevar la caja `cmd_000001` (crate 8x6x8, 20 piezas)
a Roblox Studio como malla importada. Aplican a cualquier objeto futuro que el
agente genere para importar.

## Lo que NO funciona

- **OBJ + MTL**: el importador 3D de Studio ignora el `.mtl` aunque este en la
  misma carpeta que el `.obj`. La malla entra gris (`Medium stone grey`,
  Material `Plastic`).
- El importador fusiona todos los grupos `o` del OBJ en **un solo MeshPart**
  llamado `default`: se pierden los nombres por pieza y cualquier color por
  pieza (un MeshPart = un solo Color).

## Lo que SI funciona

- **GLB (glTF 2.0 binario) con textura PNG embebida** como bufferView: importa
  texturizado. Verificado el 2026-08-22 con `caja-3d.glb` (20 mallas, atlas
  1536x512 embebido, nombres `Caja_*` preservados).
- Escala: 1 unidad del archivo = 1 stud, respetada por el importador.
- Activar **Anclado** en el dialogo de importacion; por defecto viene apagado.

## Errores de textura cometidos y su correccion (generador v1 -> v2)

1. **Manchas rojizas/verdosas en la madera**: las vetas usaban un factor
   aleatorio distinto por canal RGB -> desvio de tono. Correccion: un solo
   factor `k` por trazo aplicado a los tres canales.
2. **Parche oscuro en la tapa**: sangrado entre baldosas del atlas por
   filtrado bilineal. Correccion: margen de 16 px por baldosa al mapear UVs.
3. **Remaches invisibles en las bandas**: radio y contraste insuficientes a
   escala de importacion. Correccion: remaches de radio 9/6 px con centro al
   190% del brillo base.
4. Variacion de brillo entre tablas reducida de ±12 a ±8 para evitar bandas
   de contraste fuerte.

## Correcciones v2 -> v3 (misma sesion)

Diagnosticadas de las capturas del usuario tras importar la v2:

1. **Costuras diagonales de sombreado** en tapa y paredes: la triangulacion
   en abanico desde un vertice generaba triangulos largos y finos. Correccion:
   abanico desde el centroide de cada cara (1360 -> 2400 triangulos).
2. **Z-fighting (franjas y moire en bordes)**: caras coplanares entre base,
   paredes, esquinas y refuerzos (todas con cara exterior a 4,0). Correccion:
   planos separados: base 3,95 / paredes 4,0 / esquinas 4,03 / refuerzos 4,05
   / bandas 4,1.
3. **Moire de textura a distancia**: lineas de tabla cada 0,5 studs y vetas
   largas y oscuras. Correccion: lineas a 1 por stud con factor 0,7, vetas de
   10-40 px con factor 0,82-0,95, variacion por tabla ±6.

Estas lecciones tambien quedaron integradas en el rol `modelador-3d` del repo
maximizador-ia, seccion «Lecciones verificadas: exportar mallas a Roblox
Studio».

Verificacion pendiente: render de la v3 en Studio (importacion del usuario).

## Estado del place «Experiencia sin título»

- Plugin RobloxAgentBridge instalado y abierto como pestaña en Studio.
- `CajaDetallada` (version nativa de partes) presente en Workspace.
- Quedaron duplicados `caja-3d` grises de las pruebas OBJ: borrables.

## Referencia

- Comando del puente: `commands/pending/cmd_000001.json`.
- Generador de mallas usado en la sesion: script Python en el sandbox del
  agente (`gen_caja_glb.py`): caja con bisel 0,06 studs, normales corregidas
  por chequeo de winding (Newell), abanico desde centroide, atlas con PIL.
