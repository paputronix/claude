// Cielo anime: degradado limpio de tres tonos (horizonte → medio → cénit), disco del
// sol/luna suave con halo, nubes esponjosas procedurales que se mueven despacio y
// estrellas de noche. Los colores los conduce DayNight (scripts/world/day_night.gd)
// según la hora. Barato: unas pocas octavas de ruido de valor por píxel.
shader_type sky;

uniform vec3 top_color : source_color = vec3(0.16, 0.42, 0.88);
uniform vec3 mid_color : source_color = vec3(0.38, 0.64, 0.95);
uniform vec3 horizon_color : source_color = vec3(0.7, 0.86, 0.98);
uniform vec3 ground_color : source_color = vec3(0.32, 0.36, 0.42);
// Disco del sol (de noche, la luna: misma luz direccional).
uniform vec3 disk_color : source_color = vec3(1.0, 0.97, 0.88);
uniform float disk_size : hint_range(0.0, 0.2) = 0.045;
uniform float halo_strength : hint_range(0.0, 2.0) = 0.35;
// Nubes: color iluminado y color de la base en sombra.
uniform vec3 cloud_color : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 cloud_shade_color : source_color = vec3(0.72, 0.78, 0.94);
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.45;
uniform float cloud_softness : hint_range(0.01, 0.5) = 0.08;
uniform float cloud_scale = 1.4;
uniform vec2 cloud_speed = vec2(0.006, 0.002);
uniform float stars : hint_range(0.0, 1.0) = 0.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float sum = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 5; i++) {
		sum += value_noise(p) * amp;
		p = p * 2.03 + vec2(17.1, 9.3);
		amp *= 0.5;
	}
	return sum;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float h = dir.y;
	vec3 col;
	if (h >= 0.0) {
		float t = pow(h, 0.55);
		col = mix(horizon_color, mid_color, smoothstep(0.0, 0.35, t));
		col = mix(col, top_color, smoothstep(0.3, 0.95, t));
	} else {
		col = mix(horizon_color, ground_color, smoothstep(0.0, 0.12, -h));
	}

	// Estrellas: rejilla en la esfera, solo por encima del horizonte.
	if (stars > 0.0 && h > 0.0) {
		vec2 grid = vec2(atan(dir.x, dir.z) * 90.0, asin(h) * 90.0);
		vec2 cell = floor(grid);
		float r = hash12(cell);
		vec2 offset = vec2(hash12(cell + 7.7), hash12(cell + 3.1)) * 0.6 + 0.2;
		float dist = length(fract(grid) - offset);
		float star = step(0.985, r) * smoothstep(0.12, 0.0, dist);
		star *= 0.6 + 0.4 * sin(TIME * (1.0 + r * 3.0) + r * 40.0);
		col += vec3(star) * stars * smoothstep(0.0, 0.25, h);
	}

	// Sol/luna: disco de borde suave y halo.
	if (LIGHT0_ENABLED) {
		float d = dot(dir, LIGHT0_DIRECTION);
		float angle = acos(clamp(d, -1.0, 1.0));
		float disk = 1.0 - smoothstep(disk_size * 0.8, disk_size, angle);
		float halo = pow(max(d, 0.0), 24.0) * halo_strength;
		col = mix(col, disk_color, disk);
		col += disk_color * halo * (1.0 - disk);
	}

	// Nubes en un plano sobre la cámara: más densas hacia el cénit, se desvanecen en el horizonte.
	if (h > 0.0) {
		vec2 uv = dir.xz / (h + 0.12) * cloud_scale + TIME * cloud_speed;
		float n = fbm(uv);
		float threshold = 1.0 - cloud_coverage * 0.75 - 0.15;
		float body = smoothstep(threshold, threshold + cloud_softness, n);
		// Base en sombra: muestra desplazada hacia arriba en el ruido.
		float top = smoothstep(threshold + 0.06, threshold + 0.06 + cloud_softness, fbm(uv + vec2(0.04, 0.09)));
		vec3 cloud = mix(cloud_shade_color, cloud_color, top);
		float fade = smoothstep(0.02, 0.18, h);
		col = mix(col, cloud, body * fade);
	}

	COLOR = col;
}
