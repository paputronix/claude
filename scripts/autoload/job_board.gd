extends Node
## Encargos de reparto: ofertas diarias (data/jobs.json) por el móvil, paquete que se
## recoge con [E] (`scripts/jobs/parcel.gd`) y punto de entrega con [E] (`dropoff_point.gd`).
## Encargo = {id: String, pickup: String, dropoff: String, deadline: int (minuto del día),
##            day: int, pay: int, status: String}
## status: "offered" | "picked_up" | "delivered" | "late" | "expired"
## Reglas: a tiempo (<= deadline) paga `pay`; tarde paga la mitad (redondeo abajo) hasta
## deadline + LATE_GRACE_MINUTES; después caduca sin pago. Oferta sin recoger caduca al
## pasar el deadline. Todo se evalúa con tiempo absoluto (día + minuto).

const MINUTES_PER_DAY := 1440
const JOBS_PATH := "res://data/jobs.json"
## Minutos tras el deadline durante los que aún se puede entregar (con retraso).
const LATE_GRACE_MINUTES := 60

const TEXT_OFFER := "Recoge en %s y llévalo %s antes de %s · %d €"
const TEXT_CANCELLED := "Encargo cancelado"
const TEXT_EXPIRED := "Se ha pasado el plazo del encargo. Sin paga."
const TEXT_DELIVERED := "+%d €"
const TEXT_DELIVERED_LATE := "Con retraso, +%d €"

## Nombres legibles de lugares para los mensajes.
const PLACE_NAMES := {"kiosko": "el kiosko", "bar": "el bar", "parque": "el parque",
		"calle": "la calle", "casa_lucia": "casa de Lucía", "casa_carla": "casa de Carla",
		"terraza": "la terraza"}

var _jobs: Array[Dictionary] = []
## Ofertas diarias: {id, offer_at, pickup, dropoff, deadline, pay} (minutos del día).
var _offers: Array[Dictionary] = []
## "oferta@día" ya ofertadas.
var _offered: Dictionary = {}
## job id -> Parcel / DropoffPoint
var _parcels: Dictionary = {}
var _dropoffs: Dictionary = {}
## Avisos de location ausente ya mostrados (uno por encargo y lugar).
var _warned: Dictionary = {}


func _ready() -> void:
	load_jobs(JOBS_PATH)
	GameClock.minute_changed.connect(_on_minute_changed)


## Carga las ofertas diarias de un JSON `{"offers": [...]}`. Reemplaza las anteriores.
func load_jobs(path: String) -> void:
	_offers.clear()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("JobBoard: no se puede abrir %s" % path)
		return
	var data = JSON.parse_string(file.get_as_text())
	if not data is Dictionary or not data.get("offers") is Array:
		push_warning("JobBoard: formato inválido en %s" % path)
		return
	for o in data["offers"]:
		var offer_at := GameClock.parse_time(str(o.get("offer_at", "")))
		var deadline := GameClock.parse_time(str(o.get("deadline", "")))
		if offer_at < 0 or deadline <= offer_at or str(o.get("id", "")).is_empty():
			push_warning("JobBoard: oferta inválida %s" % [o])
			continue
		_offers.append({"id": str(o.id), "offer_at": offer_at, "pickup": str(o.get("pickup", "")),
				"dropoff": str(o.get("dropoff", "")), "deadline": deadline, "pay": int(o.get("pay", 0))})


## Encargos en curso (ofertados o recogidos, sin terminar).
func get_active() -> Array[Dictionary]:
	return _jobs.filter(func(j): return j.status in ["offered", "picked_up"])


## Todos los encargos, terminados o no.
func get_jobs() -> Array[Dictionary]:
	return _jobs.duplicate()


## El encargo recogido y aún sin entregar, o {} si no llevas nada.
func get_carried() -> Dictionary:
	for j in _jobs:
		if j.status == "picked_up":
			return j
	return {}


## Estado de un encargo ("" si no existe).
func get_status(job_id: String) -> String:
	var job := _find(job_id)
	return str(job.status) if not job.is_empty() else ""


## Reset (para tests): borra encargos y nodos. Las ofertas del JSON se conservan.
func clear() -> void:
	for node in _parcels.values() + _dropoffs.values():
		if is_instance_valid(node):
			node.queue_free()
	_parcels.clear()
	_dropoffs.clear()
	_jobs.clear()
	_offered.clear()
	_warned.clear()


## Recoge el paquete (lo llama el `Parcel`). Falso si no se puede.
func pick_up(job_id: String) -> bool:
	var job := _find(job_id)
	if job.is_empty() or job.status != "offered" or not get_carried().is_empty():
		return false
	job.status = "picked_up"
	_free_node(_parcels, job_id)
	_sync_nodes()
	return true


## Entrega el paquete (lo llama el `DropoffPoint`). Falso si no se puede.
func deliver(job_id: String) -> bool:
	var job := _find(job_id)
	if job.is_empty() or job.status != "picked_up":
		return false
	var on_time := _now() <= _deadline(job)
	var pay: int = job.pay if on_time else job.pay / 2
	job.status = "delivered" if on_time else "late"
	_free_node(_dropoffs, job_id)
	Wallet.earn(pay, "Encargo")
	EventBus.job_completed.emit(job, on_time, pay)
	Phone.notify("Encargo entregado", (TEXT_DELIVERED if on_time else TEXT_DELIVERED_LATE) % pay)
	return true


func _on_minute_changed(_minute: int) -> void:
	_check_offers()
	_check_expiry()
	_sync_nodes()


func _check_offers() -> void:
	var now := _now()
	for offer in _offers:
		var key := "%s@%d" % [offer.id, GameClock.day]
		if _offered.has(key) or GameClock.minutes_of_day < offer.offer_at:
			continue
		var deadline_abs := (GameClock.day - 1) * MINUTES_PER_DAY + int(offer.deadline)
		if now > deadline_abs:
			continue
		_offered[key] = true
		var job := {"id": "%s_d%d" % [offer.id, GameClock.day], "pickup": offer.pickup,
				"dropoff": offer.dropoff, "deadline": offer.deadline, "day": GameClock.day,
				"pay": offer.pay, "status": "offered"}
		_jobs.append(job)
		EventBus.job_offered.emit(job)
		Phone.notify("Encargo", TEXT_OFFER % [_place(job.pickup), _to_place(job.dropoff),
				_fmt(job.deadline), job.pay])


func _check_expiry() -> void:
	var now := _now()
	for job in get_active():
		var limit := _deadline(job) + (LATE_GRACE_MINUTES if job.status == "picked_up" else 0)
		if now <= limit:
			continue
		var was_offered: bool = job.status == "offered"
		job.status = "expired"
		_free_node(_parcels, job.id)
		_free_node(_dropoffs, job.id)
		Phone.notify(TEXT_CANCELLED, "" if was_offered else TEXT_EXPIRED)


## Crea los nodos que falten (paquete de ofertas, punto de entrega de recogidos).
## Si el location aún no existe, avisa una vez y reintenta en el siguiente minuto.
func _sync_nodes() -> void:
	for job in get_active():
		var offered: bool = job.status == "offered"
		var nodes := _parcels if offered else _dropoffs
		if is_instance_valid(nodes.get(job.id)):
			continue
		var place: String = job.pickup if offered else job.dropoff
		if not Locations.has(place):
			if not _warned.has(job.id + place):
				_warned[job.id + place] = true
				push_warning("JobBoard: location '%s' no registrada, se reintentará" % place)
			continue
		var node: Area3D = load("res://scripts/jobs/parcel.gd" if offered
				else "res://scripts/jobs/dropoff_point.gd").new()
		node.job_id = job.id
		node.name = ("Parcel_" if offered else "Dropoff_") + job.id
		var parent: Node = get_tree().current_scene
		if parent == null:
			parent = get_tree().root
		parent.add_child(node)
		node.global_position = Locations.get_position(place)
		nodes[job.id] = node


func _free_node(nodes: Dictionary, job_id: String) -> void:
	var node = nodes.get(job_id)
	nodes.erase(job_id)
	if is_instance_valid(node):
		node.queue_free()


func _find(job_id: String) -> Dictionary:
	for j in _jobs:
		if j.id == job_id:
			return j
	return {}


func _now() -> int:
	return (GameClock.day - 1) * MINUTES_PER_DAY + GameClock.minutes_of_day


func _deadline(job: Dictionary) -> int:
	return (int(job.day) - 1) * MINUTES_PER_DAY + int(job.deadline)


func _fmt(minute: int) -> String:
	return "%02d:%02d" % [minute / 60, minute % 60]


## "kiosko" -> "el kiosko", "portal_b" -> "el portal B".
func _place(id: String) -> String:
	if PLACE_NAMES.has(id):
		return PLACE_NAMES[id]
	if id.begins_with("portal_"):
		return "el portal " + id.trim_prefix("portal_").to_upper()
	return id.replace("_", " ")


## Destino con contracción: "al kiosko", "a la terraza".
func _to_place(id: String) -> String:
	var place := _place(id)
	if place.begins_with("el "):
		return "al " + place.trim_prefix("el ")
	return "a " + place
