extends Area3D
## Punto de entrega de un encargo (Interactable). Aparece al recoger el paquete.
## Sin class_name: JobBoard lo carga con load().

const PROMPT := "Entregar paquete"
const COLOR := Color(0.8, 0.65, 0.1)

var job_id := ""


func _init() -> void:
	collision_layer = 1
	collision_mask = 0
	monitoring = false
	monitorable = true
	add_to_group("interactable")
	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.8
	cyl.bottom_radius = 0.8
	cyl.height = 0.1
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR
	cyl.material = mat
	mesh.mesh = cyl
	mesh.position.y = 0.05
	add_child(mesh)
	var shape := CollisionShape3D.new()
	var cyl_shape := CylinderShape3D.new()
	cyl_shape.radius = 0.8
	cyl_shape.height = 1.0
	shape.shape = cyl_shape
	shape.position.y = 0.5
	add_child(shape)


func get_interaction_prompt() -> String:
	return PROMPT


func can_interact() -> bool:
	return get_node("/root/JobBoard").get_status(job_id) == "picked_up"


func interact(_by: Node) -> void:
	get_node("/root/JobBoard").deliver(job_id)
