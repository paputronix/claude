# Créditos — personajes

Los personajes del juego son los modelos anime VRoid de `anime/` (ver `anime/CREDITS.md`),
animados con la librería de Quaternius retargeteada al perfil humanoide de Godot
(`anime/retarget/`: BoneMaps y generador de `anime/anim_library.res`).

## Restos de Kenney
**Animated Characters 2 (1.1)** de Kenney (www.kenney.nl) — licencia **CC0 1.0** (dominio público), ver `License.txt`.
Descargado de https://opengameart.org/sites/default/files/kenney_animated-characters-2.zip

- `carla_skin.png` — antigua skin de Carla (`skaterFemaleA.png` recoloreada). Ya no se dibuja:
  se conserva solo porque `scenes/main.tscn` aún la asigna a `Npc.skin` (propiedad obsoleta)
  y `tests/test_hito3_foundations.gd` la comprueba. Se puede borrar cuando ninguno la use.
