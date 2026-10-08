extends "res://tests/test_base.gd"
## Peatones de ambiente: fuera de la lógica del juego, se mueven, andan animados y son variados.


func run_test() -> void:
	var main := await load_main()
	var ok := await wait_until(func(): return get_nodes_in_group("pedestrians").size() == 5, 300)
	check(ok, "hay 5 peatones en el grupo pedestrians")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/characters.json"))
	var peds := get_nodes_in_group("pedestrians")
	var start := {}
	var models := {}
	for ped in peds:
		check(not ped.is_in_group("npcs"), "%s no está en npcs" % ped.name)
		check(not ped.is_in_group("interactable"), "%s no está en interactable" % ped.name)
		check(ped.collision_layer == 0, "%s sin capa de colisión" % ped.name)
		start[ped] = ped.global_position
		var model: Node = ped.get_node("Visual/Model")
		var file: String = model.get_child(0).scene_file_path if model.get_child_count() > 0 else ""
		check(file != "" and file == ped.model_path, "%s instancia su modelo %s (%s)" % [ped.name, ped.model_path, file])
		check(model.find_children("*", "AnimationPlayer", true, false).size() == 1, "%s tiene AnimationPlayer" % ped.name)
		models[file] = true
	check(models.size() >= 3, "al menos 3 modelos distintos (hay %d)" % models.size())
	var reserved := [data.player, data.lucia, data.carla]
	for path in models:
		check(not reserved.has(path), "modelo de peatón distinto de jugador/Lucía/Carla: %s" % path)
		check(data.pedestrians.has(path), "modelo de peatón de la lista de characters.json: %s" % path)

	var moved := await wait_until(func():
		for ped in peds:
			if ped.global_position.distance_to(start[ped]) > 3.0:
				return true
		return false, 900)
	check(moved, "algún peatón avanza más de 3 m")
	var walking := await wait_until(func():
		for ped in peds:
			var anim: AnimationPlayer = ped.get_node("Visual/Model").find_children("*", "AnimationPlayer", true, false)[0]
			if anim.current_animation == "walk":
				return true
		return false, 300)
	check(walking, "algún peatón camina con la animación walk")
	var below := false
	for ped in peds:
		if ped.global_position.y < -2.0:
			below = true
	check(not below, "ningún peatón cae del mundo")
	main.queue_free()
