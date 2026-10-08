extends Node3D
## Cableado de la escena: NPCs → diálogo → jugador.
## Cada pieza solo emite señales; aquí se decide quién reacciona a qué.
##
## Citas: al empezar una (`EventBus.date_started`) se abre el diálogo con contexto "date";
## si ya hay otra conversación, se abre al terminar esta. Si te pillan (`EventBus.caught`)
## y estás hablando con la cita o con el testigo, la conversación se cierra: la cita ya
## está resuelta y no tiene sentido seguir eligiendo (ni pagando) opciones.

const DATE_CONTEXT := "date"

@onready var _player: Player = $Player
@onready var _dialogue_ui: DialogueUI = $DialogueUI

## NPC con el que se habla ahora (o null).
var _talking_to: Npc
## Cita cuyo diálogo espera a que acabe la conversación en curso (o vacío).
var _queued_date: Dictionary = {}


func _ready() -> void:
	for npc: Npc in get_tree().get_nodes_in_group("npcs"):
		npc.conversation_requested.connect(_dialogue_ui.start)
	_dialogue_ui.conversation_started.connect(_on_conversation_started)
	_dialogue_ui.conversation_ended.connect(_on_conversation_ended)
	EventBus.date_started.connect(_on_date_started)
	EventBus.caught.connect(_on_caught)


func _on_conversation_started(npc: Npc) -> void:
	_talking_to = npc
	_player.set_controls_enabled(false)
	npc.face(_player.global_position)


func _on_conversation_ended(_npc: Npc) -> void:
	_talking_to = null
	_player.set_controls_enabled(true)
	if not _queued_date.is_empty():
		var date := _queued_date
		_queued_date = {}
		# Diferido: EventBus.conversation_ended aún no se ha emitido (reloj, Brain).
		_open_date_dialogue.call_deferred(date)


func _on_date_started(date: Dictionary) -> void:
	_open_date_dialogue(date)


func _open_date_dialogue(date: Dictionary) -> void:
	if date.get("status") != "in_progress":
		return
	if _dialogue_ui.is_active():
		_queued_date = date
		return
	var npc := _find_npc(date.npc_id)
	if npc != null:
		_dialogue_ui.start(npc, DATE_CONTEXT)


func _on_caught(date: Dictionary, witness_id: String) -> void:
	if _queued_date == date:
		_queued_date = {}
	if _talking_to != null and (_talking_to.npc_id == date.npc_id or _talking_to.npc_id == witness_id):
		# El fin de conversación normal reanuda reloj, Brain y controles.
		_dialogue_ui.close()


func _find_npc(npc_id: String) -> Npc:
	for npc: Npc in get_tree().get_nodes_in_group("npcs"):
		if npc.npc_id == npc_id:
			return npc
	return null
