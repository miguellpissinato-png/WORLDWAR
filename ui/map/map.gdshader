// Pinta o mapa a partir de uma imagem de IDs (cada estado tem uma cor-código).
// - lookup (linha 0): cor do dono de cada estado; (linha 1): índice do dono + seleção
// - fronteiras de país: linha escura + faixa clara por dentro
// - fronteiras de estado: linha fina, some quando o mapa está afastado
// - oceano e terreno: texturas de ruído geradas no jogo
shader_type canvas_item;

uniform sampler2D lookup : filter_nearest;
uniform sampler2D land_noise : repeat_enable, filter_linear;
uniform sampler2D detail_noise : repeat_enable, filter_linear;
uniform sampler2D sea_noise : repeat_enable, filter_linear;
uniform vec2 tex_size;          // tamanho da imagem de IDs, em texels
uniform float texels_per_px = 1.0;   // quantos texels cabem em 1 pixel da tela (muda com o zoom)
uniform float state_border_alpha = 0.35;

varying vec2 world;

void vertex() {
	world = VERTEX;
}

int decode_id(vec4 c) {
	return int(round(c.r * 255.0)) + int(round(c.g * 255.0)) * 256;
}

int id_at(sampler2D ids, vec2 uv) {
	return decode_id(texture(ids, uv));
}

vec4 owner_color(int id) {
	return texelFetch(lookup, ivec2(id % 4096, 0), 0);
}

vec4 owner_info(int id) {
	return texelFetch(lookup, ivec2(id % 4096, 1), 0);
}

float owner_index(int id) {
	vec4 i = owner_info(id);
	return i.r * 255.0 + i.g * 255.0 * 256.0;
}

void fragment() {
	vec2 texel = 1.0 / tex_size;
	int id = id_at(TEXTURE, UV);
	bool land = id != 0;

	// Busca vizinhos em 8 direções, em 3 distâncias medidas em pixels da tela.
	const vec2 DIRS[8] = vec2[8](vec2(1.0, 0.0), vec2(-1.0, 0.0), vec2(0.0, 1.0), vec2(0.0, -1.0),
		vec2(0.707, 0.707), vec2(-0.707, 0.707), vec2(0.707, -0.707), vec2(-0.707, -0.707));
	float r_line = 1.6 * texels_per_px;     // fronteira de país (grossa)
	float r_state = 0.7 * texels_per_px;    // fronteira de estado (fina)
	float r_glow = 7.0 * texels_per_px;     // faixa clara por dentro / brilho da costa

	float me = land ? owner_index(id) : -1.0;
	bool country_edge = false;
	bool state_edge = false;
	bool coast = false;
	float glow = 0.0;
	float sea_glow = 0.0;
	for (int i = 0; i < 8; i++) {
		int n1 = id_at(TEXTURE, UV + DIRS[i] * r_line * texel);
		int n0 = id_at(TEXTURE, UV + DIRS[i] * r_state * texel);
		int n2 = id_at(TEXTURE, UV + DIRS[i] * r_glow * texel);
		int nm = id_at(TEXTURE, UV + DIRS[i] * r_glow * 0.5 * texel);
		if (land) {
			if (n1 == 0) coast = true;
			else if (owner_index(n1) != me) country_edge = true;
			if (n0 != 0 && n0 != id) state_edge = true;
			if (n2 != 0 && owner_index(n2) != me) glow += 0.08;
			if (nm != 0 && owner_index(nm) != me) glow += 0.1;
		} else {
			if (n1 != 0) coast = true;
			if (n2 != 0) sea_glow += 0.07;
			if (nm != 0) sea_glow += 0.09;
		}
	}

	vec2 w = world / tex_size * vec2(1.0, tex_size.y / tex_size.x);
	if (!land) {
		float n = texture(sea_noise, w * 5.0).r;
		float d = texture(detail_noise, w * 22.0).r;
		vec3 deep = vec3(0.13, 0.19, 0.27);
		vec3 shallow = vec3(0.26, 0.36, 0.47);
		vec3 sea = mix(deep, deep * 1.25, n) * (0.92 + 0.16 * d);
		sea = mix(sea, shallow, clamp(sea_glow, 0.0, 0.85));
		if (coast) sea = vec3(0.07, 0.09, 0.12);
		COLOR = vec4(sea, 1.0);
	} else {
		// Terreno: manchas grandes (relevo) + detalhe fino, em tons de cinza esverdeado.
		float relief = texture(land_noise, w * 6.0).r;
		float detail = texture(detail_noise, w * 30.0).r;
		vec3 terrain = mix(vec3(0.34, 0.36, 0.33), vec3(0.62, 0.60, 0.54), relief);
		terrain *= 0.85 + 0.3 * detail;

		vec3 owner = owner_color(id).rgb;
		vec3 col = mix(terrain, owner, 0.62) * (0.8 + 0.4 * relief);
		col = mix(col, owner * 1.35 + 0.08, clamp(glow, 0.0, 0.55));   // faixa clara junto à fronteira
		if (state_edge) col = mix(col, col * 0.55, state_border_alpha);
		if (country_edge) col = owner * 0.45;
		if (coast) col = vec3(0.08, 0.09, 0.11);
		if (owner_info(id).b > 0.5) col = mix(col, vec3(1.0), state_edge ? 0.85 : 0.35);  // estado selecionado
		COLOR = vec4(col, 1.0);
	}
}
