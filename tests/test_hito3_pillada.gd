extends "res://tests/test_base.gd"
## Hito 3, la pillada depende de tus decisiones. Mismo punto de partida: llegas tarde
## (21:09) a la cita con Lucía en el parque y Carla, con cita contigo a las 22:00,
## cruza el parque a las 21:40.
## - En el centro del parque, te ve: pillada, −30 con las dos y su cita cancelada.
## - En el lado del banco (lejos de su camino), no te ve: la cita sale bien.


func run_test() -> void:
	var caught := await _scenario(Vector3(0, 0, 90))
	check(caught.lucia == "caught", "en el centro: pillada (Lucía %s)" % caught.lucia)
	check(caught.carla == "cancelled", "en el centro: la cita con Carla se cancela (%s)" % caught.carla)
	check(caught.lucia_delta == -30 and caught.carla_delta == -30, "−30 con las dos (%d, %d)" % [caught.lucia_delta, caught.carla_delta])
	check(not caught.dialogue_open, "no queda ningún diálogo abierto")

	var safe := await _scenario(Vector3(-4, 0, 92))
	check(safe.lucia == "success", "en el lado del banco: cita con éxito (%s)" % safe.lucia)
	check(safe.carla == "pending", "en el lado del banco: la cita con Carla sigue en pie (%s)" % safe.carla)


func _scenario(player_pos: Vector3) -> Dictionary:
	var clock := autoload("GameClock")
	var rel := autoload("RelationshipState")
	var dates := autoload("DateScheduler")
	var locations := autoload("Locations")
	dates.clear()
	clock.time_scale = 0.0
	clock.set_time(20, 55)  # las citas se crean antes de su hora (si no, serían para mañana)
	rel.set_affinity("lucia", 30)
	rel.set_affinity("carla", 30)

	var main := await load_main()
	var player: Node3D = main.get_node("Player")
	var lucia: Node3D = main.get_node("Lucia")
	var carla: Node3D = main.get_node("Carla")
	var ui: Node = main.get_node("DialogueUI")
	var lucia_date: Dictionary = dates.schedule("lucia", "parque", 21 * 60)
	var carla_date: Dictionary = dates.schedule("carla", "bar", 22 * 60)
	lucia.global_position = locations.get_position("parque")
	carla.global_position = locations.get_position("parque_fuente")
	player.global_position = Vector3(0, 0, 60)
	clock.set_time(21, 5)
	await wait_frames(10)
	check(lucia_date.day == clock.day and carla_date.day == clock.day, "las dos citas son para hoy")

	await run_clock(4, 20)  # 21:09: llega tarde
	player.global_position = player_pos
	await run_clock(5, 20, func(): return lucia_date.status == "in_progress")
	check(lucia_date.status == "in_progress", "la cita empieza al llegar (%s)" % clock.format_time())
	await wait_until(func(): return ui.is_active())
	press_option(ui, "paseo")
	await finish_dialogue(ui)
	var lucia_before: int = rel.get_affinity("lucia")
	var carla_before: int = rel.get_affinity("carla")
	await run_clock(24, 20, func(): return lucia_date.status != "in_progress")  # hasta ~21:35
	await run_clock(20, 60, func(): return lucia_date.status != "in_progress")  # Carla cruza a las 21:40
	var result := {"lucia": lucia_date.status, "carla": carla_date.status,
			"lucia_delta": rel.get_affinity("lucia") - lucia_before, "carla_delta": rel.get_affinity("carla") - carla_before,
			"dialogue_open": ui.is_active()}
	print("jugador en %s → Lucía %s, Carla %s a las %s" % [player_pos, result.lucia, result.carla, clock.format_time()])
	main.queue_free()
	await wait_frames(2)
	return result
