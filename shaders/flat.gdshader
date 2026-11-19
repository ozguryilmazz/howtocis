// Low-poly görünüm: her yüzey tek renk ve keskin kenarlı (flat shading).
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform vec4 albedo : source_color = vec4(1.0);

void fragment() {
	ALBEDO = albedo.rgb;
	NORMAL = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	ROUGHNESS = 1.0;
}
