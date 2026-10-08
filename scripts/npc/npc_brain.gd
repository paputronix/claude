extends Node
## Cerebro del NPC (hijo `Brain` de npc.tscn): decide a qué location ir y guía al
## cuerpo con el `NavigationAgent3D` hermano. El Npc solo aplica `move_direction`.
##
## Destino: una cita pendiente con este NPC manda desde `inicio - date_lead_minutes`
## hasta que se resuelve; si no, la entrada vigente del horario.
## Llegada: para al entrar en `radio * ARRIVE_FACTOR` del marker; ya dentro del radio no se mueve.
##
## Tiempo de juego vs caminar: camina siempre a velocidad normal. Solo si va a una
## cita, el paseo estimado (en minutos de juego, según `GameClock.time_scale`) no cabe
## en el tiempo que queda, y ni él ni el destino están cerca del jugador, se
## teletransporta al destino (p. ej. a x60 nadie lo ve llegar; a x1 nunca salta).

const NpcSchedule := preload("res://scripts/npc/npc_schedule.gd")
const MINUTES_PER_DAY := 1440
## Fracción del radio del location en la que se considera llegado (is_at estable).
const ARRIVE_FACTOR := 0.6
## Distancia (m) al jugador a partir de la que algo se considera fuera de su vista.
const UNSEEN_DISTANCE := 35.0

## Location a la que va (o en la que está). "" = sin destino.
var destination := ""
## Cita que manda ahora (o vacío).
var active_date: Dictionary = {}
## Llegado al destino: quieto hasta que cambie el destino o lo saquen del radio.
var arrived := false
## En conversación con el jugador: quieto.
var talking := false

var schedule: RefCounted

@onready var _npc: Npc = get_parent()
@onready var _agent: NavigationAgent3D = get_parent().get_node("NavigationAgent3D")


func _ready() -> void:
	schedule = NpcSchedule.load_file(_npc.schedule_path)
	GameClock.minute_changed.connect(_on_minute_changed)
	EventBus.date_scheduled.connect(_on_date_changed)
	EventBus.date_resolved.connect(_on_date_resolved)
	EventBus.conversation_started.connect(_on_conversation_started)
	EventBus.conversation_ended.connect(_on_conversation_ended)
	evaluate.call_deferred()


## Recalcula el destino (horario o cita) y si ya está en él.
func evaluate() -> void:
	if not is_inside_tree():
		return
	active_date = _find_active_date()
	var target: String = active_date.location_id if not active_date.is_empty() \
			else schedule.location_at(GameClock.minutes_of_day)
	var inside := Locations.has(target) and Locations.is_at(target, _npc.global_position)
	if target != destination:
		destination = target
		arrived = inside
	elif not inside:
		arrived = false  # lo han sacado del sitio: vuelve


func _physics_process(_delta: float) -> void:
	_npc.move_direction = _steer()


## Dirección horizontal de marcha (ZERO = quieto).
func _steer() -> Vector3:
	if talking or arrived or not Locations.has(destination) or not _nav_ready():
		return Vector3.ZERO
	var goal := Locations.get_position(destination)
	if _flat_distance(goal) <= Locations.get_radius(destination) * ARRIVE_FACTOR:
		arrived = true
		return Vector3.ZERO
	if _agent.target_position != goal:
		_agent.target_position = goal
	if _should_catch_up(goal):
		_npc.global_position = NavigationServer3D.map_get_closest_point(_npc.get_world_3d().navigation_map, goal)
		_npc.velocity = Vector3.ZERO
		arrived = true
		return Vector3.ZERO
	if _agent.is_navigation_finished():
		# Fin del camino sin entrar en el radio de llegada: se queda donde ha podido llegar.
		arrived = Locations.is_at(destination, _npc.global_position)
		return Vector3.ZERO
	var dir := _agent.get_next_path_position() - _npc.global_position
	dir.y = 0.0
	return dir.normalized() if dir.length() > 0.01 else Vector3.ZERO


func _nav_ready() -> bool:
	return NavigationServer3D.map_get_iteration_id(_npc.get_world_3d().navigation_map) > 0


## True si va tarde a una cita y el salto no lo puede ver el jugador.
func _should_catch_up(goal: Vector3) -> bool:
	if active_date.is_empty() or GameClock.time_scale <= 0.0 or _npc.walk_speed <= 0.0:
		return false
	var available := _start(active_date) - _now()
	var needed := _remaining_path_length() / _npc.walk_speed * GameClock.time_scale
	if needed <= available:
		return false
	return not _near_player(_npc.global_position) and not _near_player(goal)


func _remaining_path_length() -> float:
	_agent.get_next_path_position()  # fuerza el cálculo del camino si estaba pendiente
	var path := _agent.get_current_navigation_path()
	var index := _agent.get_current_navigation_path_index()
	if path.is_empty() or index >= path.size():
		return _npc.global_position.distance_to(_agent.target_position)
	var length := _npc.global_position.distance_to(path[index])
	for i in range(index + 1, path.size()):
		length += path[i - 1].distance_to(path[i])
	return length


func _near_player(position: Vector3) -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	return player != null and player.global_position.distance_to(position) < UNSEEN_DISTANCE


func _flat_distance(target: Vector3) -> float:
	var p := _npc.global_position
	return Vector2(p.x, p.z).distance_to(Vector2(target.x, target.z))


## Cita pendiente con este NPC cuya ventana de salida ya ha empezado (la más temprana).
func _find_active_date() -> Dictionary:
	var best: Dictionary = {}
	var now := _now()
	for date in DateScheduler.get_pending():
		if date.npc_id != _npc.npc_id or now < _start(date) - schedule.date_lead_minutes:
			continue
		if best.is_empty() or _start(date) < _start(best):
			best = date
	return best


func _now() -> int:
	return (GameClock.day - 1) * MINUTES_PER_DAY + GameClock.minutes_of_day


func _start(date: Dictionary) -> int:
	return (int(date.get("day", GameClock.day)) - 1) * MINUTES_PER_DAY + int(date.minute)


func _on_minute_changed(_minute: int) -> void:
	evaluate()


func _on_date_changed(_date: Dictionary) -> void:
	evaluate()


func _on_date_resolved(_date: Dictionary, _success: bool) -> void:
	evaluate()


func _on_conversation_started(id: String) -> void:
	if id == _npc.npc_id:
		talking = true


func _on_conversation_ended(id: String) -> void:
	if id == _npc.npc_id:
		talking = false
