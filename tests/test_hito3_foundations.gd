extends "res://tests/test_base.gd"
## Contratos de la Ola 0 del Hito 3.


func run_test() -> void:
	for name in ["Wallet", "JobBoard"]:
		check(root.has_node("/root/" + name), "autoload %s registrado" % name)

	var wallet := autoload("Wallet")
	var log: Array = []
	wallet.money_changed.connect(func(v, d, r): log.append([v, d, r]))
	check(wallet.money == 20, "se empieza con 20 €")
	wallet.earn(12, "encargo")
	check(not wallet.spend(100, "caro"), "spend sin saldo devuelve false")
	check(wallet.money == 32, "spend fallido no cobra")
	check(wallet.spend(8, "copa") and wallet.money == 24, "spend con saldo cobra")
	check(log == [[32, 12, "encargo"], [24, -8, "copa"]], "money_changed (%s)" % [log])

	check(autoload("JobBoard").get_active().is_empty(), "JobBoard sin encargos al empezar")
	var bus := autoload("EventBus")
	for sig in ["date_started", "caught", "job_offered", "job_completed"]:
		check(bus.has_signal(sig), "EventBus.%s" % sig)

	var marker := add_temp_location("kiosko", Vector3(30, 0, 0), 2.0)
	check(autoload("Locations").is_at("kiosko", Vector3(31, 0, 0)), "add_temp_location registra con radio")
	check(not autoload("Locations").is_at("kiosko", Vector3(33, 0, 0)), "radio respetado")
	marker.queue_free()

	var carla_model: PackedScene = load("res://assets/characters/anime/carla.glb")
	check(carla_model != null, "modelo anime de Carla importado")
