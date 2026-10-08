extends Node
## Reloj de juego. STUB (Ola 0): API fija, implementación en `claude/ligar-clock`.
## El tiempo se mide en minutos desde las 00:00 (0..1439).

signal minute_changed(minutes_of_day: int)
signal hour_changed(hour: int)

const MINUTES_PER_DAY := 1440

## Minutos de juego que pasan por segundo real.
@export var time_scale := 1.0
var paused := false
var minutes_of_day := 18 * 60


func set_time(hour: int, minute: int) -> void:
	minutes_of_day = (hour * 60 + minute) % MINUTES_PER_DAY
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
