extends "res://tests/test_base.gd"
## Citas v2: la cita se vive (in_progress + diálogo de cita + aguantar o cortar) y te
## pueden pillar (testigo interesado, cerca y con línea de visión).
## Reloj determinista (time_scale = 0 + advance). Los Brain de los NPCs se desactivan
## para colocarlos a mano; la pillada se comprueba con wait_until (física).

const CAUGHT_FRAMES := 60

var _started: Array = []
var _caught: Array = []
var _resolved: Array = []

var _clock: Node
var _sched: Node
var _rs: Node
var _phone: Node
var _locations: Node
var _ui: Node
var _player: Node3D
var _lucia: Node3D
var _carla: Node3D


func _on_started(date: Dictionary) -> void:
	_started.append(date.npc_id)


func _on_caught(date: Dictionary, witness_id: String) -> void:
	_caught.append([date.npc_id, witness_id])


func _on_resolved(date: Dictionary, success: bool) -> void:
	_resolved.append([date.npc_id, date.status, success])


func _place(node: Node3D, position: Vector3) -> void:
	node.global_position = position
	node.velocity = Vector3.ZERO


func _reset() -> void:
	_sched.clear()
	_started.clear()
	_caught.clear()
	_resolved.clear()
	_clock.day = 1
	_rs.set_affinity("lucia", 30)
	_rs.set_affinity("carla", 0)
	_place(_carla, _locations.get_position("casa_carla"))
	_place(_lucia, _locations.get_position("parque") + Vector3(1.5, 0, 0))
	_place(_player, _locations.get_position("parque"))


## Programa la cita a `minute` y avanza hasta ella con jugador y NPC en el sitio.
func _start_date(npc_id: String, location: String, minute: int) -> Dictionary:
	_clock.set_time(minute / 60, minute % 60 - 1)
	var date: Dictionary = _sched.schedule(npc_id, location, minute)
	_clock.advance(1.0)
	return date


## Texto del panel de diálogo.
func _text() -> String:
	return _ui.get_node("%TextLabel").text


func _press(text: String) -> bool:
	for button in _ui.get_node("%OptionsBox").get_children():
		if text in button.text:
			button.pressed.emit()
			return true
	return false


## Cierra la conversación eligiendo siempre la última opción.
func _finish_dialogue() -> void:
	var box: Node = _ui.get_node("%OptionsBox")
	while _ui.is_active() and box.get_child_count() > 0:
		box.get_child(box.get_child_count() - 1).pressed.emit()


func _bodies_since(count: int) -> Array:
	return _phone.messages.slice(count).map(func(m): return m.body)


func _status(date: Dictionary) -> String:
	return date.status


func run_test() -> void:
	var main := await load_main()
	_clock = autoload("GameClock")
	_sched = autoload("DateScheduler")
	_rs = autoload("RelationshipState")
	_phone = autoload("Phone")
	_locations = autoload("Locations")
	var bus := autoload("EventBus")
	_ui = main.get_node("DialogueUI")
	_player = main.get_node("Player")
	_lucia = main.get_node("Lucia")
	_carla = main.get_node("Carla")
	for npc: Node3D in [_lucia, _carla]:
		npc.get_node("Brain").set_physics_process(false)
		npc.move_direction = Vector3.ZERO
	bus.date_started.connect(_on_started)
	bus.caught.connect(_on_caught)
	bus.date_resolved.connect(_on_resolved)
	_clock.time_scale = 0.0
	_clock.paused = false
	await wait_frames(5)
	var duration: int = _sched.DATE_DURATION_MINUTES
	var lucia_cita: String = _lucia.load_dialogue().nodes.cita.text
	var carla_cita: String = _carla.load_dialogue().nodes.cita.text

	# --- 1. Cita → en curso → diálogo de cita → aguantar → éxito ---
	_reset()
	var date := _start_date("lucia", "parque", 21 * 60)
	check(date.status == "in_progress", "coincidir en el sitio: en curso (%s)" % date.status)
	check(_started == ["lucia"], "date_started emitida: %s" % [_started])
	check(_resolved.is_empty(), "aún sin resolver: %s" % [_resolved])
	check(_ui.is_active(), "se abre sola la conversación de cita")
	check(_text() == lucia_cita, "texto del nodo cita: %s" % _text())
	check(_press("paseo"), "opción gratis del paseo")
	check(_press("Continuar"), "reacción → continuar")
	check(_press("media sube"), "cita_final")
	check(_press("Adiós"), "cierra")
	check(not _ui.is_active(), "conversación cerrada")
	check(_rs.get_affinity("lucia") == 40, "lo elegido se aplica (+5 +5 = %d)" % _rs.get_affinity("lucia"))
	check(date.status == "in_progress", "tras el diálogo la cita sigue en curso")
	check(_sched.get_pending().size() == 1 and _sched.get_in_progress().size() == 1, "cuenta como sin resolver y en curso")
	await wait_frames(10)
	_clock.advance(float(duration - 1))
	check(date.status == "in_progress", "minuto %d: sigue en curso" % (duration - 1))
	var msgs: int = _phone.messages.size()
	_clock.advance(1.0)
	check(date.status == "success", "aguantar → success (%s)" % date.status)
	check(_rs.get_affinity("lucia") == 55, "éxito: +15 sobre lo elegido (%d)" % _rs.get_affinity("lucia"))
	check(_resolved == [["lucia", "success", true]], "date_resolved(true): %s" % [_resolved])
	check(_bodies_since(msgs) == [_sched.TEXT_SUCCESS], "mensaje cariñoso: %s" % [_bodies_since(msgs)])

	# --- 2. Cortar la cita: irse antes de tiempo ---
	_reset()
	date = _start_date("lucia", "parque", 21 * 60)
	_finish_dialogue()
	var after: int = _rs.get_affinity("lucia")
	# En curso no se puede quedar otra vez con ella.
	bus.dialogue_action.emit("lucia", {"schedule_date": {"location": "parque", "time": "23:00"}})
	check(_sched.get_dates().size() == 1, "en curso no se crea otra cita con el mismo NPC")
	_clock.advance(10.0)
	# Dentro de radio * 2 del sitio aún vale.
	var radius: float = _locations.get_radius("parque")
	_place(_player, _locations.get_position("parque") + Vector3(radius * 2.0 - 0.5, 0, 0))
	_clock.advance(1.0)
	check(date.status == "in_progress", "a menos de radio*2 sigue en curso")
	msgs = _phone.messages.size()
	_place(_player, _locations.get_position("bar"))
	_clock.advance(1.0)
	check(date.status == "cut_short", "irse antes → cut_short (%s)" % date.status)
	check(_rs.get_affinity("lucia") == after - 5, "cortar: -5 y sin +15 (%d)" % _rs.get_affinity("lucia"))
	check(_resolved == [["lucia", "cut_short", false]], "date_resolved(false): %s" % [_resolved])
	check(_bodies_since(msgs).size() == 1 and "Ya te vas" in _bodies_since(msgs)[0], "mensaje de cortar: %s" % [_bodies_since(msgs)])

	# --- 3. Pillada durante la conversación: testigo con cita esta noche, a 8 m y a la vista ---
	_reset()
	_clock.set_time(20, 0)
	var carla_date: Dictionary = _sched.schedule("carla", "bar", 22 * 60)
	date = _start_date("lucia", "parque", 21 * 60)
	check(_ui.is_active() and _text() == lucia_cita, "diálogo de cita abierto")
	msgs = _phone.messages.size()
	_place(_carla, _player.global_position + Vector3(0, 0, -8))
	var ok := await wait_until(func(): return not _caught.is_empty(), CAUGHT_FRAMES)
	check(ok, "Carla a 8 m y a la vista te pilla")
	check(_caught == [["lucia", "carla"]], "caught(cita, testigo): %s" % [_caught])
	check(date.status == "caught", "la cita termina pillada (%s)" % date.status)
	check(carla_date.status == "cancelled", "la cita del testigo se cancela (%s)" % carla_date.status)
	check(_rs.get_affinity("lucia") == 0, "-30 con Lucía (%d)" % _rs.get_affinity("lucia"))
	check(_rs.get_affinity("carla") == -30, "-30 con Carla (%d)" % _rs.get_affinity("carla"))
	check(not _ui.is_active(), "la conversación de cita se cierra")
	check(_clock.is_running(), "el reloj se reanuda")
	var bodies := _bodies_since(msgs)
	check(bodies.size() == 3 and "En serio" in bodies[0] and "Carla" in bodies[0], "mensaje de la cita: %s" % [bodies])
	check(bodies.size() == 3 and "Lucía" in bodies[1], "mensaje del testigo: %s" % [bodies])
	check(bodies.size() == 3 and bodies[2] == _sched.TEXT_CANCELLED, "cancelación: %s" % [bodies])
	check(_resolved == [["lucia", "caught", false], ["carla", "cancelled", false]], "resueltas: %s" % [_resolved])
	await wait_frames(20)
	check(_caught.size() == 1, "una sola pillada por cita")

	# --- 4. Testigo a 8 m pero detrás de un obstáculo: nada; sin obstáculo: pillada ---
	_reset()
	_rs.set_affinity("carla", 25)  # interesada por afinidad, sin cita
	date = _start_date("lucia", "parque", 21 * 60)
	_finish_dialogue()
	var wall := StaticBody3D.new()  # capa 1 (mundo) por defecto
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 4, 0.5)
	shape.shape = box
	wall.add_child(shape)
	main.add_child(wall)
	wall.global_position = _player.global_position + Vector3(0, 1.5, -4)
	_place(_carla, _player.global_position + Vector3(0, 0, -8))
	await wait_frames(30)
	check(_caught.is_empty() and date.status == "in_progress", "sin línea de visión no hay pillada (%s)" % date.status)
	wall.queue_free()
	ok = await wait_until(func(): return not _caught.is_empty(), CAUGHT_FRAMES)
	check(ok and date.status == "caught", "al quitar el obstáculo, pillada (%s)" % date.status)

	# --- 5. Testigo no interesado (sin cita y afinidad < 20): nada ---
	_reset()
	_rs.set_affinity("carla", 10)
	date = _start_date("lucia", "parque", 21 * 60)
	_finish_dialogue()
	_place(_carla, _player.global_position + Vector3(0, 0, -8))
	await wait_frames(30)
	check(_caught.is_empty(), "testigo no interesado no pilla")
	_clock.advance(float(duration))
	check(date.status == "success", "la cita acaba bien (%s)" % date.status)
	check(_rs.get_affinity("carla") == 10, "Carla no cambia (%d)" % _rs.get_affinity("carla"))
	# Un plantón suyo tampoco la hace interesada.
	_reset()
	_rs.set_affinity("carla", 10)
	_clock.set_time(19, 0)
	var stood: Dictionary = _sched.schedule("carla", "terraza", 19 * 60 + 30)
	_clock.advance(60.0)  # fin de la ventana de llegada (19:30 + 30)
	check(stood.status == "stood_up", "plantón a Carla (%s)" % stood.status)
	_place(_player, _locations.get_position("parque"))
	date = _start_date("lucia", "parque", 21 * 60)
	_finish_dialogue()
	_place(_carla, _player.global_position + Vector3(0, 0, -8))
	await wait_frames(30)
	check(_caught.is_empty() and date.status == "in_progress", "con cita en stood_up no está interesada")

	# --- 6. Dos citas el mismo día sin cruzarse: ambas success ---
	_reset()
	_rs.set_affinity("carla", 30)
	_place(_carla, _locations.get_position("bar") + Vector3(1.5, 0, 0))
	_clock.set_time(20, 0)
	var date_carla: Dictionary = _sched.schedule("carla", "bar", 22 * 60)
	date = _start_date("lucia", "parque", 21 * 60)
	_finish_dialogue()
	await wait_frames(20)
	_clock.advance(float(duration))
	check(date.status == "success", "Lucía: success (%s)" % date.status)
	# Del parque al bar corriendo (~94 m a 5 m/s ≈ 19 min de juego).
	_place(_lucia, _locations.get_position("casa_lucia"))
	_place(_player, _locations.get_position("bar"))
	_clock.advance(float(22 * 60 - _clock.minutes_of_day))
	check(date_carla.status == "in_progress", "Carla: en curso a las 22:00 (%s)" % date_carla.status)
	check(_ui.is_active() and _text() == carla_cita, "diálogo de cita de Carla: %s" % _text())
	_finish_dialogue()
	await wait_frames(20)
	_clock.advance(float(duration))
	check(date_carla.status == "success", "Carla: success (%s)" % date_carla.status)
	check(_caught.is_empty(), "nadie os ha pillado")
	check(_resolved == [["lucia", "success", true], ["carla", "success", true]], "ambas con éxito: %s" % [_resolved])

	# --- 7. Si ya hay otra conversación, el diálogo de cita espera a que acabe ---
	_reset()
	_place(_carla, _locations.get_position("parque") + Vector3(-1.5, 0, 0))
	_clock.set_time(20, 59)
	date = _sched.schedule("lucia", "parque", 21 * 60)
	_ui.start(_carla)
	check(_ui.is_active() and _text() != lucia_cita, "hablando con Carla")
	_clock.set_time(21, 0)  # set_time emite el minuto aunque la conversación pause el reloj
	check(date.status == "in_progress", "la cita empieza (%s)" % date.status)
	check(_text() != lucia_cita, "no interrumpe la conversación en curso")
	_finish_dialogue()
	await process_frame
	check(_ui.is_active() and _text() == lucia_cita, "al terminar se abre el diálogo de cita")
	_finish_dialogue()

	_sched.clear()
	_clock.time_scale = 1.0
