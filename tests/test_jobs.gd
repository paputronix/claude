extends "res://tests/test_base.gd"
## Encargos de reparto: oferta, recogida, entrega a tiempo/tarde y caducidades.

const TEMP_JOBS := "user://test_jobs.json"

var _offered: Array = []
var _completed: Array = []


func _on_offered(job: Dictionary) -> void:
	_offered.append(job.id)


func _on_completed(job: Dictionary, on_time: bool, pay: int) -> void:
	_completed.append([job.id, on_time, pay])


## Nodo del grupo interactable (paquete o punto de entrega) de un encargo, o null.
func _node_of(job_id: String, prefix: String) -> Node3D:
	for n in root.get_tree().get_nodes_in_group("interactable"):
		if n.name == prefix + job_id and not n.is_queued_for_deletion():
			return n
	return null


func _status(board: Node, job_id: String) -> String:
	return board.get_status(job_id)


func _last(phone: Node) -> Dictionary:
	return phone.messages[-1] if not phone.messages.is_empty() else {}


func _write_jobs(offers: Array) -> void:
	var file := FileAccess.open(TEMP_JOBS, FileAccess.WRITE)
	file.store_string(JSON.stringify({"offers": offers}))
	file.close()


func run_test() -> void:
	var main := await load_main()
	await wait_frames(5)
	var clock := autoload("GameClock")
	var board := autoload("JobBoard")
	var wallet := autoload("Wallet")
	var phone := autoload("Phone")
	var bus := autoload("EventBus")
	var player: Node3D = main.get_node("Player")
	clock.time_scale = 0.0
	clock.paused = false
	bus.job_offered.connect(_on_offered)
	bus.job_completed.connect(_on_completed)
	add_temp_location("kiosko", Vector3(0, 0, 30))
	add_temp_location("kiosko2", Vector3(10, 0, 30))
	add_temp_location("portal_b", Vector3(-20, 0, 30))
	add_temp_location("portal_c", Vector3(20, 0, 30))
	board.clear()
	clock.day = 1
	var money0: int = wallet.money
	var expected := 0

	# --- Oferta a su hora (18:10, kiosko -> portal B, antes de 19:00, 12 €) ---
	clock.set_time(18, 9)
	check(board.get_active().is_empty(), "sin encargos antes de la hora")
	var msgs: int = phone.messages.size()
	clock.advance(1.0)
	check(_offered == ["kiosko_b_d1"], "job_offered emitida: %s" % [_offered])
	check(board.get_active().size() == 1 and board.get_active()[0].status == "offered", "un encargo ofertado")
	var job: Dictionary = board.get_active()[0]
	check(job.pickup == "kiosko" and job.dropoff == "portal_b" and job.deadline == 19 * 60
		and job.pay == 12 and job.day == 1, "datos del encargo: %s" % [job])
	check(phone.messages.size() == msgs + 1 and _last(phone).title == "Encargo", "mensaje al móvil")
	check(_last(phone).body == "Recoge en el kiosko y llévalo al portal B antes de 19:00 · 12 €",
		"texto de la oferta: %s" % _last(phone).body)
	var parcel := _node_of("kiosko_b_d1", "Parcel_")
	check(parcel != null, "aparece el paquete")
	if parcel == null:
		return
	check(parcel.global_position.is_equal_approx(Vector3(0, 0, 30)), "paquete en el kiosko")
	check(parcel.get_interaction_prompt() == "Recoger paquete", "prompt del paquete")
	check(_node_of("kiosko_b_d1", "Dropoff_") == null, "aún sin punto de entrega")

	# No se duplica la oferta en minutos posteriores.
	clock.advance(5.0)
	check(board.get_jobs().size() == 1, "una sola oferta")

	# --- Recoger con [E] ---
	await talk_to(player, parcel)
	check(_status(board, "kiosko_b_d1") == "picked_up", "recogido: %s" % _status(board, "kiosko_b_d1"))
	check(board.get_carried().get("id", "") == "kiosko_b_d1", "get_carried devuelve el encargo")
	await wait_frames(2)
	check(_node_of("kiosko_b_d1", "Parcel_") == null, "el paquete desaparece")
	var drop := _node_of("kiosko_b_d1", "Dropoff_")
	check(drop != null, "aparece el punto de entrega")
	if drop == null:
		return
	check(drop.global_position.is_equal_approx(Vector3(-20, 0, 30)), "entrega en portal B")
	check(drop.get_interaction_prompt() == "Entregar paquete", "prompt de entrega")

	# --- Entrega a tiempo (19:00 exacto) ---
	clock.set_time(19, 0)
	msgs = phone.messages.size()
	await talk_to(player, drop)
	check(_status(board, "kiosko_b_d1") == "delivered", "entregado a tiempo: %s" % _status(board, "kiosko_b_d1"))
	expected += 12
	check(wallet.money == money0 + expected, "cobra 12 € (%d)" % wallet.money)
	check(_completed == [["kiosko_b_d1", true, 12]], "job_completed a tiempo: %s" % [_completed])
	check(phone.messages.size() == msgs + 1 and _last(phone).title == "Encargo entregado"
		and _last(phone).body == "+12 €", "mensaje de entrega: %s" % [_last(phone)])
	check(board.get_carried().is_empty() and board.get_active().is_empty(), "nada en curso")
	await wait_frames(2)
	check(_node_of("kiosko_b_d1", "Dropoff_") == null, "desaparece el punto de entrega")

	# --- Entrega tarde (oferta de las 19:30, deadline 20:15, entrega a las 20:16) ---
	clock.set_time(19, 29)
	clock.advance(1.0)
	check(_offered.has("kiosko_c_d1"), "segunda oferta a las 19:30")
	parcel = _node_of("kiosko_c_d1", "Parcel_")
	check(parcel != null, "paquete de la segunda oferta")
	if parcel == null:
		return
	await talk_to(player, parcel)
	check(_status(board, "kiosko_c_d1") == "picked_up", "segundo recogido")
	await wait_frames(2)
	drop = _node_of("kiosko_c_d1", "Dropoff_")
	check(drop != null, "punto de entrega al portal C")
	if drop == null:
		return
	clock.set_time(20, 15)
	clock.advance(1.0)
	check(_status(board, "kiosko_c_d1") == "picked_up", "sigue vivo tras el deadline")
	msgs = phone.messages.size()
	await talk_to(player, drop)
	check(_status(board, "kiosko_c_d1") == "late", "entregado tarde: %s" % _status(board, "kiosko_c_d1"))
	expected += 7
	check(wallet.money == money0 + expected, "tarde paga la mitad redondeada abajo (%d)" % wallet.money)
	check(_completed[-1] == ["kiosko_c_d1", false, 7], "job_completed tarde: %s" % [_completed[-1]])
	check(_last(phone).body == "Con retraso, +7 €", "mensaje tarde: %s" % _last(phone).body)

	# --- Un solo paquete a la vez + caducidades (ofertas propias solapadas) ---
	_write_jobs([
		{"id": "x", "offer_at": "10:00", "pickup": "kiosko", "dropoff": "portal_b", "deadline": "10:30", "pay": 10},
		{"id": "y", "offer_at": "10:00", "pickup": "kiosko2", "dropoff": "portal_c", "deadline": "10:20", "pay": 10},
	])
	board.clear()
	board.load_jobs(TEMP_JOBS)
	clock.day = 2
	clock.set_time(9, 59)
	clock.advance(1.0)
	check(board.get_active().size() == 2, "dos ofertas el día 2 (%d)" % board.get_active().size())
	var px := _node_of("x_d2", "Parcel_")
	var py := _node_of("y_d2", "Parcel_")
	check(px != null and py != null, "dos paquetes")
	if px == null or py == null:
		return
	await talk_to(player, px)
	check(_status(board, "x_d2") == "picked_up", "recoge el primero")
	check(not py.can_interact(), "no se puede recoger un segundo paquete")
	check(not board.pick_up("y_d2") and _status(board, "y_d2") == "offered", "pick_up rechazado llevando otro")
	player.global_position = py.global_position + Vector3(0, 0, 1.2)
	await wait_frames(10)
	await press_action("interact")
	check(_status(board, "y_d2") == "offered", "[E] no recoge el segundo")

	# La oferta no recogida caduca al pasar el deadline (10:20).
	clock.set_time(10, 20)
	clock.advance(0.0)
	check(_status(board, "y_d2") == "offered", "en el deadline aún vale")
	msgs = phone.messages.size()
	clock.advance(1.0)
	check(_status(board, "y_d2") == "expired", "oferta caducada: %s" % _status(board, "y_d2"))
	check(phone.messages.size() == msgs + 1 and _last(phone).title == "Encargo cancelado", "mensaje de cancelación")
	await wait_frames(2)
	check(_node_of("y_d2", "Parcel_") == null, "se borra el paquete caducado")
	check(_status(board, "x_d2") == "picked_up", "el recogido sigue")

	# El recogido caduca a deadline + 60 (11:30), sin pago.
	drop = _node_of("x_d2", "Dropoff_")
	check(drop != null, "punto de entrega de x")
	clock.set_time(11, 29)
	clock.advance(1.0)
	check(_status(board, "x_d2") == "picked_up", "11:30 aún se puede entregar")
	clock.advance(1.0)
	check(_status(board, "x_d2") == "expired", "entrega caducada: %s" % _status(board, "x_d2"))
	check(board.get_carried().is_empty(), "ya no llevas nada")
	await wait_frames(2)
	check(_node_of("x_d2", "Dropoff_") == null, "se borra el punto de entrega")
	check(wallet.money == money0 + expected, "sin pago por caducar (%d)" % wallet.money)
	check(_completed.size() == 2, "sin job_completed por caducidad")

	# --- Location ausente: warning, sin error, y se crea cuando aparece ---
	_write_jobs([{"id": "z", "offer_at": "08:00", "pickup": "fantasma", "dropoff": "portal_b", "deadline": "09:00", "pay": 5}])
	board.clear()
	board.load_jobs(TEMP_JOBS)
	clock.day = 3
	clock.set_time(7, 59)
	clock.advance(1.0)
	check(_status(board, "z_d3") == "offered" and _node_of("z_d3", "Parcel_") == null, "oferta sin paquete aún")
	clock.advance(1.0)
	add_temp_location("fantasma", Vector3(5, 0, 30))
	clock.advance(1.0)
	check(_node_of("z_d3", "Parcel_") != null, "el paquete aparece al registrarse el sitio")

	board.clear()
	board.load_jobs("res://data/jobs.json")
	check(wallet.money == money0 + expected, "el saldo final cuadra (%d)" % wallet.money)
