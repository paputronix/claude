extends Node
## Citas pendientes. STUB (Ola 0): API fija, lógica real en `claude/ligar-dates`
## (avisos al móvil, ventana de llegada, resolución éxito/plantón).
## Cita = {npc_id: String, location_id: String, minute: int, status: String}
## status: "pending" | "success" | "stood_up"

var _dates: Array[Dictionary] = []


func schedule(npc_id: String, location_id: String, minute_of_day: int) -> Dictionary:
	var date := {"npc_id": npc_id, "location_id": location_id, "minute": minute_of_day, "status": "pending"}
	_dates.append(date)
	EventBus.date_scheduled.emit(date)
	return date


func get_pending() -> Array[Dictionary]:
	return _dates.filter(func(d): return d.status == "pending")
