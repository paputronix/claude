extends Node
## Fuente de verdad de la afinidad jugador↔NPC, por `npc_id`.
## Sobrevive a que el NPC se destruya o cambie de escena.

signal affinity_changed(npc_id: String, value: int, delta: int)

const MIN_AFFINITY := -100
const MAX_AFFINITY := 100

var _affinity: Dictionary = {}


func get_affinity(npc_id: String) -> int:
	return _affinity.get(npc_id, 0)


func set_affinity(npc_id: String, value: int) -> void:
	var old := get_affinity(npc_id)
	_affinity[npc_id] = clampi(value, MIN_AFFINITY, MAX_AFFINITY)
	if _affinity[npc_id] != old:
		affinity_changed.emit(npc_id, _affinity[npc_id], _affinity[npc_id] - old)


func change_affinity(npc_id: String, delta: int) -> void:
	set_affinity(npc_id, get_affinity(npc_id) + delta)
