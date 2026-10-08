class_name ToonStyler
extends Node
## Aplica el estilo toon (`ToonMaterials`) a toda la escena de su padre: al arrancar
## (`World`, jugador, NPCs...) y después a cada MeshInstance3D que entre en el árbol
## (peatones, paquetes, personajes recreados). Va en main.tscn.
## Rol "character" si la malla cuelga de un nodo de `CHARACTER_GROUPS`; si no, "world".

const CHARACTER_GROUPS: Array[String] = ["player", "npcs", "pedestrians"]

var _pending: Array[MeshInstance3D] = []


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	# Aplazado: el resto de la escena (y los _ready que fijan materiales) ya ha corrido.
	_apply_all.call_deferred()


## Rol de estilo de `node` según sus ancestros.
static func role_of(node: Node) -> String:
	var current := node
	while current != null:
		for group in CHARACTER_GROUPS:
			if current.is_in_group(group):
				return "character"
		current = current.get_parent()
	return "world"


func _apply_all() -> void:
	var scene_root := get_parent()
	if scene_root == null:
		return
	for mesh in scene_root.find_children("*", "MeshInstance3D", true, false):
		ToonMaterials.apply_mesh(mesh, role_of(mesh))


func _on_node_added(node: Node) -> void:
	if node is MeshInstance3D:
		if _pending.is_empty():
			_flush.call_deferred()
		_pending.append(node)


func _flush() -> void:
	var batch := _pending
	_pending = []
	for mesh in batch:
		if is_instance_valid(mesh) and mesh.is_inside_tree():
			ToonMaterials.apply_mesh(mesh, role_of(mesh))
