extends "res://tests/test_base.gd"
## Interacción con [E]: prompt, apertura de diálogo y bloqueo durante la conversación.


func _find_interactor(player: Node) -> Node:
	for child in player.get_children():
		if child.has_method("get_prompt"):
			return child
	return null


func run_test() -> void:
	var main := await load_main()
	var player: Node3D = main.get_node("Player")
	var npc: Node3D = main.get_node("Lucia")
	var ui: Node = main.get_node("DialogueUI")
	var interactor := _find_interactor(player)
	check(interactor != null, "el jugador tiene Interactor")
	if interactor == null:
		return
	var prompt: Node = interactor.get_prompt()
	check(npc.is_in_group("interactable"), "el NPC está en el grupo interactable")

	# Lejos: sin prompt y E no hace nada.
	player.global_position = npc.global_position + Vector3(0, 0, 8)
	await wait_frames(5)
	check(not prompt.is_showing(), "prompt oculto lejos del NPC")
	await press_action("interact")
	check(not ui.is_active(), "E lejos no abre la conversación")

	# Cerca sin pulsar: prompt visible, diálogo cerrado.
	player.global_position = npc.global_position + Vector3(0, 0, 1.2)
	await wait_until(func(): return prompt.is_showing())
	check(not ui.is_active(), "acercarse sin pulsar E no abre la conversación")
	check(prompt.is_showing(), "prompt visible cerca del NPC")
	check(prompt.get_text() == "[E] Hablar con Lucía", "texto del prompt (%s)" % prompt.get_text())

	# E abre; durante el diálogo no hay prompt ni interacción.
	await press_action("interact")
	check(ui.is_active(), "E cerca del NPC abre la conversación")
	check(not prompt.is_showing(), "sin prompt durante el diálogo")
	await press_action("interact")
	check(ui.is_active() and not player.controls_enabled, "E durante el diálogo no hace nada extra")

	# Al terminar, el prompt vuelve.
	var options: Node = ui.get_node("%OptionsBox")
	options.get_child(2).pressed.emit()
	options.get_child(0).pressed.emit()
	await wait_frames(3)
	check(not ui.is_active(), "la conversación termina")
	check(prompt.is_showing(), "el prompt vuelve tras el diálogo")
