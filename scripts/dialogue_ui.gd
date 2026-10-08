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
##
## Contexto: `start(npc, context)` (p. ej. "date"). Las entradas de `start` pueden llevar
## "context": "date". Con contexto no vacío gana la primera entrada con ese contexto que
## cumpla la afinidad; si ninguna, se usan las entradas SIN "context". Con contexto vacío
## las entradas con "context" se ignoran.
##   "start": [ {"context": "date", "node": "cita"}, {"node": "saludo"} ]
##
## Coste: una opción con "cost": 8 (euros) muestra "Texto (8 €)", se deshabilita si
## Wallet no tiene saldo (las teclas 1-9 la ignoran) y al elegirla cobra
## `Wallet.spend(cost, "Invitar a <npc_name>")` antes de aplicar afinidad/acción/reacción.
## Si el cobro falla no se aplica nada.
##   { "text": "Invitarla a un café", "cost": 8, "affinity": 10, "next": "id" | null }

signal conversation_started(npc: Npc)
signal conversation_ended(npc: Npc)

var _npc: Npc
var _nodes: Dictionary = {}
var _context := ""

@onready var _panel: Control = $Panel
@onready var _name_label: Label = %NameLabel
@onready var _affinity_label: Label = %AffinityLabel
@onready var _text_label: Label = %TextLabel
@onready var _options_box: VBoxContainer = %OptionsBox


func _ready() -> void:
	_panel.hide()


func is_active() -> bool:
	return _npc != null


## `context` permite variantes del mismo diálogo (p. ej. "date" durante una cita).
## Contrato Hito 3: condición `"context": "date"` en `start` y opciones con `"cost": 8`
## (implementación en `claude/ligar-dialogue-v2`).
func start(npc: Npc, context := "") -> void:
	if is_active():
		return
	var data := npc.load_dialogue()
	if data.is_empty():
		return

	_npc = npc
	_context = context
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
	if _context != "":
		for entry in start:
			if entry is Dictionary and entry.get("context", "") == _context and _meets_affinity(entry):
				return entry.get("node")
	for entry in start:
		if entry is Dictionary and not entry.has("context") and _meets_affinity(entry):
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
		var cost := int(option.get("cost", 0))
		var label: String = option.get("text", "...")
		if cost > 0:
			label += " (%d €)" % cost
		_add_option(label, _choose.bind(option), cost > 0 and not Wallet.can_afford(cost))


func _choose(option: Dictionary) -> void:
	var cost := int(option.get("cost", 0))
	if cost > 0 and not Wallet.spend(cost, "Invitar a %s" % _npc.npc_name):
		return

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


## Cierra la conversación desde fuera (p. ej. una pillada). Emite el fin normal.
func close() -> void:
	if is_active():
		_end()


func _end() -> void:
	var npc := _npc
	_npc.affinity_changed.disconnect(_on_affinity_changed)
	_npc = null
	_nodes = {}
	_clear_options()
	_panel.hide()
	conversation_ended.emit(npc)
	EventBus.conversation_ended.emit(npc.npc_id)


func _add_option(text: String, callback: Callable, disabled := false) -> void:
	var index := _options_box.get_child_count() + 1
	var button := Button.new()
	button.text = "%d. %s" % [index, text]
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.disabled = disabled
	button.pressed.connect(callback)
	_options_box.add_child(button)
	if index == 1:
		_focus_first_option.call_deferred()


func _focus_first_option() -> void:
	# Diferido: si se eligió otra opción en el mismo frame, el botón original ya no existe.
	for child in _options_box.get_children():
		var button := child as Button
		if not button.disabled:
			button.grab_focus()
			return


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
		var button := _options_box.get_child(index) as Button
		if not button.disabled:
			button.pressed.emit()
