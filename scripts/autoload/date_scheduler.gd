extends Node
## Citas: creación desde el diálogo, avisos al móvil, ventana de llegada, cita en curso,
## pilladas y resolución.
## Cita = {npc_id, location_id, minute, day, status}  (`day` es aditivo)
## status: "pending" → "in_progress" → "success" | "cut_short" | "caught"
##         "pending" → "stood_up" | "npc_no_show" | "cancelled"
## Reglas:
## - Ventana de llegada [inicio, inicio + 30]: si jugador y NPC coinciden en el sitio,
##   la cita pasa a "in_progress" y se emite `EventBus.date_started` (main abre el diálogo
##   de cita). Si no: "stood_up" (no viniste) o "npc_no_show" (viniste y ella no).
## - En curso dura DATE_DURATION_MINUTES de juego (el diálogo pausa el reloj, no cuenta).
##   Si el jugador se aleja más de `radio * STAY_RADIUS_FACTOR` del sitio → "cut_short".
##   Si aguanta → "success".
## - Pillada: otro NPC interesado a menos de CAUGHT_DISTANCE del jugador y con línea de
##   visión → "caught", castigo con ambas y se cancela la cita pendiente del testigo.
## Todo se evalúa con tiempo absoluto (día + minuto).
## Las claves que empiezan por `_` son estado interno (avisos, presencias vistas).

const MINUTES_PER_DAY := 1440
## Minutos tras la hora de la cita durante los que se puede llegar.
const ARRIVAL_WINDOW_MINUTES := 30
## Antelación del mensaje de recordatorio.
const REMINDER_MINUTES := 30
## Duración de la cita en curso (minutos de juego) desde que coincidís en el sitio.
## Cuadra con el día objetivo: Lucía 21:00 parque → 21:40; Carla deja la fuente
## (`parque_fuente`) a las 21:40 y pasa a ~9 m del parque; parque → bar corriendo ≈ 19 min.
const DATE_DURATION_MINUTES := 40
## Durante la cita el jugador debe seguir dentro de `radio del sitio * este factor`.
const STAY_RADIUS_FACTOR := 2.0
## Distancia (m) jugador-testigo para que te pillen.
const CAUGHT_DISTANCE := 12.0
## Altura (m) de la cabeza sobre el origen del cuerpo para la línea de visión.
const HEAD_HEIGHT := 1.6
## Capa física del mundo (máscara del raycast de visión).
const WORLD_LAYER_MASK := 1
## Afinidad desde la que un NPC sin cita contigo se pone celoso.
const INTEREST_AFFINITY := 20
## Cada cuántos physics frames se busca testigos (solo si hay citas en curso).
const CAUGHT_CHECK_FRAMES := 5

const AFFINITY_SUCCESS := 15
const AFFINITY_STOOD_UP := -25
const AFFINITY_CUT_SHORT := -5
const AFFINITY_CAUGHT := -30

const TEXT_REMINDER := "¿Sigue en pie lo de las %s en %s?"
const TEXT_ARRIVING := "Ya estoy llegando 😊"
const TEXT_SUCCESS := "Me lo he pasado genial. Repetimos 💕"
const TEXT_STOOD_UP := "Te he estado esperando... muy mal."
const TEXT_NO_SHOW := "Perdona, me ha surgido algo..."
const TEXT_CUT_SHORT := "¿Ya te vas? Vaya... pensaba que estábamos bien."
## %s = nombre del testigo.
const TEXT_CAUGHT_DATE := "¿En serio? He visto cómo te miraba %s... Me voy a casa."
## %s = nombre de la cita.
const TEXT_CAUGHT_WITNESS := "Te acabo de ver con %s. Muy bonito."
const TEXT_CANCELLED := "Olvídate de lo de esta noche."

var _dates: Array[Dictionary] = []
var _frame := 0


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
			"_reminded": false, "_arriving": false, "_player_seen": false, "_npc_seen": false,
			"_started_at": -1}
	# Si la cita es en menos de REMINDER_MINUTES, no hay recordatorio.
	date["_reminded"] = _now() >= _start(date) - REMINDER_MINUTES
	_dates.append(date)
	EventBus.date_scheduled.emit(date)
	return date


## Citas sin resolver: "pending" o "in_progress" (el Brain del NPC las sigue igual y
## no se puede crear otra con el mismo NPC mientras tanto).
func get_pending() -> Array[Dictionary]:
	return _dates.filter(func(d): return d.status == "pending" or d.status == "in_progress")


## Citas en curso.
func get_in_progress() -> Array[Dictionary]:
	return _dates.filter(func(d): return d.status == "in_progress")


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
	# Copia: una cita que empieza en este minuto no se evalúa como en curso hasta el siguiente.
	for date in get_pending():
		if date.status == "in_progress":
			_check_in_progress(date)
		else:
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
	var player_here := _is_at(date.location_id, _player())
	var npc_here := _is_at(date.location_id, _find_npc(npc_id))
	date._player_seen = date._player_seen or player_here
	date._npc_seen = date._npc_seen or npc_here
	if player_here and npc_here:
		date.status = "in_progress"
		date._started_at = now
		EventBus.date_started.emit(date)
	elif now >= end:
		if date._player_seen:
			_resolve(date, "npc_no_show", 0, TEXT_NO_SHOW)
		else:
			_resolve(date, "stood_up", AFFINITY_STOOD_UP, TEXT_STOOD_UP)


func _check_in_progress(date: Dictionary) -> void:
	if not _player_stays(date):
		_resolve(date, "cut_short", AFFINITY_CUT_SHORT, TEXT_CUT_SHORT)
	elif _now() >= int(date._started_at) + DATE_DURATION_MINUTES:
		_resolve(date, "success", AFFINITY_SUCCESS, TEXT_SUCCESS)


func _player_stays(date: Dictionary) -> bool:
	var player := _player() as Node3D
	if player == null or not player.is_inside_tree() or not Locations.has(date.location_id):
		return false
	var p := Locations.get_position(date.location_id)
	var q := player.global_position
	var limit := Locations.get_radius(date.location_id) * STAY_RADIUS_FACTOR
	return Vector2(p.x, p.z).distance_to(Vector2(q.x, q.z)) <= limit


func _physics_process(_delta: float) -> void:
	_frame += 1
	if _frame % CAUGHT_CHECK_FRAMES != 0:
		return
	for date in get_in_progress():
		var witness := _find_witness(date)
		if witness != null:
			_catch(date, witness)


## Otro NPC interesado, cerca del jugador y con línea de visión (o null).
func _find_witness(date: Dictionary) -> Node3D:
	var player := _player() as Node3D
	if player == null or not player.is_inside_tree():
		return null
	var date_npc := _find_npc(date.npc_id) as CollisionObject3D
	for node in get_tree().get_nodes_in_group("npcs"):
		var witness := node as CollisionObject3D
		if witness == null or not "npc_id" in node or node.npc_id == date.npc_id:
			continue
		if not _is_interested(node.npc_id, int(date.day)):
			continue
		if witness.global_position.distance_to(player.global_position) >= CAUGHT_DISTANCE:
			continue
		if _has_line_of_sight(witness, player, date_npc):
			return witness
	return null


## Interesado = cita contigo ese día (salvo plantón suyo) o afinidad alta.
func _is_interested(npc_id: String, day: int) -> bool:
	if RelationshipState.get_affinity(npc_id) >= INTEREST_AFFINITY:
		return true
	for d in _dates:
		if d.npc_id == npc_id and int(d.day) == day and d.status != "stood_up":
			return true
	return false


## Raycast cabeza a cabeza contra el mundo, ignorando los cuerpos de ambos NPCs.
func _has_line_of_sight(witness: CollisionObject3D, player: Node3D, date_npc: CollisionObject3D) -> bool:
	var exclude: Array[RID] = [witness.get_rid()]
	if date_npc != null:
		exclude.append(date_npc.get_rid())
	var from := witness.global_position + Vector3.UP * HEAD_HEIGHT
	var to := player.global_position + Vector3.UP * HEAD_HEIGHT
	var query := PhysicsRayQueryParameters3D.create(from, to, WORLD_LAYER_MASK, exclude)
	return witness.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _catch(date: Dictionary, witness: Node) -> void:
	var witness_id: String = witness.npc_id
	EventBus.caught.emit(date, witness_id)
	_resolve(date, "caught", AFFINITY_CAUGHT, TEXT_CAUGHT_DATE % _npc_name(witness_id))
	RelationshipState.change_affinity(witness_id, AFFINITY_CAUGHT)
	Phone.notify(_npc_name(witness_id), TEXT_CAUGHT_WITNESS % _npc_name(date.npc_id))
	for d in _dates:
		if d.npc_id == witness_id and d.status == "pending":
			_resolve(d, "cancelled", 0, TEXT_CANCELLED)


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


func _player() -> Node:
	return get_tree().get_first_node_in_group("player")


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
