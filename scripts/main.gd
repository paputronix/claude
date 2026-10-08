extends Node3D
## Cableado de la escena: NPCs → diálogo → jugador.
## Cada pieza solo emite señales; aquí se decide quién reacciona a qué.

@onready var _player: Player = $Player
@onready var _dialogue_ui: DialogueUI = $DialogueUI


func _ready() -> void:
	for npc: Npc in get_tree().get_nodes_in_group("npcs"):
		npc.conversation_requested.connect(_dialogue_ui.start)
	_dialogue_ui.conversation_started.connect(_on_conversation_started)
	_dialogue_ui.conversation_ended.connect(_on_conversation_ended)


func _on_conversation_started(npc: Npc) -> void:
	_player.set_controls_enabled(false)
	npc.face(_player.global_position)


func _on_conversation_ended(_npc: Npc) -> void:
	_player.set_controls_enabled(true)
