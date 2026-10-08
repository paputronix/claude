class_name ToonMaterials
extends RefCounted
## Estilo anime (cel shading + contorno). STUB (Ola 0 del Hito 5): API fija,
## implementación en `claude/ligar-anime-shader`.
## `apply(root, role)` convierte los materiales de todas las MeshInstance3D bajo `root`
## al material toon, conservando color y textura de albedo. Idempotente.
## role: "character" (contorno más marcado, sombra de piel cálida) | "world".


static func apply(_root: Node, _role := "world") -> void:
	pass
