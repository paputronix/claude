# Ligar Simulator

Prototipo de dating sim 3D en Godot 4.3+. Hito 1: sala, personaje en tercera persona, un NPC y una conversación que cambia la afinidad.

## Ejecutar
1. Abre Godot 4.3 o superior → *Import* → selecciona `project.godot`.
2. F5.

## Controles
| Acción | Tecla |
|---|---|
| Moverse | WASD |
| Cámara | Ratón |
| Soltar / recapturar ratón | Esc / clic |
| Elegir respuesta | 1-3 o clic |

Acércate a Lucía (la cápsula al fondo de la sala) y la conversación salta sola. Su color va de rojo (afinidad -100) a verde (+100). Para volver a hablar, aléjate y acércate otra vez.

## Estructura
```
scenes/   main, room, player, npc, dialogue_ui
scripts/  lógica de cada escena
data/dialogues/  conversaciones en JSON (edítalas sin tocar código)
```
