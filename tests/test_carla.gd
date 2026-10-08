extends "res://tests/test_base.gd"
## Carla, segundo NPC: coexiste con Lucía, modelo anime propio, diálogo y afinidad
## independientes, horario terraza → fuente del parque → casa y robustez si faltan locations.

const CARLA_MODEL := "res://assets/characters/anime/carla.glb"
const LUCIA_MODEL := "res://assets/characters/anime/lucia.glb"


## glb instanciado bajo Visual/Model y número de mallas que trae.
func _model_info(npc: Node) -> Array:
	var model: Node = npc.get_node("Visual/Model")
	if model.get_child_count() == 0:
		return ["", 0]
	var character: Node = model.get_child(0)
	return [character.scene_file_path, character.find_children("*", "MeshInstance3D", true, false).size()]


func _dialogue_texts(npc: Node, ids: Array) -> Array:
	var nodes: Dictionary = npc.load_dialogue().get("nodes", {})
	return ids.map(func(id): return nodes[id].text)


func run_test() -> void:
	var main := await load_main()
	var clock := autoload("GameClock")
	var rel := autoload("RelationshipState")
	var sched := autoload("DateScheduler")
	var locations := autoload("Locations")
	var player: Node3D = main.get_node("Player")
	var lucia: Node3D = main.get_node("Lucia")
	var carla: Node3D = main.get_node("Carla")
	var ui: Node = main.get_node("DialogueUI")
	var brain: Node = carla.get_node("Brain")
	clock.time_scale = 0.0
	clock.paused = false
	clock.day = 1
	sched.clear()
	clock.set_time(18, 0)

	# --- Coexistencia ---
	var npcs := get_nodes_in_group("npcs")
	check(npcs.has(lucia) and npcs.has(carla) and npcs.size() == 2, "Lucía y Carla en el grupo npcs")
	check(carla.npc_id == "carla" and lucia.npc_id == "lucia", "ids distintos")
	check(carla.npc_name == "Carla", "nombre de Carla")
	check(carla.global_position.distance_to(Vector3(5, 0, 15)) < 0.5, "Carla colocada en (5, 0, 15)")

	# --- Modelo por instancia (data/characters.json por npc_id) ---
	var carla_model := _model_info(carla)
	var lucia_model := _model_info(lucia)
	check(carla_model[0] == CARLA_MODEL and carla_model[1] > 0, "Carla usa carla.glb: %s" % [carla_model])
	check(lucia_model[0] == LUCIA_MODEL and lucia_model[1] > 0, "Lucía usa lucia.glb: %s" % [lucia_model])
	# `skin` (obsoleto) sigue existiendo para que main.tscn cargue, pero no se pinta encima del modelo.
	check("skin" in carla, "Npc.skin sigue existiendo (obsoleto)")
	var painted := carla.get_node("Visual/Model").find_children("*", "MeshInstance3D", true, false).filter(
		func(m): return m.material_override is StandardMaterial3D and m.material_override.albedo_texture == carla.skin)
	check(carla.skin == null or painted.is_empty(), "la skin obsoleta no se aplica al modelo")

	# --- Horario sin locations: quieta y sin errores ---
	check(brain.schedule.location_at(18 * 60) == "terraza", "18:00 terraza")
	check(brain.schedule.location_at(20 * 60 + 14) == "terraza" and brain.schedule.location_at(20 * 60 + 15) == "parque_fuente", "20:15 parque_fuente")
	check(brain.schedule.location_at(21 * 60 + 39) == "parque_fuente" and brain.schedule.location_at(21 * 60 + 40) == "casa_carla", "21:40 casa_carla")
	check(brain.schedule.date_lead_minutes == 20, "date_lead_minutes 20")
	# El mapa ya tiene terraza y casa_carla: se desregistran para simular que faltan.
	var real_markers := {}
	for id in ["terraza", "casa_carla"]:
		if locations.has(id):
			real_markers[id] = locations._locations[id]
			locations.unregister(id)
	var pos0: Vector3 = carla.global_position
	for t in [[18, 0], [21, 40]]:
		clock.set_time(t[0], t[1])
		await wait_frames(30)
		check(carla.global_position.distance_to(pos0) < 0.1, "%02d:%02d con el destino sin registrar Carla se queda quieta" % t)
	check(not locations.has("terraza") and not locations.has("casa_carla"), "terraza y casa_carla desregistradas")
	for id in real_markers:
		locations.register(id, real_markers[id])
	check(carla.is_on_floor(), "Carla sobre el suelo en (5,0,15)")

	# --- Diálogo propio y afinidad independiente ---
	clock.set_time(18, 0)
	await wait_frames(5)
	var lucia_before: int = rel.get_affinity("lucia")
	var carla_before: int = rel.get_affinity("carla")
	await talk_to(player, carla)
	check(ui.is_active(), "[E] abre el diálogo de Carla")
	var text: String = ui.get_node("%TextLabel").text
	# Sin contexto de cita, el start ignora {"context": "date"} y abre el saludo.
	check(_dialogue_texts(carla, ["saludo"]).has(text), "muestra el saludo de Carla: %s" % text)
	check(not _dialogue_texts(lucia, ["saludo"]).has(text), "no es el saludo de Lucía")
	var options: Node = ui.get_node("%OptionsBox")
	options.get_child(0).pressed.emit()
	check(rel.get_affinity("carla") != carla_before, "la afinidad de Carla cambia")
	check(rel.get_affinity("lucia") == lucia_before, "la de Lucía no cambia")
	while ui.is_active():
		var box: Node = ui.get_node("%OptionsBox")
		if box.get_child_count() == 0:
			break
		box.get_child(box.get_child_count() - 1).pressed.emit()
		await process_frame

	# --- Horario con locations temporales: terraza → fuente del parque a las 20:15 ---
	clock.set_time(18, 0)
	sched.clear()
	var terraza := add_temp_location("terraza", Vector3(5, 0, 15), 3.0)
	carla.global_position = Vector3(5, 0.1, 15)
	carla.velocity = Vector3.ZERO
	clock.set_time(18, 1)
	await wait_frames(5)
	check(brain.destination == "terraza", "18:01 destino terraza (%s)" % brain.destination)
	check(locations.is_at("terraza", carla.global_position), "Carla en la terraza")
	clock.set_time(20, 15)
	check(brain.destination == "parque_fuente", "20:15 destino parque_fuente (%s)" % brain.destination)
	check(locations.has("parque_fuente"), "la fuente del parque existe")
	await wait_until(func(): return Vector2(carla.velocity.x, carla.velocity.z).length() > 1.0)
	check(Vector2(carla.velocity.x, carla.velocity.z).length() > 1.0, "sale hacia el parque")
	terraza.queue_free()
	await wait_frames(2)
