extends Node
## Señales globales entre sistemas que no deben conocerse entre sí.
## Regla: solo señales, sin estado ni lógica.

## Emitidas por DialogueUI. Útiles para pausar el reloj, ocultar HUD, etc.
signal conversation_started(npc_id: String)
signal conversation_ended(npc_id: String)

## Emitida por DialogueUI cuando una opción elegida trae `"action": {...}` en el JSON.
## Ej.: {"schedule_date": {"location": "parque", "time": "21:00"}}.
signal dialogue_action(npc_id: String, action: Dictionary)

## Emitidas por DateScheduler. `date` = {npc_id, location_id, minute, status}.
signal date_scheduled(date: Dictionary)
signal date_resolved(date: Dictionary, success: bool)
