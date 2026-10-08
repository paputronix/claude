extends "res://tests/test_base.gd"


func run_test() -> void:
	var wallet := autoload("Wallet")
	var hud := autoload("ClockHud")
	var phone := autoload("Phone")
	var money: Label = hud.get_node("Box/MoneyLabel")
	var delta: Label = hud.get_node("DeltaLabel")
	var phone_money: Label = phone.get_node("Root/Panel").find_child("MoneyLabel", true, false)
	check(phone_money != null, "el móvil tiene MoneyLabel")

	check(money.text == "%d €" % wallet.money, "HUD muestra el saldo inicial: " + money.text)
	check(hud.get_node("Box/TimeLabel") != null and hud.get_node("Box/DayLabel") != null, "HUD conserva reloj y día")
	check(money.mouse_filter == Control.MOUSE_FILTER_IGNORE and delta.mouse_filter == Control.MOUSE_FILTER_IGNORE, "HUD ignora el ratón")

	phone.open()
	var start: int = wallet.money
	wallet.earn(12, "test")
	check(money.text == "%d €" % (start + 12), "HUD tras earn: " + money.text)
	check(delta.text == "+12 €", "indicador +12: " + delta.text)
	check(delta.get_theme_color("font_color").g > delta.get_theme_color("font_color").r, "indicador verde")
	check(delta.modulate.a > 0.5, "indicador visible")
	check(phone_money.text == "%d €" % (start + 12), "móvil tras earn: " + phone_money.text)

	check(wallet.spend(8, "test"), "gasto posible")
	check(money.text == "%d €" % (start + 4), "HUD tras spend: " + money.text)
	check(delta.text == "−8 €", "indicador −8: " + delta.text)
	check(delta.get_theme_color("font_color").r > delta.get_theme_color("font_color").g, "indicador rojo")
	check(phone_money.text == "%d €" % (start + 4), "móvil tras spend: " + phone_money.text)

	var faded := await wait_until(func(): return delta.modulate.a < 0.05, 240)
	check(faded, "el indicador se desvanece")
	phone.close()
