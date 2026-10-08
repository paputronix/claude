extends Node
## Crea los peatones de ambiente al arrancar el mundo (lo instancia world.gd).
## Cada uno aparece en un location distinto (si hay menos que peatones, se repiten),
## nunca en `bar` para no caer encima del jugador, con modelo (data/characters.json),
## escala y velocidad propias. Los modelos se reparten sin repetir hasta agotar la lista.

const PEDESTRIAN := preload("res://scenes/pedestrian.tscn")
const PedestrianScript := preload("res://scripts/pedestrians/pedestrian.gd")
const CharacterModels := preload("res://scripts/visual/character_models.gd")
const SPAWN_EXCLUDED := ["bar"]

@export var count := 5


func _ready() -> void:
	_spawn.call_deferred()


func _spawn() -> void:
	# El navmesh se hornea en el _ready del mundo y el mapa sincroniza en el siguiente paso de física.
	var map := get_viewport().find_world_3d().navigation_map
	while NavigationServer3D.map_get_iteration_id(map) == 0:
		await get_tree().physics_frame
		if not is_inside_tree():
			return
	var ids := Locations.ids().filter(func(id): return not SPAWN_EXCLUDED.has(id))
	if ids.is_empty():
		return
	ids.shuffle()
	var models := CharacterModels.pedestrian_paths()
	models.shuffle()
	for i in count:
		var ped: CharacterBody3D = PEDESTRIAN.instantiate()
		if not models.is_empty():
			ped.model_path = models[i % models.size()]
		ped.speed = randf_range(1.8, 2.5)
		ped.visual_scale = randf_range(0.95, 1.05)
		ped.name = "Pedestrian%d" % (i + 1)
		var id: String = ids[i % ids.size()]
		get_parent().add_child(ped)
		ped.global_position = PedestrianScript.random_point_near(id, ped.spread, map) + Vector3(0, 0.1, 0)
