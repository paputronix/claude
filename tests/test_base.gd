extends SceneTree
## Base para tests headless. Cada test: `extends "res://tests/test_base.gd"`
## e implementa `func run_test() -> void` (puede usar await).
## Ojo: los autoloads no son identificadores globales al compilar un script -s;
## accede a ellos con `autoload("GameClock")`.
## Por lo mismo, NO uses tipos class_name del juego (Player, Npc, DialogueUI...) en
## los tests: arrastran la compilación de scripts que usan autoloads y falla.
## Usa Node/Node3D y acceso dinámico.

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await run_test()
	if _failures > 0:
		print("FAIL: %d comprobaciones fallidas" % _failures)
	quit(1 if _failures > 0 else 0)


func run_test() -> void:
	pass


func check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: ", message)


func autoload(name: String) -> Node:
	return root.get_node("/root/" + name)


func wait_frames(count: int) -> void:
	for i in count:
		await physics_frame


## Simula pulsar y soltar una action (p. ej. "interact") y espera un par de frames.
func press_action(action: String) -> void:
	for pressed in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await wait_frames(2)


func load_main() -> Node:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	return main
