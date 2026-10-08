class_name Player
extends CharacterBody3D
## Personaje jugable en tercera persona.
## El cuerpo no rota: rota `CameraPivot` (yaw) + `SpringArm3D` (pitch) con el ratón,
## y `Visual` gira hacia la dirección de movimiento.

@export var move_speed := 5.0
@export var acceleration := 12.0
@export var turn_speed := 10.0
@export var mouse_sensitivity := 0.003
@export_range(-89.0, 0.0) var min_pitch_deg := -70.0
@export_range(0.0, 89.0) var max_pitch_deg := 20.0
@export var initial_pitch_deg := -20.0

var controls_enabled := true

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var _camera_pivot: Node3D = $CameraPivot
@onready var _spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var _visual: Node3D = $Visual


func _ready() -> void:
	_spring_arm.rotation.x = deg_to_rad(initial_pitch_deg)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	add_child(Interactor.new())


func set_controls_enabled(enabled: bool) -> void:
	controls_enabled = enabled
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if enabled else Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
		return

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_camera_pivot.rotation.y -= event.relative.x * mouse_sensitivity
		_spring_arm.rotation.x = clampf(
			_spring_arm.rotation.x - event.relative.y * mouse_sensitivity,
			deg_to_rad(min_pitch_deg),
			deg_to_rad(max_pitch_deg)
		)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta

	var direction := Vector3.ZERO
	if controls_enabled:
		var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		# CameraPivot solo tiene yaw, así que su basis da "adelante" en el plano XZ.
		direction = _camera_pivot.global_basis * Vector3(input_dir.x, 0.0, input_dir.y)
		direction.y = 0.0
		direction = direction.normalized()

	var target_velocity := direction * move_speed
	velocity.x = lerpf(velocity.x, target_velocity.x, acceleration * delta)
	velocity.z = lerpf(velocity.z, target_velocity.z, acceleration * delta)

	if direction != Vector3.ZERO:
		var target_yaw := atan2(-direction.x, -direction.z)
		_visual.rotation.y = lerp_angle(_visual.rotation.y, target_yaw, turn_speed * delta)

	move_and_slide()
