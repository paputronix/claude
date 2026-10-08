// Sombreado toon con alpha scissor (MASK) a dos caras. Cuerpo en toon.gdshaderinc.
shader_type spatial;
render_mode cull_disabled;
#define TOON_CUTOUT
#include "res://shaders/toon.gdshaderinc"
