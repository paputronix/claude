extends "res://tests/test_base.gd"
## Personajes anime: modelo por characters.json, AnimationPlayer con la librería compartida,
## altura real con colisión/etiqueta ajustadas, mira a −Z, y paso idle → walk/run → idle.

const ANIMS := ["idle", "walk", "run", "talk", "interact", "pickup", "sit_enter", "sit_idle", "sit_talk", "sit_exit", "dance"]


func run_test() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/characters.json"))
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
			for anim_name in ANIMS:
				check(anim.has_animation(anim_name), "%s: animación %s" % [scene.name, anim_name])
			check(anim.current_animation == "idle", "%s: arranca en idle" % scene.name)
			check(anim.get_animation("walk").loop_mode == Animation.LOOP_LINEAR, "%s: walk en bucle" % scene.name)
		var height := _height(model)
		check(height > 1.4 and height < 2.0, "%s: altura del modelo 1,4–2 m (es %.2f)" % [scene.name, height])
		var shape: CollisionShape3D = scene.get_node("CollisionShape3D")
		var capsule := shape.shape as CapsuleShape3D
		check(capsule != null and absf(capsule.height - clampf(height, 1.4, 1.9)) < 0.05,
			"%s: cápsula ajustada a la altura (%.2f)" % [scene.name, capsule.height if capsule else 0.0])
		check(absf(shape.position.y - capsule.height * 0.5) < 0.01, "%s: cápsula apoyada en el suelo" % scene.name)
		# El modelo mira a −Z: la cara (ojos) queda delante (z negativo) de la nuca.
		var skeleton: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
		var eye := (skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("LeftEye"))).origin
		var head := (skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("Head"))).origin
		check(eye.z < head.z, "%s: la cara mira a −Z" % scene.name)

	# Modelo elegido por characters.json.
	check(_model_file(player) == data.player, "el jugador usa %s (%s)" % [data.player, _model_file(player)])
	check(_model_file(npc) == data.get(npc.npc_id), "el NPC usa el modelo de su npc_id (%s)" % _model_file(npc))
	var label: Node3D = npc.get_node("NameLabel")
	check(label.position.y > _height(npc.get_node("Visual/Model")), "NameLabel por encima de la cabeza")
	var pivot: Node3D = player.get_node("CameraPivot")
	check(pivot.position.y > 1.2 and pivot.position.y < _height(player.get_node("Visual/Model")), "CameraPivot a la altura del modelo")

	var body: MeshInstance3D = npc.get_node_or_null("Visual/Body")
	check(body != null and body.mesh != null and body.mesh.material is StandardMaterial3D,
		"el NPC conserva Visual/Body con StandardMaterial3D (indicador de afinidad)")

	var player_anim := _anim_player(player.get_node("Visual/Model"))
	Input.action_press("move_forward")
	var ok := await wait_until(func(): return player_anim.current_animation == "walk")
	check(ok, "al arrancar el jugador pasa a walk")
	ok = await wait_until(func(): return player_anim.current_animation == "run")
	check(ok, "a toda velocidad pasa a run")
	Input.action_release("move_forward")
	ok = await wait_until(func(): return player_anim.current_animation == "idle")
	check(ok, "al parar vuelve a idle")
	var npc_anim := _anim_player(npc.get_node("Visual/Model"))
	check(npc_anim != null and npc_anim.current_animation == "idle", "el NPC sigue en idle")

	# Cuando el NPC anda (lo mueve el Brain con move_direction) pasa a walk y mira hacia donde va.
	npc.get_node("Brain").set_physics_process(false)
	npc.move_direction = Vector3.RIGHT
	ok = await wait_until(func(): return npc_anim.current_animation == "walk")
	check(ok, "el NPC andando pasa a walk")
	await wait_frames(30)
	var forward: Vector3 = -npc.get_node("Visual").global_basis.z
	check(forward.dot(Vector3.RIGHT) > 0.9, "el NPC mira hacia donde camina (%s)" % forward)
	npc.move_direction = Vector3.ZERO


func _anim_player(model: Node) -> AnimationPlayer:
	var players := model.find_children("*", "AnimationPlayer", true, false)
	return null if players.is_empty() else players[0]


func _model_file(scene: Node) -> String:
	var character: Node = scene.get_node("Visual/Model").get_child(0)
	return character.scene_file_path


func _height(model: Node3D) -> float:
	var box := AABB()
	var first := true
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var global_box: AABB = mesh.global_transform * mesh.get_aabb()
		box = global_box if first else box.merge(global_box)
		first = false
	return box.size.y
