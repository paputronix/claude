extends "res://tests/test_base.gd"
## Carla, segundo NPC: coexiste con Lucía, skin propia, diálogo y afinidad
## independientes, horario terraza → parque y robustez sin locations.

const CARLA_SKIN := "res://assets/characters/carla_skin.png"


func _skin_paths(npc: Node) -> Array:
	var paths: Array = []
	for mesh in npc.get_node("Visual/Model").find_children("*", "MeshInstance3D", true, false):
		var material := (mesh as MeshInstance3D).material_override as StandardMaterial3D
		paths.append(material.albedo_texture.resource_path if material != null and material.albedo_texture != null else "")
	return paths


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

	# --- Skins por instancia ---
	var carla_skins := _skin_paths(carla)
	var lucia_skins := _skin_paths(lucia)
	check(not carla_skins.is_empty() and carla_skins.all(func(p): return p == CARLA_SKIN), "mallas de Carla con carla_skin.png: %s" % [carla_skins])
	check(not lucia_skins.is_empty() and lucia_skins.all(func(p): return p.ends_with("skaterFemaleA.png")), "Lucía conserva su skin: %s" % [lucia_skins])

	# --- Horario sin locations: quieta y sin errores ---
	check(brain.schedule.location_at(18 * 60) == "terraza", "18:00 terraza")
	check(brain.schedule.location_at(20 * 60 + 44) == "terraza" and brain.schedule.location_at(20 * 60 + 45) == "parque", "20:45 parque")
	check(brain.schedule.location_at(21 * 60 + 20) == "casa_carla", "21:20 casa_carla")
	check(brain.schedule.date_lead_minutes == 40, "date_lead_minutes 40")
	var pos0: Vector3 = carla.global_position
	for t in [[18, 0], [21, 20]]:
		clock.set_time(t[0], t[1])
		await wait_frames(30)
		check(carla.global_position.distance_to(pos0) < 0.1, "%02d:%02d con el destino sin registrar Carla se queda quieta" % t)
	check(not locations.has("terraza") and not locations.has("casa_carla"), "terraza y casa_carla aún no existen")
	check(carla.is_on_floor(), "Carla sobre el suelo en (5,0,15)")

	# --- Diálogo propio y afinidad independiente ---
	clock.set_time(18, 0)
	await wait_frames(5)
	var lucia_before: int = rel.get_affinity("lucia")
	var carla_before: int = rel.get_affinity("carla")
	await talk_to(player, carla)
	check(ui.is_active(), "[E] abre el diálogo de Carla")
	var text: String = ui.get_node("%TextLabel").text
	# "cita" también vale: hasta que DialogueUI implemente "context" (dialogue-v2) la
	# condición {"context": "date"} del start se cumple siempre.
	check(_dialogue_texts(carla, ["saludo", "cita"]).has(text), "muestra el texto de Carla: %s" % text)
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

	# --- Horario con locations temporales: terraza → parque a las 20:45 ---
	clock.set_time(18, 0)
	sched.clear()
	var terraza := add_temp_location("terraza", Vector3(5, 0, 15), 3.0)
	carla.global_position = Vector3(5, 0.1, 15)
	carla.velocity = Vector3.ZERO
	clock.set_time(18, 1)
	await wait_frames(5)
	check(brain.destination == "terraza", "18:01 destino terraza (%s)" % brain.destination)
	check(locations.is_at("terraza", carla.global_position), "Carla en la terraza")
	clock.set_time(20, 45)
	check(brain.destination == "parque", "20:45 destino parque (%s)" % brain.destination)
	check(locations.has("parque"), "el parque real existe")
	await wait_until(func(): return Vector2(carla.velocity.x, carla.velocity.z).length() > 1.0)
	check(Vector2(carla.velocity.x, carla.velocity.z).length() > 1.0, "sale hacia el parque")
	terraza.queue_free()
	await wait_frames(2)
