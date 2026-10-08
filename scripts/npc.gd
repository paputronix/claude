class_name Npc
extends StaticBody3D
## NPC con el que se puede hablar. Guarda su propia afinidad con el jugador
## y pide una conversación cuando el jugador lo interactúa con [E] (contrato Interactable).

signal conversation_requested(npc: Npc)
signal affinity_changed(new_value: int, delta: int)

const MIN_AFFINITY := -100
const MAX_AFFINITY := 100

## Identificador estable (afinidad, citas, horarios). No cambiar una vez usado.
@export var npc_id := "lucia"
@export var npc_name := "Lucía"
@export_file("*.json") var dialogue_path := "res://data/dialogues/lucia.json"
@export_range(-100, 100) var affinity := 0

var _body_material: StandardMaterial3D

## TODO: eliminar TalkArea de npc.tscn (sin uso; la conversación se dispara con [E]).
@onready var _name_label: Label3D = $NameLabel
@onready var _visual: Node3D = $Visual
@onready var _body_mesh: MeshInstance3D = $Visual/Body


func _ready() -> void:
	add_to_group("interactable")
	# Material propio por instancia: si hay varios NPCs, cada uno se tiñe por separado.
	_body_material = _body_mesh.mesh.material.duplicate()
	_body_mesh.material_override = _body_material
	_refresh_visuals()


func change_affinity(delta: int) -> void:
	affinity = clampi(affinity + delta, MIN_AFFINITY, MAX_AFFINITY)
	_refresh_visuals()
	affinity_changed.emit(affinity, delta)


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
	var t := float(affinity) / MAX_AFFINITY
	var color := Color.WHITE.lerp(Color(0.3, 0.9, 0.4) if t >= 0.0 else Color(0.9, 0.25, 0.25), absf(t))
	_body_material.albedo_color = color

