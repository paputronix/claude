extends "res://tests/test_base.gd"
## Ciclo día/noche: el sol, el ambiente, el cielo y las farolas siguen a GameClock.


func run_test() -> void:
	var clock := autoload("GameClock")
	clock.time_scale = 0.0
	clock.set_time(12, 0)
	var main := await load_main()
	var sun: DirectionalLight3D = main.get_node("Sun")
	var env: Environment = main.get_node("WorldEnvironment").environment
	var sky: ProceduralSkyMaterial = env.sky.sky_material
	var lamps := root.get_tree().get_nodes_in_group("street_lamps")
	var bulbs := main.get_node("World").find_children("LampBulb*", "MeshInstance3D")
	check(lamps.size() > 0 and lamps.size() == bulbs.size(),
		"una luz por farola (%d luces, %d bombillas)" % [lamps.size(), bulbs.size()])
	for lamp: OmniLight3D in lamps:
		check(not lamp.shadow_enabled and lamp.omni_range <= 12.0, "farola sin sombras y con rango corto")

	# Mediodía: sol fuerte, farolas apagadas.
	var noon := _snapshot(sun, env, sky, lamps)
	check(noon.sun > 0.7, "a las 12:00 el sol es fuerte (%.2f)" % noon.sun)
	check(noon.lamps == 0.0, "a las 12:00 las farolas están apagadas")

	# Noche: se actualiza al instante tras set_time.
	clock.set_time(22, 0)
	var night := _snapshot(sun, env, sky, lamps)
	check(night.sun < 0.4, "a las 22:00 sol/luna tenue (%.2f)" % night.sun)
	check(night.lamps > 0.0, "a las 22:00 las farolas están encendidas")
	check(night.ambient < noon.ambient, "a las 22:00 el ambiente es más oscuro que a mediodía")
	check(night.sky < noon.sky * 0.5, "a las 22:00 el cielo es oscuro")
	check(night.ambient > 0.05, "de noche no es negro: queda luz ambiental (%.2f)" % night.ambient)
	var day_night := main.get_node("DayNight")
	check(day_night.night_amount > 0.99, "a las 22:00 es noche cerrada")

	# Atardecer: valores intermedios, y el sol se vuelve cálido.
	clock.set_time(20, 0)
	var dusk := _snapshot(sun, env, sky, lamps)
	check(dusk.sun < noon.sun and dusk.sun > night.sun, "a las 20:00 la energía del sol está entre día y noche")
	check(dusk.ambient < noon.ambient and dusk.ambient > night.ambient, "a las 20:00 el ambiente está entre día y noche")
	check(sun.light_color.b < sun.light_color.r - 0.2, "al atardecer el sol es anaranjado")
	check(dusk.lamps == 0.0, "a las 20:00 las farolas aún no se han encendido")

	# Avance minuto a minuto: continuo (sin saltos bruscos) entre 19:30 y 21:30.
	clock.set_time(19, 30)
	clock.time_scale = 0.0
	var prev := _snapshot(sun, env, sky, lamps)
	var max_jump := 0.0
	for i in 120:
		clock.advance(1.0)
		var now := _snapshot(sun, env, sky, lamps)
		max_jump = maxf(max_jump, absf(now.ambient - prev.ambient))
		max_jump = maxf(max_jump, absf(now.sun - prev.sun))
		prev = now
	check(clock.minutes_of_day == 21 * 60 + 30, "el reloj llega a las 21:30")
	check(max_jump < 0.05, "la transición es suave minuto a minuto (salto máx. %.3f)" % max_jump)
	check(prev.lamps > 0.0, "tras avanzar a las 21:30 las farolas están encendidas")

	# Amanecer: a las 09:00 vuelve el día y las farolas se apagan.
	clock.set_time(9, 0)
	var morning := _snapshot(sun, env, sky, lamps)
	check(is_equal_approx(morning.sun, noon.sun), "a las 09:00 vuelve el sol de día")
	check(morning.lamps == 0.0, "a las 09:00 las farolas están apagadas")

	# El sonido ambiente existe y no rompe en headless.
	var ambience := main.get_node("Ambience")
	check(ambience.get_child_count() == 2, "el ambiente tiene murmullo y grillos")
	main.queue_free()
	await process_frame


## Luminancia aproximada de un color × energía.
func _lum(color: Color, energy: float) -> float:
	return (0.3 * color.r + 0.59 * color.g + 0.11 * color.b) * energy


func _snapshot(sun: DirectionalLight3D, env: Environment, sky: ProceduralSkyMaterial, lamps: Array) -> Dictionary:
	var lamp_energy := 0.0
	for lamp: OmniLight3D in lamps:
		lamp_energy += lamp.light_energy if lamp.visible else 0.0
	return {
		"sun": sun.light_energy,
		"ambient": _lum(env.ambient_light_color, env.ambient_light_energy),
		"sky": _lum(sky.sky_top_color, 1.0) + _lum(sky.sky_horizon_color, 1.0),
		"lamps": lamp_energy,
	}
