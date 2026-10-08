extends "res://tests/test_base.gd"
## Mapa: locations registradas, navegación entre todas, suelo firme, NPC en el bar.

const IDS := ["bar", "calle", "casa_lucia", "parque", "terraza", "kiosko", "portal_a", "portal_b", "portal_c", "casa_carla"]
## Sitios que deben estar sobre suelo caminable (la casa de Lucía y el bar tienen su propia comprobación).
const WALKABLE := ["terraza", "kiosko", "portal_a", "portal_b", "portal_c", "casa_carla", "calle", "parque"]


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

	check(IDS.size() == 10, "hay 10 locations esperadas")
	for id: String in WALKABLE:
		var pos: Vector3 = locations.get_position(id)
		var near := NavigationServer3D.map_get_closest_point(nav_map, pos)
		# El navmesh queda ~0,5 m por encima del suelo (cell_height/agent_max_climb): se compara en XZ.
		var flat := Vector2(near.x - pos.x, near.z - pos.z).length()
		check(flat < 0.5, "%s sobre suelo caminable (a %.2f m del navmesh)" % [id, flat])

	# La terraza no bloquea el paso del bar a la calle: camino casi recto y sin tocar mesas.
	var bar_pos: Vector3 = locations.get_position("bar")
	var calle_pos: Vector3 = locations.get_position("calle")
	var door := Vector3(0, 0, 11)
	var out_path := NavigationServer3D.map_get_path(nav_map, bar_pos, calle_pos, true)
	var out_len := 0.0
	for k in range(1, out_path.size()):
		out_len += out_path[k - 1].distance_to(out_path[k])
	check(out_len < bar_pos.distance_to(calle_pos) * 1.1, "bar -> calle casi recto con la terraza (%.1f m)" % out_len)
	var door_near := NavigationServer3D.map_get_closest_point(nav_map, door)
	check(Vector2(door_near.x - door.x, door_near.z - door.z).length() < 0.3, "el paso frente a la puerta del bar está libre")

	# Encargos: hay uno corto y otro largo desde el kiosko.
	var kiosk: Vector3 = locations.get_position("kiosko")
	var dists: Array[float] = []
	for id: String in ["portal_a", "portal_b", "portal_c"]:
		dists.append(kiosk.distance_to(locations.get_position(id)))
	check(dists.min() < 12.0 and dists.max() > 30.0, "portales a distancias variadas del kiosko %s" % [dists])

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
