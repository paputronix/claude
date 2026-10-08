extends CanvasLayer
## Móvil del personaje. STUB (Ola 0): API fija, UI real en `claude/ligar-phone`
## (toast + sonido, Tab abre la lista de mensajes).

signal notified(title: String, body: String)

## Historial: [{title, body, time: "HH:MM"}], más reciente al final.
var messages: Array[Dictionary] = []


func notify(title: String, body: String) -> void:
	messages.append({"title": title, "body": body, "time": GameClock.format_time()})
	notified.emit(title, body)
