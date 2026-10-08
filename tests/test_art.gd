extends "res://tests/test_base.gd"
## Personajes animados: escenas, AnimationPlayer con idle/run, altura y paso a run.


func run_test() -> void:
	var player: Node3D = load("res://scenes/player.tscn").instantiate()
	var npc: Node3D = load("res://scenes/npc.tscn").instantiate()
	check(player != null and npc != null, "player.tscn y npc.tscn instancian")
	root.add_child(player)
	npc.position = Vector3(5, 0, 0)
	root.add_child(npc)
	await wait_frames(2)

	for scene in [player, npc]:
		var model: Node3D = scene.get_node_or_null("Visual/Model")
		check(model != null, "%s tiene Visual/Model" % scene.name)
		if model == null:
			continue
		var anim := _anim_player(model)
		check(anim != null, "%s: Model tiene AnimationPlayer" % scene.name)
		if anim != null:
			check(anim.has_animation("idle") and anim.has_animation("run"), "%s: animaciones idle y run" % scene.name)
			check(anim.current_animation == "idle", "%s: arranca en idle" % scene.name)
		var height := _height(model)
		check(height > 1.5 and height < 2.0, "%s: altura del modelo ~1.8 m (es %.2f)" % [scene.name, height])

	var body: MeshInstance3D = npc.get_node_or_null("Visual/Body")
	check(body != null and body.mesh != null and body.mesh.material is StandardMaterial3D,
		"el NPC conserva Visual/Body con StandardMaterial3D (indicador de afinidad)")

	var player_anim := _anim_player(player.get_node("Visual/Model"))
	Input.action_press("move_forward")
	await wait_frames(20)
	check(player_anim != null and player_anim.current_animation == "run", "al moverse el jugador pasa a run")
	Input.action_release("move_forward")
	await wait_frames(40)
	check(player_anim != null and player_anim.current_animation == "idle", "al parar vuelve a idle")
	await wait_frames(20)
	var npc_anim := _anim_player(npc.get_node("Visual/Model"))
	check(npc_anim != null and npc_anim.current_animation == "idle", "el NPC sigue en idle")


func _anim_player(model: Node) -> AnimationPlayer:
	var players := model.find_children("*", "AnimationPlayer", true, false)
	return null if players.is_empty() else players[0]


func _height(model: Node3D) -> float:
	var box := AABB()
	var first := true
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var global_box: AABB = mesh.global_transform * mesh.get_aabb()
		box = global_box if first else box.merge(global_box)
		first = false
	return box.size.y
