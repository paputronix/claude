extends Node3D
## Mapa: bar, calle, casa de Lucía y parque. Todo primitivo (CSG con colisión).
## La navegación se hornea al arrancar a partir de los colisionadores estáticos,
## así no hay vértices horneados en la escena y basta con mover cajas en el editor.

@onready var _nav_region: NavigationRegion3D = $NavigationRegion3D


func _ready() -> void:
	_nav_region.bake_navigation_mesh(false)
