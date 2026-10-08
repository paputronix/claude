extends "res://tests/test_base.gd"
## Hito 3, primera mitad del día sin atajos de lógica: encargo de reparto → cobro →
## quedar con Lucía y con Carla → cita con Lucía pagando la invitación, sin pillada.
## Solo se teletransporta al jugador (sustituye a caminar). Reloj ≈ time_scale 1.


func run_test() -> void:
	var clock := autoload("GameClock")
	var rel := autoload("RelationshipState")
	var wallet := autoload("Wallet")
	var jobs := autoload("JobBoard")
	var dates := autoload("DateScheduler")
	var locations := autoload("Locations")
	var phone := autoload("Phone")
	clock.time_scale = 0.0
	clock.set_time(18, 0)
	rel.set_affinity("lucia", 25)
	rel.set_affinity("carla", 25)
	check(wallet.money == 20, "se empieza con 20 €")

	var main := await load_main()
	var player: Node3D = main.get_node("Player")
	var lucia: Node3D = main.get_node("Lucia")
	var carla: Node3D = main.get_node("Carla")
	var ui: Node = main.get_node("DialogueUI")
	await wait_frames(10)

	# 1. Encargo: llega la oferta, se recoge en el kiosko y se entrega en el portal B.
	await run_clock(10, 2)
	var active: Array = jobs.get_active()
	check(active.size() == 1 and active[0].pickup == "kiosko" and active[0].dropoff == "portal_b", "oferta de las 18:10")
	if active.is_empty():
		return
	var job_id: String = active[0].id
	check(phone.messages.back().title == "Encargo", "la oferta llega al móvil")
	var parcel: Node3D = root.find_child("Parcel_" + job_id, true, false)
	check(parcel != null and locations.is_at("kiosko", parcel.global_position), "el paquete está en el kiosko")
	await talk_to(player, parcel, Vector3(1.0, 0, 0))
	check(jobs.get_status(job_id) == "picked_up", "paquete recogido con [E]")
	await wait_frames(2)
	var dropoff: Node3D = root.find_child("Dropoff_" + job_id, true, false)
	check(dropoff != null and locations.is_at("portal_b", dropoff.global_position), "punto de entrega en el portal B")
	await run_clock(15, 2)  # el paseo hasta el portal B
	await talk_to(player, dropoff, Vector3(-1.0, 0, 0))
	check(jobs.get_status(job_id) == "delivered", "entregado a tiempo")
	check(wallet.money == 32, "cobro de 12 € (saldo %d)" % wallet.money)

	# 2. Quedar con las dos.
	await talk_to(player, lucia)
	check(press_option(ui, "21:00 en el parque"), "Lucía ofrece quedar a las 21:00")
	await finish_dialogue(ui)
	await talk_to(player, carla)
	check(press_option(ui, "22:00 en el bar"), "Carla ofrece quedar a las 22:00")
	await finish_dialogue(ui)
	check(dates.get_pending().size() == 2, "dos citas pendientes")

	# 3. La tarde: Lucía va al parque sola; Carla a la fuente. El jugador llega puntual al centro.
	clock.set_time(20, 15)
	player.global_position = Vector3(0, 0, 60)
	var lucia_date: Dictionary = dates.get_pending().filter(func(d): return d.npc_id == "lucia")[0]
	var carla_date: Dictionary = dates.get_pending().filter(func(d): return d.npc_id == "carla")[0]
	await run_clock(40, 60)  # 20:55
	player.global_position = locations.get_position("parque") + Vector3(0, 0, -2)
	var started := await run_clock(30, 60, func(): return lucia_date.status == "in_progress")
	check(started and clock.minutes_of_day <= 21 * 60 + 1, "la cita con Lucía empieza puntual (%s)" % clock.format_time())
	check(locations.is_at("parque_fuente", carla.global_position), "Carla está en la fuente")

	# 4. Diálogo de cita: invitar a un helado.
	await wait_until(func(): return ui.is_active())
	check(ui.is_active(), "se abre el diálogo de cita")
	var affinity_before: int = rel.get_affinity("lucia")
	check(press_option(ui, "helado"), "opción de invitar a un helado (8 €)")
	check(wallet.money == 24, "la invitación cuesta 8 € (saldo %d)" % wallet.money)
	await finish_dialogue(ui)

	# 5. Aguantar la cita: éxito y sin pillada (Carla queda a ~15 m).
	await run_clock(45, 30, func(): return lucia_date.status != "in_progress")
	check(lucia_date.status == "success", "cita con Lucía: %s" % lucia_date.status)
	check(rel.get_affinity("lucia") >= affinity_before + 25, "afinidad: invitación + éxito")
	check(carla_date.status == "pending", "la cita con Carla sigue en pie")
	print("Lucía %d · Carla %d · %d € · %s" % [rel.get_affinity("lucia"), rel.get_affinity("carla"), wallet.money, clock.format_time()])
