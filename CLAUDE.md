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
- `scenes/main.tscn` + `scripts/main.gd`: cablea señales NPC → DialogueUI → Player. Las piezas no se conocen entre sí.
- `Player` (CharacterBody3D, capa física 2): tercera persona, `CameraPivot` (yaw) + `SpringArm3D` (pitch).
- `Npc` (StaticBody3D, grupo `npcs`): guarda su `affinity` (-100..100); `TalkArea` (mask 2) emite `conversation_requested` al entrar el jugador, se rearma al salir.
- `DialogueUI` (CanvasLayer): lee el JSON del NPC (`data/dialogues/*.json`) y aplica deltas de afinidad.
- Formato diálogo: `{ "start": id, "nodes": { id: { "text", "options": [{ "text", "affinity", "reaction", "next": id|null }] } } }`.

## Hitos
1. ✅ Prototipo mínimo: sala, player WASD+ratón, NPC, conversación por proximidad con 3 opciones que mueven la afinidad.

## Visión a futuro (NO implementar aún)
- Tiempo real estilo GTA/Schedule I, móvil con avisos.
- Logística de quedadas: evitar que dos citas se solapen/crucen físicamente.
- Bucle trabajar → dinero/estatus → tiempo como recurso.
- Ramas de relación a largo plazo.
