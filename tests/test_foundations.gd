extends "res://tests/test_base.gd"
## Contratos de la Ola 0: autoloads registrados y APIs básicas.


func run_test() -> void:
	for name in ["EventBus", "GameClock", "RelationshipState", "Locations", "DateScheduler", "Phone", "ClockHud"]:
		check(root.has_node("/root/" + name), "autoload %s registrado" % name)
	for action in ["interact", "phone", "move_forward"]:
		check(InputMap.has_action(action), "input action %s" % action)

	var clock := autoload("GameClock")
	clock.set_time(21, 5)
	check(clock.format_time() == "21:05", "GameClock.format_time")
	check(clock.parse_time("21:00") == 1260 and clock.parse_time("x") == -1, "GameClock.parse_time")

	var rel := autoload("RelationshipState")
	rel.change_affinity("test", 150)
	check(rel.get_affinity("test") == 100, "RelationshipState clampa a 100")

	var locations := autoload("Locations")
	var marker := Node3D.new()
	root.add_child(marker)
	marker.global_position = Vector3(10, 0, 0)
	locations.register("sitio", marker)
	check(locations.is_at("sitio", Vector3(11, 5, 1)), "Locations.is_at dentro del radio")
	check(not locations.is_at("sitio", Vector3(20, 0, 0)), "Locations.is_at fuera del radio")

	var bus := autoload("EventBus")
	var log: Array = []
	bus.date_scheduled.connect(func(d): log.append(d))
	autoload("DateScheduler").schedule("lucia", "sitio", 1260)
	check(log.size() == 1 and autoload("DateScheduler").get_pending().size() == 1, "DateScheduler.schedule emite y queda pendiente")

	var phone := autoload("Phone")
	phone.notify("Lucía", "¿Sigue en pie lo de esta noche?")
	check(phone.messages.size() == 1 and phone.messages[0].time == "21:05", "Phone.notify guarda mensaje con hora")

	# DialogueUI publica en EventBus
	var events: Array = []
	bus.conversation_started.connect(func(id): events.append("start:" + id))
	bus.conversation_ended.connect(func(id): events.append("end:" + id))
	var main := await load_main()
	var player: Node3D = main.get_node("Player")
	var npc: Node3D = main.get_node("Lucia")
	player.global_position = npc.global_position + Vector3(0, 0, 1.2)
	await wait_frames(5)
	await press_action("interact")
	var options: Node = main.get_node("DialogueUI/%OptionsBox")
	options.get_child(2).pressed.emit()  # respuesta borde, termina
	options.get_child(0).pressed.emit()  # Adiós
	check(events == ["start:lucia", "end:lucia"], "EventBus.conversation_started/ended (%s)" % [events])
