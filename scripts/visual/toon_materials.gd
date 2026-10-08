class_name ToonMaterials
extends RefCounted
## Estilo anime (cel shading + contorno).
## `apply(root, role)` convierte los materiales de todas las MeshInstance3D bajo `root`
## (incluido `root`) al material toon (`shaders/toon*.gdshader`), conservando color,
## textura de albedo, modo de transparencia y cull. Idempotente; caché por material origen.
## role: "character" (contorno marcado, sombra de piel cálida) | "world" (contorno fino,
## sombra fría-violácea, sin contorno en suelos grandes).
##
## No toca:
## - nodos con `set_meta("keep_material", true)` (materiales que mutan los scripts);
## - el anillo de afinidad del NPC (`Visual/Body`, lo tiñe npc.gd);
## - `material_override` de modelos cuya skin gestiona un script (`set_skin`).
## `set_meta("toon_outline", false)` en un nodo le quita el contorno.
##
## Coste: el contorno es un next_pass (inverted hull) = una draw call más por superficie
## con contorno (no entra en las pasadas de sombra). Las superficies transparentes
## (BLEND) y los ojos/cara no llevan.

const META_KEEP := "keep_material"
const META_OUTLINE := "toon_outline"
## Marca en los ShaderMaterial generados (y su material origen).
const META_TOON := "toon_source"

const SHADER_DIR := "res://shaders/"
const OUTLINE_SHADER := preload("res://shaders/outline.gdshader")

## Perfiles por rol: uniforms del material toon y del contorno.
const PROFILES := {
	"character": {
		"shadow_color": Color(0.98, 0.7, 0.68), "shadow_strength": 0.5,
		"shade_threshold": 0.0, "shade_softness": 0.03,
		"rim_strength": 0.2, "rim_width": 0.28, "light_scale": 0.72, "saturation": 1.0,
		"outline_width": 1.6, "outline_darken": 0.35,
	},
	"world": {
		"shadow_color": Color(0.42, 0.45, 0.86), "shadow_strength": 0.5,
		"shade_threshold": 0.05, "shade_softness": 0.04,
		"rim_strength": 0.0, "rim_width": 0.3, "light_scale": 0.85, "saturation": 1.15,
		"outline_width": 1.0, "outline_darken": 0.3,
	},
}
## Superficies que no llevan contorno en personajes (ojos, boca, cejas: sufijos de VRoid).
const NO_OUTLINE_SUFFIXES := ["_EYE", "_FACE"]
## Mundo: superficie plana (alto < FLAT_RATIO × lado menor) y grande (> FLAT_MIN_SIZE m)
## = suelo/calzada, sin contorno.
const FLAT_RATIO := 0.2
const FLAT_MIN_SIZE := 4.0

## Caché: clave "<id origen>|<rol>|<contorno>" → ShaderMaterial.
static var _cache := {}
static var _shaders := {}


static func apply(root: Node, role := "world") -> void:
	if root == null:
		return
	var meshes: Array[Node] = []
	if root is MeshInstance3D:
		meshes.append(root)
	meshes.append_array(root.find_children("*", "MeshInstance3D", true, false))
	for node in meshes:
		apply_mesh(node as MeshInstance3D, role)


## Convierte los materiales de una sola MeshInstance3D.
static func apply_mesh(mesh_instance: MeshInstance3D, role := "world") -> void:
	if mesh_instance == null or mesh_instance.mesh == null or _is_kept(mesh_instance):
		return
	var outline := _wants_outline(mesh_instance, role)
	for i in mesh_instance.mesh.get_surface_count():
		var source := mesh_instance.get_surface_override_material(i)
		if source == null:
			source = mesh_instance.mesh.surface_get_material(i)
		var toon := convert_material(source, role, outline)
		if toon != source:
			mesh_instance.set_surface_override_material(i, toon)
	var override := mesh_instance.material_override
	if override != null and not _skin_managed(mesh_instance):
		mesh_instance.material_override = convert_material(override, role, outline)


## Material toon equivalente a `source` (cacheado). Devuelve `source` si no es un
## BaseMaterial3D o si ya es toon.
static func convert_material(source: Material, role := "world", outline := true) -> Material:
	if source == null or is_toon(source) or not source is BaseMaterial3D:
		return source
	var base := source as BaseMaterial3D
	var profile: Dictionary = PROFILES.get(role, PROFILES.world)
	var transparent := base.transparency in [BaseMaterial3D.TRANSPARENCY_ALPHA,
			BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS]
	if transparent or (role == "character" and _no_outline_name(base.resource_name)):
		outline = false
	var key := "%d|%s|%s" % [source.get_instance_id(), role, outline]
	if _cache.has(key):
		return _cache[key]
	var material := ShaderMaterial.new()
	material.resource_name = base.resource_name
	material.shader = _shader_for(base)
	material.set_meta(META_TOON, source)
	_copy_base(base, material)
	for param in ["shadow_color", "shadow_strength", "shade_threshold", "shade_softness",
			"rim_strength", "rim_width", "light_scale", "saturation"]:
		material.set_shader_parameter(param, profile[param])
	if role == "character":
		_tune_character(base.resource_name, material)
	if outline:
		var pass_material := ShaderMaterial.new()
		pass_material.shader = OUTLINE_SHADER
		_copy_base(base, pass_material)
		var cutout := base.transparency in [BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR,
				BaseMaterial3D.TRANSPARENCY_ALPHA_HASH]
		pass_material.set_shader_parameter("alpha_scissor", base.alpha_scissor_threshold if cutout else 0.0)
		pass_material.set_shader_parameter("outline_width", profile.outline_width)
		pass_material.set_shader_parameter("darken", profile.outline_darken)
		material.next_pass = pass_material
	_cache[key] = material
	return material


static func is_toon(material: Material) -> bool:
	return material is ShaderMaterial and material.has_meta(META_TOON)


## Color/textura/UV comunes al material toon y al contorno.
static func _copy_base(base: BaseMaterial3D, material: ShaderMaterial) -> void:
	material.set_shader_parameter("albedo", base.albedo_color)
	material.set_shader_parameter("use_texture", base.albedo_texture != null)
	if base.albedo_texture != null:
		material.set_shader_parameter("albedo_texture", base.albedo_texture)
	material.set_shader_parameter("uv_scale", base.uv1_scale)
	material.set_shader_parameter("uv_offset", base.uv1_offset)
	if material.shader != OUTLINE_SHADER:
		material.set_shader_parameter("alpha_scissor", base.alpha_scissor_threshold)
		if base.emission_enabled:
			material.set_shader_parameter("emission_color", base.emission)
			material.set_shader_parameter("emission_energy", base.emission_energy_multiplier)
		material.render_priority = base.render_priority


## Ajustes por tipo de superficie VRoid: cara casi sin banda de sombra, anillo en el pelo.
static func _tune_character(surface_name: String, material: ShaderMaterial) -> void:
	if "Face" in surface_name and "SKIN" in surface_name:
		material.set_shader_parameter("shade_threshold", -0.35)
		material.set_shader_parameter("shade_softness", 0.12)
	elif "HAIR" in surface_name or "Hair" in surface_name:
		material.set_shader_parameter("hair_ring_strength", 0.22)
		material.set_shader_parameter("shadow_color", Color(0.78, 0.68, 0.9))


static func _shader_for(base: BaseMaterial3D) -> Shader:
	var variant := "toon"
	match base.transparency:
		BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR, BaseMaterial3D.TRANSPARENCY_ALPHA_HASH:
			variant += "_cutout"
		BaseMaterial3D.TRANSPARENCY_ALPHA, BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS:
			variant += "_blend"
	if base.cull_mode == BaseMaterial3D.CULL_DISABLED:
		variant += "_double"
	if not _shaders.has(variant):
		_shaders[variant] = load(SHADER_DIR + variant + ".gdshader")
	return _shaders[variant]


static func _is_kept(node: Node) -> bool:
	if node.get_meta(META_KEEP, false):
		return true
	# Anillo de afinidad del NPC: npc.gd lo tiñe por material_override.
	var parent := node.get_parent()
	return node.name == "Body" and parent != null and parent.name == "Visual" \
			and parent.get_parent() != null and parent.get_parent().is_in_group("npcs")


## El material_override lo pone (y lo cambia) un script de skin: no se toca.
static func _skin_managed(node: Node) -> bool:
	var current := node.get_parent()
	while current != null:
		if current.has_method("set_skin"):
			return true
		current = current.get_parent()
	return false


static func _wants_outline(mesh_instance: MeshInstance3D, role: String) -> bool:
	if not mesh_instance.get_meta(META_OUTLINE, true):
		return false
	if role == "character":
		return true
	var size := mesh_instance.get_aabb().size
	if mesh_instance.is_inside_tree():
		size *= mesh_instance.global_transform.basis.get_scale()
	var flat := size.y < FLAT_RATIO * minf(size.x, size.z)
	return not (flat and maxf(size.x, size.z) > FLAT_MIN_SIZE)


static func _no_outline_name(surface_name: String) -> bool:
	for suffix: String in NO_OUTLINE_SUFFIXES:
		if surface_name.ends_with(suffix):
			return true
	return false
