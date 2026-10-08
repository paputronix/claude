extends CharacterBody3D
## Peatón de ambiente: pasea entre locations y se para un rato en cada uno.
## Fuera de la lógica del juego: no está en `npcs` ni `interactable` (grupo `pedestrians`),
## no tiene capa de colisión (nadie choca con él ni tapa líneas de visión) y solo
## camina sobre el mundo (máscara 1).
##
## Destino: un punto navegable aleatorio cerca de un location al azar (sin `bar`, un
## interior), para que no se amontonen en el marker. Espera 3-10 s REALES al llegar:
## es ambiente y debe verse vivo con cualquier `time_scale` (a x60 se vería frenético).

## Locations que no se eligen como destino (interiores).
const EXCLUDED_LOCATIONS := ["bar"]
const ARRIVE_DISTANCE := 0.6
const WAIT_RANGE := Vector2(3.0, 10.0)
## Si no avanza esto en STUCK_TIME segundos, cambia de destino.
const STUCK_TIME := 4.0
const STUCK_PROGRESS := 0.5

@export var skin: Texture2D
@export var speed := 2.0
@export var turn_speed := 10.0
## Radio máximo (m) alrededor del location donde se elige el punto de destino.
@export var spread := 3.0
## Escala del modelo (no del cuerpo físico).
@export var visual_scale := 1.0

var destination := ""
var target_point := Vector3.ZERO
var _has_target := false
var _wait_left := 0.0
var _stuck_time := 0.0
var _stuck_origin := Vector3.ZERO
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var _agent: NavigationAgent3D = $NavigationAgent3D
@onready var _visual: Node3D = $Visual


func _ready() -> void:
	var model := _visual.get_node_or_null("Model")
	if skin != null and model != null and model.has_method("set_skin"):
		model.set_skin(skin)
	_visual.scale = Vector3.ONE * visual_scale
	_wait_left = randf_range(0.0, 2.0)  # que no arranquen todos a la vez


func _physics_process(delta: float) -> void:
	var dir := _steer(delta)
	if not is_on_floor():
		velocity.y -= _gravity * delta
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	if dir != Vector3.ZERO:
		var target_yaw := atan2(-dir.x, -dir.z)
		_visual.global_rotation.y = lerp_angle(_visual.global_rotation.y, target_yaw, turn_speed * delta)
	move_and_slide()


func _steer(delta: float) -> Vector3:
	if not _nav_ready():
		return Vector3.ZERO
	if not _has_target:
		if _wait_left > 0.0:
			_wait_left -= delta
			return Vector3.ZERO
		_pick_destination()
		if not _has_target:
			_wait_left = 1.0
			return Vector3.ZERO
	var flat := Vector2(global_position.x - target_point.x, global_position.z - target_point.z)
	if flat.length() <= ARRIVE_DISTANCE or _agent.is_navigation_finished():
		_arrive()
		return Vector3.ZERO
	_track_progress(delta)
	if not _has_target:
		return Vector3.ZERO
	var dir := _agent.get_next_path_position() - global_position
	dir.y = 0.0
	return dir.normalized() if dir.length() > 0.01 else Vector3.ZERO


func _arrive() -> void:
	_has_target = false
	_wait_left = randf_range(WAIT_RANGE.x, WAIT_RANGE.y)


## Atascado (sin avanzar): abandona el destino y elige otro.
func _track_progress(delta: float) -> void:
	_stuck_time += delta
	if _stuck_time < STUCK_TIME:
		return
	if global_position.distance_to(_stuck_origin) < STUCK_PROGRESS:
		_has_target = false
		_wait_left = 0.0
	_stuck_time = 0.0
	_stuck_origin = global_position


func _pick_destination() -> void:
	var ids := Locations.ids().filter(func(id): return not EXCLUDED_LOCATIONS.has(id) and id != destination)
	if ids.is_empty():
		return
	destination = ids.pick_random()
	target_point = random_point_near(destination, spread, get_world_3d().navigation_map)
	_agent.target_position = target_point
	_has_target = true
	_stuck_time = 0.0
	_stuck_origin = global_position


func _nav_ready() -> bool:
	return NavigationServer3D.map_get_iteration_id(get_world_3d().navigation_map) > 0


## Punto navegable aleatorio a menos de `spread` m (y dentro del radio) del location.
static func random_point_near(location_id: String, max_spread: float, nav_map: RID) -> Vector3:
	var center := Locations.get_position(location_id)
	var r := minf(max_spread, Locations.get_radius(location_id) * 0.8)
	var angle := randf() * TAU
	var offset := Vector3(cos(angle), 0.0, sin(angle)) * r * sqrt(randf())
	return NavigationServer3D.map_get_closest_point(nav_map, center + offset)
