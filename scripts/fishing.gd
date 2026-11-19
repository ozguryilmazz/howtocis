extends Node3D
## Balık tutma döngüsü:
##   At → bekle → vuruş (ÇEK!) → sar (gerginliği yeşilde tut) → balık havaya fırlar
##   → yumrukla vur (havadayken vurmak gösteri çarpanını artırır) → kovaya.
## Silahlar 3. aşamada dükkândan alınacak; o zamana kadar yumruk.

const C := preload("res://scripts/creatures.gd")
const FISH := preload("res://scripts/fish.gd")
const FLAT := preload("res://shaders/flat.gdshader")

const CAST_DIST := 9.0
const LAUNCH_DIST := 2.5
const WATER_Y := -0.25

## Yumruk. Silahlar da aynı alanlarla tanımlanacak (hasar, menzil, bekleme, itme).
const FISTS := {"name": "Yumruk", "damage": 1, "reach": 3.0, "cooldown": 0.32, "push": 0.8}

enum S { IDLE, CASTING, WAITING, BITE, REELING, FIGHT }

var world: Node
var player: Node
var touch: Node
var hud: Node

var state := S.IDLE
var weapon: Dictionary = FISTS
var rng := RandomNumberGenerator.new()

var _diff: Dictionary
var _timer := 0.0
var _cast_from := Vector3.ZERO
var _cast_to := Vector3.ZERO
var _dir := Vector3.FORWARD
var _dist := 0.0
var _tension := 0.0
var _slack := 0.0
var _surge := 0.0
var _zone := Vector2(0.25, 0.8)
var _species := ""
var _fish: Node3D = null
var _bonuses: Array = []
var _air_hits := 0
var _cooldown := 0.0
var _punch_t := 0.0

var _rod: Node3D
var _rod_tip: Node3D
var _fist: Node3D
var _bobber: MeshInstance3D
var _line: MeshInstance3D
var _line_mesh: ImmediateMesh

## Geliştirme: "--otomatik" ile oyun kendi kendine bir balık tutar (başsız test için).
var autopilot := false
var _auto_log: Array = []


func setup(p_world: Node, p_player: Node, p_touch: Node, p_hud: Node) -> void:
	world = p_world
	player = p_player
	touch = p_touch
	hud = p_hud
	_diff = Game.difficulty()
	rng.randomize()
	var w := float(_diff["bite_window"])  # kolay 1.4, normal 1, zor 0.7
	var half := 0.27 * w
	_zone = Vector2(clampf(0.52 - half, 0.08, 0.5), clampf(0.52 + half, 0.55, 0.9))
	_build_gear()
	player.fainted.connect(_on_fainted)
	_set_idle()
	hud.message("İskelenin ucuna yürü, denize dön ve At'a bas.", 6.0)


# --- Görseller -----------------------------------------------------------

func _flat(color: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FLAT
	m.set_shader_parameter("albedo", color)
	return m


func _build_gear() -> void:
	var cam: Camera3D = player.camera
	# Olta: kameranın sağ altında, ileri ve yukarı bakar.
	_rod = Node3D.new()
	_rod.position = Vector3(0.42, -0.42, -0.62)
	_rod.rotation_degrees = Vector3(-55, 12, 0)
	cam.add_child(_rod)
	var stick := CylinderMesh.new()
	stick.top_radius = 0.006
	stick.bottom_radius = 0.016
	stick.height = 0.95
	stick.radial_segments = 5
	stick.rings = 0
	stick.material = _flat(Color("7A5A3A"))
	var smi := MeshInstance3D.new()
	smi.mesh = stick
	smi.position.y = 0.475
	smi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rod.add_child(smi)
	var reel := CylinderMesh.new()
	reel.top_radius = 0.035
	reel.bottom_radius = 0.035
	reel.height = 0.03
	reel.radial_segments = 8
	reel.rings = 0
	reel.material = _flat(Color("378ADD"))
	var rmi := MeshInstance3D.new()
	rmi.mesh = reel
	rmi.position = Vector3(0.04, 0.12, 0)
	rmi.rotation_degrees = Vector3(0, 0, 90)
	_rod.add_child(rmi)
	_rod_tip = Node3D.new()
	_rod_tip.position.y = 0.95
	_rod.add_child(_rod_tip)

	# Yumruk: ten rengi el, parmak eklemleri ve kol.
	_fist = Node3D.new()
	_fist.position = Vector3(0.3, -0.3, -0.55)
	_fist.scale = Vector3.ONE * 0.75
	cam.add_child(_fist)
	var skin := _flat(Color("E8B48A"))
	var hand := BoxMesh.new()
	hand.size = Vector3(0.12, 0.11, 0.13)
	hand.material = skin
	var hmi := MeshInstance3D.new()
	hmi.mesh = hand
	_fist.add_child(hmi)
	var knuckles := BoxMesh.new()
	knuckles.size = Vector3(0.12, 0.035, 0.03)
	knuckles.material = _flat(Color("D39A72"))
	var kmi := MeshInstance3D.new()
	kmi.mesh = knuckles
	kmi.position = Vector3(0, 0.035, -0.07)
	_fist.add_child(kmi)
	var arm := BoxMesh.new()
	arm.size = Vector3(0.08, 0.08, 0.3)
	arm.material = skin
	var ami := MeshInstance3D.new()
	ami.mesh = arm
	ami.position = Vector3(0.03, -0.03, 0.2)
	_fist.add_child(ami)
	_fist.visible = false

	# Şamandıra
	var bm := SphereMesh.new()
	bm.radius = 0.12
	bm.height = 0.24
	bm.radial_segments = 8
	bm.rings = 4
	bm.material = _flat(Color("D1495B"))
	_bobber = MeshInstance3D.new()
	_bobber.mesh = bm
	_bobber.top_level = true
	_bobber.visible = false
	add_child(_bobber)
	var cap := SphereMesh.new()
	cap.radius = 0.07
	cap.height = 0.14
	cap.radial_segments = 6
	cap.rings = 3
	cap.material = _flat(Color.WHITE)
	var capmi := MeshInstance3D.new()
	capmi.mesh = cap
	capmi.position.y = 0.11
	_bobber.add_child(capmi)

	# Misina
	_line_mesh = ImmediateMesh.new()
	_line = MeshInstance3D.new()
	_line.mesh = _line_mesh
	_line.top_level = true
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.albedo_color = Color("3A2A1A")
	_line.material_override = lm
	_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_line)


func _draw_line(sag: float) -> void:
	_line_mesh.clear_surfaces()
	if not _bobber.visible:
		return
	var a := _rod_tip.global_position
	var b := _bobber.global_position + Vector3(0, 0.1, 0)
	_line_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in 13:
		var t := i / 12.0
		var p := a.lerp(b, t)
		p.y -= sin(t * PI) * sag
		_line_mesh.surface_add_vertex(p)
	_line_mesh.surface_end()


# --- Durumlar ------------------------------------------------------------

func _set_idle() -> void:
	state = S.IDLE
	player.locked = false
	_bobber.visible = false
	_rod.visible = true
	_fist.visible = false
	hud.hide_tension()
	hud.prompt("")
	touch.set_action("At")
	_draw_line(0)


func _try_cast() -> void:
	if Game.bucket_full():
		hud.message("Kova dolu! Balıkçı Teyze'ye sat.")
		return
	_dir = player.facing()
	var start: Vector3 = player.global_position
	var target := start + _dir * CAST_DIST
	if not world.is_water(target) or not world.is_water(start + _dir * (CAST_DIST * 0.6)):
		hud.message("Denize dön, oltayı suya at.")
		return
	_cast_from = _rod_tip.global_position
	_cast_to = Vector3(target.x, WATER_Y, target.z)
	_dist = start.distance_to(Vector3(target.x, start.y, target.z))
	_timer = 0.0
	state = S.CASTING
	_bobber.visible = true
	touch.set_action("Bekle")
	_log("at")


func _start_wait() -> void:
	state = S.WAITING
	_timer = rng.randf_range(2.0, 5.0)
	touch.set_action("Bekle")
	hud.message("Şamandırayı izle…", 1.6)


func _start_bite() -> void:
	state = S.BITE
	_species = C.roll_species(rng)
	_timer = 1.0 * float(_diff["bite_window"])
	hud.prompt("ÇEK!")
	touch.set_action("ÇEK!", true, true)
	_log("vuruş " + _species)


func _start_reel() -> void:
	state = S.REELING
	player.locked = true
	_tension = 0.45
	_slack = 0.0
	_surge = rng.randf_range(0.6, 1.4)
	hud.prompt("")
	touch.set_action("Sar")
	hud.message("Basılı tut ve sar! İbreyi yeşilde tut.", 2.6)
	_log("sar")


func _fail(text: String) -> void:
	hud.message(text)
	_log("kaçtı: " + text)
	_set_idle()


func _launch() -> void:
	state = S.FIGHT
	player.locked = false
	hud.hide_tension()
	_bobber.visible = false
	_draw_line(0)
	_rod.visible = false
	_fist.visible = true
	touch.set_action("Vur")
	hud.prompt("")
	hud.message("Havadayken vur!", 1.8)

	var since := int(Game.data.get("since_shiny", 0))
	_fish = FISH.new()
	_fish.setup(world, player, _species, C.roll_size(rng), C.roll_shiny(rng, since))
	world.add_child(_fish)
	var start := Vector3(_bobber.global_position.x, 0.0, _bobber.global_position.z)
	_fish.global_position = start
	# Kolayda balık daha yavaş düşer ve daha uzun havada kalır.
	var assist := float(_diff["aim_assist"])
	_fish.gravity = 9.0 - 3.0 * assist
	# Balık oyuncunun başının biraz üstünden geçip arkasına düşer: tepe noktası yumruk menzilinde.
	var g: float = _fish.gravity
	var land: Vector3 = player.global_position - _dir * 1.2
	var peak: float = player.global_position.y + 2.9 + 0.5 * assist
	var vy := sqrt(2.0 * g * maxf(peak - start.y, 0.5))
	var drop: float = peak - (land.y + 0.3)
	var flight := vy / g + sqrt(2.0 * maxf(drop, 0.1) / g)
	var v := (land - start) / flight
	v.y = vy
	_fish.velocity = v
	_fish.died.connect(_on_fish_died)
	_fish.escaped.connect(_on_fish_escaped)
	_fish.attacked.connect(_on_fish_attacked)
	_fish.inked.connect(_on_fish_inked)
	_bonuses.clear()
	_air_hits = 0
	if _fish.shiny:
		hud.popup("✦ PARLAK! ✦")
	_log("fırladı " + _species)


func _punch() -> void:
	if _cooldown > 0.0:
		return
	_cooldown = float(weapon["cooldown"])
	_punch_t = 0.18
	if _fish == null or not is_instance_valid(_fish):
		return
	var cam: Camera3D = player.camera
	var aim: Vector3 = player.aim()
	var assist := float(_diff["aim_assist"])
	var reach := float(weapon["reach"]) + 0.6 * assist
	var to_body: Vector3 = _fish.global_position - cam.global_position
	var to_head: Vector3 = _fish.head_position() - cam.global_position
	if to_body.length() > reach + _fish.radius():
		hud.popup("Uzak!")
		return
	var cone := 24.0 + 18.0 * assist
	var ang := rad_to_deg(aim.angle_to(to_body))
	if ang > cone and to_body.length() > 1.0:
		hud.popup("Iska!")
		return
	var was_air: bool = _fish.state == "air"
	var full_hp: bool = _fish.hits == 0
	var head := rad_to_deg(aim.angle_to(to_head)) < 9.0 + 8.0 * assist and to_head.length() < to_body.length() + 0.05
	var spun: bool = player.spin_recent() >= 330.0
	var damage := int(weapon["damage"])
	# Vurulan balık hafifçe oyuncuya doğru geri süzülür, böylece zincir kurulabilir.
	# Zorda vuruş balığı ileri iter; denize düşürmemek oyuncunun işi.
	var back: Vector3 = player.global_position - _fish.global_position
	back.y = 0.0
	var drift: Vector3 = back * (0.25 + 0.35 * assist) + player.facing() * float(weapon["push"]) * (1.0 - assist)
	if _fish.hp - damage <= 0:
		# Bonuslar balık ölmeden önce yazılmalı; ölünce kovaya hemen eklenir.
		if was_air:
			_bonuses.append("air")
		if head:
			_bonuses.append("head")
		if spun:
			_bonuses.append("spin")
		if full_hp:
			_bonuses.append("one")
		for i in _air_hits:
			_bonuses.append("juggle")
		_slowmo()
		_fish.hit(drift, damage)
	else:
		_fish.hit(drift, damage)
		if was_air:
			_air_hits += 1
			hud.popup("Zincir ×%d!" % _air_hits if _air_hits > 1 else "Pat!")
		else:
			hud.popup("Pat!")


func _slowmo() -> void:
	Engine.time_scale = 0.35
	get_tree().create_timer(0.35, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)


func _on_fish_died() -> void:
	var f := _fish
	var show := C.show_multiplier(_bonuses)
	var value := C.price(f.species, f.size_mult, show, f.shiny, float(_diff["sell_bonus"]))
	var cm := int(round(float(f.info["cm"]) * f.size_mult))
	Game.add_catch({"id": f.species, "cm": cm, "size": f.size_mult, "show": show,
		"shiny": f.shiny, "value": value, "bonuses": _bonuses.duplicate()})
	hud.show_catch(f.info["name"], "%d cm" % cm, C.bonus_lines(_bonuses), show, value, f.shiny)
	_log("tutuldu %s %dcm show=%s değer=%d bonus=%s" % [f.species, cm, show, value, _bonuses])
	_fish = null
	_set_idle()


func _on_fish_escaped(reason: String) -> void:
	_fish = null
	_fail("Balık denize düştü, kaçtı!" if reason == "water" else "Balık çırpına çırpına denize kaçtı!")


func _on_fish_attacked(damage: float) -> void:
	player.take_damage(damage)
	hud.popup("Isırdı!")


func _on_fish_inked() -> void:
	hud.ink()
	hud.message("Mürekkep püskürttü!", 1.6)


func _on_fainted() -> void:
	if _fish and is_instance_valid(_fish):
		_fish.queue_free()
	_fish = null
	_fail("Bayıldın! Balık kaçtı.")


# --- Döngü ---------------------------------------------------------------

func _physics_process(delta: float) -> void:
	var tap: bool = touch.consume_action()
	var held: bool = touch.action_held
	if autopilot:
		var a := _autopilot(delta)
		tap = a[0]
		held = a[1]
	_cooldown -= delta
	if _punch_t > 0.0:
		_punch_t -= delta
		var k := sin(clampf(1.0 - _punch_t / 0.18, 0.0, 1.0) * PI)
		_fist.position = Vector3(0.3 - 0.2 * k, -0.3 + 0.12 * k, -0.55 - 0.4 * k)

	match state:
		S.IDLE:
			if tap:
				_try_cast()
		S.CASTING:
			_timer += delta / 0.6
			var t := minf(_timer, 1.0)
			var p := _cast_from.lerp(_cast_to, t)
			p.y += sin(t * PI) * 3.0
			_bobber.global_position = p
			_draw_line(0.4)
			if _timer >= 1.0:
				_start_wait()
		S.WAITING:
			_bob(delta, 0.04)
			_draw_line(0.25)
			_timer -= delta
			if tap:
				hud.message("Henüz değil! Şamandıra batınca çek.", 1.4)
			if _timer <= 0.0:
				_start_bite()
		S.BITE:
			_bob(delta, 0.0)
			_bobber.global_position.y = WATER_Y - 0.22 + sin(Time.get_ticks_msec() * 0.04) * 0.05
			_draw_line(0.3)
			_timer -= delta
			if tap:
				_start_reel()
			elif _timer <= 0.0:
				hud.prompt("")
				_fail("Yemi kaptı, kaçtı! Daha hızlı çek.")
		S.REELING:
			_reel(delta, held)
		S.FIGHT:
			if _fish and is_instance_valid(_fish):
				if _fish.state == "air" or _fish.state == "ground":
					player.assist_toward(_fish.global_position, 3.0 * float(_diff["aim_assist"]), delta)
			if tap:
				_punch()


func _bob(_delta: float, amp: float) -> void:
	var p := _cast_to
	p.y = WATER_Y + sin(Time.get_ticks_msec() * 0.004) * amp
	_bobber.global_position = p


func _reel(delta: float, held: bool) -> void:
	var pull := float(C.SPECIES[_species]["pull"])
	if held:
		_tension += (0.42 + 0.25 * pull) * delta
	else:
		_tension -= 0.6 * delta
	# Balık ara ara silkelenir: gerginlik bir anda artar.
	_surge -= delta
	if _surge <= 0.0:
		_surge = rng.randf_range(0.7, 1.6) / (0.6 + pull)
		_tension += rng.randf_range(0.06, 0.16) * (0.5 + pull)
	_tension = clampf(_tension, 0.0, 1.05)

	var in_zone := _tension >= _zone.x and _tension <= _zone.y
	if held and _tension >= _zone.x:
		_dist -= (2.2 if in_zone else 0.8) * delta
	if _tension >= 1.0:
		_fail("Misina koptu! Bu kadar sıkı çekme.")
		return
	if _tension <= 0.02:
		_slack += delta
		if _slack > 2.0:
			_fail("Misina gevşedi, balık kaçtı.")
			return
	else:
		_slack = 0.0

	var base: Vector3 = player.global_position + _dir * _dist
	var side := _dir.cross(Vector3.UP) * sin(Time.get_ticks_msec() * 0.006) * 0.8
	_bobber.global_position = Vector3(base.x + side.x, WATER_Y + sin(Time.get_ticks_msec() * 0.02) * 0.06, base.z + side.z)
	_draw_line(0.05)
	hud.show_tension(_tension, _zone, maxf(_dist - LAUNCH_DIST, 0.0))
	if _dist <= LAUNCH_DIST:
		_launch()


# --- Otomatik pilot (yalnızca test) -----------------------------------------

func _log(s: String) -> void:
	if not autopilot:
		return
	print("[balık] ", s)
	# Geliştirme: BALIK_SHOT=klasör ise her aşamanın ekran görüntüsü alınır.
	var dir := OS.get_environment("BALIK_SHOT")
	if dir != "":
		var tag := s.split(" ")[0]
		var delay: float = {"at": 1.2, "vuruş": 0.3, "sar": 1.5, "fırladı": 0.5, "tutuldu": 0.6}.get(tag, -1.0)
		if delay >= 0.0:
			var n := _auto_log.size()
			_auto_log.append(tag)
			get_tree().create_timer(delay).timeout.connect(func():
				get_viewport().get_texture().get_image().save_png("%s/%02d_%s.png" % [dir, n, tag]))


func _autopilot(delta: float) -> Array:
	var tap := false
	var held := false
	match state:
		S.IDLE:
			if Game.bucket_full():
				return [false, false]
			_timer -= delta
			if _timer < -0.5:
				_timer = 0.0
				tap = true
		S.BITE:
			tap = _timer < float(_diff["bite_window"]) * 0.6
		S.REELING:
			held = _tension < (_zone.x + _zone.y) * 0.5
		S.FIGHT:
			if _fish and is_instance_valid(_fish):
				player.assist_toward(_fish.global_position, 12.0, delta)
				var d: float = _fish.global_position.distance_to(player.camera.global_position)
				tap = d < float(weapon["reach"]) and _fish.state == "air"
				if _fish.state == "ground":
					tap = d < float(weapon["reach"]) and _fish._ground_time > 1.0
	return [tap, held]
