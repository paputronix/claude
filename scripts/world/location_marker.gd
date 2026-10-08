class_name LocationMarker
extends Marker3D
## Lugar con nombre del mapa. Se registra en Locations mientras está en el árbol.

@export var id := ""
## Radio (m) dentro del cual se considera que alguien está en el sitio.
@export var radius := 3.0


func _ready() -> void:
	if id.is_empty():
		push_warning("LocationMarker sin id: %s" % get_path())
		return
	Locations.register(id, self)


func _exit_tree() -> void:
	if not id.is_empty():
		Locations.unregister(id)
