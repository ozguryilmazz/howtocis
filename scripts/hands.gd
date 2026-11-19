extends RefCounted
## Birinci şahıs eller ve olta: low-poly kutulardan kurulur, kameraya eklenir.
## Yumruk modeli: parmak eklemleri ileri (-Z), kol geriye (+Z) uzanır.
## Bir şeyi kavrarken nesne yumruğun içinden X ekseni boyunca geçer.

const FLAT := preload("res://shaders/flat.gdshader")

const SKIN := Color("E9B58C")
const SKIN_DARK := Color("CF9670")
const SLEEVE := Color("2F6FA8")
const CUFF := Color("F4F1EA")

static var _cache := {}


static func mat(color: Color) -> ShaderMaterial:
	var k := color.to_html()
	if not _cache.has(k):
		var m := ShaderMaterial.new()
		m.shader = FLAT
		m.set_shader_parameter("albedo", color)
		_cache[k] = m
	return _cache[k]


static func part(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	mesh.material = mat(color)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func box(parent: Node3D, size: Vector3, pos: Vector3, rot := Vector3.ZERO, color := SKIN) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return part(parent, b, color, pos, rot)


static func cyl(parent: Node3D, r_top: float, r_bot: float, h: float, seg: int, pos: Vector3, rot: Vector3, color: Color) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = seg
	c.rings = 0
	return part(parent, c, color, pos, rot)


static func capsule(parent: Node3D, r: float, h: float, pos: Vector3, rot: Vector3, color := SKIN) -> MeshInstance3D:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = maxf(h, r * 2.0)
	c.radial_segments = 6
	c.rings = 1
	return part(parent, c, color, pos, rot)


static func ball(parent: Node3D, r: float, pos: Vector3, scl := Vector3.ONE, color := SKIN) -> MeshInstance3D:
	var b := SphereMesh.new()
	b.radius = r
	b.height = r * 2.0
	b.radial_segments = 7
	b.rings = 4
	var mi := part(parent, b, color, pos)
	mi.scale = scl
	return mi


## Kapalı yumruk. left: sol el (başparmak diğer tarafta). arm: önkolun uzunluğu.
## Parmaklar üç boğumlu kapsüllerdir; avuç yuvarlatılmış, bilek incelir.
static func fist(left := false, arm := 0.26) -> Node3D:
	var h := Node3D.new()
	var s := -1.0 if left else 1.0
	# Avuç: kutu ve yuvarlak elin sırtı
	box(h, Vector3(0.082, 0.062, 0.07), Vector3(0, 0, 0.002))
	ball(h, 0.045, Vector3(0, 0.012, 0.004), Vector3(0.95, 0.55, 0.85))
	# Dört parmak: üst boğum ileri, orta boğum aşağı, uç boğum geriye kıvrık
	var lens := [0.036, 0.042, 0.04, 0.032]
	for i in 4:
		var x := (-0.03 + i * 0.02) * s
		var L: float = lens[i]
		ball(h, 0.0115, Vector3(x, 0.024, -0.03), Vector3.ONE, SKIN_DARK)  # eklem
		capsule(h, 0.0105, L, Vector3(x, 0.02, -0.03 - L * 0.4), Vector3(-80, 0, 0))
		capsule(h, 0.0098, 0.034, Vector3(x, -0.004, -0.032 - L * 0.8), Vector3(10, 0, 0))
		capsule(h, 0.009, 0.026, Vector3(x, -0.026, -0.046), Vector3(-70, 0, 0), SKIN_DARK)
	# Başparmak: avucun yanından çıkıp parmakların önüne kapanır
	ball(h, 0.02, Vector3(-0.038 * s, -0.012, -0.005), Vector3(0.9, 1.0, 1.3))
	capsule(h, 0.0115, 0.04, Vector3(-0.034 * s, -0.024, -0.03), Vector3(-60, 0, 25 * s))
	capsule(h, 0.0105, 0.034, Vector3(-0.014 * s, -0.034, -0.052), Vector3(0, 0, 80 * s))
	# Bilek ve önkol (bileğe doğru incelir), manşet ve gömlek kolu
	cyl(h, 0.03, 0.026, 0.05, 8, Vector3(0, -0.004, 0.055), Vector3(90, 0, 0), SKIN)
	cyl(h, 0.039, 0.03, arm, 8, Vector3(0, -0.004, 0.08 + arm * 0.5), Vector3(90, 0, 0), SKIN)
	cyl(h, 0.047, 0.047, 0.035, 8, Vector3(0, -0.004, 0.08 + arm), Vector3(90, 0, 0), CUFF)
	cyl(h, 0.052, 0.046, 0.22, 8, Vector3(0, -0.004, 0.2 + arm), Vector3(90, 0, 0), SLEEVE)
	return h


## Olta: sap Y ekseni boyunca, uç y = length. Sap mantar, gövde lacivert, makara gümüş.
## Makara oltanın sol yanındadır (-X); kolu dış yüzdedir.
## Döndürür: [kök düğüm, uç düğümü, makara kolu topuzu]
static func rod(length := 1.05) -> Array:
	var r := Node3D.new()
	# Mantar sap
	cyl(r, 0.017, 0.019, 0.26, 6, Vector3(0, 0.13, 0), Vector3.ZERO, Color("C8A26B"))
	cyl(r, 0.021, 0.021, 0.025, 6, Vector3(0, 0.005, 0), Vector3.ZERO, Color("2B2B2B"))
	# Makara yuvası ve makara (sapın altında)
	cyl(r, 0.014, 0.014, 0.05, 6, Vector3(0, 0.29, 0), Vector3.ZERO, Color("2B2B2B"))
	var reel := Node3D.new()
	reel.position = Vector3(-0.05, 0.29, 0)
	r.add_child(reel)
	# Ayak (oltaya bağlanır), makara gövdesi ve ipek sarılı bobin; ekseni X boyunca
	box(reel, Vector3(0.04, 0.02, 0.012), Vector3(0.025, 0, 0), Vector3.ZERO, Color("8D949E"))
	cyl(reel, 0.04, 0.04, 0.035, 10, Vector3(-0.005, 0, 0), Vector3(0, 0, 90), Color("C9CED6"))
	cyl(reel, 0.03, 0.03, 0.04, 10, Vector3(-0.005, 0, 0), Vector3(0, 0, 90), Color("E2A93B"))
	# Kol: dış yüzde, ucunda topuz
	box(reel, Vector3(0.008, 0.008, 0.055), Vector3(-0.028, 0, 0.025), Vector3.ZERO, Color("8D949E"))
	cyl(reel, 0.009, 0.009, 0.03, 6, Vector3(-0.042, 0, 0.05), Vector3(0, 0, 90), Color("2B2B2B"))
	var knob := Node3D.new()
	knob.position = reel.position + Vector3(-0.045, 0, 0.05)
	r.add_child(knob)
	# Gövde: incelen lacivert çubuk
	var blank_len := length - 0.32
	cyl(r, 0.004, 0.011, blank_len, 6, Vector3(0, 0.32 + blank_len * 0.5, 0), Vector3.ZERO, Color("1F3A5F"))
	# Misina halkaları
	for i in 4:
		var y := 0.42 + i * (blank_len - 0.12) / 3.0
		var rr := 0.013 - i * 0.002
		cyl(r, rr, rr, 0.004, 8, Vector3(0, y, 0.018), Vector3(90, 0, 0), Color("C9CED6"))
	var tip := Node3D.new()
	tip.position = Vector3(0, length, 0.01)
	r.add_child(tip)
	return [r, tip, knob]
