extends Node
## Expresiones faciales con los morph targets VRoid (se buscan por sufijo: el glb los
## nombra "Face.M_F00_000_00_Fcl_EYE_Close"...). Lo crea el animador si el modelo los tiene.
## - Parpadeo aleatorio cada BLINK_INTERVAL s (no mientras hay expresión: la alegría ya cierra los ojos).
## - Boca (MTH_A) que se abre y cierra a ráfagas mientras `talking`.
## - `show_expression("joy" | "angry" | "sorrow" | "fun" | "surprised", segundos)` con fundido.

const MORPHS := {
	"joy": "Fcl_ALL_Joy",
	"angry": "Fcl_ALL_Angry",
	"sorrow": "Fcl_ALL_Sorrow",
	"fun": "Fcl_ALL_Fun",
	"surprised": "Fcl_ALL_Surprised",
	"blink": "Fcl_EYE_Close",
	"mouth": "Fcl_MTH_A",
}
const BLINK_INTERVAL := Vector2(2.0, 6.0)
const BLINK_TIME := 0.16
const EXPRESSION_FADE := 0.25
## Ráfagas de habla: abre y cierra la boca durante TALK_BURST s y calla TALK_PAUSE s.
const TALK_BURST := Vector2(1.2, 2.8)
const TALK_PAUSE := Vector2(0.3, 1.0)
const MOUTH_RATE := 9.0
const MOUTH_OPEN := 0.7

var talking := false:
	set(value):
		talking = value
		_burst_left = randf_range(TALK_BURST.x, TALK_BURST.y)

## mesh → {morph_key: índice}
var _targets: Array[Dictionary] = []
var _blink_wait := 0.0
var _blink_t := -1.0
var _expression := ""
var _expression_left := 0.0
var _expression_weight := 0.0
var _burst_left := 0.0
var _pause_left := 0.0
var _talk_t := 0.0


## Busca los morphs en las mallas de `model`. Devuelve false si no tiene ninguno (peatones).
func setup(model: Node) -> bool:
	_targets.clear()
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var found := {}
		for i in mesh_instance.mesh.get_blend_shape_count():
			var shape_name := String(mesh_instance.mesh.get_blend_shape_name(i))
			for key in MORPHS:
				if shape_name.ends_with(MORPHS[key]):
					found[key] = i
		if not found.is_empty():
			_targets.append({"mesh": mesh_instance, "morphs": found})
	_blink_wait = randf_range(BLINK_INTERVAL.x, BLINK_INTERVAL.y)
	return not _targets.is_empty()


func has_morph(key: String) -> bool:
	for target in _targets:
		if target.morphs.has(key):
			return true
	return false


## Valor actual de un morph (0..1), para tests y depuración.
func get_morph(key: String) -> float:
	for target in _targets:
		if target.morphs.has(key):
			return (target.mesh as MeshInstance3D).get_blend_shape_value(target.morphs[key])
	return 0.0


func blink() -> void:
	_blink_t = 0.0


func show_expression(expression: String, duration := 1.5) -> void:
	if not MORPHS.has(expression):
		return
	if _expression != "" and _expression != expression:
		_set_morph(_expression, 0.0)
		_expression_weight = 0.0
	_expression = expression
	_expression_left = duration


func get_expression() -> String:
	return _expression


func _process(delta: float) -> void:
	if _targets.is_empty():
		return
	_update_expression(delta)
	_update_blink(delta)
	_update_mouth(delta)


func _update_expression(delta: float) -> void:
	if _expression == "":
		return
	_expression_left -= delta
	var target := 1.0 if _expression_left > 0.0 else 0.0
	_expression_weight = move_toward(_expression_weight, target, delta / EXPRESSION_FADE)
	_set_morph(_expression, _expression_weight)
	if _expression_left <= 0.0 and _expression_weight <= 0.0:
		_expression = ""


func _update_blink(delta: float) -> void:
	if _blink_t < 0.0:
		_blink_wait -= delta
		if _blink_wait <= 0.0 and _expression == "":
			_blink_t = 0.0
		return
	_blink_t += delta
	var phase := _blink_t / BLINK_TIME
	_set_morph("blink", 1.0 - absf(phase * 2.0 - 1.0) if phase < 1.0 else 0.0)
	if phase >= 1.0:
		_blink_t = -1.0
		_blink_wait = randf_range(BLINK_INTERVAL.x, BLINK_INTERVAL.y)


func _update_mouth(delta: float) -> void:
	var value := 0.0
	if talking:
		_burst_left -= delta
		if _burst_left <= 0.0 and _burst_left + delta > 0.0:
			_pause_left = randf_range(TALK_PAUSE.x, TALK_PAUSE.y)
		elif _burst_left <= 0.0:
			_pause_left -= delta
			if _pause_left <= 0.0:
				_burst_left = randf_range(TALK_BURST.x, TALK_BURST.y)
		if _burst_left > 0.0:
			_talk_t += delta
			value = absf(sin(_talk_t * MOUTH_RATE)) * MOUTH_OPEN
	var current := get_morph("mouth")
	_set_morph("mouth", move_toward(current, value, delta * 8.0))


func _set_morph(key: String, value: float) -> void:
	for target in _targets:
		if target.morphs.has(key):
			(target.mesh as MeshInstance3D).set_blend_shape_value(target.morphs[key], value)
