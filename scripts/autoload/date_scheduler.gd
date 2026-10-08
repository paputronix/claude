extends Node
## Citas: creación desde el diálogo, avisos al móvil, ventana de llegada y resolución.
## Cita = {npc_id, location_id, minute, day, status}  (`day` es aditivo)
## status: "pending" | "success" | "stood_up" | "npc_no_show"
## Reglas: ver `_check_date`. Todo se evalúa con tiempo absoluto (día + minuto).
## Las claves que empiezan por `_` son estado interno (avisos, presencias vistas).

const MINUTES_PER_DAY := 1440
## Minutos tras la hora de la cita durante los que se puede llegar.
const ARRIVAL_WINDOW_MINUTES := 30
## Antelación del mensaje de recordatorio.
const REMINDER_MINUTES := 30
const AFFINITY_SUCCESS := 15
const AFFINITY_STOOD_UP := -25

const TEXT_REMINDER := "¿Sigue en pie lo de las %s en %s?"
const TEXT_ARRIVING := "Ya estoy llegando 😊"
const TEXT_SUCCESS := "Me lo he pasado genial. Repetimos 💕"
const TEXT_STOOD_UP := "Te he estado esperando... muy mal."
const TEXT_NO_SHOW := "Perdona, me ha surgido algo..."

var _dates: Array[Dictionary] = []


func _ready() -> void:
	EventBus.dialogue_action.connect(_on_dialogue_action)
	GameClock.minute_changed.connect(_on_minute_changed)


## Crea una cita. Es hoy si la hora no ha pasado, si no, mañana.
func schedule(npc_id: String, location_id: String, minute_of_day: int) -> Dictionary:
	var day: int = GameClock.day
	if minute_of_day < GameClock.minutes_of_day:
		day += 1
	var date := {"npc_id": npc_id, "location_id": location_id, "minute": minute_of_day,
			"day": day, "status": "pending",
			"_reminded": false, "_arriving": false, "_player_seen": false, "_npc_seen": false}
	# Si la cita es en menos de REMINDER_MINUTES, no hay recordatorio.
	date["_reminded"] = _now() >= _start(date) - REMINDER_MINUTES
	_dates.append(date)
	EventBus.date_scheduled.emit(date)
	return date


func get_pending() -> Array[Dictionary]:
	return _dates.filter(func(d): return d.status == "pending")


## Todas las citas, resueltas o no.
func get_dates() -> Array[Dictionary]:
	return _dates.duplicate()


## Reset (para tests).
func clear() -> void:
	_dates.clear()


func _on_dialogue_action(npc_id: String, action: Dictionary) -> void:
	var req = action.get("schedule_date")
	if not req is Dictionary:
		return
	var minute := GameClock.parse_time(str(req.get("time", "")))
	var location := str(req.get("location", ""))
	if minute < 0 or location.is_empty():
		return
	for d in get_pending():
		if d.npc_id == npc_id:
			return
	schedule(npc_id, location, minute)
	Phone.notify("Cita con %s" % _npc_name(npc_id), "%s · %s" % [_fmt(minute), location])


func _on_minute_changed(_minute: int) -> void:
	for date in get_pending():
		_check_date(date)


func _check_date(date: Dictionary) -> void:
	var now := _now()
	var start := _start(date)
	var end := start + ARRIVAL_WINDOW_MINUTES
	var npc_id: String = date.npc_id
	if not date._reminded and now >= start - REMINDER_MINUTES:
		date._reminded = true
		Phone.notify(_npc_name(npc_id), TEXT_REMINDER % [_fmt(date.minute), date.location_id])
	if now < start:
		return
	if not date._arriving:
		date._arriving = true
		Phone.notify(_npc_name(npc_id), TEXT_ARRIVING)
	# Ventana [start, end], ambos extremos incluidos: quién está en el sitio.
	var player_here := _is_at(date.location_id, get_tree().get_first_node_in_group("player"))
	var npc_here := _is_at(date.location_id, _find_npc(npc_id))
	date._player_seen = date._player_seen or player_here
	date._npc_seen = date._npc_seen or npc_here
	if player_here and npc_here:
		_resolve(date, "success", AFFINITY_SUCCESS, TEXT_SUCCESS)
	elif now >= end:
		if date._player_seen:
			_resolve(date, "npc_no_show", 0, TEXT_NO_SHOW)
		else:
			_resolve(date, "stood_up", AFFINITY_STOOD_UP, TEXT_STOOD_UP)


func _resolve(date: Dictionary, status: String, delta: int, text: String) -> void:
	date.status = status
	if delta != 0:
		RelationshipState.change_affinity(date.npc_id, delta)
	Phone.notify(_npc_name(date.npc_id), text)
	EventBus.date_resolved.emit(date, status == "success")


func _now() -> int:
	return (GameClock.day - 1) * MINUTES_PER_DAY + GameClock.minutes_of_day


func _start(date: Dictionary) -> int:
	return (int(date.day) - 1) * MINUTES_PER_DAY + int(date.minute)


func _fmt(minute: int) -> String:
	return "%02d:%02d" % [minute / 60, minute % 60]


func _is_at(location_id: String, node: Node) -> bool:
	var n3 := node as Node3D
	return n3 != null and n3.is_inside_tree() and Locations.is_at(location_id, n3.global_position)


func _find_npc(npc_id: String) -> Node:
	for n in get_tree().get_nodes_in_group("npcs"):
		if "npc_id" in n and n.npc_id == npc_id:
			return n
	return null


func _npc_name(npc_id: String) -> String:
	var npc := _find_npc(npc_id)
	if npc != null and "npc_name" in npc:
		return npc.npc_name
	return npc_id
