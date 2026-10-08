// Cuerpo común del sombreado toon (cel shading). Lo incluyen las variantes de
// `toon*.gdshader` (cambian solo render_mode y los #define de transparencia):
//   TOON_CUTOUT: alpha scissor (pelo/ropa MASK de VRoid).
//   TOON_BLEND: mezcla alfa (pestañas, cejas, BLEND de VRoid).
// Compatible con GL Compatibility: todo el sombreado va en light().

// --- Color base ---
uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_texture = false;
uniform vec3 uv_scale = vec3(1.0);
uniform vec3 uv_offset = vec3(0.0);
uniform float alpha_scissor : hint_range(0.0, 1.0) = 0.5;
// > 1 aviva el color de base (paleta anime saturada).
uniform float saturation : hint_range(0.0, 2.0) = 1.0;

// --- Bandas luz/sombra ---
// Umbral de N·L donde cambia de luz a sombra, y anchura del borde entre bandas.
uniform float shade_threshold : hint_range(-1.0, 1.0) = 0.05;
uniform float shade_softness : hint_range(0.0, 0.5) = 0.04;
// Tinte de la zona en sombra (fracción de la luz directa que sigue llegando, coloreada).
// Cálido en piel/personajes, frío-violáceo en el mundo: nunca gris.
uniform vec4 shadow_color : source_color = vec4(0.55, 0.52, 0.78, 1.0);
uniform float shadow_strength : hint_range(0.0, 1.0) = 0.45;
// Escala global de la luz directa (sin tonemapping: evita quemar los colores claros).
uniform float light_scale : hint_range(0.0, 2.0) = 0.85;
// Escala de las luces puntuales (farolas): sin el coseno de Lambert brillarían de más.
uniform float point_light_scale : hint_range(0.0, 2.0) = 0.65;

// --- Luz de borde (rim) ---
uniform float rim_strength : hint_range(0.0, 1.0) = 0.0;
uniform float rim_width : hint_range(0.0, 1.0) = 0.3;

// --- Brillo especular estilizado ---
uniform float specular_strength : hint_range(0.0, 1.0) = 0.0;
uniform float specular_size : hint_range(0.0, 1.0) = 0.15;

// --- Anillo de brillo del pelo (angel ring), en espacio de vista ---
uniform float hair_ring_strength : hint_range(0.0, 1.0) = 0.0;
uniform float hair_ring_height : hint_range(-1.0, 1.0) = 0.45;
uniform float hair_ring_width : hint_range(0.0, 0.5) = 0.08;

// --- Emisión (bombillas, ventanas de noche) ---
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;

void vertex() {
	UV = UV * uv_scale.xy + uv_offset.xy;
}

void fragment() {
	vec4 color = albedo;
	if (use_texture) {
		color *= texture(albedo_texture, UV);
	}
	float grey = dot(color.rgb, vec3(0.3, 0.59, 0.11));
	ALBEDO = clamp(mix(vec3(grey), color.rgb, saturation), 0.0, 1.0);
#if defined(TOON_CUTOUT)
	ALPHA = color.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor;
#elif defined(TOON_BLEND)
	ALPHA = color.a;
#endif
	METALLIC = 0.0;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	EMISSION = emission_color.rgb * emission_energy;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lit = smoothstep(shade_threshold - shade_softness, shade_threshold + shade_softness, ndl);
	vec3 shade = shadow_color.rgb * shadow_strength;
	vec3 radiance = LIGHT_COLOR / PI * light_scale;
	if (LIGHT_IS_DIRECTIONAL) {
		// La sombra proyectada también en dos bandas (sin degradado).
		float shadowed = smoothstep(0.3, 0.7, ATTENUATION);
		float band = lit * shadowed;
		// En sombra el tinte manda sobre el color del sol (violeta también al atardecer).
		float lum = dot(radiance, vec3(0.3, 0.59, 0.11));
		vec3 shade_light = shade * mix(radiance, vec3(lum), 0.7);
		DIFFUSE_LIGHT += mix(shade_light, radiance, band);
		float fresnel = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
		float rim = smoothstep(1.0 - rim_width, 1.0 - rim_width + 0.06, fresnel);
		DIFFUSE_LIGHT += radiance * rim * rim_strength * (0.35 + 0.65 * band);
		vec3 half_dir = normalize(LIGHT + VIEW);
		float spec = smoothstep(1.0 - specular_size * 0.1, 1.0 - specular_size * 0.1 + 0.005,
				max(dot(NORMAL, half_dir), 0.0));
		SPECULAR_LIGHT += radiance * spec * specular_strength * band;
		float ring = 1.0 - smoothstep(hair_ring_width * 0.5, hair_ring_width, abs(NORMAL.y - hair_ring_height));
		ring *= smoothstep(0.2, 0.5, dot(NORMAL, VIEW));
		DIFFUSE_LIGHT += radiance * ring * hair_ring_strength * (0.4 + 0.6 * band);
	} else {
		// Farolas: caída suave con la distancia, borde toon con la orientación.
		DIFFUSE_LIGHT += radiance * ATTENUATION * point_light_scale * mix(shade, vec3(1.0), lit);
	}
}
