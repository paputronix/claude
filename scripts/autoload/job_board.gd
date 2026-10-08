extends Node
## Encargos de reparto. STUB (Ola 0 del Hito 3): API fija, lógica en `claude/ligar-jobs`
## (ofertas por el móvil, paquete a recoger con [E], entrega con [E], pago por puntualidad).
## Encargo = {id: String, pickup: String, dropoff: String, deadline: int (minuto del día),
##            day: int, pay: int, status: String}
## status: "offered" | "picked_up" | "delivered" | "late" | "expired"

var _jobs: Array[Dictionary] = []


## Encargos en curso (ofertados o recogidos, sin terminar).
func get_active() -> Array[Dictionary]:
	return _jobs.filter(func(j): return j.status in ["offered", "picked_up"])
