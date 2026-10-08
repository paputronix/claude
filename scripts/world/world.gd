extends Node3D
## Mapa: bar, calle, casa de Lucía y parque, con estética de ciudad de anime.
## Todo primitivo (StaticBody3D + MeshInstance3D + CollisionShape3D, sin CSG).
## La navegación se hornea al arrancar a partir de los colisionadores estáticos,
## así no hay vértices horneados en la escena y basta con mover cajas en el editor.
## Decorado: el nodo `Anime` agrupa lo que no tiene colisión (ventanas, rótulos, cables,
## flores...); lo que se puede pisar o estorba cuelga de `NavigationRegion3D`.
## Los cristales de ventana están en el grupo `window_glass` (el ciclo día/noche los enciende).
## `scenes/world/world.tscn` se generó con un script; edítalo a mano con normalidad.

const PedestrianSpawner := preload("res://scripts/pedestrians/pedestrian_spawner.gd")

@onready var _nav_region: NavigationRegion3D = $NavigationRegion3D


func _ready() -> void:
	_nav_region.bake_navigation_mesh(false)
	_merge_static_meshes()
	add_child(PedestrianSpawner.new())  # peatones de ambiente


## Fusiona las mallas estáticas del mapa por material (y por si proyectan sombra): de unas
## 1.400 MeshInstance3D a ~150. Imprescindible en web/móvil: WebGL dejaba de dibujar la escena
## con miles de draw calls. Se quedan sueltas las que se cambian en runtime: ventanas
## (`window_glass`), bombillas (`LampBulb*`) y nodos con `keep_material`. Las originales
## pierden la malla pero conservan nodo, hijos y colisión.
func _merge_static_meshes() -> void:
	var tools := {}
	var keys := {}
	var to_world := global_transform.affine_inverse()
	for node in find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if not _is_mergeable(mesh_instance):
			continue
		var mesh := mesh_instance.mesh
		var local := to_world * mesh_instance.global_transform
		for surface in mesh.get_surface_count():
			var material := mesh_instance.get_active_material(surface)
			var key := "%d|%d" % [material.get_instance_id() if material else 0, mesh_instance.cast_shadow]
			if not tools.has(key):
				tools[key] = SurfaceTool.new()
				keys[key] = [material, mesh_instance.cast_shadow]
			(tools[key] as SurfaceTool).append_from(mesh, surface, local)
		mesh_instance.mesh = null
	var index := 0
	for key: String in tools:
		var merged := MeshInstance3D.new()
		merged.name = "Merged_%d" % index
		merged.mesh = (tools[key] as SurfaceTool).commit()
		merged.material_override = keys[key][0]
		merged.cast_shadow = keys[key][1]
		add_child(merged)
		index += 1


func _is_mergeable(mesh_instance: MeshInstance3D) -> bool:
	if mesh_instance.mesh == null or not mesh_instance.is_visible_in_tree():
		return false
	if mesh_instance.is_in_group("window_glass") or mesh_instance.name.begins_with("LampBulb"):
		return false
	var node: Node = mesh_instance
	while node != null and node != self:
		if node.has_meta("keep_material"):
			return false
		node = node.get_parent()
	return true
