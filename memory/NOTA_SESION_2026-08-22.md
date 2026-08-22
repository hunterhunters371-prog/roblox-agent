# Nota de sesion 2026-08-22 — Importacion de mallas 3D en Studio

Lecciones verificadas al llevar la caja `cmd_000001` (crate 8x6x8, 20 piezas)
a Roblox Studio como malla importada. Aplican a cualquier objeto futuro que el
agente genere para importar.

**Handoff de la conversacion completa**: pagina «Handoff — Caja 3D Roblox
(sesión 2026-08-22)» en el workspace de Notion del usuario. Leerla primero al
continuar este trabajo en un chat nuevo.

## Lo que NO funciona

- **OBJ + MTL**: el importador 3D de Studio ignora el `.mtl` aunque este en la
  misma carpeta que el `.obj`. La malla entra gris (`Medium stone grey`,
  Material `Plastic`).
- El importador fusiona todos los grupos `o` del OBJ en **un solo MeshPart**
  llamado `default`: se pierden los nombres por pieza y cualquier color por
  pieza (un MeshPart = un solo Color).

## Lo que SI funciona

- **GLB (glTF 2.0 binario) con texturas PNG embebidas** como bufferViews:
  importa texturizado. Verificado el 2026-08-22 con `caja-3d.glb` (20 mallas,
  nombres `Caja_*` preservados).
- **Una textura 512x512 por material con wrap REPEAT** (default de glTF, sin
  `samplers` en el JSON) y UVs en coordenadas de mundo: sin atlas, sin bordes
  que sangrar, sin colapsos por wrap.
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

## Correcciones v3 -> v4 (misma sesion)

Diagnosticadas de las capturas del usuario tras importar la v3:

1. **Parpadeo de la textura al alejarse o en angulo rasante**: detalle de
   alta frecuencia (cepillado del metal cada 3 px, vetas finas) hace moire
   al minificarse. Correccion: eliminar lineas finas; solo rasgos grandes y
   suaves.
2. **Lineas diagonales visibles en las caras grandes**: el importador suelda
   los vertices duplicados y suaviza normales por su cuenta; el sombreado
   plano del archivo no sobrevive. No controlable desde el archivo.

## Correcciones v4 -> v6 (misma sesion)

1. **Caras de 8 studs salian planas (el bug feo)**: con atlas, el mapeo
   `coord * 0.25 % 1.0` colapsaba a una sola columna de textura toda cara
   cuya extension era multiplo exacto del periodo (4 studs) — ambas aristas
   caian en el mismo texel. Lo detecto una asercion de UV nueva en el
   generador. Solucion definitiva: fuera el atlas; una textura por material
   con wrap REPEAT y UVs en coordenadas de mundo sin modulo.
2. **Bisel eliminado por completo**: el suavizado de normales del importador
   hacia visible el anillo del bisel como lineas poligonales. Cajas planas;
   el detalle lo da la geometria en capas (marco, esquinas, bandas).
3. **Caras inferiores**: primero se quitaron las 15 y la caja quedo hueca
   vista desde abajo; el usuario pidio conservarlas. Analisis correcto: esas
   caras se solapaban coplanares ENTRE SI (la base cubre toda la huella;
   paredes, esquinas, refuerzos y bandas la pisaban) y ademas con el piso.
   Estado final: se conserva SOLO la cara inferior de la base y toda la caja
   se eleva 0,02 studs para no quedar coplanar con el suelo. Leccion: antes
   de borrar caras por z-fighting, revisar que piezas comparten el plano —
   una sola cara por huella basta.
4. Patron de tablas desplazado media baldosa para que y=0 no caiga sobre la
   linea oscura (parpadeaba en los refuerzos inferiores).

Estas lecciones tambien quedaron integradas en el rol `modelador-3d` del repo
maximizador-ia, seccion «Lecciones verificadas: exportar mallas a Roblox
Studio».

Verificacion pendiente: render de la v6 en Studio (importacion del usuario).

## Estado del place «Experiencia sin título»

- Plugin RobloxAgentBridge instalado y abierto como pestaña en Studio.
- `CajaDetallada` (version nativa de partes) presente en Workspace.
- Quedaron duplicados `caja-3d` grises de las pruebas OBJ: borrables.

## Referencia

- Comando del puente: `commands/pending/cmd_000001.json`.
- Generador de mallas usado en la sesion: script Python en el sandbox del
  agente (`gen_caja_glb.py`): cajas planas, una textura REPEAT por material,
  UVs de mundo, normales por chequeo de winding (Newell), abanico desde
  centroide, una sola cara inferior (base), elevacion 0,02 studs, PIL.
