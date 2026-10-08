extends Node
## Reloj de juego. El tiempo se mide en minutos desde las 00:00 (0..1439).
##
## Teclas de debug (solo en build debug, leídas por keycode, sin input actions):
## F1 = x1, F2 = x10, F3 = x60 de `time_scale`.

signal minute_changed(minutes_of_day: int)
signal hour_changed(hour: int)
signal day_changed(day: int)

const MINUTES_PER_DAY := 1440

## Minutos de juego que pasan por segundo real.
@export var time_scale := 1.0
## Pausa manual. Independiente de la pausa por conversación.
var paused := false
var minutes_of_day := 18 * 60
## Día actual (empieza en 1).
var day := 1

var _accum := 0.0
var _in_conversation := false


func _ready() -> void:
	var bus := get_node_or_null("/root/EventBus")
	if bus:
		bus.conversation_started.connect(_on_conversation_started)
		bus.conversation_ended.connect(_on_conversation_ended)


func _process(delta: float) -> void:
	advance(delta * time_scale)


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_F1: time_scale = 1.0
		KEY_F2: time_scale = 10.0
		KEY_F3: time_scale = 60.0


## True si el reloj avanza (ni pausa manual ni conversación).
func is_running() -> bool:
	return not paused and not _in_conversation


## Avanza `game_minutes` minutos de juego (si el reloj corre). Emite las señales
## por cada minuto/hora/día cruzado.
func advance(game_minutes: float) -> void:
	if not is_running() or game_minutes <= 0.0:
		return
	_accum += game_minutes
	while _accum >= 1.0:
		_accum -= 1.0
		_step_minute()


func set_time(hour: int, minute: int) -> void:
	minutes_of_day = (hour * 60 + minute) % MINUTES_PER_DAY
	_accum = 0.0
	minute_changed.emit(minutes_of_day)


func get_hour() -> int:
	return minutes_of_day / 60


func get_minute() -> int:
	return minutes_of_day % 60


## "HH:MM"
func format_time() -> String:
	return "%02d:%02d" % [get_hour(), get_minute()]


## "21:00" -> 1260. Devuelve -1 si el formato no es válido.
static func parse_time(text: String) -> int:
	var parts := text.split(":")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return -1
	return int(parts[0]) * 60 + int(parts[1])


func _step_minute() -> void:
	var old_hour := get_hour()
	minutes_of_day += 1
	var new_day := false
	if minutes_of_day >= MINUTES_PER_DAY:
		minutes_of_day = 0
		day += 1
		new_day = true
	minute_changed.emit(minutes_of_day)
	if get_hour() != old_hour:
		hour_changed.emit(get_hour())
	if new_day:
		day_changed.emit(day)


func _on_conversation_started(_npc_id: String) -> void:
	_in_conversation = true


func _on_conversation_ended(_npc_id: String) -> void:
	_in_conversation = false
