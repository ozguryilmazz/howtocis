extends Node3D
## Model Training: yeni modelleri, animasyonları ve üçüncü şahıs kamerayı denemek için
## ayrı bölüm. Asıl oyunu etkilemez. Ana menüden açılır.
##
## Alan: çimenli düzlük, rampa, basamaklar, duvar (kamera kolunun kısalmasını görmek
## için), ağaç ve kayalar. Üstte animasyon tarayıcısı: modeldeki her animasyon oynatılabilir.

const FLAT := preload("res://shaders/flat.gdshader")
const TOUCH := preload("res://scripts/touch_controls.gd")
const PLAYER := preload("res://scripts/training_player.gd")
const MENU := preload("res://scripts/main_menu.gd")

const SKY := Color("F7E3C6")
const GRASS := Color("8DB255")
const GRASS_DARK := Color("7AA048")
const PATH := Color("D8C49A")
const STONE := Color("B4B2A9")
const WOOD := Color("A0703F")
const WHITE := Color("FAFAF5")
const ROOF := Color("D85A30")
const DARK := Color("4A2A12")

var player: CharacterBody3D
var _touch: Control
var _mats := {}
var _anims: Array = []
var _anim_i := 0
var _anim_label: Label
var _info: Label


func _ready() -> void:
	_build_environment()
	_build_ground()
	_build_props()
	player = PLAYER.new()
	player.position = Vector3(0, 0.1, 6)
	add_child(player)
	_build_ui()
	player.touch = _touch
	if "--otomatik" in OS.get_cmdline_user_args():
		_autopilot()


# --- Yardımcılar -----------------------------------------------------------

func mat(color: Color) -> ShaderMaterial:
	var key := color.to_html()
	if not _mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = FLAT
		m.set_shader_parameter("albedo", color)
		_mats[key] = m
	return _mats[key]


func block(size: Vector3, color: Color, pos: Vector3, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	b.material = mat(color)
	var mi := MeshInstance3D.new()
	mi.mesh = b
	mi.position = pos
	mi.rotation_degrees = rot_deg
	add_child(mi)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	body.add_child(shape)
	mi.add_child(body)
	return mi


func model(path: String, pos: Vector3, scl: float, yaw := 0.0) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var m: Node3D = (load(path) as PackedScene).instantiate()
	m.position = pos
	m.scale = Vector3.ONE * scl
	m.rotation_degrees.y = yaw
	add_child(m)
	return m


# --- Sahne -----------------------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("FFF4E0")
	env.ambient_light_energy = 0.6
	env.fog_enabled = true
	env.fog_light_color = SKY
	env.fog_density = 0.008
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("FFD9B0")
	sun.light_energy = 1.15
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.shadow_enabled = true
	add_child(sun)


func _build_ground() -> void:
	block(Vector3(90, 1, 90), GRASS, Vector3(0, -0.5, 0))
	# Dama desenli koyu kareler: yürürken hızı ve yönü görmek kolaylaşır.
	for x in range(-4, 5):
		for z in range(-4, 5):
			if (x + z) % 2 == 0:
				var q := MeshInstance3D.new()
				var pm := PlaneMesh.new()
				pm.size = Vector2(4, 4)
				pm.material = mat(GRASS_DARK)
				q.mesh = pm
				q.position = Vector3(x * 4, 0.005, z * 4)
				add_child(q)
	# Yürüme yolu
	var path := MeshInstance3D.new()
	var pp := PlaneMesh.new()
	pp.size = Vector2(3, 40)
	pp.material = mat(PATH)
	path.mesh = pp
	path.position = Vector3(0, 0.01, -8)
	add_child(path)


func _build_props() -> void:
	# Rampa ve üstünde platform
	block(Vector3(4, 0.4, 7), STONE, Vector3(-9, 0.95, -4), Vector3(-16, 0, 0))
	block(Vector3(5, 1.9, 5), STONE, Vector3(-9, 0.95, -10))
	# Basamaklar
	for i in 5:
		block(Vector3(3, 0.3 * (i + 1), 1.0), WOOD, Vector3(9, 0.15 * (i + 1), -2 - i))
	block(Vector3(3, 1.5, 4), WOOD, Vector3(9, 0.75, -9))
	# Duvar: kamera arkasına girince kol kısalır
	block(Vector3(10, 3, 0.6), WHITE, Vector3(0, 1.5, 14))
	block(Vector3(10.4, 0.3, 1.0), ROOF, Vector3(0, 3.1, 14))
	# Sandıklar (zıplama denemesi)
	block(Vector3(1.2, 1.0, 1.2), WOOD, Vector3(4, 0.5, 3))
	block(Vector3(1.2, 1.0, 1.2), WOOD, Vector3(5.4, 1.0, 3.2), Vector3(0, 20, 0))
	block(Vector3(1.2, 0.2, 1.2), WOOD, Vector3(5.4, 0.5 - 0.4, 3.2))
	# Ağaç ve kayalar (asıl oyunun modelleri)
	for p in [Vector3(-14, 0, 8), Vector3(14, 0, 10), Vector3(-16, 0, -18), Vector3(16, 0, -16)]:
		var t := model("res://models/nature/agac%d.glb" % (1 + int(p.x > 0)), p, 0.5, p.z * 10.0)
		if t:
			var body := StaticBody3D.new()
			var sh := CollisionShape3D.new()
			var c := CylinderShape3D.new()
			c.radius = 0.35
			c.height = 3.0
			sh.shape = c
			body.position = p + Vector3(0, 1.5, 0)
			body.add_child(sh)
			add_child(body)
	for p in [Vector3(-5, 0, 9), Vector3(12, 0, 4), Vector3(-13, 0, -2)]:
		var r := model("res://models/nature/kaya.glb", p, 1.2, p.x * 20.0)
		if r:
			for mi in r.find_children("*", "MeshInstance3D", true, false):
				(mi as MeshInstance3D).create_convex_collision()


# --- Arayüz ----------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_touch = TOUCH.new()
	layer.add_child(_touch)
	_touch.set_action("Vur")

	var back := Button.new()
	back.text = "◀ Menü"
	back.position = Vector2(16, 14)
	back.custom_minimum_size = Vector2(150, 64)
	back.add_theme_font_size_override("font_size", 26)
	MENU.style_button(back)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	layer.add_child(back)

	# Animasyon tarayıcısı (üst orta)
	_anims = Array(player.anim.get_animation_list())
	_anims.erase("RESET")
	_anim_i = maxi(0, maxi(_anims.find("Dance_Loop"), _anims.find("Dance")))
	var bar := HBoxContainer.new()
	bar.anchor_left = 0.5
	bar.anchor_right = 0.5
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.position.y = 14
	bar.add_theme_constant_override("separation", 8)
	layer.add_child(bar)
	bar.add_child(_small_button("◀", func(): _step(-1)))
	_anim_label = Label.new()
	_anim_label.custom_minimum_size = Vector2(330, 64)
	_anim_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_anim_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_anim_label.add_theme_font_size_override("font_size", 26)
	_anim_label.add_theme_color_override("font_color", DARK)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.85)
	sb.set_corner_radius_all(14)
	_anim_label.add_theme_stylebox_override("normal", sb)
	bar.add_child(_anim_label)
	bar.add_child(_small_button("▶", func(): _step(1)))
	bar.add_child(_small_button("Oynat", _play_selected, 130))

	_info = Label.new()
	_info.position = Vector2(16, 90)
	_info.add_theme_font_size_override("font_size", 18)
	_info.add_theme_color_override("font_color", DARK)
	layer.add_child(_info)

	var title := Label.new()
	title.text = "MODEL TRAINING"
	title.anchor_left = 1.0
	title.anchor_right = 1.0
	title.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	title.position.y = 26
	title.offset_right = -20
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", ROOF)
	title.add_theme_color_override("font_outline_color", Color.WHITE)
	title.add_theme_constant_override("outline_size", 8)
	layer.add_child(title)
	_step(0)


func _small_button(t: String, cb: Callable, w := 64) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(w, 64)
	b.add_theme_font_size_override("font_size", 26)
	MENU.style_button(b)
	b.pressed.connect(cb)
	return b


func _step(d: int) -> void:
	_anim_i = posmod(_anim_i + d, _anims.size())
	_anim_label.text = "%s  (%d/%d)" % [_anims[_anim_i], _anim_i + 1, _anims.size()]


func _play_selected() -> void:
	player.play_showcase(_anims[_anim_i])


func _process(_delta: float) -> void:
	if _info:
		_info.text = "Manken · %d üçgen · %d animasyon\nŞu an: %s\nSol: yürü · Sağı kaydır: kamera · Zıpla · Vur" % [
			_tris(), _anims.size(), player.anim.current_animation]


var _tri_cache := -1


func _tris() -> int:
	if _tri_cache < 0:
		_tri_cache = player.triangle_count()
	return _tri_cache


# --- Otomatik test: ekran görüntüleri (MODEL_SHOT=klasör) ---------------------

func _shot(name: String) -> void:
	var dir := OS.get_environment("MODEL_SHOT")
	print("[model] ", name, " anim=", player.anim.current_animation, " pos=", player.global_position)
	if dir != "":
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, name])


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _autopilot() -> void:
	await _wait(1.2)
	_shot("01_bekle")
	_touch.move_vector = Vector2(0, -0.45)
	await _wait(1.5)
	_shot("02_yuru")
	_touch.move_vector = Vector2(0, -1)
	await _wait(1.2)
	_shot("03_kos")
	# Geri dön: kamera dönmez, karakterin önü görünür.
	_touch.move_vector = Vector2(0, 1)
	await _wait(1.0)
	_shot("04_geri_on")
	_touch.move_vector = Vector2.ZERO
	await _wait(0.6)
	_touch._jump = true
	await _wait(0.35)
	_shot("05_zipla")
	await _wait(1.2)
	_touch._action_tap = true
	await _wait(0.25)
	_shot("06_yumruk")
	await _wait(0.8)
	# Kamerayı yandan çevir
	for i in 20:
		_touch._look += Vector2(-30, 0)
		await _wait(0.02)
	await _wait(0.4)
	_shot("07_kamera_yan")
	_play_selected()
	await _wait(1.0)
	_shot("08_dans")
	# Duvara doğru geri git: kamera kolu kısalmalı
	_touch._look += Vector2(600, 0)
	await _wait(0.3)
	player.global_position = Vector3(0, 0.1, 11)
	player.rotation.y = 0
	await _wait(0.6)
	_shot("09_duvar")
	get_tree().quit()
