// Olta bükülmesi: modelin kendi uzunluk ekseni (model uzayında Z) boyunca,
// uca doğru artan bir eğrilikle esner. bend = 0 düz, 1 çok bükük.
// Renk modeldeki malzemeden gelir; yüzeyler low-poly (düz) gölgelenir.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_disabled;

uniform vec4 albedo : source_color = vec4(1.0);
uniform float bend = 0.0;
uniform float z0 = 0.0;      // sapın dibi (model uzayı)
uniform float len = 1.0;     // oltanın boyu (model uzayı)
uniform vec2 dir = vec2(0.0, 1.0);  // bükülme yönü (model uzayında XY)

void vertex() {
	float t = clamp((VERTEX.z - z0) / len, 0.0, 1.0);
	float k = t * t;
	VERTEX.xy += dir * bend * len * 0.55 * k;
	// Eğilen uç biraz geri çekilir: boy kabaca korunur.
	VERTEX.z -= bend * bend * len * 0.18 * k * t;
}

void fragment() {
	ALBEDO = albedo.rgb;
	NORMAL = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	ROUGHNESS = 1.0;
}
