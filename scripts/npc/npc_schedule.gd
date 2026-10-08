extends RefCounted
## Horario de un NPC leído de JSON (`data/schedules/*.json`):
## { "entries": [{"from": "HH:MM", "location": id}, ...], "date_lead_minutes": int }
## La entrada vigente es la última cuyo `from` <= hora; antes de la primera vale la última (wrap a medianoche).

const DEFAULT_LEAD_MINUTES := 30

## [{from: int, location: String}] ordenadas por `from`.
var entries: Array[Dictionary] = []
## Minutos antes de una cita en los que el NPC sale hacia el sitio.
var date_lead_minutes := DEFAULT_LEAD_MINUTES


## Carga un horario; si falla, devuelve uno vacío (el NPC se queda donde está).
static func load_file(path: String) -> RefCounted:
	var schedule: RefCounted = load("res://scripts/npc/npc_schedule.gd").new()
	if path.is_empty():
		return schedule
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("No se puede abrir el horario: %s" % path)
		return schedule
	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Horario con formato inválido: %s" % path)
		return schedule
	schedule.parse(data)
	return schedule


func parse(data: Dictionary) -> void:
	entries.clear()
	for raw in data.get("entries", []):
		if not raw is Dictionary:
			continue
		var minute := _parse_time(str(raw.get("from", "")))
		var location := str(raw.get("location", ""))
		if minute < 0 or location.is_empty():
			push_warning("Entrada de horario inválida: %s" % [raw])
			continue
		entries.append({"from": minute, "location": location})
	entries.sort_custom(func(a, b): return a.from < b.from)
	date_lead_minutes = int(data.get("date_lead_minutes", DEFAULT_LEAD_MINUTES))


## Location del horario a esa hora (minutos 0..1439), o "" si no hay entradas.
func location_at(minute_of_day: int) -> String:
	if entries.is_empty():
		return ""
	var current: Dictionary = entries[-1]
	for entry in entries:
		if entry.from <= minute_of_day:
			current = entry
	return current.location


## Como GameClock.parse_time, sin depender del autoload (se puede testear suelto).
static func _parse_time(text: String) -> int:
	var parts := text.split(":")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return -1
	return int(parts[0]) * 60 + int(parts[1])
