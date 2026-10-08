extends Node
## Dinero del jugador (euros enteros). Única fuente de verdad del saldo.

signal money_changed(value: int, delta: int, reason: String)

const STARTING_MONEY := 20

var money := STARTING_MONEY


func can_afford(amount: int) -> bool:
	return amount <= money


func earn(amount: int, reason := "") -> void:
	if amount <= 0:
		return
	money += amount
	money_changed.emit(money, amount, reason)


## Devuelve false (sin cobrar nada) si no hay saldo suficiente.
func spend(amount: int, reason := "") -> bool:
	if amount <= 0:
		return true
	if not can_afford(amount):
		return false
	money -= amount
	money_changed.emit(money, -amount, reason)
	return true
