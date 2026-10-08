extends "res://tests/test_base.gd"
## Bucle completo del Hito 2, de principio a fin y sin atajos internos:
## hablar con [E] → proponer la cita en el diálogo → aviso en el móvil →
## Lucía deja el bar y camina sola al parque → el jugador llega → cita con éxito.
## El reloj avanza 1 min de juego por cada 60 physics frames (≈ time_scale 1).


func run_test() -> void:
	var clock := autoload("GameClock")
	var rel := autoload("RelationshipState")
	var phone := autoload("Phone")
	var dates := autoload("DateScheduler")
	clock.time_scale = 0.0
	clock.set_time(18, 0)
	rel.set_affinity("lucia", 25)  # "conocidos": ya sale la opción de quedar

	var main := await load_main()
	var player: Node3D = main.get_node("Player")
	var npc: Node3D = main.get_node("Lucia")
	var ui: Node = main.get_node("DialogueUI")
	var options: Node = main.get_node("DialogueUI/%OptionsBox")
	var locations := autoload("Locations")
	check(locations.is_at("bar", npc.global_position), "a las 18:00 Lucía está en el bar")

	# 1. Hablar y proponer la cita.
	await talk_to(player, npc)
	check(ui.is_active(), "E abre la conversación")
	check(_press_option(options, "Quedamos"), "el saludo de 'conocidos' ofrece quedar")
	while ui.is_active():
		options.get_child(0).pressed.emit()  # Continuar / Adiós
	var pending: Array = dates.get_pending()
	check(pending.size() == 1, "hay una cita pendiente")
	if pending.is_empty():
		return
	check(pending[0].location_id == "parque" and pending[0].minute == 21 * 60, "cita a las 21:00 en el parque")
	check(_last_title(phone) == "Cita con Lucía", "el móvil confirma la cita")

	# 2. Pasa la tarde: a las 20:15 sigue en el bar.
	clock.set_time(20, 15)
	await wait_frames(30)
	check(locations.is_at("bar", npc.global_position), "a las 20:15 Lucía sigue en el bar")

	# 3. El jugador va al parque; Lucía sale sola y el reloj corre hasta la cita.
	player.global_position = locations.get_position("parque") + Vector3(-2, 0, 0)
	var affinity_before: int = rel.get_affinity("lucia")
	var reminded := false
	var left_bar_at := -1
	var arrived_at := -1
	while clock.minutes_of_day < 21 * 60 + 30 and dates.get_pending().size() > 0:
		await wait_frames(60)
		clock.advance(1.0)
		if not reminded and phone.messages.back().body.begins_with("¿Sigue en pie"):
			reminded = true
			check(clock.minutes_of_day == 20 * 60 + 30, "recordatorio a las 20:30 (%s)" % clock.format_time())
		if left_bar_at < 0 and not locations.is_at("bar", npc.global_position):
			left_bar_at = clock.minutes_of_day
		if arrived_at < 0 and locations.is_at("parque", npc.global_position):
			arrived_at = clock.minutes_of_day
	check(reminded, "llega el recordatorio al móvil")
	check(left_bar_at > 0, "Lucía sale del bar por su cuenta")
	check(arrived_at > 0 and arrived_at <= 21 * 60, "Lucía llega al parque antes de las 21:00 (%d)" % arrived_at)

	# 4. Resolución.
	var date: Dictionary = dates.get_dates()[0]
	check(date.status == "success", "la cita sale bien (status %s)" % date.status)
	check(rel.get_affinity("lucia") == affinity_before + 15, "la cita sube la afinidad +15")
	check(phone.messages.back().body.begins_with("Me lo he pasado genial"), "mensaje de despedida en el móvil")
	check(npc.get_node("Brain").destination == "casa_lucia", "tras la cita vuelve a su horario (casa)")
	print("Lucía sale del bar a las %02d:%02d y llega al parque a las %02d:%02d" % [
			left_bar_at / 60, left_bar_at % 60, arrived_at / 60, arrived_at % 60])


func _press_option(options: Node, text: String) -> bool:
	for button in options.get_children():
		if text in button.text:
			button.pressed.emit()
			return true
	return false


func _last_title(phone: Node) -> String:
	return phone.messages.back().title if not phone.messages.is_empty() else ""
