shader_type spatial;

// Tournament-ring stone tiles in world XZ: per-tile tint variation, dark grout, light wear.

uniform vec3 stone_a : source_color = vec3(0.78, 0.74, 0.66);
uniform vec3 stone_b : source_color = vec3(0.66, 0.62, 0.55);
uniform vec3 grout : source_color = vec3(0.32, 0.3, 0.27);
uniform float tile_size = 2.2;
uniform float grout_width = 0.015;

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = world_pos.xz / tile_size;
	vec2 cell = floor(uv);
	vec2 f = fract(uv);
	float edge = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
	float g = smoothstep(grout_width, grout_width + 0.02, edge);
	float h = hash(cell);
	vec3 stone = mix(stone_a, stone_b, h);
	float speck = hash(floor(uv * 24.0)) * 0.06;
	ALBEDO = mix(grout, stone - speck, g);
	ROUGHNESS = mix(0.95, 0.75, g);
}
