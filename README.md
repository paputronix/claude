# Ligar Simulator

Dating sim 3D de hobby en Godot 4.3+, inspirado en Schedule I: el tiempo pasa, el móvil avisa y quedas con alguien a una hora en un sitio concreto.

**Estado:** Hito 3 ("El tiempo es el recurso") completo.

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
Empiezas a las 18:00 en el bar con 20 €. El móvil te ofrece encargos de reparto: recoge el paquete en el kiosko con [E] y entrégalo en el portal indicado antes de la hora límite (con retraso cobras la mitad). Habla con Lucía, en el bar, y con Carla, en la terraza: cada una recuerda cómo la tratas (anillo a sus pies). Con suficiente afinidad puedes quedar con las dos la misma noche: Lucía a las 21:00 en el parque, Carla a las 22:00 en el bar.

Cada una va sola al sitio. Al coincidir empieza la cita: un diálogo donde puedes invitar (si te llega el dinero) y luego unos 40 minutos juntos. Quédate y sale bien; vete antes y queda a medias. Ojo: si la otra te ve en plena cita, **pillada**, y te quedas sin ninguna. La puntualidad, dónde te pones y cuándo te vas deciden la noche.

## Estructura
```
scenes/          main, player, npc, dialogue_ui, world/ (mapa), ui/ (móvil, reloj)
scripts/         lógica; autoload/ (sistemas globales), npc/ (horario), interaction/
data/dialogues/  conversaciones en JSON (edítalas sin tocar código)
data/schedules/  horarios de los NPCs en JSON
assets/          personajes (Kenney, CC0)
data/jobs.json   encargos de reparto
tests/           tests headless: tests/run.sh
```

## Tests
`tests/run.sh` (descarga Godot 4.3 headless si hace falta) · `tests/run.sh clock` para uno concreto.

## Créditos
Personajes: [Kenney](https://kenney.nl) — Animated Characters 2 (CC0).
