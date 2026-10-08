extends Node3D
## Mapa: bar, calle, casa de Lucía y parque, con estética de ciudad de anime.
## Todo primitivo (StaticBody3D + MeshInstance3D + CollisionShape3D, sin CSG).
## La navegación se hornea al arrancar a partir de los colisionadores estáticos,
## así no hay vértices horneados en la escena y basta con mover cajas en el editor.
## Decorado: el nodo `Anime` agrupa lo que no tiene colisión (ventanas, rótulos, cables,
## flores...); lo que se puede pisar o estorba cuelga de `NavigationRegion3D`.
## Los cristales de ventana están en el grupo `window_glass` (el ciclo día/noche los enciende).
## `scenes/world/world.tscn` se generó con un script; edítalo a mano con normalidad.

const PedestrianSpawner := preload("res://scripts/pedestrians/pedestrian_spawner.gd")

@onready var _nav_region: NavigationRegion3D = $NavigationRegion3D


func _ready() -> void:
	_nav_region.bake_navigation_mesh(false)
	add_child(PedestrianSpawner.new())  # peatones de ambiente
