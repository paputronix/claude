extends Area3D
## Paquete a recoger en el punto de recogida de un encargo (Interactable).
## Lo crea JobBoard al ofertar el encargo y lo borra al recogerlo o caducar.
## Sin class_name: JobBoard lo carga con load() (evita dependencia circular con el autoload).

const PROMPT := "Recoger paquete"
const BOX_SIZE := 0.5
const COLOR := Color(0.45, 0.32, 0.17)

var job_id := ""


func _init() -> void:
	collision_layer = 1
	collision_mask = 0
	monitoring = false
	monitorable = true
	add_to_group("interactable")
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(BOX_SIZE, BOX_SIZE, BOX_SIZE)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR
	box.material = mat
	mesh.mesh = box
	mesh.position.y = BOX_SIZE * 0.5
	add_child(mesh)
	var shape := CollisionShape3D.new()
	var shape_box := BoxShape3D.new()
	shape_box.size = Vector3(0.8, 0.8, 0.8)
	shape.shape = shape_box
	shape.position.y = 0.4
	add_child(shape)


func get_interaction_prompt() -> String:
	return PROMPT


## No se puede llevar más de un paquete a la vez.
func can_interact() -> bool:
	var board := get_node("/root/JobBoard")
	return board.get_carried().is_empty() and board.get_status(job_id) == "offered"


func interact(_by: Node) -> void:
	get_node("/root/JobBoard").pick_up(job_id)
