extends SceneTree
## Genera `anim_library.res` (AnimationLibrary compartida) a partir de `anims.glb` ya
## retargeteado al perfil humanoide (ver anims.glb.import). Ejecutar tras cambiar el import:
##   godot --headless --path . -s res://assets/characters/anime/retarget/build_anim_library.gd
## Las pistas quedan como `%GeneralSkeleton:<hueso del perfil>`: sirven en cualquier modelo
## importado con el mismo BoneMap/perfil (los VRoid, ver vroid_bone_map.tres).

const SOURCE := "res://assets/characters/anime/anims.glb"
const OUTPUT := "res://assets/characters/anime/anim_library.res"
## nombre limpio → [animación de origen, en bucle]
const CLIPS := {
	"idle": ["Idle", true],
	"walk": ["Walk", true],
	"run": ["Jog_Fwd", true],
	"talk": ["Idle_Talking", true],
	"interact": ["Interact", false],
	"pickup": ["PickUp_Table", false],
	"sit_enter": ["Sitting_Enter", false],
	"sit_idle": ["Sitting_Idle", true],
	"sit_talk": ["Sitting_Talking", true],
	"sit_exit": ["Sitting_Exit", false],
	"dance": ["Dance", true],
}


func _initialize() -> void:
	var scene: Node = load(SOURCE).instantiate()
	var source: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
	var library := AnimationLibrary.new()
	for clip in CLIPS:
		var from: String = CLIPS[clip][0]
		var animation := source.get_animation(from).duplicate(true) as Animation
		animation.resource_name = clip
		animation.loop_mode = Animation.LOOP_LINEAR if CLIPS[clip][1] else Animation.LOOP_NONE
		if CLIPS[clip][1]:
			_strip_root_motion(animation)
		library.add_animation(clip, animation)
		print("%s <- %s (%.2f s, %d pistas)" % [clip, from, animation.length, animation.get_track_count()])
	scene.free()
	var err := ResourceSaver.save(library, OUTPUT, ResourceSaver.FLAG_COMPRESS)
	print("Guardado %s: %s" % [OUTPUT, error_string(err)])
	quit(0 if err == OK else 1)


## Bucles: son "in place", pero por si acaso: se quita la deriva lineal de las caderas
## en XZ (el desplazamiento lo da el CharacterBody3D); se conserva la altura (sentarse, botar).
func _strip_root_motion(animation: Animation) -> void:
	for track in animation.get_track_count():
		if animation.track_get_type(track) != Animation.TYPE_POSITION_3D:
			continue
		if not String(animation.track_get_path(track)).ends_with(":Hips"):
			continue
		var count := animation.track_get_key_count(track)
		if count < 2:
			continue
		var start: Vector3 = animation.track_get_key_value(track, 0)
		var end: Vector3 = animation.track_get_key_value(track, count - 1)
		var drift := Vector3(end.x - start.x, 0.0, end.z - start.z)
		if drift.length() > 0.01:
			print("  deriva de caderas %s en %s" % [drift, animation.resource_name])
		var values: Array[Vector3] = []
		for key in count:
			var t := animation.track_get_key_time(track, key) / maxf(animation.length, 0.001)
			values.append(animation.track_get_key_value(track, key) - drift * t)
		for key in count:
			animation.track_set_key_value(track, key, values[key])
