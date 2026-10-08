extends "res://tests/test_base.gd"
## Hito 3, la noche: dos citas seguidas el mismo día. Parte de la cita con Lucía ya
## empezada en el parque (el camino hasta ahí lo cubre test_hito3_dia) y comprueba que,
## aguantándola entera, aún se llega a la de Carla en el bar y que ambas salen bien.


func run_test() -> void:
	var clock := autoload("GameClock")
	var rel := autoload("RelationshipState")
	var wallet := autoload("Wallet")
	var dates := autoload("DateScheduler")
	var locations := autoload("Locations")
	clock.time_scale = 0.0
	clock.set_time(20, 50)
	rel.set_affinity("lucia", 30)
	rel.set_affinity("carla", 30)
	wallet.earn(10)  # 30 €

	var main := await load_main()
	var player: Node3D = main.get_node("Player")
	var lucia: Node3D = main.get_node("Lucia")
	var carla: Node3D = main.get_node("Carla")
	var ui: Node = main.get_node("DialogueUI")
	var lucia_date: Dictionary = dates.schedule("lucia", "parque", 21 * 60)
	var carla_date: Dictionary = dates.schedule("carla", "bar", 22 * 60)
	lucia.global_position = locations.get_position("parque")
	carla.global_position = locations.get_position("parque_fuente")
	player.global_position = locations.get_position("parque") + Vector3(0, 0, -2)
	await wait_frames(10)

	# Cita con Lucía (puntual, en el centro): gratis y entera.
	await run_clock(15, 20, func(): return lucia_date.status == "in_progress")
	await wait_until(func(): return ui.is_active())
	check(press_option(ui, "paseo"), "Lucía: opción gratis")
	await finish_dialogue(ui)
	await run_clock(45, 20, func(): return lucia_date.status != "in_progress")
	check(lucia_date.status == "success", "Lucía: %s" % lucia_date.status)
	var lucia_end: int = clock.minutes_of_day

	# Corre al bar: ~94 m a 5 m/s ≈ 19 min de juego. Carla sale de la fuente a las 21:40.
	await run_clock(19, 60)
	player.global_position = locations.get_position("bar") + Vector3(0, 0, 3)
	var started := await run_clock(40, 60, func(): return carla_date.status == "in_progress")
	check(started, "la cita con Carla empieza (%s, estado %s)" % [clock.format_time(), carla_date.status])
	check(clock.minutes_of_day <= 22 * 60 + 30, "Carla llega dentro de la ventana (%s)" % clock.format_time())
	await wait_until(func(): return ui.is_active())
	check(press_option(ui, "ronda"), "Carla: invitar a una ronda (6 €)")
	check(wallet.money == 24, "la ronda cuesta 6 € (saldo %d)" % wallet.money)
	await finish_dialogue(ui)
	await run_clock(45, 20, func(): return carla_date.status != "in_progress")
	check(carla_date.status == "success", "Carla: %s" % carla_date.status)
	check(dates.get_dates().all(func(d): return d.status == "success"), "las dos citas salen bien")
	print("Lucía termina %02d:%02d · Carla %s · Lucía %d · Carla %d · %d €" % [lucia_end / 60, lucia_end % 60,
			clock.format_time(), rel.get_affinity("lucia"), rel.get_affinity("carla"), wallet.money])
