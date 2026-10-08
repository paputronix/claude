extends "res://tests/test_base.gd"
## Afinidad persistente en RelationshipState y diálogo condicional.

var _actions: Array = []


func _on_action(npc_id: String, action: Dictionary) -> void:
	_actions.append([npc_id, action])


func _make_npc(id: String, start := 0) -> Node:
	var npc: Node = load("res://scenes/npc.tscn").instantiate()
	npc.npc_id = id
	npc.starting_affinity = start
	root.add_child(npc)
	return npc


func _options(ui: Node) -> Array:
	var out := []
	for b in ui.get_node("%OptionsBox").get_children():
		out.append((b as Button).text)
	return out


func run_test() -> void:
	var rs := autoload("RelationshipState")

	# Persistencia y starting_affinity.
	var npc := _make_npc("test_a", 10)
	await wait_frames(1)
	check(npc.affinity == 10, "starting_affinity se aplica si no hay valor (%d)" % npc.affinity)
	npc.change_affinity(15)
	check(rs.get_affinity("test_a") == 25, "la afinidad vive en RelationshipState")
	root.remove_child(npc)
	npc.free()
	var npc2 := _make_npc("test_a", 99)
	await wait_frames(1)
	check(npc2.affinity == 25, "la afinidad persiste y starting_affinity no la pisa (%d)" % npc2.affinity)
	var got := []
	npc2.affinity_changed.connect(func(v, d): got.append([v, d]))
	rs.change_affinity("otro", 5)
	npc2.change_affinity(-5)
	check(got == [[20, -5]], "señal del NPC filtrada por npc_id: %s" % str(got))
	root.remove_child(npc2)
	npc2.free()

	# Start condicional y opciones condicionadas.
	var main := await load_main()
	var ui: Node = main.get_node("DialogueUI")
	autoload("EventBus").dialogue_action.connect(_on_action)
	var cases := {0: "Vienes mucho", 25: "otra vez tú", 60: "favorita", -30: "Hoy no tengo"}
	for aff in cases:
		var n := _make_npc("lucia_t%d" % aff)
		n.dialogue_path = "res://data/dialogues/lucia.json"
		rs.set_affinity(n.npc_id, aff)
		ui.start(n)
		var text: String = ui.get_node("%TextLabel").text
		check(cases[aff] in text, "afinidad %d -> nodo correcto ('%s')" % [aff, text])
		var has_date := _options(ui).any(func(o): return "21:00" in o)
		check(has_date == (aff >= 20), "opción de quedar visible solo con afinidad>=20 (aff %d)" % aff)
		if aff == 25:
			(ui.get_node("%OptionsBox").get_child(1) as Button).pressed.emit()
			var expected := {"schedule_date": {"location": "parque", "time": "21:00"}}
			check(_actions.size() == 1 and _actions[0][0] == n.npc_id and _actions[0][1] == expected, "dialogue_action con schedule_date: %s" % str(_actions))
		ui._end()
		await wait_frames(2)
		root.remove_child(n)
		n.free()
