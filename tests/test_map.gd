extends "res://tests/test_base.gd"
## Mapa: locations registradas, navegación entre todas, suelo firme, NPC en el bar.

const IDS := ["bar", "calle", "casa_lucia", "parque"]


func run_test() -> void:
	var main := await load_main()
	var locations := autoload("Locations")
	for id: String in IDS:
		check(locations.has(id), "location registrada: %s" % id)

	# El bake es síncrono en World._ready; el mapa se sincroniza en los siguientes frames.
	await wait_frames(3)
	var nav_map: RID = main.get_world_3d().navigation_map
	check(NavigationServer3D.map_get_iteration_id(nav_map) > 0, "el mapa de navegación está sincronizado")
	for i in IDS.size():
		for j in range(i + 1, IDS.size()):
			var a: Vector3 = locations.get_position(IDS[i])
			var b: Vector3 = locations.get_position(IDS[j])
			var path := NavigationServer3D.map_get_path(nav_map, a, b, true)
			var length := 0.0
			for k in range(1, path.size()):
				length += path[k - 1].distance_to(path[k])
			var ends_ok := path.size() >= 2 and path[-1].distance_to(b) < 1.0 and path[0].distance_to(a) < 1.0
			check(ends_ok, "camino %s -> %s llega a destino" % [IDS[i], IDS[j]])
			var straight := a.distance_to(b)
			check(length >= straight - 0.5 and length < straight * 1.6 + 10.0,
				"longitud razonable %s -> %s (%.1f m, recta %.1f m)" % [IDS[i], IDS[j], length, straight])

	# Bar -> parque andando a 5 m/s: entre 15 y 25 s.
	var walk := NavigationServer3D.map_get_path(nav_map, locations.get_position("bar"), locations.get_position("parque"), true)
	var walk_len := 0.0
	for k in range(1, walk.size()):
		walk_len += walk[k - 1].distance_to(walk[k])
	check(walk_len / 5.0 >= 15.0 and walk_len / 5.0 <= 25.0, "bar -> parque en 15-25 s (%.1f s)" % (walk_len / 5.0))

	var player: Node3D = main.get_node("Player")
	var npc: Node3D = main.get_node("Lucia")
	await wait_frames(30)
	check(player.is_on_floor(), "el jugador está sobre el suelo")
	check(absf(player.global_position.y) < 0.2, "el jugador no se hunde ni flota (y=%.2f)" % player.global_position.y)
	check(locations.is_at("bar", player.global_position), "el jugador aparece dentro del bar")
	check(locations.is_at("bar", npc.global_position), "Lucía está dentro del radio del bar")
