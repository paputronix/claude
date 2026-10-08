extends CanvasLayer
## HUD del reloj: "HH:MM" y "Día N" arriba a la derecha. Se actualiza por señales.

@onready var _time_label: Label = $Box/TimeLabel
@onready var _day_label: Label = $Box/DayLabel


func _ready() -> void:
	var clock := get_node("/root/GameClock")
	clock.minute_changed.connect(func(_m: int) -> void: _refresh())
	clock.day_changed.connect(func(_d: int) -> void: _refresh())
	_refresh()


func _refresh() -> void:
	var clock := get_node("/root/GameClock")
	_time_label.text = clock.format_time()
	_day_label.text = "Día %d" % clock.day
