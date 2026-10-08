extends Node3D
## Va en la raíz del modelo animado (nodo `Model`). Aplica la skin y reproduce
## idle/run según la velocidad horizontal del CharacterBody3D ancestro.
## Si no hay CharacterBody3D (p. ej. el NPC es StaticBody3D), idle en bucle.
## Las animaciones vienen en FBX aparte (mismo esqueleto): se copian en un
## AnimationPlayer propio al arrancar.

const IDLE := "idle"
const RUN := "run"

@export var skin: Texture2D
@export var idle_source: PackedScene
@export var run_source: PackedScene
## Velocidad horizontal (m/s) a partir de la que se pasa a correr.
@export var run_threshold := 0.5
## Velocidad a la que la animación de correr va a ritmo 1.0.
@export var run_reference_speed := 5.0
@export var blend_time := 0.15

var _body: CharacterBody3D
var _anim: AnimationPlayer


func _ready() -> void:
	_apply_skin()
	_anim = _ensure_animation_player()
	_import_animation(idle_source, IDLE)
	_import_animation(run_source, RUN)
	_body = _find_body()
	_play(IDLE)


func _physics_process(_delta: float) -> void:
	if _body == null or _anim == null:
		return
	var speed := Vector2(_body.velocity.x, _body.velocity.z).length()
	if speed > run_threshold:
		_play(RUN, clampf(speed / run_reference_speed, 0.5, 1.5))
	else:
		_play(IDLE)


func _play(anim_name: String, speed_scale := 1.0) -> void:
	if _anim == null or not _anim.has_animation(anim_name):
		return
	_anim.speed_scale = speed_scale
	if _anim.current_animation != anim_name:
		_anim.play(anim_name, blend_time)


func _apply_skin() -> void:
	if skin == null:
		return
	var material := StandardMaterial3D.new()
	material.albedo_texture = skin
	for mesh in find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_override = material


func _ensure_animation_player() -> AnimationPlayer:
	var players := find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		return players[0]
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	add_child(player)
	# root_node por defecto es "..": las pistas ("Root/Skeleton3D:...") se resuelven desde este nodo.
	return player


## Copia la primera animación del FBX `source` cuyo nombre contenga `anim_name`.
func _import_animation(source: PackedScene, anim_name: String) -> void:
	if source == null:
		push_warning("CharacterAnimator: falta la escena de la animación '%s'" % anim_name)
		return
	var instance := source.instantiate()
	var found: Animation
	for node in instance.find_children("*", "AnimationPlayer", true, false):
		var player := node as AnimationPlayer
		for candidate in player.get_animation_list():
			if candidate.to_lower().contains(anim_name):
				found = player.get_animation(candidate)
				break
		if found != null:
			break
	instance.free()
	if found == null:
		push_warning("CharacterAnimator: no se encuentra la animación '%s'" % anim_name)
		return
	var animation := found.duplicate() as Animation
	animation.loop_mode = Animation.LOOP_LINEAR
	if not _anim.has_animation_library(""):
		_anim.add_animation_library("", AnimationLibrary.new())
	_anim.get_animation_library("").add_animation(anim_name, animation)


func _find_body() -> CharacterBody3D:
	var node := get_parent()
	while node != null:
		if node is CharacterBody3D:
			return node
		node = node.get_parent()
	return null
