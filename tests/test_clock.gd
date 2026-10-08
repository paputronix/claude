extends "res://tests/test_base.gd"


func run_test() -> void:
	var clock := autoload("GameClock")
	var bus := autoload("EventBus")
	var minutes: Array[int] = []
	var hours: Array[int] = []
	var days: Array[int] = []
	clock.minute_changed.connect(func(m: int) -> void: minutes.append(m))
	clock.hour_changed.connect(func(h: int) -> void: hours.append(h))
	clock.day_changed.connect(func(d: int) -> void: days.append(d))
	clock.time_scale = 0.0  # evita que _process interfiera

	clock.set_time(10, 58)
	minutes.clear()
	clock.advance(0.5)
	check(minutes.is_empty(), "medio minuto no emite")
	clock.advance(0.5)
	check(minutes == [659], "acumula fracciones: %s" % [minutes])
	clock.advance(1.0)
	check(minutes == [659, 660] and hours == [11], "cruce de hora")

	minutes.clear()
	hours.clear()
	clock.advance(185.0)
	check(minutes.size() == 185, "185 minutos emitidos")
	check(hours == [12, 13, 14], "cruce de varias horas: %s" % [hours])
	check(clock.format_time() == "14:05", "hora final " + clock.format_time())

	clock.set_time(23, 59)
	hours.clear()
	clock.advance(1.0)
	check(clock.day == 2 and days == [2], "rollover de día")
	check(clock.minutes_of_day == 0 and hours == [0], "medianoche y hora 0")

	# Pausa por conversación (separada de la manual)
	clock.set_time(9, 0)
	bus.conversation_started.emit("x")
	check(not clock.is_running(), "conversación detiene")
	clock.advance(5.0)
	check(clock.minutes_of_day == 540, "no avanza en conversación")
	bus.conversation_ended.emit("x")
	check(clock.is_running(), "reanuda al terminar")
	clock.advance(5.0)
	check(clock.minutes_of_day == 545, "avanza tras conversación")

	clock.paused = true
	clock.advance(5.0)
	check(clock.minutes_of_day == 545 and not clock.is_running(), "pausa manual")
	bus.conversation_started.emit("x")
	bus.conversation_ended.emit("x")
	check(not clock.is_running(), "fin de conversación no pisa la pausa manual")
	clock.paused = false

	# HUD
	var hud := autoload("ClockHud")
	clock.set_time(7, 30)
	clock.advance(5.0)
	var label: Label = hud.get_node("Box/TimeLabel")
	check(label.text == "07:35", "HUD muestra la hora: " + label.text)
	var dlabel: Label = hud.get_node("Box/DayLabel")
	check(dlabel.text == "Día %d" % clock.day, "HUD muestra el día")
	clock.time_scale = 1.0
