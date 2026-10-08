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
## Simula pulsar y soltar una action. Espera frames de proceso (no de física):
## la entrada se despacha por iteración del bucle principal, y bajo carga puede
## haber varios pasos de física en una misma iteración.
func press_action(action: String) -> void:
	for pressed in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		Input.parse_input_event(ev)
		for i in 2:
			await process_frame


## Espera (en physics frames) hasta que `condition` sea true. Devuelve si se cumplió.
## Úsalo en vez de un número fijo de frames cuando dependas de la física.
func wait_until(condition: Callable, max_frames := 120) -> bool:
	for i in max_frames:
		if condition.call():
			return true
		await physics_frame
	return condition.call()


## Interactor del jugador (lo crea player.gd en _ready).
func interactor_of(player: Node) -> Node:
	for child in player.get_children():
		if child.has_method("get_target"):
			return child
	return null


## Acerca al jugador a `target`, espera a que el Interactor lo detecte y pulsa E.
func talk_to(player: Node3D, target: Node3D, offset := Vector3(0, 0, 1.2)) -> void:
	player.global_position = target.global_position + offset
	var interactor := interactor_of(player)
	var ok := await wait_until(func(): return interactor != null and interactor.get_target() == target)
	check(ok, "el Interactor detecta a %s" % target.name)
	await press_action("interact")


## Registra en `Locations` un marcador temporal (para tests que necesitan un sitio
## que el mapa aún no tiene). Se desregistra al salir del árbol.
func add_temp_location(id: String, position: Vector3, radius := 3.0) -> Node3D:
	var marker: Node3D = load("res://scripts/world/location_marker.gd").new()
	marker.id = id
	marker.radius = radius
	marker.position = position
	root.add_child(marker)  # LocationMarker se registra solo en _ready
	return marker


func load_main() -> Node:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	return main
