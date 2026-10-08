extends "res://tests/test_base.gd"
## Animador de personajes: talk en conversación (NPC y jugador), acciones sueltas,
## parpadeo, boca al hablar y expresión al cambiar la afinidad. Peatones sin cara.


func run_test() -> void:
	var bus := autoload("EventBus")
	var rel := autoload("RelationshipState")
	var player: Node3D = load("res://scenes/player.tscn").instantiate()
	var npc: Node3D = load("res://scenes/npc.tscn").instantiate()
	var ped: Node3D = load("res://scenes/pedestrian.tscn").instantiate()
	root.add_child(player)
	npc.position = Vector3(0, 0, -2)
	root.add_child(npc)
	ped.position = Vector3(4, 0, 0)
	root.add_child(ped)
	npc.get_node("Brain").set_physics_process(false)
	ped.set_physics_process(false)
	await wait_frames(3)

	var npc_model: Node = npc.get_node("Visual/Model")
	var player_model: Node = player.get_node("Visual/Model")
	var npc_anim: AnimationPlayer = npc_model.get_animation_player()
	var player_anim: AnimationPlayer = player_model.get_animation_player()
	var face: Node = npc_model.face
	check(face != null and player_model.face != null, "protagonistas con controlador de cara")
	check(ped.get_node("Visual/Model").face == null, "peatón sin expresiones (no tiene morphs)")
	if face == null:
		return
	for key in ["joy", "angry", "blink", "mouth"]:
		check(face.has_morph(key), "morph %s encontrado por sufijo" % key)

	# --- Conversación: el NPC aludido y el jugador hablan; otro NPC no ---
	bus.conversation_started.emit("carla")
	await wait_frames(5)
	check(npc_anim.current_animation == "idle", "conversación con otro NPC: Lucía sigue en idle")
	bus.conversation_ended.emit("carla")
	bus.conversation_started.emit(npc.npc_id)
	var ok := await wait_until(func(): return npc_anim.current_animation == "talk")
	check(ok, "en conversación el NPC pasa a talk")
	check(player_anim.current_animation == "talk", "el jugador también habla")
	ok = await wait_until(func(): return face.get_morph("mouth") > 0.2, 240)
	check(ok, "la boca se abre mientras habla")
	bus.conversation_ended.emit(npc.npc_id)
	ok = await wait_until(func(): return npc_anim.current_animation == "idle" and player_anim.current_animation == "idle")
	check(ok, "al acabar la conversación vuelven a idle")
	ok = await wait_until(func(): return face.get_morph("mouth") < 0.01)
	check(ok, "la boca se cierra al dejar de hablar")

	# --- Parpadeo: forzado y espontáneo (cada 2–6 s) ---
	face.blink()
	ok = await wait_until(func(): return face.get_morph("blink") > 0.5, 30)
	check(ok, "blink() cierra los ojos")
	ok = await wait_until(func(): return face.get_morph("blink") == 0.0, 30)
	check(ok, "y los vuelve a abrir")
	ok = await wait_until(func(): return face.get_morph("blink") > 0.0, 420)
	check(ok, "parpadea solo en menos de 7 s")

	# --- Afinidad: alegría si sube, enfado si baja ---
	var before: int = rel.get_affinity(npc.npc_id)
	npc.change_affinity(5)
	check(face.get_expression() == "joy", "sube la afinidad → alegría")
	ok = await wait_until(func(): return face.get_morph("joy") > 0.9)
	check(ok, "el morph de alegría se aplica")
	npc.change_affinity(-5)
	check(face.get_expression() == "angry", "baja la afinidad → enfado")
	check(face.get_morph("joy") == 0.0, "la alegría se quita al cambiar de expresión")
	ok = await wait_until(func(): return face.get_expression() == "" and face.get_morph("angry") == 0.0, 240)
	check(ok, "la expresión se desvanece sola (~1,5 s)")
	check(rel.get_affinity(npc.npc_id) == before, "afinidad restaurada")

	# --- Acción suelta ---
	player_model.play_action("pickup")
	check(player_anim.current_animation == "pickup", "play_action reproduce pickup")
	ok = await wait_until(func(): return player_anim.current_animation == "idle", 180)
	check(ok, "tras la acción vuelve a idle")
