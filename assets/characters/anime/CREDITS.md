# Créditos — personajes anime y animaciones

## Personajes: VRoid Project (pixiv), modelos de muestra
Licencia incluida en cada modelo (metadatos VRM): uso por cualquiera, redistribución y modificación permitidas, uso comercial permitido, crédito no necesario.
Descargados de https://opengameart.org/content/vroid-studio-cc0-models

| Fichero | Original | Papel |
|---|---|---|
| `player.glb` | Sakurada Fumiriya (桜田 史利矢) | Jugador |
| `lucia.glb` | AvatarSample_D (千駄ヶ谷渋) | Lucía |
| `carla.glb` | AvatarSample_G (ヴィクトリア・ルービン) | Carla |
| `ped_a.glb` | AvatarSample_E (ビビ) | Peatón |
| `ped_b.glb` | AvatarSample_F (ヴィータ) | Peatón |
| `ped_c.glb` | Sendagaya Shino (千駄ヶ谷篠) | Peatón |

Modificaciones: texturas reducidas (1024 px protagonistas, 512 px peatones), solo 7 expresiones faciales en protagonistas (alegría, enfado, tristeza, diversión, sorpresa, parpadeo, boca abierta) y ninguna en peatones, sin colores por vértice (el modelo masculino los traía a cero y Godot lo dibujaba transparente).
Hito 5: la articulación `Root` girada 180° en Y (miran a +Z, como pide el perfil humanoide de Godot para retargetear; el juego los vuelve a girar) y los nombres de los morphs copiados a `mesh.extras.targetNames` (Godot 4.3 no lee los de la primitiva).

## Animaciones: Universal Animation Library (Standard) de Quaternius — CC0 1.0
https://quaternius.itch.io/universal-animation-library
`anims.glb` conserva 13 de las 43 animaciones: Idle_Loop, Walk_Loop, Jog_Fwd_Loop, Sprint_Loop, Idle_Talking_Loop, Interact, PickUp_Table, Sitting_Enter, Sitting_Idle_Loop, Sitting_Talking_Loop, Sitting_Exit, Dance_Loop, A_TPose. Esqueleto del maniquí de Unreal (sin malla).

## Retargeting (Hito 5)
- `retarget/vroid_bone_map.tres` y `retarget/mannequin_bone_map.tres`: BoneMap de cada esqueleto al `SkeletonProfileHumanoid`, referenciados desde los `.glb.import` (renombrar huesos, esqueleto único `%GeneralSkeleton`, rest fixer con overwrite axis; `anims.glb` además con fix silhouette).
- `anim_library.res`: AnimationLibrary compartida con nombres limpios (idle, walk, run, talk, interact, pickup, sit_enter, sit_idle, sit_talk, sit_exit, dance). Se regenera con `retarget/build_anim_library.gd` si cambia el import de `anims.glb`.
