extends "res://tests/test_base.gd"
## Diálogo v2: entradas de start con contexto y opciones con coste.


func _make_npc(id: String, path: String) -> Node:
	var npc: Node = load("res://scenes/npc.tscn").instantiate()
	npc.npc_id = id
	npc.dialogue_path = path
	root.add_child(npc)
	return npc


func _buttons(ui: Node) -> Array:
	return ui.get_node("%OptionsBox").get_children()


func _text(ui: Node) -> String:
	return ui.get_node("%TextLabel").text


func _close(ui: Node, npc: Node) -> void:
	if ui.is_active():
		ui._end()
	await wait_frames(2)
	root.remove_child(npc)
	npc.free()


func run_test() -> void:
	var wallet := autoload("Wallet")
	var main := await load_main()
	var ui: Node = main.get_node("DialogueUI")
	var path := "res://data/dialogues/lucia.json"

	# Sin contexto: flujo normal.
	var npc := _make_npc("dv2_a", path)
	await wait_frames(1)
	ui.start(npc)
	check("Vienes mucho" in _text(ui), "sin contexto no entra en cita: '%s'" % _text(ui))
	await _close(ui, npc)

	# Con contexto "date": nodo cita.
	npc = _make_npc("dv2_b", path)
	await wait_frames(1)
	wallet.money = 20
	ui.start(npc, "date")
	check("Has venido" in _text(ui), "con contexto date entra en cita: '%s'" % _text(ui))
	var buttons := _buttons(ui)
	check(buttons.size() == 3, "cita tiene 3 opciones (%d)" % buttons.size())
	check("(8 €)" in buttons[0].text and "(15 €)" in buttons[1].text, "los costes se muestran")
	check(not buttons[0].disabled and not buttons[1].disabled, "con saldo no están deshabilitadas")
	await _close(ui, npc)

	# Sin saldo: deshabilitadas, la tecla no hace nada.
	npc = _make_npc("dv2_c", path)
	await wait_frames(1)
	wallet.money = 5
	ui.start(npc, "date")
	buttons = _buttons(ui)
	check(buttons[0].disabled and buttons[1].disabled and not buttons[2].disabled, "sin saldo solo la gratis está habilitada")
	await wait_frames(2)
	check(buttons[2].has_focus(), "el foco va a la primera opción habilitada")
	var ev := InputEventKey.new()
	ev.keycode = KEY_1
	ev.pressed = true
	ui._unhandled_input(ev)
	check(wallet.money == 5 and npc.affinity == 0 and "Has venido" in _text(ui), "tecla sobre opción deshabilitada no hace nada")
	await _close(ui, npc)

	# Con saldo: cobra y aplica afinidad.
	npc = _make_npc("dv2_d", path)
	await wait_frames(1)
	wallet.money = 20
	ui.start(npc, "date")
	_buttons(ui)[1].pressed.emit()
	check(wallet.money == 5, "cobra 15 € (%d)" % wallet.money)
	check(npc.affinity == 20, "aplica afinidad +20 (%d)" % npc.affinity)
	await _close(ui, npc)

	# Opción gratis: sin cobro.
	npc = _make_npc("dv2_e", path)
	await wait_frames(1)
	wallet.money = 20
	ui.start(npc, "date")
	_buttons(ui)[2].pressed.emit()
	check(wallet.money == 20 and npc.affinity == 5, "opción gratis no cobra")
	await _close(ui, npc)

	# Contexto sin entradas de contexto en el JSON: cae al flujo normal.
	var tmp := "user://dv2_tmp.json"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	f.store_string('{"start":[{"node":"hola"}],"nodes":{"hola":{"text":"Normal","options":[{"text":"Ok","next":null}]}}}')
	f.close()
	npc = _make_npc("dv2_f", tmp)
	await wait_frames(1)
	ui.start(npc, "date")
	check(_text(ui) == "Normal", "contexto sin entradas de contexto cae al flujo normal")
	await _close(ui, npc)

	wallet.money = wallet.STARTING_MONEY
	main.queue_free()
