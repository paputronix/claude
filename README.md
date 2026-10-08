# Ligar Simulator

Dating sim 3D de hobby en Godot 4.3+, inspirado en Schedule I: el tiempo pasa, el móvil avisa y quedas con alguien a una hora en un sitio concreto.

**Estado:** Hito 2 ("Un día en la vida") completo.

## Ejecutar
1. Abre Godot 4.3 o superior → *Import* → selecciona `project.godot`.
2. F5.

## Controles
| Acción | Tecla |
|---|---|
| Moverse | WASD |
| Cámara | Ratón |
| Hablar / interactuar | E |
| Móvil | Tab |
| Elegir respuesta | 1-3 o clic |
| Soltar / recapturar ratón | Esc / clic |
| Velocidad del tiempo (debug) | F1 x1 · F2 x10 · F3 x60 |

## Cómo se juega (hoy)
Empiezas a las 18:00 en el bar. Habla con Lucía: sus respuestas cambian la afinidad (anillo a sus pies, de rojo a verde) y lo recuerda la próxima vez. Con suficiente afinidad puedes proponerle quedar a las 21:00 en el parque. El móvil te avisa antes; Lucía sale del bar por su cuenta y camina hasta allí. Si llegáis los dos a tiempo, la cita sale bien; si no apareces, le has dado plantón.

## Estructura
```
scenes/          main, player, npc, dialogue_ui, world/ (mapa), ui/ (móvil, reloj)
scripts/         lógica; autoload/ (sistemas globales), npc/ (horario), interaction/
data/dialogues/  conversaciones en JSON (edítalas sin tocar código)
data/schedules/  horarios de los NPCs en JSON
assets/          personajes (Kenney, CC0)
tests/           tests headless: tests/run.sh
```

## Tests
`tests/run.sh` (descarga Godot 4.3 headless si hace falta) · `tests/run.sh clock` para uno concreto.

## Créditos
Personajes: [Kenney](https://kenney.nl) — Animated Characters 2 (CC0).
