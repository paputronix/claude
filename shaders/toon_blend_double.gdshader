// Sombreado toon con mezcla alfa (BLEND) a dos caras. Cuerpo en toon.gdshaderinc.
shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
#define TOON_BLEND
#include "res://shaders/toon.gdshaderinc"
