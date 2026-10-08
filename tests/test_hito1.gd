extends "res://tests/test_base.gd"
## Bucle del Hito 1: moverse, acercarse al NPC, conversar, cambiar afinidad.
## La conversación se dispara con [E] (Interactor).


func run_test() -> void:
	var main := await load_main()
	var player: Node3D = main.get_node("Player")
	var npc: Node3D = main.get_node("Lucia")
	var ui: Node = main.get_node("DialogueUI")

	var z0: float = player.global_position.z
	Input.action_press("move_forward")
	await wait_frames(30)
	Input.action_release("move_forward")
	check(player.global_position.z < z0 - 0.5, "el jugador avanza con move_forward")

	player.global_position = npc.global_position + Vector3(0, 0, 1.2)
	var interactor := interactor_of(player)
	await wait_until(func(): return interactor.get_target() == npc)
	check(not ui.is_active(), "acercarse sin pulsar E no abre la conversación")
	await press_action("interact")
	check(ui.is_active(), "pulsar E cerca del NPC abre la conversación")
	check(not player.controls_enabled, "controles congelados en conversación")

	var options: Node = ui.get_node("%OptionsBox")
	check(options.get_child_count() == 3, "el saludo ofrece 3 opciones")
	var before: int = npc.affinity
	options.get_child(1).pressed.emit()  # +15
	options.get_child(0).pressed.emit()  # Continuar
	options.get_child(0).pressed.emit()  # +10
	options.get_child(0).pressed.emit()  # Adiós
	check(npc.affinity == before + 25, "afinidad +25 tras dos buenas respuestas (es %d)" % npc.affinity)
	check(not ui.is_active() and player.controls_enabled, "la conversación termina y devuelve el control")
