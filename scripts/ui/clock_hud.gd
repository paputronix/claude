extends CanvasLayer
## HUD del reloj: "HH:MM", "Día N" y saldo arriba a la derecha. Se actualiza por señales.
## Al cambiar el saldo muestra un indicador flotante "+12 €" / "−8 €" que sube y se desvanece.

const FLOAT_TIME := 1.2
const FLOAT_RISE := 24.0
const COLOR_GAIN := Color(0.4, 1.0, 0.45)
const COLOR_LOSS := Color(1.0, 0.35, 0.3)

@onready var _time_label: Label = $Box/TimeLabel
@onready var _day_label: Label = $Box/DayLabel
@onready var _money_label: Label = $Box/MoneyLabel
@onready var _delta_label: Label = $DeltaLabel

var _delta_base_y := 0.0
var _delta_tween: Tween


func _ready() -> void:
	var clock := get_node("/root/GameClock")
	clock.minute_changed.connect(func(_m: int) -> void: _refresh())
	clock.day_changed.connect(func(_d: int) -> void: _refresh())
	get_node("/root/Wallet").money_changed.connect(_on_money_changed)
	_delta_base_y = _delta_label.offset_top
	_refresh()


func _refresh() -> void:
	var clock := get_node("/root/GameClock")
	_time_label.text = clock.format_time()
	_day_label.text = "Día %d" % clock.day
	_money_label.text = "%d €" % get_node("/root/Wallet").money


func _on_money_changed(value: int, delta: int, _reason: String) -> void:
	_money_label.text = "%d €" % value
	if delta == 0:
		return
	# Un solo indicador: si llega otro cambio, se reinicia con el nuevo importe.
	if _delta_tween:
		_delta_tween.kill()
	_delta_label.text = ("+%d €" if delta > 0 else "−%d €") % absi(delta)
	_delta_label.add_theme_color_override("font_color", COLOR_GAIN if delta > 0 else COLOR_LOSS)
	_delta_label.offset_top = _delta_base_y
	_delta_label.modulate.a = 1.0
	_delta_tween = create_tween()
	_delta_tween.set_parallel(true)
	_delta_tween.tween_property(_delta_label, "offset_top", _delta_base_y - FLOAT_RISE, FLOAT_TIME)
	_delta_tween.tween_property(_delta_label, "modulate:a", 0.0, FLOAT_TIME).set_ease(Tween.EASE_IN)
