extends Node3D
## Ciclo día/noche: sigue a `GameClock` minuto a minuto (y al instante tras `set_time`).
##
## Interpola entre estados clave (noche → amanecer → día → atardecer → noche) el sol
## (que de noche hace de luna), la luz ambiental, la niebla y el cielo anime
## (`shaders/sky.gdshader`: degradado, nubes, disco del sol/luna, estrellas). Enciende las
## farolas del mapa (nodos `LampBulb*` dentro de `World`, sin tocar world.tscn): a cada
## una le cuelga un OmniLight3D sin sombras y hace brillar la bombilla. Añade también
## unas pocas luces fijas (bar sin techo, parque) que se encienden con la noche.
## Ventanas: los cristales del grupo `window_glass` (MeshInstance3D) reciben un material
## toon propio con emisión cálida que sube con `night_amount` (unas más que otras; alguna
## queda a oscuras). Bombillas y ventanas llevan `keep_material` para que ToonStyler no
## sustituya sus materiales.
##
## Coste (Compatibility/web): todas las luces sin sombras y con rango corto; ningún
## objeto recibe más de `max_lights_per_object` (8) a la vez.

## Estados clave del cielo y la luz. `elev`/`az`: elevación y azimut del sol en grados.
## Cielo (shaders/sky.gdshader): degradado `sky_horizon` → `sky_mid` → `sky_top`, nubes
## `cloud`/`cloud_shade`, disco `disk` (sol de día, luna de noche) y `stars` (0..1).
const DAY := {
	"sun_color": Color(1.0, 0.96, 0.9), "sun_energy": 0.9, "elev": 50.0, "az": 30.0,
	"amb_color": Color(0.55, 0.58, 0.65), "amb_energy": 0.6,
	"sky_top": Color(0.16, 0.42, 0.88), "sky_mid": Color(0.36, 0.63, 0.95),
	"sky_horizon": Color(0.7, 0.86, 0.98), "ground": Color(0.5, 0.6, 0.72), "sky_energy": 1.0,
	"cloud": Color(1.0, 1.0, 1.0), "cloud_shade": Color(0.72, 0.78, 0.94),
	"disk": Color(1.0, 0.97, 0.88), "disk_size": 0.045, "halo": 0.35, "stars": 0.0,
}
const SUNSET := {
	"sun_color": Color(1.0, 0.55, 0.28), "sun_energy": 0.8, "elev": 18.0, "az": 90.0,
	"amb_color": Color(0.62, 0.5, 0.52), "amb_energy": 0.6,
	"sky_top": Color(0.24, 0.24, 0.58), "sky_mid": Color(0.86, 0.46, 0.6),
	"sky_horizon": Color(1.0, 0.62, 0.36), "ground": Color(0.5, 0.36, 0.4), "sky_energy": 1.0,
	"cloud": Color(1.0, 0.72, 0.55), "cloud_shade": Color(0.56, 0.38, 0.6),
	"disk": Color(1.0, 0.78, 0.5), "disk_size": 0.06, "halo": 0.8, "stars": 0.0,
}
const SUNRISE := {
	"sun_color": Color(1.0, 0.68, 0.45), "sun_energy": 0.75, "elev": 18.0, "az": -90.0,
	"amb_color": Color(0.58, 0.52, 0.6), "amb_energy": 0.6,
	"sky_top": Color(0.3, 0.4, 0.75), "sky_mid": Color(0.78, 0.6, 0.78),
	"sky_horizon": Color(1.0, 0.74, 0.58), "ground": Color(0.5, 0.42, 0.46), "sky_energy": 1.0,
	"cloud": Color(1.0, 0.84, 0.76), "cloud_shade": Color(0.62, 0.52, 0.72),
	"disk": Color(1.0, 0.86, 0.66), "disk_size": 0.055, "halo": 0.6, "stars": 0.0,
}
const NIGHT := {
	"sun_color": Color(0.6, 0.7, 1.0), "sun_energy": 0.25, "elev": 40.0, "az": -30.0,
	"amb_color": Color(0.3, 0.36, 0.58), "amb_energy": 0.5,
	"sky_top": Color(0.02, 0.03, 0.1), "sky_mid": Color(0.04, 0.07, 0.2),
	"sky_horizon": Color(0.1, 0.14, 0.32), "ground": Color(0.04, 0.05, 0.09), "sky_energy": 1.0,
	"cloud": Color(0.2, 0.24, 0.4), "cloud_shade": Color(0.07, 0.09, 0.18),
	"disk": Color(0.86, 0.9, 1.0), "disk_size": 0.03, "halo": 0.25, "stars": 1.0,
}
const MINUTES_PER_DAY := 1440
## [minuto del día, estado]. Entre dos claves se interpola con smoothstep.
const KEYFRAMES := [
	[6 * 60, NIGHT],
	[7 * 60, SUNRISE],
	[8 * 60, DAY],
	[19 * 60 + 30, DAY],
	[20 * 60 + 30, SUNSET],
	[21 * 60 + 30, NIGHT],
]

## Farolas: se encienden entre estas horas por la tarde y se apagan al amanecer.
const LAMPS_ON_FROM := 20 * 60 + 15
const LAMPS_ON_TO := 20 * 60 + 45
const LAMPS_OFF_FROM := 6 * 60 + 45
const LAMPS_OFF_TO := 7 * 60 + 15
const LAMP_PREFIX := "LampBulb"
const LAMP_COLOR := Color(1.0, 0.72, 0.42)
const LAMP_ENERGY := 5.0
const LAMP_RANGE := 10.0
## La luz cuelga un poco por debajo del centro de la bombilla.
const LAMP_OFFSET := Vector3(0, -0.45, 0)
const BULB_EMISSION := 3.0
const STREET_LAMP_GROUP := "street_lamps"

## Ventanas iluminadas de noche.
const WINDOW_GROUP := "window_glass"
const WINDOW_COLOR := Color(1.0, 0.68, 0.32)
const WINDOW_EMISSION := 2.2
const WINDOW_LIT_ALBEDO := Color(0.1, 0.08, 0.06)
## Nivel de luz por ventana (elegido por su posición): variedad de pisos encendidos.
const WINDOW_LEVELS := [1.0, 0.7, 0.0, 1.0, 0.45, 0.85]
const SKY_SHADER := preload("res://shaders/sky.gdshader")

## Luces fijas de noche (bar sin techo, parque): [posición, energía, rango].
const NIGHT_FILL_LIGHTS := [
	[Vector3(-4.5, 2.7, -5.0), 4.5, 10.0],  # bar, zona de la barra
	[Vector3(4.0, 2.7, 0.0), 4.5, 9.0],  # bar, mesas y puerta
	[Vector3(-2.0, 4.5, 92.0), 1.5, 11.0],  # parque, banco
	[Vector3(8.0, 1.4, 100.0), 1.2, 6.0],  # parque, fuente
]
const FILL_COLOR := Color(1.0, 0.75, 0.5)
const FILL_GROUP := "night_fill_lights"

@export var sun_path: NodePath
@export var environment_path: NodePath
@export var world_path: NodePath

## 0 = pleno día, 1 = noche cerrada. Lo usan otros (p. ej. el sonido ambiente).
var night_amount := 0.0
## 0..1: farolas apagadas/encendidas.
var lamps_amount := 0.0

var _sun: DirectionalLight3D
var _env: Environment
var _sky: ShaderMaterial
var _lamp_lights: Array[OmniLight3D] = []
var _fill_lights: Array[OmniLight3D] = []
var _fill_energy: Array[float] = []
var _bulb_material: StandardMaterial3D
## [ShaderMaterial, nivel, albedo de día] por variante de ventana; caché "<id origen>|<nivel>".
var _windows: Array = []
var _window_materials := {}


func _ready() -> void:
	_sun = get_node_or_null(sun_path) as DirectionalLight3D
	var world_env := get_node_or_null(environment_path) as WorldEnvironment
	if world_env and world_env.environment:
		_env = world_env.environment
		_setup_sky()
	var world := get_node_or_null(world_path)
	if world:
		_setup_lamps(world)
	_setup_fill_lights()
	GameClock.minute_changed.connect(_on_minute_changed)
	apply_time(GameClock.minutes_of_day)


## Luces OmniLight3D de las farolas.
func get_lamp_lights() -> Array[OmniLight3D]:
	return _lamp_lights


## Aplica el estado de la hora `minutes` (0..1439).
func apply_time(minutes: float) -> void:
	var state := sample(minutes)
	night_amount = _night_amount(minutes)
	lamps_amount = _lamps_amount(minutes)
	if _sun:
		_sun.light_color = state.sun_color
		_sun.light_energy = state.sun_energy
		_sun.rotation = Vector3(deg_to_rad(-state.elev), deg_to_rad(state.az), 0.0)
	if _env:
		_env.ambient_light_color = state.amb_color
		_env.ambient_light_energy = state.amb_energy
		# Niebla de distancia teñida como el horizonte: profundidad de "cuadro".
		_env.fog_light_color = state.sky_horizon.lerp(state.amb_color, 0.3)
	if _sky:
		var energy: float = state.sky_energy
		_sky.set_shader_parameter("top_color", state.sky_top * energy)
		_sky.set_shader_parameter("mid_color", state.sky_mid * energy)
		_sky.set_shader_parameter("horizon_color", state.sky_horizon * energy)
		_sky.set_shader_parameter("ground_color", state.ground * energy)
		_sky.set_shader_parameter("cloud_color", state.cloud * energy)
		_sky.set_shader_parameter("cloud_shade_color", state.cloud_shade * energy)
		_sky.set_shader_parameter("disk_color", state.disk)
		_sky.set_shader_parameter("disk_size", state.disk_size)
		_sky.set_shader_parameter("halo_strength", state.halo)
		_sky.set_shader_parameter("stars", state.stars)
	for light in _lamp_lights:
		light.light_energy = LAMP_ENERGY * lamps_amount
		light.visible = lamps_amount > 0.0
	if _bulb_material:
		_bulb_material.emission_energy_multiplier = BULB_EMISSION * lamps_amount
	for i in _fill_lights.size():
		_fill_lights[i].light_energy = _fill_energy[i] * night_amount
		_fill_lights[i].visible = night_amount > 0.0
	_setup_windows()
	for entry: Array in _windows:
		var glow: float = entry[1] * night_amount
		var window_material := entry[0] as ShaderMaterial
		window_material.set_shader_parameter("emission_energy", WINDOW_EMISSION * glow)
		# El cristal encendido oscurece su albedo para que mande el color de la luz.
		window_material.set_shader_parameter("albedo", (entry[2] as Color).lerp(WINDOW_LIT_ALBEDO, glow))


## Material del cielo (ShaderMaterial de `shaders/sky.gdshader`).
func get_sky_material() -> ShaderMaterial:
	return _sky


## Estado interpolado (diccionario con las claves de DAY) para `minutes`.
static func sample(minutes: float) -> Dictionary:
	var count := KEYFRAMES.size()
	for i in count:
		var from: Array = KEYFRAMES[i]
		var to: Array = KEYFRAMES[(i + 1) % count]
		var start: float = from[0]
		var end: float = to[0]
		if end < start:
			end += MINUTES_PER_DAY
		var m := minutes
		if m < start:
			m += MINUTES_PER_DAY
		if m >= start and m <= end:
			var t := smoothstep(start, end, m) if end > start else 0.0
			return _lerp_state(from[1], to[1], t)
	return DAY


static func _lerp_state(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var out := {}
	for key in a:
		out[key] = lerp(a[key], b[key], t)
	return out


static func _night_amount(minutes: float) -> float:
	if minutes < 12 * 60:
		return 1.0 - smoothstep(6 * 60, 8 * 60, minutes)
	return smoothstep(19 * 60 + 30, 21 * 60 + 30, minutes)


static func _lamps_amount(minutes: float) -> float:
	if minutes < 12 * 60:
		return 1.0 - smoothstep(LAMPS_OFF_FROM, LAMPS_OFF_TO, minutes)
	return smoothstep(LAMPS_ON_FROM, LAMPS_ON_TO, minutes)


func _setup_lamps(world: Node) -> void:
	for node in world.find_children(LAMP_PREFIX + "*", "MeshInstance3D"):
		var bulb := node as MeshInstance3D
		if _bulb_material == null:
			var source := bulb.get_active_material(0) as StandardMaterial3D
			_bulb_material = source.duplicate() if source else StandardMaterial3D.new()
			_bulb_material.emission_enabled = true
			_bulb_material.emission = LAMP_COLOR
		bulb.material_override = _bulb_material
		bulb.set_meta(ToonMaterials.META_KEEP, true)
		var light := OmniLight3D.new()
		light.name = "LampLight"
		light.position = LAMP_OFFSET
		light.light_color = LAMP_COLOR
		light.omni_range = LAMP_RANGE
		light.omni_attenuation = 1.0
		light.shadow_enabled = false
		light.add_to_group(STREET_LAMP_GROUP)
		bulb.add_child(light)
		_lamp_lights.append(light)


## Usa el cielo shader de la escena o lo crea si el Environment trae otro.
func _setup_sky() -> void:
	if _env.sky and _env.sky.sky_material is ShaderMaterial:
		_sky = _env.sky.sky_material
		return
	_sky = ShaderMaterial.new()
	_sky.shader = SKY_SHADER
	if _env.sky == null:
		_env.sky = Sky.new()
	_env.sky.sky_material = _sky


## Da material de ventana a los cristales nuevos del grupo `window_glass` (barato si no hay).
func _setup_windows() -> void:
	if not is_inside_tree():
		return
	for node in get_tree().get_nodes_in_group(WINDOW_GROUP):
		var glass := node as MeshInstance3D
		if glass == null or glass.has_meta("window_level"):
			continue
		var pos := glass.global_position
		var level: float = WINDOW_LEVELS[absi(int(floor(pos.x * 3.1 + pos.y * 1.7 + pos.z * 2.3))) % WINDOW_LEVELS.size()]
		var source := glass.get_active_material(0)
		var key := "%d|%s" % [source.get_instance_id() if source else 0, level]
		if not _window_materials.has(key):
			var toon := ToonMaterials.convert_material(source if source else StandardMaterial3D.new(), "world", false)
			var material: ShaderMaterial = toon.duplicate() if ToonMaterials.is_toon(toon) \
					else ToonMaterials.convert_material(StandardMaterial3D.new(), "world", false).duplicate()
			material.next_pass = null
			material.set_shader_parameter("emission_color", WINDOW_COLOR)
			_window_materials[key] = material
			_windows.append([material, level, material.get_shader_parameter("albedo")])
		glass.material_override = _window_materials[key]
		glass.set_meta(ToonMaterials.META_KEEP, true)
		glass.set_meta("window_level", level)


func _setup_fill_lights() -> void:
	for spec: Array in NIGHT_FILL_LIGHTS:
		var light := OmniLight3D.new()
		light.name = "NightFill%d" % _fill_lights.size()
		light.position = spec[0]
		light.light_color = FILL_COLOR
		light.omni_range = spec[2]
		light.omni_attenuation = 1.2
		light.shadow_enabled = false
		light.add_to_group(FILL_GROUP)
		add_child(light)
		_fill_lights.append(light)
		_fill_energy.append(spec[1])


func _on_minute_changed(minutes: int) -> void:
	apply_time(minutes)
