extends "res://tests/test_base.gd"
## Peatones de ambiente: fuera de la lógica del juego, se mueven y son variados.


func run_test() -> void:
	var main := await load_main()
	var ok := await wait_until(func(): return get_nodes_in_group("pedestrians").size() == 5, 300)
	check(ok, "hay 5 peatones en el grupo pedestrians")
	var peds := get_nodes_in_group("pedestrians")
	var start := {}
	var skins := {}
	for ped in peds:
		check(not ped.is_in_group("npcs"), "%s no está en npcs" % ped.name)
		check(not ped.is_in_group("interactable"), "%s no está en interactable" % ped.name)
		check(ped.collision_layer == 0, "%s sin capa de colisión" % ped.name)
		start[ped] = ped.global_position
		skins[ped.skin.resource_path] = true
	check(skins.size() >= 3, "al menos 3 skins distintas (hay %d)" % skins.size())
	var reserved := [
		"res://assets/characters/skaterMaleA.png",
		"res://assets/characters/skaterFemaleA.png",
		"res://assets/characters/carla_skin.png",
	]
	for path in skins:
		check(not reserved.has(path), "skin de peatón distinta de jugador/Lucía/Carla: %s" % path)

	var moved := await wait_until(func():
		for ped in peds:
			if ped.global_position.distance_to(start[ped]) > 3.0:
				return true
		return false, 900)
	check(moved, "algún peatón avanza más de 3 m")
	var below := false
	for ped in peds:
		if ped.global_position.y < -2.0:
			below = true
	check(not below, "ningún peatón cae del mundo")
	main.queue_free()
