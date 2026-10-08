// Sombreado toon con alpha scissor (MASK). Cuerpo en toon.gdshaderinc.
shader_type spatial;
render_mode cull_back;
#define TOON_CUTOUT
#include "res://shaders/toon.gdshaderinc"
