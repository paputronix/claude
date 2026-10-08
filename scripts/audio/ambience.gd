extends Node
## Sonido ambiente generado en memoria (sin ficheros de audio): murmullo urbano suave
## (ruido filtrado en bucle) y grillos que entran con la noche. El volumen sigue a
## `DayNight.night_amount`. Con el driver de audio dummy (headless) simplemente no suena.

const MIX_RATE := 22050
## Murmullo: bucle de ruido marrón con un vaivén lento.
const MURMUR_SECONDS := 4.0
const MURMUR_DB_DAY := -24.0
const MURMUR_DB_NIGHT := -30.0
## Grillos: ráfagas de 3 pulsos agudos.
const CRICKET_SECONDS := 2.4
const CRICKET_DB := -30.0
const SILENT_DB := -80.0
## Muestras de fundido entre el final y el principio del bucle (evita el clic).
const LOOP_FADE := 2048

@export var day_night_path: NodePath

var _day_night: Node
var _murmur: AudioStreamPlayer
var _crickets: AudioStreamPlayer


func _ready() -> void:
	_day_night = get_node_or_null(day_night_path)
	_murmur = _make_player("Murmur", build_murmur())
	_crickets = _make_player("Crickets", build_crickets())
	_update_volumes()


func _process(_delta: float) -> void:
	_update_volumes()


func _update_volumes() -> void:
	var night: float = _day_night.night_amount if _day_night else 0.0
	_murmur.volume_db = lerpf(MURMUR_DB_DAY, MURMUR_DB_NIGHT, night)
	_crickets.volume_db = SILENT_DB if night <= 0.01 else CRICKET_DB + linear_to_db(night)


func _make_player(player_name: String, stream: AudioStreamWAV) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.stream = stream
	player.volume_db = SILENT_DB
	add_child(player)
	player.play()
	return player


## Ruido marrón (paso bajo de un polo sobre ruido blanco) con modulación lenta.
static func build_murmur() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var length := int(MURMUR_SECONDS * MIX_RATE)
	var raw := PackedFloat32Array()
	raw.resize(length + LOOP_FADE)
	var low := 0.0
	var low2 := 0.0
	for i in raw.size():
		low += (rng.randf_range(-1.0, 1.0) - low) * 0.04
		low2 += (low - low2) * 0.08
		# Dos vaivenes cuyo periodo divide el bucle, para que empalme bien.
		var t := float(i) / length
		var swell := 0.75 + 0.15 * sin(TAU * 2.0 * t) + 0.1 * sin(TAU * 5.0 * t + 1.3)
		raw[i] = low2 * swell * 4.0
	return _to_wav(_close_loop(raw, length))


## Grillos: dos "bichos" con tono y ritmo distintos.
static func build_crickets() -> AudioStreamWAV:
	var length := int(CRICKET_SECONDS * MIX_RATE)
	var raw := PackedFloat32Array()
	raw.resize(length)
	_add_cricket(raw, 4600.0, 0.0, 0.8, 0.5)
	_add_cricket(raw, 5200.0, 0.37, 1.2, 0.3)
	return _to_wav(raw)


## Suma a `raw` un grillo: cada `period` s, 3 pulsos de 18 ms separados 30 ms.
static func _add_cricket(raw: PackedFloat32Array, freq: float, offset: float, period: float, gain: float) -> void:
	var pulse := int(0.018 * MIX_RATE)
	var gap := int(0.048 * MIX_RATE)
	var start := offset
	while start < float(raw.size()) / MIX_RATE:
		for p in 3:
			var first := int(start * MIX_RATE) + p * gap
			for k in pulse:
				var i := first + k
				if i >= raw.size():
					break
				var env := sin(PI * k / pulse)
				raw[i] += sin(TAU * freq * i / MIX_RATE) * env * gain
		start += period


## Funde las últimas `LOOP_FADE` muestras sobre las primeras y recorta a `length`.
static func _close_loop(raw: PackedFloat32Array, length: int) -> PackedFloat32Array:
	for i in LOOP_FADE:
		var w := float(i) / LOOP_FADE
		raw[i] = raw[i] * w + raw[length + i] * (1.0 - w)
	return raw.slice(0, length)


static func _to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = samples.size()
	return wav
