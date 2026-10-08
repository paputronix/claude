class_name Interactor
extends Area3D
## Detecta interactuables cercanos al jugador y los activa con la action `interact` ([E]).
## Lo añade el Player en `_ready` (`add_child(Interactor.new())`); el padre es el jugador.
##
## Contrato Interactable: cualquier nodo del grupo "interactable" (el cuerpo detectado
## o su padre) que implemente:
##   func get_interaction_prompt() -> String   # p. ej. "Hablar con Lucía" (el "[E] " lo pone la UI)
##   func can_interact() -> bool               # false = ignorado (sin prompt)
##   func interact(by: Node) -> void           # acción al pulsar E; `by` es el jugador
## Inactivo mientras el padre tenga `controls_enabled == false` (p. ej. en diálogo).

const GROUP := "interactable"
const RADIUS := 2.0
## Bonus de distancia (m) a lo que está delante de la cámara.
const FRONT_BONUS := 0.75

var _target: Node = null
var _prompt: InteractionPrompt


func _init() -> void:
	# No es parte del mundo: solo escucha la capa 1 (world, donde están los NPCs).
	collision_layer = 0
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = RADIUS
	shape.shape = sphere
	add_child(shape)
	_prompt = InteractionPrompt.new()
	add_child(_prompt)


## Interactuable actual (o null).
func get_target() -> Node:
	return _target


func get_prompt() -> InteractionPrompt:
	return _prompt


func _physics_process(_delta: float) -> void:
	_target = _find_target() if _is_active() else null
	if _target != null:
		_prompt.show_prompt(_target.get_interaction_prompt())
	else:
		_prompt.hide_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact") or not _is_active():
		return
	# Revalida: el estado pudo cambiar desde el último physics frame.
	if _target != null and is_instance_valid(_target) and _target.can_interact():
		get_viewport().set_input_as_handled()
		_target.interact(get_parent())


func _is_active() -> bool:
	var parent := get_parent()
	return parent != null and parent.get("controls_enabled") != false


func _as_interactable(node: Node) -> Node:
	if node == null:
		return null
	if node.is_in_group(GROUP):
		return node
	var parent := node.get_parent()
	if parent != null and parent.is_in_group(GROUP):
		return parent
	return null


func _find_target() -> Node:
	var origin: Vector3 = global_position
	var forward := Vector3.ZERO
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		forward = -camera.global_basis.z
		forward.y = 0.0
		forward = forward.normalized()

	var candidates: Array[Node3D] = []
	candidates.append_array(get_overlapping_bodies())
	candidates.append_array(get_overlapping_areas())

	var best: Node = null
	var best_score := INF
	for candidate in candidates:
		var node := _as_interactable(candidate)
		if node == null or not node.can_interact():
			continue
		var pos: Vector3 = node.global_position if node is Node3D else candidate.global_position
		var to := pos - origin
		to.y = 0.0
		var score := to.length()
		if forward != Vector3.ZERO and to.length() > 0.001 and forward.dot(to.normalized()) > 0.0:
			score -= FRONT_BONUS
		if score < best_score:
			best_score = score
			best = node
	return best
