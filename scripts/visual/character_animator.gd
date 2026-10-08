extends Node3D
## Va en `Visual/Model`. Instancia el modelo anime del personaje (data/characters.json),
## le añade un AnimationPlayer con la librería compartida y elige la animación:
## - idle / walk / run según la velocidad horizontal del CharacterBody3D ancestro (con fundido);
## - talk mientras su personaje está en conversación (EventBus; el jugador habla en todas);
## - acciones sueltas con `play_action()` (el jugador hace pickup al recoger un paquete
##   e interact al entregarlo).
## Elección del modelo: `model_path` > `model_path` del cuerpo (peatones) > `npc_id` del cuerpo
## > `character_id`; `character_id = "pedestrians"` elige uno al azar de la lista.
## Los glb miran a +Z (perfil humanoide de Godot); se giran 180° para mirar a −Z (adelante del juego).
## Además ajusta al tamaño real del modelo la colisión, el NameLabel y el CameraPivot del cuerpo.

signal model_loaded(model: Node3D)

const CharacterModels := preload("res://scripts/visual/character_models.gd")
const FaceController := preload("res://scripts/visual/face_controller.gd")
const IDLE := "idle"
const WALK := "walk"
const RUN := "run"
const TALK := "talk"
const LIBRARY := ""

## Clave en characters.json ("player", "lucia"...). Vacío = `npc_id` del cuerpo.
@export var character_id := ""
## Fuerza un glb concreto (gana a todo lo demás).
@export_file("*.glb") var model_path := ""
## Por debajo (m/s) se considera quieto; por encima de run_threshold, corre.
@export var walk_threshold := 0.3
@export var run_threshold := 3.6
## Velocidades a las que walk/run van a ritmo 1.0 para un modelo de REFERENCE_HEIGHT.
@export var walk_reference_speed := 1.9
@export var run_reference_speed := 4.6
@export var blend_time := 0.2

const REFERENCE_HEIGHT := 1.7
const HEIGHT_RANGE := Vector2(1.4, 1.9)

var model: Node3D
var face: Node
## Altura real del modelo (m), calculada al instanciarlo.
var model_height := REFERENCE_HEIGHT

var _body: CharacterBody3D
var _anim: AnimationPlayer
var _talking := false
var _action := ""
var _carried_job := ""
var _job_poll := 0.0


func _ready() -> void:
	_body = _find_body()
	var path := _resolve_model_path()
	if path == "":
		push_warning("CharacterAnimator: sin modelo para '%s'" % character_id)
		return
	_load_model(path)
	_connect_signals()
	_play(IDLE)


## Reproduce una animación suelta (sin bucle) y vuelve a la locomoción al acabar.
func play_action(anim_name: String) -> void:
	if _anim == null or not _anim.has_animation(anim_name):
		return
	_action = anim_name
	_anim.speed_scale = 1.0
	_anim.play(anim_name, blend_time)


func get_animation_player() -> AnimationPlayer:
	return _anim


func is_talking() -> bool:
	return _talking


func _physics_process(delta: float) -> void:
	if _anim == null:
		return
	if _is_player():
		_poll_jobs(delta)
	var speed := 0.0
	if _body != null:
		speed = Vector2(_body.velocity.x, _body.velocity.z).length()
	if _action != "":
		# Moverse corta la acción; si no, se deja terminar.
		if speed <= walk_threshold * 2.0 and _anim.current_animation == _action and _anim.is_playing():
			return
		_action = ""
	var scale_by_height := model_height / REFERENCE_HEIGHT
	if speed > run_threshold:
		_play(RUN, clampf(speed / (run_reference_speed * scale_by_height), 0.6, 1.6))
	elif speed > walk_threshold:
		_play(WALK, clampf(speed / (walk_reference_speed * scale_by_height), 0.6, 1.7))
	elif _talking:
		_play(TALK)
	else:
		_play(IDLE)


func _play(anim_name: String, speed_scale := 1.0) -> void:
	if not _anim.has_animation(anim_name):
		return
	_anim.speed_scale = speed_scale
	if _anim.current_animation != anim_name:
		_anim.play(anim_name, blend_time)


func _load_model(path: String) -> void:
	var scene := load(path) as PackedScene
	if scene == null:
		push_error("CharacterAnimator: no se puede cargar %s" % path)
		return
	model = scene.instantiate() as Node3D
	model.name = "Character"
	model.rotation.y = PI
	add_child(model)
	# Debajo de la raíz del modelo: las pistas `%GeneralSkeleton:Hueso` se resuelven desde ahí.
	_anim = AnimationPlayer.new()
	_anim.name = "AnimationPlayer"
	_anim.add_animation_library(LIBRARY, CharacterModels.animation_library())
	model.add_child(_anim)
	ToonMaterials.apply(model, "character")
	face = FaceController.new()
	face.name = "Face"
	if face.setup(model):
		add_child(face)
	else:
		face.free()
		face = null
	model_height = _measure_height()
	_fit_body()
	model_loaded.emit(model)


func _resolve_model_path() -> String:
	if model_path != "":
		return model_path
	if _body != null:
		var body_path = _body.get("model_path")
		if typeof(body_path) == TYPE_STRING and body_path != "":
			return body_path
		var npc_id = _body.get("npc_id")
		if typeof(npc_id) == TYPE_STRING and CharacterModels.path_for(npc_id) != "":
			return CharacterModels.path_for(npc_id)
	if character_id == CharacterModels.PEDESTRIANS_KEY:
		var paths := CharacterModels.pedestrian_paths()
		return paths.pick_random() if not paths.is_empty() else ""
	return CharacterModels.path_for(character_id)


func _connect_signals() -> void:
	EventBus.conversation_started.connect(_on_conversation_started)
	EventBus.conversation_ended.connect(_on_conversation_ended)
	if _is_player():
		EventBus.job_completed.connect(func(_job, _on_time, _pay): play_action("interact"))
	if _body != null and _body.has_signal("affinity_changed"):
		_body.affinity_changed.connect(_on_affinity_changed)


func _on_conversation_started(npc_id: String) -> void:
	if _is_player() or _own_npc_id() == npc_id:
		_set_talking(true)


func _on_conversation_ended(npc_id: String) -> void:
	if _is_player() or _own_npc_id() == npc_id:
		_set_talking(false)


func _set_talking(value: bool) -> void:
	_talking = value
	if face != null:
		face.talking = value


func _on_affinity_changed(_value: int, delta: int) -> void:
	if face != null and delta != 0:
		face.show_expression("joy" if delta > 0 else "angry", 1.5)


## El jugador recoge un paquete: JobBoard no emite señal, se mira cada poco.
func _poll_jobs(delta: float) -> void:
	_job_poll -= delta
	if _job_poll > 0.0:
		return
	_job_poll = 0.2
	var board := get_node_or_null("/root/JobBoard")
	if board == null:
		return
	var carried: Dictionary = board.get_carried()
	var id: String = carried.get("id", "")
	if id != "" and id != _carried_job:
		play_action("pickup")
	_carried_job = id


func _is_player() -> bool:
	return _body != null and _body.is_in_group("player")


func _own_npc_id() -> String:
	if _body == null:
		return ""
	var id = _body.get("npc_id")
	return id if typeof(id) == TYPE_STRING else ""


func _measure_height() -> float:
	var top := 0.0
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var box: AABB = mesh.transform * mesh.get_aabb()
		top = maxf(top, box.end.y)
	return top if top > 0.0 else REFERENCE_HEIGHT


## Colisión (cápsula propia por instancia), etiqueta sobre la cabeza y cámara a la altura real.
func _fit_body() -> void:
	if _body == null:
		return
	var height := clampf(model_height, HEIGHT_RANGE.x, HEIGHT_RANGE.y)
	var shape_node := _body.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node != null and shape_node.shape is CapsuleShape3D:
		var capsule := shape_node.shape.duplicate() as CapsuleShape3D
		capsule.height = height
		shape_node.shape = capsule
		shape_node.position.y = height * 0.5
	var label := _body.get_node_or_null("NameLabel") as Node3D
	if label != null:
		label.position.y = model_height + 0.35
	var pivot := _body.get_node_or_null("CameraPivot") as Node3D
	if pivot != null:
		pivot.position.y = model_height * 0.85


func _find_body() -> CharacterBody3D:
	var node := get_parent()
	while node != null:
		if node is CharacterBody3D:
			return node
		node = node.get_parent()
	return null
