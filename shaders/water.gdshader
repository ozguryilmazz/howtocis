// Ege denizi: dalgalanan, low-poly yüzeyli su.
shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

uniform vec4 water_color : source_color = vec4(0.235, 0.553, 0.749, 1.0);
uniform float wave_height = 0.16;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(w.x * 0.25 + TIME * 1.2) * wave_height
		+ cos(w.z * 0.3 + TIME) * wave_height * 0.8;
}

void fragment() {
	ALBEDO = water_color.rgb;
	NORMAL = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	ROUGHNESS = 0.35;
	METALLIC = 0.0;
}
