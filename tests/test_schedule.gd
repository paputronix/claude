extends "res://tests/test_base.gd"
## Horario del NPC: se queda, camina al siguiente sitio, acude a la cita y vuelve.
## Reloj determinista (time_scale = 0 + advance); 60 physics frames = 1 min de juego (x1).

var _resolved: Array = []
var _locations: Node
var _clock: Node


func _on_resolved(date: Dictionary, success: bool) -> void:
	_resolved.append([date.status, success])


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


func _place(node: Node3D, location: String) -> void:
	node.global_position = _locations.get_position(location)
	node.velocity = Vector3.ZERO


## Deja caminar hasta llegar a `location` o agotar `max_frames`. Si `tick_clock`,
## avanza 1 min de juego cada 60 frames. Devuelve los frames usados (-1 si no llega).
func _walk_until(npc: Node3D, location: String, max_frames: int, tick_clock := false) -> int:
	for i in max_frames:
		if _locations.is_at(location, npc.global_position):
			return i
		await physics_frame
		if tick_clock and i % 60 == 59:
			_clock.advance(1.0)
	return max_frames if _locations.is_at(location, npc.global_position) else -1


func run_test() -> void:
	var main := await load_main()
	_locations = autoload("Locations")
	_clock = autoload("GameClock")
	var sched := autoload("DateScheduler")
	var bus := autoload("EventBus")
	var player: Node3D = main.get_node("Player")
	var npc: Node3D = main.get_node("Lucia")
	var brain: Node = npc.get_node("Brain")
	bus.date_resolved.connect(_on_resolved)
	_clock.time_scale = 0.0
	_clock.paused = false
	_clock.day = 1
	sched.clear()
	_clock.set_time(18, 0)

	check(npc is CharacterBody3D, "el NPC es CharacterBody3D")
	check(npc.collision_layer == 1 and npc.collision_mask == 1, "NPC en capa 1 / máscara 1")
	check(npc.get_node_or_null("TalkArea") == null, "TalkArea eliminada")
	var nav_map: RID = main.get_world_3d().navigation_map
	for i in 30:
		if NavigationServer3D.map_get_iteration_id(nav_map) > 0:
			break
		await physics_frame
	check(NavigationServer3D.map_get_iteration_id(nav_map) > 0, "navegación sincronizada")

	# --- Horario: parser y wrap a medianoche ---
	var schedule: RefCounted = brain.schedule
	check(schedule.location_at(18 * 60) == "bar" and schedule.location_at(20 * 60 + 29) == "bar", "18:00-20:29 en el bar")
	check(schedule.location_at(20 * 60 + 30) == "casa_lucia" and schedule.location_at(23 * 60) == "casa_lucia", "desde 20:30 en casa")
	check(schedule.location_at(3 * 60) == "casa_lucia", "antes de la primera entrada vale la última")
	check(schedule.date_lead_minutes == 40, "date_lead_minutes del JSON")

	# --- 18:00: quieta en el bar ---
	await wait_frames(10)
	var p0: Vector3 = npc.global_position
	await wait_frames(60)
	check(brain.destination == "bar", "18:00 destino bar (%s)" % brain.destination)
	check(_locations.is_at("bar", npc.global_position), "Lucía en el bar")
	check(_flat(p0, npc.global_position) < 0.05, "no se mueve en el bar (%.2f m)" % _flat(p0, npc.global_position))
	check(npc.is_on_floor(), "Lucía sobre el suelo")

	# --- 20:30 sin cita: camina a casa ---
	_clock.set_time(20, 30)
	check(brain.destination == "casa_lucia", "20:30 destino casa_lucia (%s)" % brain.destination)
	await wait_frames(30)
	check(Vector2(npc.velocity.x, npc.velocity.z).length() > 2.0, "camina hacia casa")
	var anim: AnimationPlayer = npc.get_node("Visual/Model").find_children("*", "AnimationPlayer", true, false)[0]
	check(anim.current_animation == "run", "anima run al caminar (%s)" % anim.current_animation)
	var frames: int = await _walk_until(npc, "casa_lucia", 1500)
	check(frames >= 0, "llega a casa_lucia")
	await wait_frames(30)
	check(_locations.is_at("casa_lucia", npc.global_position), "se queda en casa_lucia")
	check(Vector2(npc.velocity.x, npc.velocity.z).length() < 0.01, "quieta al llegar")
	check(anim.current_animation == "idle", "idle al llegar (%s)" % anim.current_animation)

	# --- Cita 21:00 en el parque: sale a las 20:20 y llega antes de las 21:00 ---
	_place(npc, "bar")
	_clock.set_time(20, 0)
	await wait_frames(5)
	sched.schedule("lucia", "parque", 21 * 60)
	check(brain.destination == "bar", "20:00 con cita a las 21:00 sigue en el bar (%s)" % brain.destination)
	_clock.set_time(20, 19)
	check(brain.destination == "bar", "20:19 aún en el bar")
	_clock.advance(1.0)
	check(brain.destination == "parque", "20:20 la cita manda: destino parque (%s)" % brain.destination)
	frames = await _walk_until(npc, "parque", 60 * 45, true)
	check(frames >= 0, "llega al parque")
	check(_clock.minutes_of_day < 21 * 60, "llega antes de las 21:00 (%s)" % _clock.format_time())

	# --- Integración: jugador en el parque → a las 21:00 empieza; se queda toda la cita → éxito ---
	_place(player, "parque")
	_resolved.clear()
	while _clock.minutes_of_day < 21 * 60:
		await wait_frames(2)
		check(brain.destination == "parque" and _locations.is_at("parque", npc.global_position),
			"espera en el parque (%s)" % _clock.format_time())
		_clock.advance(1.0)
	check(sched.get_dates()[0].status == "in_progress", "a las 21:00 la cita empieza (%s)" % sched.get_dates()[0].status)
	var ui: Node = main.get_node("DialogueUI")
	var box: Node = ui.get_node("%OptionsBox")
	while ui.is_active() and box.get_child_count() > 0:
		box.get_child(box.get_child_count() - 1).pressed.emit()  # diálogo de cita: opción gratis
	var end: int = 21 * 60 + sched.DATE_DURATION_MINUTES
	while _clock.minutes_of_day < end:
		await wait_frames(2)
		check(brain.destination == "parque" and _locations.is_at("parque", npc.global_position),
			"se queda en el parque durante la cita (%s)" % _clock.format_time())
		_clock.advance(1.0)
	check(_resolved == [["success", true]], "la cita se resuelve con éxito: %s" % [_resolved])

	# --- Tras la cita vuelve a su horario ---
	check(brain.destination == "casa_lucia", "tras la cita destino casa_lucia (%s)" % brain.destination)
	await wait_frames(30)
	check(Vector2(npc.velocity.x, npc.velocity.z).length() > 2.0, "se va hacia casa")

	# --- Conversación: se detiene y reanuda ---
	bus.conversation_started.emit("lucia")
	await wait_frames(2)
	var p1: Vector3 = npc.global_position
	await wait_frames(60)
	check(_flat(p1, npc.global_position) < 0.01, "quieta durante la conversación (%.2f m)" % _flat(p1, npc.global_position))
	bus.conversation_ended.emit("lucia")
	await wait_frames(30)
	check(_flat(p1, npc.global_position) > 1.0, "reanuda al terminar la conversación")

	# --- x60: lejos del jugador se teletransporta a la cita; cerca, no ---
	sched.clear()
	_clock.paused = true  # time_scale alto sin que el reloj corra solo
	_clock.time_scale = 60.0
	_place(npc, "bar")
	_place(player, "bar")
	_clock.set_time(20, 40)
	sched.schedule("lucia", "parque", 21 * 60)
	await wait_frames(5)
	check(not _locations.is_at("parque", npc.global_position), "con el jugador cerca no salta")
	_place(npc, "bar")
	_place(player, "casa_lucia")
	await wait_frames(5)
	check(_locations.is_at("parque", npc.global_position), "lejos del jugador salta al parque a x60")

	sched.clear()
	_clock.paused = false
	_clock.time_scale = 1.0
