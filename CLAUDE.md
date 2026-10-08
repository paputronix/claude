# Ligar Simulator — Contexto del Proyecto

## Qué es
Juego de hobby (no comercial) tipo life/dating sim en 3D, inspirado en **Schedule I**: mundo en tiempo real, movimiento libre, el móvil del personaje suena para avisarte de quedadas y eventos. El gancho: ligar como **sistema vivo con logística espacial**, no un menú de diálogos estáticos.

## Alcance (IMPORTANTE)
Proyecto personal. Prioridad absoluta: **pequeño, que funcione, y que se termine**. Nada de sandbox gigante.

## Decisiones técnicas
- **Motor:** Godot 4.3+ · **Lenguaje:** GDScript (tipado estático cuando sea razonable).
- **Personajes:** Mixamo. **Entorno/props:** Kenney o Blender MCP.
- **Filosofía:** primero funciona con cápsulas/cubos, luego bonito. Nunca al revés.

## Cómo trabajar
- Tareas **pequeñas y concretas**, una a una. El usuario es arquitecto/director; Claude programa.
- Explicar lo justo, sin sobreexplicar lo básico.

## Arquitectura actual
- `scenes/world/world.tscn`: bar, calle, casa de Lucía y parque (StaticBody3D primitivos, no CSG: el navmesh se hornea en `_ready` desde colisionadores). `LocationMarker` registra `bar`, `calle`, `casa_lucia`, `parque` en `Locations`. Tras el bake, esperar `NavigationServer3D.map_get_iteration_id() > 0` antes de pedir caminos.
- `scenes/main.tscn` + `scripts/main.gd`: cablea señales NPC → DialogueUI → Player. Las piezas no se conocen entre sí.
- `Player` (CharacterBody3D, capa física 2): tercera persona, `CameraPivot` (yaw) + `SpringArm3D` (pitch).
- `Npc` (CharacterBody3D + NavigationAgent3D, grupos `npcs` + `interactable`): afinidad en `RelationshipState` por `npc_id`; `interact()` emite `conversation_requested`. Su hijo `Brain` (`scripts/npc/npc_brain.gd`) decide destino: horario JSON (`data/schedules/*.json`) o cita pendiente desde `inicio - date_lead_minutes`; teletransporte a la cita solo si no llega y el jugador no lo ve.
- Visual: personajes Kenney (CC0) en `assets/characters/`; `character_animator.gd` cambia idle/run por velocidad. `Visual/Body` del NPC es el anillo de afinidad.
- `Interactor` (lo crea `player.gd`): detecta `interactable` cercanos y muestra "[E] ...". Contrato en `scripts/interaction/interactor.gd`.
- `DialogueUI` (CanvasLayer): lee el JSON del NPC (`data/dialogues/*.json`) y aplica deltas de afinidad.
- Formato diálogo (detalle en la cabecera de `dialogue_ui.gd`): `{ "start": id | [condiciones por afinidad], "nodes": { id: { "text", "options": [{ "text", "affinity", "reaction", "next": id|null }] } } }`.

## Autoloads (contratos — Ola 0)
Registrados en `project.godot`, en `scripts/autoload/` (+ `scenes/ui/` para los que son escena). La API pública de cada uno es el contrato entre ramas: **ampliar sí, romper firmas no**.
- `EventBus`: solo señales (`conversation_started/ended(npc_id)`, `dialogue_action(npc_id, action)`, `date_scheduled(date)`, `date_resolved(date, success)`).
- `GameClock`: `minutes_of_day`, `day`, `time_scale`, `paused`, `advance()`, `set_time()`, `format_time()`, `parse_time()`, señales `minute_changed`, `hour_changed`, `day_changed`. Se pausa solo durante conversaciones. Debug: F1/F2/F3 = x1/x10/x60.
- `RelationshipState`: `get_affinity/set_affinity/change_affinity(npc_id, ...)`, señal `affinity_changed`.
- `Locations`: `register(id, node)`, `get_position(id)`, `is_at(id, pos)`, `ids()`.
- `DateScheduler`: `schedule()`, `get_pending()`, `get_dates()`. Cita = `{npc_id, location_id, minute, day, status}`, status `pending|success|stood_up|npc_no_show`. Crea citas desde `dialogue_action.schedule_date`, avisa al móvil, ventana de llegada 30 min.
- `Phone` (escena): `notify(title, body)`, `messages`, `open/close/toggle()`, señal `notified`. Tab abre el móvil.
- `ClockHud` (escena): HUD del reloj.

## Tests
- `tests/run.sh [patrón]`: Godot 4.3 headless (se descarga solo a `~/.cache`). Debe quedar en verde antes de cualquier PR.
- Cada test: `extends "res://tests/test_base.gd"` + `func run_test()`. Helpers: `check()`, `autoload()`, `wait_frames()`, `load_main()`.
- En tests no uses tipos `class_name` del juego (ver `test_base.gd`).
- No esperes un número fijo de frames cuando dependas de la física: usa `wait_until()` / `talk_to()`.
- Verificación visual: Xvfb + `--rendering-driver opengl3` permite capturas, pero es el renderer de compatibilidad (no Forward+): no ajustes iluminación solo con esas capturas.

## Trabajo en paralelo (Hito 2)
Rama de integración: `claude/ligar-simulator-prototype-jq95e7`. Cada feature en `claude/ligar-<feature>`, PR contra integración.
Reglas para cada rama: no tocar `project.godot`; tocar solo tus ficheros (abajo) o usar los contratos de autoload; si necesitas ampliar un contrato, hazlo solo de forma aditiva y dilo en el PR; añadir `tests/test_<feature>.gd`.

| Rama | Ficheros dueños |
|---|---|
| clock | `scripts/autoload/game_clock.gd`, `scenes/ui/clock_hud.tscn`, `scripts/ui/clock_hud.gd` |
| phone | `scripts/autoload/phone.gd`, `scenes/ui/phone.tscn`, `assets/sfx/*` |
| relationships | `dialogue_ui.gd`, `npc.gd` (bloque afinidad), `data/dialogues/*` |
| interaction | `scripts/interaction/*`, `player.gd` (hook), `npc.gd` (disparo de conversación) |
| map | `scenes/world/*`, `scripts/world/*`, `main.tscn` |
| art | `assets/characters/*`, `player.tscn`, `npc.tscn` |

## Hitos
1. ✅ Prototipo mínimo: sala, player WASD+ratón, NPC, conversación por proximidad con 3 opciones que mueven la afinidad.
2. ✅ "Un día en la vida": reloj, móvil, afinidad persistente, [E] Hablar, mapa con zonas, NPC con horario, quedada a hora y lugar (`tests/test_hito2.gd` cubre el bucle completo).

## Visión a futuro (NO implementar aún)
- Tiempo real estilo GTA/Schedule I, móvil con avisos.
- Logística de quedadas: evitar que dos citas se solapen/crucen físicamente.
- Bucle trabajar → dinero/estatus → tiempo como recurso.
- Ramas de relación a largo plazo.
