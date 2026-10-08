class_name DialogueUI
extends CanvasLayer
## Panel de conversación. Lee el JSON del NPC, pinta opciones y aplica
## los cambios de afinidad. No sabe nada del jugador: avisa por señales.
##
## Formato del JSON:
## { "start": "id", "nodes": { "id": { "text": "...", "options": [
##     { "text": "...", "affinity": 10, "reaction": "...", "next": "id" | null } ] } } }
##
## "start" puede ser un id o un array de condiciones evaluadas en orden (gana la
## primera que cumpla; sin min/max cumple siempre):
##   "start": [ {"min_affinity": 50, "node": "amigos"},
##              {"max_affinity": -20, "node": "enfadada"}, {"node": "saludo"} ]
## Las opciones admiten "min_affinity"/"max_affinity": si no se cumplen, se ocultan.
## Una opción puede llevar "action": {...}, que se emite en EventBus.dialogue_action.

signal conversation_started(npc: Npc)
signal conversation_ended(npc: Npc)

var _npc: Npc
var _nodes: Dictionary = {}

@onready var _panel: Control = $Panel
@onready var _name_label: Label = %NameLabel
@onready var _affinity_label: Label = %AffinityLabel
@onready var _text_label: Label = %TextLabel
@onready var _options_box: VBoxContainer = %OptionsBox


func _ready() -> void:
	_panel.hide()


func is_active() -> bool:
	return _npc != null


func start(npc: Npc) -> void:
	if is_active():
		return
	var data := npc.load_dialogue()
	if data.is_empty():
		return

	_npc = npc
	_nodes = data.get("nodes", {})
	_npc.affinity_changed.connect(_on_affinity_changed)
	_name_label.text = npc.npc_name
	_set_affinity_text(npc.affinity, 0)
	_panel.show()
	conversation_started.emit(npc)
	EventBus.conversation_started.emit(npc.npc_id)
	_show_node(_resolve_start(data.get("start", "")))


## Devuelve el id del nodo inicial según la afinidad actual.
func _resolve_start(start) -> Variant:
	if not start is Array:
		return start
	for entry in start:
		if entry is Dictionary and _meets_affinity(entry):
			return entry.get("node")
	return null


func _meets_affinity(entry: Dictionary) -> bool:
	var value := _npc.affinity
	return value >= int(entry.get("min_affinity", -999)) and value <= int(entry.get("max_affinity", 999))


func _show_node(node_id) -> void:
	if node_id == null or not _nodes.has(node_id):
		_end()
		return

	var node: Dictionary = _nodes[node_id]
	_text_label.text = node.get("text", "")
	_clear_options()

	var options: Array = node.get("options", [])
	var visible_options := options.filter(_meets_affinity)
	if visible_options.is_empty():
		_add_option("Adiós", _end)
	for option in visible_options:
		_add_option(option.get("text", "..."), _choose.bind(option))


func _choose(option: Dictionary) -> void:
	if option.get("action") is Dictionary:
		EventBus.dialogue_action.emit(_npc.npc_id, option.action)

	var delta := int(option.get("affinity", 0))
	if delta != 0:
		_npc.change_affinity(delta)

	var next = option.get("next")
	var reaction: String = option.get("reaction", "")
	if reaction.is_empty():
		_show_node(next)
		return

	_text_label.text = reaction
	_clear_options()
	_add_option("Continuar" if next != null else "Adiós", _show_node.bind(next))


func _end() -> void:
	var npc := _npc
	_npc.affinity_changed.disconnect(_on_affinity_changed)
	_npc = null
	_nodes = {}
	_clear_options()
	_panel.hide()
	conversation_ended.emit(npc)
	EventBus.conversation_ended.emit(npc.npc_id)


func _add_option(text: String, callback: Callable) -> void:
	var index := _options_box.get_child_count() + 1
	var button := Button.new()
	button.text = "%d. %s" % [index, text]
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(callback)
	_options_box.add_child(button)
	if index == 1:
		_focus_first_option.call_deferred()


func _focus_first_option() -> void:
	# Diferido: si se eligió otra opción en el mismo frame, el botón original ya no existe.
	if _options_box.get_child_count() > 0:
		(_options_box.get_child(0) as Button).grab_focus()


func _clear_options() -> void:
	for child in _options_box.get_children():
		_options_box.remove_child(child)
		child.queue_free()


func _set_affinity_text(value: int, delta: int) -> void:
	var text := "Afinidad: %d" % value
	if delta != 0:
		text += " (%+d)" % delta
	_affinity_label.text = text
	var color := Color.WHITE
	if delta > 0:
		color = Color(0.4, 1.0, 0.5)
	elif delta < 0:
		color = Color(1.0, 0.4, 0.4)
	_affinity_label.add_theme_color_override("font_color", color)


func _on_affinity_changed(new_value: int, delta: int) -> void:
	_set_affinity_text(new_value, delta)


func _unhandled_input(event: InputEvent) -> void:
	# Teclas 1-9 para elegir opción sin ratón.
	if not is_active() or not (event is InputEventKey and event.pressed and not event.echo):
		return
	var index: int = event.keycode - KEY_1
	if index >= 0 and index < _options_box.get_child_count():
		get_viewport().set_input_as_handled()
		(_options_box.get_child(index) as Button).pressed.emit()
