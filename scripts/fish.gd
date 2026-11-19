extends Node3D
## Oltaya takılan canlı. Durumlar:
##   hang   : oltanın ucunda asılı, çırpınır
##   fall   : bırakıldı, düşüyor (havadayken vurulamaz)
##   ground : yerde zıplaya zıplaya kaçışır; yumrukla vurulur
##   dead   : öldü, yerde yatar; oyuncu "Al" ile eline alır
##   held   : oyuncunun elinde (yalnızca görüntü)
##   gone   : suya kaçtı

signal died
signal escaped(reason: String)
signal attacked(damage: float)
signal inked

const FLAT := preload("res://shaders/flat.gdshader")
const C := preload("res://scripts/creatures.gd")

const WATER_Y := -0.3

var species := "istavrit"
var info: Dictionary = {}
var size_mult := 1.0
var shiny := false
var hp := 1
var max_hp := 1
var hits := 0
var length := 0.4
var velocity := Vector3.ZERO
var gravity := 9.0
var state := "hang"
## Zıplama gücü çarpanı (zorluğa göre fishing.gd ayarlar).
var hop_scale := 1.0
var world: Node = null
var player: Node3D = null

var _spin := Vector3.ZERO
var _t := 0.0
## Havada mı (zıplama, düşme)? Hız sıfırdan geçerken durmasın diye ayrı tutulur.
var _airborne := false
var _flop_timer := 0.0
var _bite_timer := 1.0
var _flash := 0.0
var _visual: Node3D
var _label: Label3D
var _mats: Array[ShaderMaterial] = []
var _inked := false
## Model dosyalı türler için
var _anim: AnimationPlayer = null
var _model_meshes: Array = []
var _flash_mat: StandardMaterial3D = null


func setup(p_world: Node, p_player: Node3D, p_species: String, p_size: float, p_shiny: bool) -> void:
	world = p_world
	player = p_player
	species = p_species
	info = C.SPECIES[species]
	size_mult = p_size
	shiny = p_shiny
	var hp_mult := float(Game.difficulty()["creature_hp"])
	max_hp = maxi(1, int(round(int(info["hp"]) * hp_mult)))
	hp = max_hp
	length = float(info["cm"]) / 100.0 * size_mult * 1.6  # oyunda görünsün diye biraz büyük
	_build()


func head_position() -> Vector3:
	return _visual.global_transform * Vector3(0, 0, -length * 0.4)


func radius() -> float:
	return length * 0.3


func _mat(color: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FLAT
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("glow", 0.45)
	_mats.append(m)
	return m


func _part(mesh: Mesh, color: Color, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	mesh.material = _mat(color)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = scl
	_visual.add_child(mi)
	return mi


func _build() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	var body := Color(info["body"])
	var fin := Color(info["fin"])
	if shiny:
		body = Color("F2C94C")
		fin = Color("E8A33D")
		var glow := OmniLight3D.new()
		glow.light_color = Color("FFE08A")
		glow.light_energy = 1.5
		glow.omni_range = 3.0
		add_child(glow)
	var L := length

	if info["shape"] == "model":
		_build_model(L)
	elif info["shape"] == "squid":
		var mantle := CylinderMesh.new()
		mantle.top_radius = 0.0
		mantle.bottom_radius = L * 0.22
		mantle.height = L * 0.7
		mantle.radial_segments = 7
		mantle.rings = 0
		_part(mantle, body, Vector3(0, 0, -L * 0.1), Vector3(-90, 0, 0))
		for i in 6:
			var a := TAU * i / 6.0
			var t := CylinderMesh.new()
			t.top_radius = L * 0.03
			t.bottom_radius = L * 0.012
			t.height = L * 0.45
			t.radial_segments = 4
			t.rings = 0
			_part(t, fin, Vector3(cos(a) * L * 0.1, sin(a) * L * 0.1, L * 0.45), Vector3(90, 0, 0))
		for s in [-1, 1]:
			var e := SphereMesh.new()
			e.radius = L * 0.05
			e.height = L * 0.1
			e.radial_segments = 6
			e.rings = 3
			_part(e, Color("1B1B1B"), Vector3(s * L * 0.17, L * 0.05, L * 0.2))
	else:
		var tall := 0.75 if info["shape"] == "round" else 0.5
		var b := SphereMesh.new()
		b.radius = 0.5
		b.height = 1.0
		b.radial_segments = 8
		b.rings = 4
		_part(b, body, Vector3.ZERO, Vector3.ZERO, Vector3(L * 0.28, L * tall * 0.7, L * 0.8))
		var tail := CylinderMesh.new()
		tail.top_radius = 0.0
		tail.bottom_radius = L * 0.22
		tail.height = L * 0.3
		tail.radial_segments = 3
		tail.rings = 0
		_part(tail, fin, Vector3(0, 0, L * 0.45), Vector3(-90, 0, 0), Vector3(0.25, 1, 1))
		var dorsal := CylinderMesh.new()
		dorsal.top_radius = 0.0
		dorsal.bottom_radius = L * 0.12
		dorsal.height = L * 0.16
		dorsal.radial_segments = 3
		dorsal.rings = 0
		_part(dorsal, fin, Vector3(0, L * tall * 0.33, L * 0.05), Vector3.ZERO, Vector3(0.2, 1, 1.6))
		for s in [-1, 1]:
			var e := SphereMesh.new()
			e.radius = L * 0.045
			e.height = L * 0.09
			e.radial_segments = 6
			e.rings = 3
			_part(e, Color("1B1B1B"), Vector3(s * L * 0.12, L * 0.06, -L * 0.28))

	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.fixed_size = true
	_label.pixel_size = 0.0012
	_label.font_size = 40
	_label.outline_size = 10
	_label.outline_modulate = Color.WHITE
	_label.modulate = Color("4A2A12")
	_label.position = Vector3(0, L * 0.5 + 0.25, 0)
	add_child(_label)
	_update_label()
	_spin = Vector3(randf_range(-5, 5), randf_range(-3, 3), randf_range(-6, 6))


## glb modelini yükler: boyu ayarlar, burnu -Z'ye çevirir, çırpınma animasyonunu başlatır.
func _build_model(L: float) -> void:
	var scene: PackedScene = load(str(info["model"]))
	var m: Node3D = scene.instantiate()
	var s := L / float(info.get("model_len", 1.0))
	m.scale = Vector3.ONE * s
	m.rotation.y = PI  # modelin burnu +Z'de, bizim balıklarımız -Z'ye bakar
	_visual.add_child(m)
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		_model_meshes.append(mi)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if shiny:
		var gold := StandardMaterial3D.new()
		gold.albedo_color = Color(1.0, 0.8, 0.25, 0.55)
		gold.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		gold.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		for mi in _model_meshes:
			mi.material_overlay = gold
	_anim = m.find_child("AnimationPlayer", true, false)
	if _anim and _anim.has_animation(str(info.get("anim_flop", ""))):
		_anim.get_animation(str(info["anim_flop"])).loop_mode = Animation.LOOP_LINEAR
		_anim.play(str(info["anim_flop"]))


func _play_death() -> void:
	if _anim and _anim.has_animation(str(info.get("anim_die", ""))):
		_anim.play(str(info["anim_die"]))


func _flash_model(on: bool) -> void:
	if _model_meshes.is_empty():
		return
	if _flash_mat == null:
		_flash_mat = StandardMaterial3D.new()
		_flash_mat.albedo_color = Color(1, 1, 1, 0.8)
		_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for mi in _model_meshes:
		if on:
			mi.set_meta("ov", mi.material_overlay)
			mi.material_overlay = _flash_mat
		elif mi.has_meta("ov"):
			mi.material_overlay = mi.get_meta("ov")


func _update_label() -> void:
	var pips := ""
	for i in max_hp:
		pips += "●" if i < hp else "○"
	var title: String = info["name"]
	if shiny:
		title = "✦ " + title + " ✦"
	_label.text = "%s\n%s" % [title, pips]


func _process(delta: float) -> void:
	if state == "gone" or state == "held":
		return
	_t += delta
	if _flash > 0.0:
		_flash -= delta
		var on := _flash > 0.0
		for m in _mats:
			m.set_shader_parameter("albedo", Color.WHITE if on else m.get_meta("c", Color.WHITE))
		if not on:
			_flash_model(false)
	match state:
		"hang":
			# Ağzından asılı: başı yukarıda, kuyruğu sağa sola çırpar.
			_visual.rotation = Vector3(PI * 0.5, sin(_t * 9.0) * 0.4, sin(_t * 17.0) * 0.8)
		"fall":
			_move(delta)
			_visual.rotation += _spin * delta
		"ground":
			_move(delta)
			_flop_timer -= delta
			if _flop_timer <= 0.0 and not _airborne:
				_hop()
			if info.get("bites", false) and player:
				_bite_timer -= delta
				if _bite_timer <= 0.0 and player.global_position.distance_to(global_position) < 2.2:
					_bite_timer = 1.4
					attacked.emit(10.0)
		"dead":
			_move(delta)


## Yerçekimiyle hareket; zemine değince durur, denize düşerse kaçar.
func _move(delta: float) -> void:
	if not _airborne:
		return
	velocity.y -= gravity * delta
	position += velocity * delta
	var h: float = world.ground_height(position)
	if is_nan(h):
		if position.y <= WATER_Y:
			_gone("water")
	elif position.y <= h + radius() and velocity.y < 0.0:
		position.y = h + radius()
		velocity = Vector3.ZERO
		_airborne = false
		if state == "fall":
			state = "ground"
			_flop_timer = 0.25
		if state != "hang":
			_visual.rotation = Vector3(0, _visual.rotation.y, PI * 0.5)


## Rastgele bir yöne zıplar.
func _hop() -> void:
	var a := randf() * TAU
	var speed := randf_range(1.2, 2.2) * (0.7 + float(info["pull"])) * hop_scale
	velocity = Vector3(cos(a) * speed, randf_range(2.6, 3.6), sin(a) * speed)
	_airborne = true
	_flop_timer = randf_range(0.35, 0.8)
	_visual.rotation = Vector3(randf_range(-0.4, 0.4), a, PI * 0.5 * (1 if randf() < 0.5 else -1))


## Oltadan bırakılır, aşağı düşer.
func drop() -> void:
	if state != "hang":
		return
	state = "fall"
	velocity = Vector3(0, 0.5, 0)
	_airborne = true
	_spin = Vector3(randf_range(-4, 4), randf_range(-2, 2), randf_range(-5, 5))


func _gone(reason: String) -> void:
	state = "gone"
	escaped.emit(reason)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * 0.01, 0.3)
	tw.tween_callback(queue_free)


## Vuruş. drift: vuruştan sonraki yatay hız. Yalnızca yerdeyken vurulabilir. Ölürse true döner.
func hit(drift: Vector3, damage: int) -> bool:
	if state != "ground":
		return false
	hits += 1
	hp -= damage
	_flash = 0.12
	_flash_model(true)
	for m in _mats:
		if not m.has_meta("c"):
			m.set_meta("c", m.get_shader_parameter("albedo"))
	if info.get("ink", false) and not _inked:
		_inked = true
		inked.emit()
	velocity = Vector3(drift.x, 2.2, drift.z)
	_airborne = true
	if hp <= 0:
		hp = 0
		state = "dead"
		_play_death()
		_label.text = "Al"
		_label.modulate = Color("D85A30")
		_label.font_size = 56
		died.emit()
		return true
	_update_label()
	_flop_timer = 0.6
	return false


## Oyuncunun eline alınır: etiket gizlenir, fizik durur.
func make_held() -> void:
	state = "held"
	velocity = Vector3.ZERO
	_airborne = false
	_play_death()
	_label.visible = false
	for c in get_children():
		if c is OmniLight3D:
			c.light_energy = 0.4
	# Ağzından tutulur: baş yukarıda, karın oyuncuya dönük.
	_visual.rotation = Vector3(PI * 0.5, PI * 0.5, 0)
