// Contorno por casco invertido (inverted hull): se usa como next_pass del material toon.
// Dibuja las caras traseras desplazadas por la normal en espacio de pantalla, así el
// grosor es estable en píxeles (escalado a 720p) y se adelgaza con la distancia.
// Color = albedo oscurecido y algo más saturado; se ilumina con el ambiente y el sol
// (tenue) para que de noche no brille.
// depth_draw_never lo manda a la pasada transparente (tras lo opaco): así no proyecta
// sombra (sin él, el contorno duplicaba las draw calls de las cascadas de sombra).
shader_type spatial;
render_mode cull_front, specular_disabled, depth_draw_never;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_texture = false;
uniform vec3 uv_scale = vec3(1.0);
uniform vec3 uv_offset = vec3(0.0);
// > 0: descarta donde el alfa de la textura no llega (pelo con MASK).
uniform float alpha_scissor : hint_range(0.0, 1.0) = 0.0;
// Grosor en píxeles a 720p.
uniform float outline_width : hint_range(0.0, 8.0) = 1.6;
// Distancia (m) a partir de la que el contorno empieza a adelgazar.
uniform float fade_distance = 6.0;
uniform float min_width_scale : hint_range(0.0, 1.0) = 0.35;
// Grosor mínimo en píxeles: por debajo de 1 px la línea sale a trazos.
uniform float min_width_px = 1.0;
// Cuánto se oscurece el albedo y cuánto se satura.
uniform float darken : hint_range(0.0, 1.0) = 0.35;
uniform float saturation : hint_range(0.0, 2.0) = 1.3;

void vertex() {
	UV = UV * uv_scale.xy + uv_offset.xy;
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec3 view_normal = normalize(MODELVIEW_NORMAL_MATRIX * NORMAL);
	vec2 dir = (PROJECTION_MATRIX * vec4(view_normal, 0.0)).xy * VIEWPORT_SIZE;
	float len = length(dir);
	dir = len > 0.0001 ? dir / len : vec2(0.0);
	float scale = clamp(fade_distance / max(clip.w, 0.001), min_width_scale, 1.0);
	float px = max(outline_width * scale * VIEWPORT_SIZE.y / 720.0, min_width_px);
	clip.xy += dir * px * 2.0 / VIEWPORT_SIZE * clip.w;
	POSITION = clip;
}

void fragment() {
	vec4 color = albedo;
	if (use_texture) {
		color *= texture(albedo_texture, UV);
	}
	if (alpha_scissor > 0.0 && color.a < alpha_scissor) {
		discard;
	}
	float grey = dot(color.rgb, vec3(0.3, 0.59, 0.11));
	vec3 rgb = clamp(mix(vec3(grey), color.rgb, saturation), 0.0, 1.0);
	ALBEDO = rgb * darken;
	ROUGHNESS = 1.0;
}

void light() {
	if (LIGHT_IS_DIRECTIONAL) {
		DIFFUSE_LIGHT += LIGHT_COLOR / PI * 0.5;
	}
}
