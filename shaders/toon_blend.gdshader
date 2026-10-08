// Sombreado toon con mezcla alfa (BLEND) y prepaso de profundidad. Cuerpo en toon.gdshaderinc.
shader_type spatial;
render_mode cull_back, depth_prepass_alpha;
#define TOON_BLEND
#include "res://shaders/toon.gdshaderinc"
