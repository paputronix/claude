class_name Npc
extends CharacterBody3D
## NPC con el que se puede hablar. La afinidad vive en `RelationshipState`
## (por `npc_id`) y pide una conversación cuando el jugador lo interactúa con [E] (contrato Interactable).
## Vive según su horario: el hijo `Brain` (scripts/npc/npc_brain.gd) decide adónde ir y
## fija `move_direction`; aquí solo se aplica gravedad, velocidad y giro del `Visual`.

signal conversation_requested(npc: Npc)
signal affinity_changed(new_value: int, delta: int)

## Identificador estable (afinidad, citas, horarios). No cambiar una vez usado.
@export var npc_id := "lucia"
@export var npc_name := "Lucía"
@export_file("*.json") var dialogue_path := "res://data/dialogues/lucia.json"
## Afinidad inicial: solo se aplica si RelationshipState aún no conoce a este NPC.
@export_range(-100, 100) var starting_affinity := 0
## Horario (ver scripts/npc/npc_schedule.gd). Vacío = se queda quieto salvo citas.
@export_file("*.json") var schedule_path := "res://data/schedules/lucia.json"
## Obsoleto (Hito 5): sin efecto. El modelo sale de data/characters.json por `npc_id`.
## Se conserva para que las escenas que aún lo asignan (main.tscn) carguen sin error.
@export var skin: Texture2D
## Velocidad de paseo (m/s).
@export var walk_speed := 3.0
@export var turn_speed := 10.0

## Dirección horizontal de marcha (normalizada o ZERO). La fija el Brain.
var move_direction := Vector3.ZERO

## Solo lectura: el valor real está en RelationshipState.
var affinity: int:
	get:
		return RelationshipState.get_affinity(npc_id)

var _body_material: StandardMaterial3D
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var _name_label: Label3D = $NameLabel
@onready var _visual: Node3D = $Visual
@onready var _body_mesh: MeshInstance3D = $Visual/Body


func _ready() -> void:
	add_to_group("interactable")
	# Material propio por instancia: si hay varios NPCs, cada uno se tiñe por separado.
	_body_material = _body_mesh.mesh.material.duplicate()
	_body_mesh.material_override = _body_material
	if not RelationshipState.has_npc(npc_id):
		RelationshipState.set_affinity(npc_id, starting_affinity)
	RelationshipState.affinity_changed.connect(_on_state_affinity_changed)
	_refresh_visuals()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	velocity.x = move_direction.x * walk_speed
	velocity.z = move_direction.z * walk_speed
	if move_direction != Vector3.ZERO:
		# Global: la raíz del NPC puede venir rotada en la escena.
		var target_yaw := atan2(-move_direction.x, -move_direction.z)
		_visual.global_rotation.y = lerp_angle(_visual.global_rotation.y, target_yaw, turn_speed * delta)
	move_and_slide()


func change_affinity(delta: int) -> void:
	RelationshipState.change_affinity(npc_id, delta)


func get_interaction_prompt() -> String:
	return "Hablar con %s" % npc_name


func can_interact() -> bool:
	return true


func interact(_by: Node) -> void:
	conversation_requested.emit(self)


func face(target: Vector3) -> void:
	target.y = _visual.global_position.y
	if _visual.global_position.distance_to(target) > 0.01:
		_visual.look_at(target, Vector3.UP)


func load_dialogue() -> Dictionary:
	var file := FileAccess.open(dialogue_path, FileAccess.READ)
	if file == null:
		push_error("No se puede abrir el diálogo: %s" % dialogue_path)
		return {}
	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Diálogo con formato inválido: %s" % dialogue_path)
		return {}
	return data


func _refresh_visuals() -> void:
	_name_label.text = "%s\nAfinidad: %d" % [npc_name, affinity]
	# Rojo (-100) → blanco (0) → verde (+100).
	var t := float(affinity) / RelationshipState.MAX_AFFINITY
	var color := Color.WHITE.lerp(Color(0.3, 0.9, 0.4) if t >= 0.0 else Color(0.9, 0.25, 0.25), absf(t))
	_body_material.albedo_color = color


func _on_state_affinity_changed(id: String, value: int, delta: int) -> void:
	if id != npc_id:
		return
	_refresh_visuals()
	affinity_changed.emit(value, delta)
