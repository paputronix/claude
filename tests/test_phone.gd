extends "res://tests/test_base.gd"
## Móvil: mensajes, toast con cola, sonido, panel abrir/cerrar, no leídos.


func run_test() -> void:
	var phone := autoload("Phone")
	phone.toast_duration = 0.2
	var got: Array = []
	phone.notified.connect(func(t, b): got.append([t, b]))

	check(not phone.is_open() and phone.unread_count() == 0, "estado inicial cerrado y sin no leídos")
	autoload("GameClock").set_time(10, 30)
	phone.notify("Lucía", "¿Quedamos a las 21:00?")
	check(phone.messages.size() == 1 and phone.messages[0]["title"] == "Lucía", "notify guarda mensaje")
	check(phone.messages[0]["time"] == "10:30", "mensaje con hora")
	check(got.size() == 1 and got[0][1] == "¿Quedamos a las 21:00?", "notify emite señal")
	check(phone.unread_count() == 1, "no leídos sube")
	var toast: Control = phone.get_node("Root/Toast")
	var badge: Control = phone.get_node("Root/Badge")
	check(toast.visible, "toast visible tras notify")
	check(badge.visible, "badge visible con no leídos")

	phone.notify("Marta", "Hola")
	phone.notify("Sara", "Buenas")
	check(phone.pending_toasts() == 2, "avisos encolados")
	check(phone.unread_count() == 3, "3 no leídos")
	await create_timer(1.0).timeout
	check(phone.pending_toasts() <= 1, "la cola avanza")
	await create_timer(2.5).timeout
	check(phone.pending_toasts() == 0 and not toast.visible, "cola vaciada y toast oculto")

	# Panel: tecla Tab simulada
	var ev := InputEventAction.new()
	ev.action = "phone"
	ev.pressed = true
	Input.parse_input_event(ev)
	await wait_frames(2)
	check(phone.is_open(), "acción phone abre el panel")
	check(phone.unread_count() == 0 and not badge.visible, "abrir resetea no leídos y oculta badge")
	var list: Control = phone.get_node("Root/Panel").find_child("List", true, false)
	check(list.get_child_count() == 3, "lista refleja los mensajes")
	check(list.get_child(0).find_child("Title", true, false).text == "Sara", "más reciente primero")
	phone.notify("Eva", "Nuevo")
	await wait_frames(1)
	check(list.get_child_count() == 4 and phone.unread_count() == 0, "notify con panel abierto actualiza lista")
	phone.toggle()
	check(not phone.is_open(), "toggle cierra")
	phone.toggle()
	check(phone.is_open(), "toggle abre")
	phone.close()
	check(not phone.is_open(), "close cierra")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "no cambia el modo del ratón")
