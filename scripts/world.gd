extends Node3D
## Ege koyu: başlangıç kasabası. Sahne, low-poly temel şekillerden kod ile kurulur.
## Deniz -Z yönünde, kasaba ve tepe +Z yönündedir.

const FLAT := preload("res://shaders/flat.gdshader")
const WATER := preload("res://shaders/water.gdshader")
const PLAYER := preload("res://scripts/player.gd")
const TOUCH := preload("res://scripts/touch_controls.gd")
const FISHING := preload("res://scripts/fishing.gd")
const FISHING_HUD := preload("res://scripts/fishing_hud.gd")
const C := preload("res://scripts/creatures.gd")

const SKY := Color("F7E3C6")
const SAND := Color("D8C49A")
const HILL := Color("C9B48A")
const WHITE := Color("FAFAF5")
const ROOF := Color("D85A30")
const DOOR := Color("378ADD")
const WOOD := Color("A0703F")
const DARK_WOOD := Color("7A5A3A")
const OLIVE := Color("7C8B4A")
const ROCK := Color("B4B2A9")

const STALL := Vector3(5, 0.1, -4)
const SELL_RANGE := 4.0
const PIER_MIN := Vector2(-3.5, -33.0)
const PIER_MAX := Vector2(-0.5, -15.0)
const PIER_TOP := 0.475
## Kumsaldan iskeleye çıkan rampa (z: -15 → -11.5)
const RAMP_Z := Vector2(-15.0, -11.5)
const BEACH_CENTER := Vector2(0, 12)
const BEACH_RADIUS := 30.0

var player: CharacterBody3D
var fishing: Node3D
var hud: Control
var _mats := {}
var _money_label: Label
var _sell: Button


func _ready() -> void:
	_build_environment()
	_build_sea()
	_build_town()
	_build_distance()
	_spawn_player()
	_build_hud()


# --- Zemin ---------------------------------------------------------------

## Bir noktanın altındaki zeminin yüksekliği; altı denizse NAN.
func ground_height(p: Vector3) -> float:
	if p.x >= PIER_MIN.x and p.x <= PIER_MAX.x and p.z >= PIER_MIN.y and p.z <= PIER_MAX.y:
		return PIER_TOP
	if p.x >= PIER_MIN.x and p.x <= PIER_MAX.x and p.z > RAMP_Z.x and p.z <= RAMP_Z.y:
		return lerpf(PIER_TOP, 0.1, (p.z - RAMP_Z.x) / (RAMP_Z.y - RAMP_Z.x))
	if Vector2(p.x, p.z).distance_to(BEACH_CENTER) <= BEACH_RADIUS:
		return 0.1
	return NAN


func is_water(p: Vector3) -> bool:
	return is_nan(ground_height(p))


# --- Yardımcılar ---------------------------------------------------------

func mat(color: Color) -> ShaderMaterial:
	var key := color.to_html()
	if not _mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = FLAT
		m.set_shader_parameter("albedo", color)
		_mats[key] = m
	return _mats[key]


func add_mesh(mesh: Mesh, color: Color, pos: Vector3, rot_deg := Vector3.ZERO, collide := false) -> MeshInstance3D:
	mesh.material = mat(color)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot_deg
	add_child(mi)
	if collide:
		mi.create_convex_collision(true, true)
	return mi


func box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


func cyl(top: float, bottom: float, height: float, segments: int) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = segments
	m.rings = 0
	return m


func ball(radius: float, segments := 7, rings := 4) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = segments
	m.rings = rings
	return m


func sign_label(text: String, pos: Vector3, size := 64) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.outline_size = 12
	l.modulate = Color("4A2A12")
	l.outline_modulate = Color.WHITE
	l.pixel_size = 0.01
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = pos
	add_child(l)
	return l


# --- Sahne ---------------------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("FFF4E0")
	env.ambient_light_energy = 0.55
	env.fog_enabled = true
	env.fog_light_color = SKY
	env.fog_density = 0.006
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color("FFD9B0")
	sun.light_energy = 1.15
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.shadow_enabled = true
	add_child(sun)


func _build_sea() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(420, 420)
	plane.subdivide_width = 90
	plane.subdivide_depth = 90
	var m := ShaderMaterial.new()
	m.shader = WATER
	plane.material = m
	var sea := MeshInstance3D.new()
	sea.mesh = plane
	# Dalgalar en fazla ~0.29 yükselir; kumsalın üstü (y = 0.1) hep kuru kalır.
	sea.position = Vector3(0, -0.35, -80)
	add_child(sea)


func _house(pos: Vector3, w: float) -> void:
	add_mesh(box(Vector3(w, w * 0.9, w)), WHITE, pos + Vector3(0, w * 0.45, 0), Vector3.ZERO, true)
	add_mesh(cyl(0.0, w * 0.78, w * 0.55, 4), ROOF, pos + Vector3(0, w * 0.9 + w * 0.27, 0), Vector3(0, 45, 0))
	add_mesh(box(Vector3(w * 0.28, w * 0.5, 0.06)), DOOR, pos + Vector3(0, w * 0.25, -w * 0.5 - 0.03))
	add_mesh(box(Vector3(w * 0.22, w * 0.22, 0.06)), DOOR, pos + Vector3(w * 0.28, w * 0.6, -w * 0.5 - 0.03))


func _olive(pos: Vector3) -> void:
	add_mesh(cyl(0.12, 0.2, 1.4, 5), DARK_WOOD, pos + Vector3(0, 0.7, 0), Vector3.ZERO, true)
	add_mesh(ball(1.0), OLIVE, pos + Vector3(0, 1.8, 0))


func _build_town() -> void:
	# Kumsal (yürünebilir zemin). Üstü y = 0.1, kıyı çizgisi z ≈ -18.
	add_mesh(cyl(30, 31, 2, 18), SAND, Vector3(0, -0.9, 12), Vector3.ZERO, true)
	# Tepe ve üstündeki evler
	add_mesh(cyl(7, 20, 8, 12), HILL, Vector3(0, 4.0, 34), Vector3.ZERO, true)
	for h in [
		[Vector3(-7, 0.1, 16), 3.0], [Vector3(-2, 0.1, 19), 3.4], [Vector3(4, 0.1, 17), 3.0],
		[Vector3(9, 0.1, 15), 2.8], [Vector3(-12, 0.1, 13), 2.6], [Vector3(-3, 8.0, 34), 3.0],
		[Vector3(3, 8.0, 32), 2.6], [Vector3(-9, 3.4, 27), 2.8], [Vector3(9, 3.0, 26), 2.8],
	]:
		_house(h[0], h[1])
	for p in [Vector3(-15, 0.1, 6), Vector3(14, 0.1, 8), Vector3(-17, 0.1, 18), Vector3(17, 0.1, 19), Vector3(12, 0.1, -2)]:
		_olive(p)

	# Kahvehane: tenteli masa ve tabureler
	var kh := Vector3(-9, 0.1, 2)
	add_mesh(box(Vector3(6, 0.15, 4)), ROOF, kh + Vector3(0, 2.8, 0))
	for c in [Vector3(-2.8, 1.4, -1.8), Vector3(2.8, 1.4, -1.8), Vector3(-2.8, 1.4, 1.8), Vector3(2.8, 1.4, 1.8)]:
		add_mesh(cyl(0.08, 0.08, 2.8, 5), DARK_WOOD, kh + c)
	for t in [Vector3(-1.4, 0, 0), Vector3(1.4, 0, 0)]:
		add_mesh(cyl(0.6, 0.6, 0.08, 8), WHITE, kh + t + Vector3(0, 0.8, 0))
		add_mesh(cyl(0.06, 0.06, 0.8, 5), DARK_WOOD, kh + t + Vector3(0, 0.4, 0), Vector3.ZERO, true)
		add_mesh(cyl(0.07, 0.06, 0.16, 6), Color("C2410C"), kh + t + Vector3(0.15, 0.92, 0))
		for s in [Vector3(-0.9, 0, 0), Vector3(0.9, 0, 0)]:
			add_mesh(cyl(0.25, 0.25, 0.45, 6), WOOD, kh + t + s + Vector3(0, 0.22, 0))
	sign_label("Kahvehane", kh + Vector3(0, 3.6, 0))

	# Balıkçı Teyze'nin tezgâhı: balık burada satılır
	var st := STALL
	add_mesh(box(Vector3(3.4, 1.0, 1.2)), WOOD, st + Vector3(0, 0.5, 0), Vector3.ZERO, true)
	add_mesh(box(Vector3(3.8, 0.12, 1.8)), Color("378ADD"), st + Vector3(0, 2.4, -0.2))
	for x in [-1.7, 1.7]:
		add_mesh(cyl(0.06, 0.06, 2.4, 5), DARK_WOOD, st + Vector3(x, 1.2, 0.5))
	sign_label("Balıkçı Teyze", st + Vector3(0, 3.1, 0))
	sign_label("Balık alınır", st + Vector3(0, 1.4, -0.7), 40)

	# İskele denize doğru uzanır
	add_mesh(box(Vector3(3, 0.35, 18)), WOOD, Vector3(-2, 0.3, -24), Vector3.ZERO, true)
	# Rampa: kumsaldan iskeleye yürüyerek çıkılsın diye
	var ramp_len := RAMP_Z.y - RAMP_Z.x
	var slope := atan2(PIER_TOP - 0.1, ramp_len)
	add_mesh(box(Vector3(3, 0.2, ramp_len / cos(slope) + 0.1)), WOOD,
		Vector3(-2, (PIER_TOP + 0.1) * 0.5 - 0.1, (RAMP_Z.x + RAMP_Z.y) * 0.5), Vector3(rad_to_deg(slope), 0, 0), true)
	for z in range(-32, -15, 4):
		for x in [-3.4, -0.6]:
			add_mesh(cyl(0.14, 0.14, 2.2, 6), DARK_WOOD, Vector3(x, -0.6, z))

	# Kayık
	add_mesh(box(Vector3(1.6, 0.7, 4.0)), WHITE, Vector3(2.2, -0.15, -26), Vector3(0, 8, 0))
	add_mesh(box(Vector3(1.64, 0.16, 4.04)), DOOR, Vector3(2.2, 0.12, -26), Vector3(0, 8, 0))

	# Kıyı kayaları
	for r in [[Vector3(-20, 0.2, -12), 1.8], [Vector3(18, 0.1, -10), 1.4], [Vector3(-24, 0.0, 0), 2.2]]:
		add_mesh(ball(r[1], 5, 3), ROCK, r[0], Vector3(0, 30, 10), true)


func _build_distance() -> void:
	# Uzak adalar ve güneş
	for isl in [[Vector3(-70, -1.0, -150), 18.0], [Vector3(90, -1.0, -190), 24.0], [Vector3(10, -1.0, -260), 30.0]]:
		var p: Vector3 = isl[0]
		var r: float = isl[1]
		add_mesh(cyl(r * 0.4, r, r * 0.45, 9), HILL, p + Vector3(0, r * 0.22, 0))
		_house(p + Vector3(-r * 0.15, r * 0.44, r * 0.1), 3.0)
		_house(p + Vector3(r * 0.15, r * 0.4, -r * 0.05), 2.6)
	var sun_mat := StandardMaterial3D.new()
	sun_mat.albedo_color = Color("F0997B")
	sun_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sun_mat.disable_fog = true
	var sun_mesh := ball(14.0, 16, 8)
	sun_mesh.material = sun_mat
	var s := MeshInstance3D.new()
	s.mesh = sun_mesh
	s.position = Vector3(-140, 55, -320)
	add_child(s)


func _spawn_player() -> void:
	player = PLAYER.new()
	player.position = Vector3(-2, 0.2, -6)
	var args := OS.get_cmdline_user_args()
	# Geliştirme: "-- --kasaba" ile başlatılınca kamera kasabaya bakar (ekran görüntüsü için).
	if "--kasaba" in args:
		player.rotation.y = PI
	# Geliştirme: iskelenin ucundan başla.
	if "--iskele" in args or "--otomatik" in args:
		player.position = Vector3(-2, 0.6, -31)
	add_child(player)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	hud = FISHING_HUD.new()
	layer.add_child(hud)

	var touch := TOUCH.new()
	layer.add_child(touch)
	player.touch = touch

	fishing = FISHING.new()
	add_child(fishing)
	fishing.setup(self, player, touch, hud)
	fishing.autopilot = "--otomatik" in OS.get_cmdline_user_args()
	player.hp_changed.connect(hud.set_hp)
	Game.bucket_changed.connect(_update_bucket)
	_update_bucket()

	_sell = Button.new()
	_sell.anchor_left = 0.5
	_sell.anchor_right = 0.5
	_sell.offset_left = -330
	_sell.offset_right = 330
	_sell.offset_top = 64
	_sell.offset_bottom = 134
	_sell.add_theme_font_size_override("font_size", 28)
	preload("res://scripts/main_menu.gd").style_button(_sell)
	_sell.visible = false
	_sell.pressed.connect(_on_sell)
	layer.add_child(_sell)

	_money_label = Label.new()
	_money_label.position = Vector2(20, 16)
	_money_label.add_theme_font_size_override("font_size", 30)
	_money_label.add_theme_color_override("font_color", Color("854F0B"))
	_money_label.add_theme_color_override("font_outline_color", Color.WHITE)
	_money_label.add_theme_constant_override("outline_size", 10)
	layer.add_child(_money_label)
	_update_money(Game.money())
	Game.money_changed.connect(_update_money)

	var place := Label.new()
	place.text = "Ege Koyu  ·  %s" % Game.difficulty()["label"]
	place.anchor_left = 0.5
	place.anchor_right = 0.5
	place.offset_left = -200
	place.offset_right = 200
	place.offset_top = 18
	place.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	place.add_theme_font_size_override("font_size", 24)
	place.add_theme_color_override("font_color", Color("4A2A12"))
	place.add_theme_color_override("font_outline_color", Color.WHITE)
	place.add_theme_constant_override("outline_size", 8)
	layer.add_child(place)

	var menu := Button.new()
	menu.text = "Menü"
	menu.anchor_left = 1.0
	menu.anchor_right = 1.0
	menu.offset_left = -150
	menu.offset_right = -16
	menu.offset_top = 14
	menu.offset_bottom = 74
	menu.add_theme_font_size_override("font_size", 26)
	preload("res://scripts/main_menu.gd").style_button(menu)
	menu.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	layer.add_child(menu)


func _update_money(value: int) -> void:
	_money_label.text = "%s altın" % Game.format_money(value)


func _update_bucket() -> void:
	hud.set_bucket(_hand_text() if not Game.bucket().is_empty() else "Elin boş")


func _hand_text() -> String:
	var b := Game.bucket()
	var name := "%d balık" % b.size()
	if b.size() == 1:
		name = str(C.SPECIES.get(str(b[0].get("id", "")), {}).get("name", "Balık"))
	return "Elinde: %s · %s altın" % [name, Game.format_money(Game.bucket_value())]


func _process(_delta: float) -> void:
	var near := player.global_position.distance_to(STALL) < SELL_RANGE and not Game.bucket().is_empty()
	_sell.visible = near
	if near:
		_sell.text = "Sat: " + _hand_text().trim_prefix("Elinde: ")


func _on_sell() -> void:
	var got := Game.sell_all()
	hud.message("Balıkçı Teyze balığı aldı: +%s altın" % Game.format_money(got), 3.0)
