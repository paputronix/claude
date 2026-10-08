extends "res://tests/test_base.gd"
## Quedadas: creación desde el diálogo, avisos, ventana de llegada y resolución.

var _resolved: Array = []


func _on_resolved(date: Dictionary, success: bool) -> void:
	_resolved.append([date.status, success])


## Abre el diálogo con Lucía y pulsa la opción de quedar; luego cierra la conversación.
func _propose(ui: Node, npc: Node) -> void:
	ui.start(npc)
	var buttons: Array = ui.get_node("%OptionsBox").get_children()
	var chosen: Button = null
	for b: Button in buttons:
		if "Quedamos" in b.text:
			chosen = b
	check(chosen != null, "el diálogo ofrece la opción de quedar")
	if chosen == null:
		return
	chosen.pressed.emit()
	# Reacción -> botón "Adiós" que cierra la conversación (y reanuda el reloj).
	(ui.get_node("%OptionsBox").get_child(0) as Button).pressed.emit()


func _last_body(phone: Node) -> String:
	return phone.messages[-1]["body"] if not phone.messages.is_empty() else ""


func _move(node: Node3D, location: String) -> void:
	node.global_position = autoload("Locations").get_position(location)


func run_test() -> void:
	var main := await load_main()
	await wait_frames(5)
	var clock := autoload("GameClock")
	var sched := autoload("DateScheduler")
	var phone := autoload("Phone")
	var rs := autoload("RelationshipState")
	var bus := autoload("EventBus")
	var player: Node3D = main.get_node("Player")
	var npc: Node3D = main.get_node("Lucia")
	var ui: Node = main.get_node("DialogueUI")
	clock.time_scale = 0.0
	clock.paused = false
	bus.date_resolved.connect(_on_resolved)

	# --- Crear cita desde el diálogo ---
	sched.clear()
	clock.day = 1
	clock.set_time(18, 0)
	rs.set_affinity("lucia", 25)
	var msgs_before: int = phone.messages.size()
	_propose(ui, npc)
	var pending: Array = sched.get_pending()
	check(pending.size() == 1, "una cita pendiente (%d)" % pending.size())
	if pending.size() == 1:
		check(pending[0].location_id == "parque" and pending[0].minute == 21 * 60, "cita 21:00 en parque")
		check(pending[0].day == 1, "la cita es hoy")
	check(phone.messages.size() == msgs_before + 1, "llega un mensaje al móvil")
	check(phone.messages[-1]["title"] == "Cita con Lucía" and "21:00" in _last_body(phone) and "parque" in _last_body(phone),
		"mensaje de cita: %s" % [phone.messages[-1]])
	check(clock.is_running(), "el reloj se reanuda al acabar la conversación")

	# --- No duplica ---
	_propose(ui, npc)
	check(sched.get_pending().size() == 1, "segunda propuesta no duplica")
	check(sched.get_dates().size() == 1, "get_dates cuenta una")

	# --- Aviso a las 20:30 ---
	clock.set_time(20, 29)
	var count: int = phone.messages.size()
	clock.advance(1.0)
	check(phone.messages.size() == count + 1 and "21:00" in _last_body(phone) and phone.messages[-1]["title"] == "Lucía",
		"aviso a las 20:30: %s" % [phone.messages[-1]])
	count = phone.messages.size()
	clock.advance(29.0)
	check(phone.messages.size() == count, "sin mensajes extra antes de la hora")
	clock.advance(1.0)
	check(phone.messages.size() == count + 1 and "llegando" in _last_body(phone), "aviso a las 21:00")
	check(sched.get_pending().size() == 1, "sigue pendiente sin nadie en el sitio")

	# --- Éxito ---
	_move(player, "bar")
	_move(npc, "bar")
	sched.clear()
	_resolved.clear()
	clock.set_time(20, 59)
	rs.set_affinity("lucia", 30)
	sched.schedule("lucia", "parque", 21 * 60)
	clock.advance(5.0)  # 21:04, nadie en el sitio
	check(sched.get_pending().size() == 1, "dentro de la ventana sigue pendiente")
	_move(player, "parque")
	_move(npc, "parque")
	clock.advance(1.0)
	check(sched.get_dates()[0].status == "success", "éxito: %s" % sched.get_dates()[0].status)
	check(rs.get_affinity("lucia") == 45, "éxito: +15 (%d)" % rs.get_affinity("lucia"))
	check(_resolved == [["success", true]], "date_resolved(true): %s" % [_resolved])
	check(sched.get_pending().is_empty(), "ya no está pendiente")

	# --- Plantón ---
	_move(player, "bar")
	_move(npc, "bar")
	sched.clear()
	_resolved.clear()
	clock.set_time(20, 59)
	rs.set_affinity("lucia", 30)
	sched.schedule("lucia", "parque", 21 * 60)
	clock.advance(30.0)  # 21:29
	check(sched.get_pending().size() == 1, "21:29 aún en ventana")
	clock.advance(1.0)  # 21:30
	check(sched.get_dates()[0].status == "stood_up", "plantón: %s" % sched.get_dates()[0].status)
	check(rs.get_affinity("lucia") == 5, "plantón: -25 (%d)" % rs.get_affinity("lucia"))
	check(_resolved == [["stood_up", false]], "date_resolved(false): %s" % [_resolved])
	check("esperando" in _last_body(phone), "mensaje de plantón")

	# --- NPC no aparece ---
	sched.clear()
	_resolved.clear()
	clock.set_time(20, 59)
	rs.set_affinity("lucia", 30)
	sched.schedule("lucia", "parque", 21 * 60)
	_move(player, "parque")
	clock.advance(31.0)
	check(sched.get_dates()[0].status == "npc_no_show", "npc_no_show: %s" % sched.get_dates()[0].status)
	check(rs.get_affinity("lucia") == 30, "npc_no_show no cambia afinidad (%d)" % rs.get_affinity("lucia"))
	check(_resolved == [["npc_no_show", false]], "date_resolved(false) en no_show: %s" % [_resolved])

	# --- Hora ya pasada: mañana ---
	sched.clear()
	_move(player, "bar")
	clock.day = 1
	clock.set_time(22, 0)
	var late: Dictionary = sched.schedule("lucia", "parque", 21 * 60)
	check(late.day == 2, "cita pasada queda para mañana (día %d)" % late.day)
	clock.advance(1379.0)  # hasta las 20:59 del día 2
	check(clock.day == 2 and clock.minutes_of_day == 21 * 60 - 1, "reloj en día 2, 20:59")
	check(sched.get_pending().size() == 1, "no se resuelve antes de tiempo")
	clock.advance(1.0)
	check(_last_body(phone).contains("llegando"), "mañana a las 21:00 llega el aviso")

	# --- Sin jugador ni NPC en el árbol: no crashea ---
	sched.clear()
	main.remove_child(player)
	main.remove_child(npc)
	clock.set_time(20, 59)
	sched.schedule("lucia", "parque", 21 * 60)
	clock.advance(31.0)
	check(sched.get_dates()[0].status == "stood_up", "sin nodos se trata como ausentes")
	main.add_child(player)
	main.add_child(npc)
	sched.clear()
	clock.time_scale = 1.0
