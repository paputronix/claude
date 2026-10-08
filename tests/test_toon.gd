extends "res://tests/test_base.gd"
## Estilo toon: ToonMaterials.apply convierte materiales estándar a ShaderMaterial toon
## (contorno como next_pass en personajes), conserva color/textura/transparencia/cull,
## es idempotente, respeta keep_material y el anillo del NPC; ToonStyler convierte
## también lo que entra en la escena después.

const TOON := "res://scripts/visual/toon_materials.gd"
const OUTLINE := "res://shaders/outline.gdshader"
const TEXTURE := "res://assets/characters/anime/lucia_F00_000_Face_00.png"


func run_test() -> void:
	var toon: GDScript = load(TOON)
	_test_apply(toon)
	_test_world(toon)
	await _test_styler()


func _box(parent: Node, material: Material, size := Vector3.ONE, node_name := "Mesh") -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	mesh.mesh = box
	parent.add_child(mesh)
	return mesh


func _test_apply(toon: GDScript) -> void:
	var character := Node3D.new()
	var textured := StandardMaterial3D.new()
	textured.albedo_color = Color(0.8, 0.5, 0.3)
	textured.albedo_texture = load(TEXTURE)
	var cutout := StandardMaterial3D.new()
	cutout.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	cutout.alpha_scissor_threshold = 0.4
	cutout.cull_mode = BaseMaterial3D.CULL_DISABLED
	var blend := StandardMaterial3D.new()
	blend.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	var a := _box(character, textured, Vector3.ONE, "A")
	var b := _box(character, textured, Vector3.ONE, "B")
	var hair := _box(character, cutout, Vector3.ONE, "Hair")
	var lashes := _box(character, blend, Vector3.ONE, "Lashes")
	var kept := _box(character, textured, Vector3.ONE, "Kept")
	kept.set_meta("keep_material", true)
	# Anillo de afinidad del NPC (Visual/Body): lo tiñe npc.gd por material_override.
	var npc := Node3D.new()
	npc.add_to_group("npcs")
	var visual := Node3D.new()
	visual.name = "Visual"
	npc.add_child(visual)
	var ring_material := StandardMaterial3D.new()
	var ring := _box(visual, ring_material, Vector3.ONE, "Body")
	ring.material_override = ring_material
	character.add_child(npc)

	toon.apply(character, "character")

	var mat := a.get_surface_override_material(0) as ShaderMaterial
	check(mat != null, "apply convierte el StandardMaterial3D en ShaderMaterial")
	if mat:
		check(mat.get_shader_parameter("albedo") == textured.albedo_color, "conserva el color de albedo")
		check(mat.get_shader_parameter("albedo_texture") == textured.albedo_texture, "conserva la textura")
		check(mat.get_shader_parameter("use_texture") == true, "usa la textura")
		var outline := mat.next_pass as ShaderMaterial
		check(outline != null and outline.shader.resource_path == OUTLINE, "personaje: contorno como next_pass")
		check(mat.shader.resource_path.ends_with("toon.gdshader"), "opaco a una cara: variante toon base")
	check(b.get_surface_override_material(0) == mat, "caché: mismo material origen → mismo material toon")
	var hair_mat := hair.get_surface_override_material(0) as ShaderMaterial
	check(hair_mat != null and "cutout_double" in hair_mat.shader.resource_path,
		"alpha scissor + doble cara → variante cutout_double")
	if hair_mat:
		check(is_equal_approx(hair_mat.get_shader_parameter("alpha_scissor"), 0.4), "conserva el umbral de scissor")
		check(hair_mat.next_pass != null, "el pelo (MASK) lleva contorno")
	var lash_mat := lashes.get_surface_override_material(0) as ShaderMaterial
	check(lash_mat != null and "blend" in lash_mat.shader.resource_path, "transparencia → variante blend")
	check(lash_mat != null and lash_mat.next_pass == null, "lo transparente no lleva contorno")
	check(kept.get_surface_override_material(0) == null, "keep_material: no se toca")
	check(ring.material_override == ring_material and ring.get_surface_override_material(0) == null,
		"el anillo de afinidad del NPC (Visual/Body) no se toca")

	# Idempotente: una segunda pasada no cambia nada.
	toon.apply(character, "character")
	check(a.get_surface_override_material(0) == mat, "apply es idempotente")
	check(toon.convert_material(mat, "character") == mat, "convertir un material toon lo deja igual")
	character.free()


func _test_world(toon: GDScript) -> void:
	var world := Node3D.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.3, 0.3)
	var ground := _box(world, material, Vector3(20, 0.5, 20), "Ground")
	var crate := _box(world, material, Vector3(1, 1, 1), "Crate")
	var no_line := _box(world, material, Vector3(1, 1, 1), "NoLine")
	no_line.set_meta("toon_outline", false)
	toon.apply(world, "world")
	var ground_mat := ground.get_surface_override_material(0) as ShaderMaterial
	var crate_mat := crate.get_surface_override_material(0) as ShaderMaterial
	check(ground_mat != null and ground_mat.next_pass == null, "mundo: suelo grande sin contorno")
	check(crate_mat != null and crate_mat.next_pass != null, "mundo: objeto pequeño con contorno fino")
	if crate_mat and crate_mat.next_pass:
		check(crate_mat.next_pass.get_shader_parameter("outline_width") < 1.6, "el contorno del mundo es más fino")
	var no_line_mat := no_line.get_surface_override_material(0) as ShaderMaterial
	check(no_line_mat != null and no_line_mat.next_pass == null, "toon_outline = false quita el contorno")
	world.free()


func _test_styler() -> void:
	var main := await load_main()
	await process_frame
	var styler := main.get_node_or_null("ToonStyler")
	check(styler != null, "main.tscn tiene ToonStyler")
	# El mundo queda convertido al arrancar (salvo bombillas: las gobierna DayNight).
	var converted := 0
	for node in main.get_node("World").find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.name.begins_with("LampBulb"):
			check(mesh.material_override is StandardMaterial3D, "las bombillas conservan su material (DayNight)")
		elif mesh.get_surface_override_material(0) is ShaderMaterial:
			converted += 1
	check(converted > 10, "el World se convierte al estilo toon (%d mallas)" % converted)
	var lucia_ring: MeshInstance3D = main.get_node("Lucia/Visual/Body")
	check(lucia_ring.material_override is StandardMaterial3D, "el anillo de Lucía sigue siendo StandardMaterial3D")

	# Lo que aparece después: un peatón (personaje) y un paquete (mundo).
	var pedestrian := Node3D.new()
	pedestrian.add_to_group("pedestrians")
	var ped_mesh := _box(pedestrian, StandardMaterial3D.new())
	main.add_child(pedestrian)
	var parcel := Node3D.new()
	var parcel_mesh := _box(parcel, StandardMaterial3D.new(), Vector3(0.5, 0.5, 0.5))
	main.add_child(parcel)
	await process_frame
	await process_frame
	var ped_mat := ped_mesh.get_surface_override_material(0) as ShaderMaterial
	check(ped_mat != null, "el styler convierte un peatón añadido después")
	if ped_mat and ped_mat.next_pass:
		check(is_equal_approx(ped_mat.next_pass.get_shader_parameter("outline_width"), 1.6),
			"el peatón usa el contorno de personaje")
	else:
		check(false, "el peatón lleva contorno")
	check(parcel_mesh.get_surface_override_material(0) is ShaderMaterial, "el styler convierte un objeto añadido después")
	main.queue_free()
	await process_frame
