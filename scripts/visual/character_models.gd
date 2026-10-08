extends RefCounted
## Catálogo de modelos anime (data/characters.json) y librería de animaciones compartida.
## Sin class_name: se usa con preload() desde el animador y el spawner de peatones.

const CHARACTERS_PATH := "res://data/characters.json"
const PEDESTRIANS_KEY := "pedestrians"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var file := FileAccess.open(CHARACTERS_PATH, FileAccess.READ)
		var parsed = JSON.parse_string(file.get_as_text()) if file != null else null
		if typeof(parsed) != TYPE_DICTIONARY:
			push_error("characters.json ausente o inválido")
			return {}
		_data = parsed
	return _data


## Ruta del glb de un personaje con nombre propio ("player", "lucia", "carla"...). "" si no existe.
static func path_for(id: String) -> String:
	var value = data().get(id, "")
	return value if typeof(value) == TYPE_STRING and id != "animations" and not id.begins_with("_") else ""


static func pedestrian_paths() -> Array[String]:
	var paths: Array[String] = []
	for path in data().get(PEDESTRIANS_KEY, []):
		paths.append(String(path))
	return paths


static func animation_library() -> AnimationLibrary:
	return load(data().get("animations", "")) as AnimationLibrary
