extends Node
## Registro de lugares con nombre ("bar", "parque", "casa"...).
## Los LocationMarker del mapa se registran aquí en su _ready.

var _locations: Dictionary = {}


func register(id: String, node: Node3D) -> void:
	_locations[id] = node


func unregister(id: String) -> void:
	_locations.erase(id)


func has(id: String) -> bool:
	return _locations.has(id) and is_instance_valid(_locations[id])


func get_position(id: String) -> Vector3:
	if not has(id):
		push_error("Location desconocida: %s" % id)
		return Vector3.ZERO
	return (_locations[id] as Node3D).global_position


## Radio en metros dentro del cual se considera que alguien "está" en el sitio.
func get_radius(id: String) -> float:
	if has(id) and "radius" in _locations[id]:
		return _locations[id].radius
	return 3.0


func is_at(id: String, position: Vector3) -> bool:
	if not has(id):
		return false
	var p := get_position(id)
	return Vector2(p.x, p.z).distance_to(Vector2(position.x, position.z)) <= get_radius(id)


func ids() -> Array:
	return _locations.keys().filter(func(id): return has(id))
