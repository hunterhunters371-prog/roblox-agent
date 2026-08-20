# project/ — Código del juego (Rojo)

Este directorio se sincroniza con Roblox Studio mediante [Rojo](https://rojo.space/).

## Uso

1. Instala Rojo v7+: `aftman add rojo-rbx/rojo` (o desde GitHub Releases).
2. En este directorio: `rojo serve`.
3. En Studio: plugin de Rojo → **Connect**.
4. El código de `src/` se sincroniza en caliente con el place abierto.

## División de responsabilidades

- **Rojo** mueve *código* (scripts, modules) entre el repo y Studio.
- **Roblox Agent Bridge** (`plugin/`) ejecuta *comandos* sobre instancias: construcción del mundo, propiedades, GUI, inspección.

Ambos conviven en el mismo proyecto sin conflicto.
