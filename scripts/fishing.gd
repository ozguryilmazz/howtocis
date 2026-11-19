extends Node3D
## Balık tutma döngüsü:
##   At → bekle → ÇEK! → sar (gerginliği yeşilde tut)
##   → balık oltanın ucunda asılı çırpınır; oyuncu onu karaya taşır ve Bırak'a basar
##     (5 saniye içinde bırakmazsa balık kendiliğinden düşer)
##   → balık yerde zıplaya zıplaya kaçışır; yumrukla vura vura öldürülür
##   → Al ile ele alınır, Balıkçı Teyze'ye götürülüp satılır.
## Silahlar 3. aşamada dükkândan alınacak; o zamana kadar yumruk.

const C := preload("res://scripts/creatures.gd")
const FISH := preload("res://scripts/fish.gd")
const FLAT := preload("res://shaders/flat.gdshader")
const HANDS := preload("res://scripts/hands.gd")

const CAST_DIST := 9.0
const LIFT_DIST := 1.8
const HANG_TIME := 5.0
const PICK_RANGE := 2.6
const FIST_R := Vector3(0.19, -0.21, -0.44)
const FIST_L := Vector3(-0.19, -0.23, -0.46)
const WATER_Y := -0.25

## Yumruk. Silahlar da aynı alanlarla tanımlanacak (hasar, menzil, bekleme, itme).
const FISTS := {"name": "Yumruk", "damage": 1, "reach": 3.0, "cooldown": 0.32, "push": 0.8}

enum S { IDLE, CASTING, WAITING, BITE, REELING, HANGING, FIGHT, PICKUP }

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
var _held: Node3D = null
var _bonuses: Array = []
var _lift_from := Vector3.ZERO
var _cooldown := 0.0
var _punch_t := 0.0

var _rod: Node3D
var _rod_tip: Node3D
var _fists: Node3D
var _fist: Node3D
var _fist_l: Node3D
var _punch_left := false
var _hold: Node3D
var _rod_hands: Array = []
var _hold_slot: Node3D
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
	Game.bucket_changed.connect(_refresh_hand)
	_set_idle()
	_refresh_hand()
	hud.message("İskelenin ucuna yürü, denize dön ve At'a bas.", 6.0)
	# Geliştirme: BALIK_POZ=yumruk|balik ile el görüntüleri test edilir (kayıt değişmez).
	match OS.get_environment("BALIK_POZ"):
		"yumruk":
			state = S.FIGHT
			_update_gear()
		"balik":
			var tur := OS.get_environment("BALIK_TUR")
			Game.data["bucket"] = [{"id": tur if tur != "" else "levrek", "size": 1.0, "value": 40}]
			_refresh_hand()


# --- Görseller -----------------------------------------------------------

func _flat(color: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FLAT
	m.set_shader_parameter("albedo", color)
	return m


func _build_gear() -> void:
	var cam: Camera3D = player.camera

	# Olta iki elle tutulur: sağ el sapın dibinde, sol el makaranın üstünde.
	var built: Array = HANDS.rod(1.05)
	_rod = built[0]
	_rod_tip = built[1]
	_rod.position = Vector3(0.2, -0.36, -0.5)
	_rod.rotation_degrees = Vector3(-50, 10, -4)
	cam.add_child(_rod)
	# Eller kameraya bağlıdır: kol ekranın altından gelir, yumruk oltayı kavrar.
	var axis: Vector3 = _rod.transform.basis.y
	var rh := HANDS.fist(false, 0.3)
	_grip(rh, _rod.transform * Vector3(0, 0.12, 0), Vector3(0.35, -0.75, 0.55), axis)
	cam.add_child(rh)
	var lh := HANDS.fist(true, 0.3)
	_grip(lh, _rod.transform * Vector3(0, 0.36, 0), Vector3(-0.6, -0.55, 0.55), axis)
	cam.add_child(lh)
	_rod_hands = [rh, lh]

	# Dövüş: iki yumruk
	_fists = Node3D.new()
	cam.add_child(_fists)
	_fist = HANDS.fist(false)
	_fist.position = FIST_R
	_fist.rotation_degrees = Vector3(18, 10, -8)
	_fists.add_child(_fist)
	_fist_l = HANDS.fist(true)
	_fist_l.position = FIST_L
	_fist_l.rotation_degrees = Vector3(18, -10, 8)
	_fists.add_child(_fist_l)
	_fists.visible = false

	# Eldeki balık: yumruk balığı ağzından tutar, balık aşağı sarkar.
	_hold = Node3D.new()
	_hold.position = Vector3(0.16, -0.06, -0.62)
	cam.add_child(_hold)
	var hh := HANDS.fist(false, 0.3)
	_grip(hh, Vector3.ZERO, Vector3(0.5, -0.65, 0.55), Vector3.UP)
	_hold.add_child(hh)
	_hold_slot = Node3D.new()
	_hold_slot.position = Vector3(-0.01, -0.04, -0.02)
	_hold.add_child(_hold_slot)
	_hold.visible = false

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


## Yumruğu yerleştirir: kol arm yönüne uzanır, kavrama ekseni grip'e (olta sapı) hizalanır.
func _grip(hand: Node3D, pos: Vector3, arm: Vector3, grip: Vector3) -> void:
	var z := arm.normalized()
	var x := (grip - z * grip.dot(z)).normalized()
	var y := z.cross(x)
	hand.transform = Transform3D(Basis(x, y, z), pos)


func _draw_line(sag: float) -> void:
	if _bobber.visible:
		_draw_line_to(_bobber.global_position + Vector3(0, 0.1, 0), sag)
	else:
		_line_mesh.clear_surfaces()


func _draw_line_to(b: Vector3, sag: float) -> void:
	_line_mesh.clear_surfaces()
	var a := _rod_tip.global_position
	_line_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in 13:
		var t := i / 12.0
		var p := a.lerp(b, t)
		p.y -= sin(t * PI) * sag
		_line_mesh.surface_add_vertex(p)
	_line_mesh.surface_end()


# --- Durumlar ------------------------------------------------------------

## Hangi el görüntüsü: olta, iki yumruk veya eldeki balık.
func _update_gear() -> void:
	var holding := not Game.bucket().is_empty()
	var fighting := state == S.FIGHT or state == S.PICKUP
	_fists.visible = fighting
	_rod.visible = not fighting and not holding
	for h in _rod_hands:
		h.visible = _rod.visible
	_hold.visible = holding and not fighting


func _set_idle() -> void:
	state = S.IDLE
	player.locked = false
	_bobber.visible = false
	hud.hide_tension()
	hud.prompt("")
	_draw_line(0)
	_update_gear()
	if Game.bucket().is_empty():
		touch.set_action("At")
	else:
		touch.set_action("", false)


func _try_cast() -> void:
	if Game.bucket_full():
		hud.message("Elinde balık var! Balıkçı Teyze'ye götür ve sat.")
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
	if _fish and is_instance_valid(_fish) and _fish.state != "gone":
		_fish.queue_free()
	_fish = null
	_set_idle()


## Balık sudan çıkar ve oltanın ucunda asılı kalır.
func _lift() -> void:
	state = S.HANGING
	player.locked = false
	hud.hide_tension()
	_bobber.visible = false
	touch.set_action("Bırak", true, true)
	_timer = HANG_TIME
	hud.message("Balığı karaya getir ve Bırak'a bas!", 2.6)

	var since := int(Game.data.get("since_shiny", 0))
	_fish = FISH.new()
	_fish.setup(world, player, _species, C.roll_size(rng), C.roll_shiny(rng, since))
	world.add_child(_fish)
	_lift_from = Vector3(_bobber.global_position.x, WATER_Y, _bobber.global_position.z)
	_fish.global_position = _lift_from
	var assist := float(_diff["aim_assist"])
	_fish.gravity = 9.0 - 3.0 * assist
	_fish.hop_scale = 1.25 - 0.6 * assist
	_fish.died.connect(_on_fish_died)
	_fish.escaped.connect(_on_fish_escaped)
	_fish.attacked.connect(_on_fish_attacked)
	_fish.inked.connect(_on_fish_inked)
	_bonuses.clear()
	if _fish.shiny:
		hud.popup("✦ PARLAK! ✦")
	_log("asılı " + _species)


## Balık oltanın ucundan biraz ileride sarkar ki kolların arkasında kalmasın.
func _hang_point() -> Vector3:
	var fwd: Vector3 = player.facing()
	return _rod_tip.global_position + fwd * 0.9 + Vector3(0, -0.2 - _fish.length * 0.5, 0)


func _hanging(delta: float, tap: bool) -> void:
	if _fish == null or not is_instance_valid(_fish):
		_set_idle()
		return
	# İlk yarım saniyede balık sudan oltanın ucuna yükselir.
	var t := clampf((HANG_TIME - _timer) / 0.5, 0.0, 1.0)
	_fish.global_position = _lift_from.lerp(_hang_point(), t)
	_draw_line_to(_fish.global_position + Vector3(0, _fish.length * 0.45, 0), 0.0)
	_timer -= delta
	hud.prompt("%d" % ceili(maxf(_timer, 0.0)))
	if tap and t >= 1.0:
		_release("Bıraktın!")
	elif _timer <= 0.0:
		_release("Balık oltadan düştü!")


func _release(text: String) -> void:
	state = S.FIGHT
	hud.prompt("")
	_line_mesh.clear_surfaces()
	_fish.drop()
	_update_gear()
	touch.set_action("Vur")
	hud.message(text + " Yere düşünce vur.", 2.0)
	_log("bırak")


func _punch() -> void:
	if _cooldown > 0.0:
		return
	_cooldown = float(weapon["cooldown"])
	_punch_t = 0.18
	_punch_left = not _punch_left
	if _fish == null or not is_instance_valid(_fish):
		return
	if _fish.state == "fall":
		hud.popup("Yere düşsün!")
		return
	if _fish.state != "ground":
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
	if rad_to_deg(aim.angle_to(to_body)) > cone and to_body.length() > 1.0:
		hud.popup("Iska!")
		return
	var full_hp: bool = _fish.hits == 0
	var head := rad_to_deg(aim.angle_to(to_head)) < 9.0 + 8.0 * assist and to_head.length() < to_body.length() + 0.05
	var spun: bool = player.spin_recent() >= 330.0
	var damage := int(weapon["damage"])
	# Kolayda vuruş balığı oyuncuya doğru, zorda denize doğru iter.
	var drift: Vector3 = player.facing() * (0.9 - 1.2 * assist)
	if _fish.hp - damage <= 0:
		# Bonuslar balık ölmeden önce yazılmalı.
		if head:
			_bonuses.append("head")
		if spun:
			_bonuses.append("spin")
		if full_hp:
			_bonuses.append("one")
		_slowmo()
	_fish.hit(drift, damage)
	if _fish.state != "dead":
		hud.popup("Pat!")


func _slowmo() -> void:
	Engine.time_scale = 0.35
	get_tree().create_timer(0.35, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)


func _on_fish_died() -> void:
	state = S.PICKUP
	touch.set_action("Al", true, true)
	hud.message("Yakaladın! Balığı Al.", 2.0)
	_log("öldü " + _fish.species)


func _pickup(tap: bool) -> void:
	if _fish == null or not is_instance_valid(_fish):
		_set_idle()
		return
	var flat: Vector3 = _fish.global_position - player.global_position
	flat.y = 0.0
	var near := flat.length() <= PICK_RANGE
	player.assist_toward(_fish.global_position, 2.0 * float(_diff["aim_assist"]), get_physics_process_delta_time())
	if not tap:
		return
	if not near:
		hud.message("Balığın yanına git.", 1.2)
		return
	var f := _fish
	var show := C.show_multiplier(_bonuses)
	var value := C.price(f.species, f.size_mult, show, f.shiny, float(_diff["sell_bonus"]))
	var cm := int(round(float(f.info["cm"]) * f.size_mult))
	_fish = null
	f.queue_free()
	Game.add_catch({"id": f.species, "cm": cm, "size": f.size_mult, "show": show,
		"shiny": f.shiny, "value": value, "bonuses": _bonuses.duplicate()})
	hud.show_catch(f.info["name"], "%d cm" % cm, C.bonus_lines(_bonuses), show, value, f.shiny)
	hud.message("Balıkçı Teyze'ye götür ve sat.", 3.0)
	_log("aldı %s %dcm show=%s değer=%d bonus=%s" % [f.species, cm, show, value, _bonuses])
	_set_idle()


## Eldeki balığın görüntüsü: kovadaki ilk balık elde, ağzından tutulmuş sarkar.
func _refresh_hand() -> void:
	var b := Game.bucket()
	if b.is_empty():
		if _held and is_instance_valid(_held):
			_held.queue_free()
		_held = null
	elif not (_held and is_instance_valid(_held)):
		var e: Dictionary = b[0]
		var id := str(e.get("id", ""))
		if not C.SPECIES.has(id):
			id = "istavrit"
		_held = FISH.new()
		_held.setup(world, player, id, float(e.get("size", 1.0)), bool(e.get("shiny", false)))
		_hold_slot.add_child(_held)
		_held.make_held()
		var sc := clampf(0.3 / _held.length, 0.15, 1.0)
		_held.scale = Vector3.ONE * sc
		_held.position = Vector3(0, -_held.length * sc * 0.45, 0)
	if state == S.IDLE:
		_set_idle()
	else:
		_update_gear()


func _on_fish_escaped(reason: String) -> void:
	_fish = null
	_fail("Balık denize düştü, kaçtı!" if reason == "water" else "Balık kaçtı!")


func _on_fish_attacked(damage: float) -> void:
	player.take_damage(damage)
	hud.popup("Isırdı!")


func _on_fish_inked() -> void:
	hud.ink()
	hud.message("Mürekkep püskürttü!", 1.6)


func _on_fainted() -> void:
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
		_fist.position = FIST_R
		_fist_l.position = FIST_L
		if _punch_left:
			_fist_l.position = FIST_L + Vector3(0.15 * k, 0.12 * k, -0.36 * k)
		else:
			_fist.position = FIST_R + Vector3(-0.15 * k, 0.12 * k, -0.36 * k)
	if _held and is_instance_valid(_held):
		var tt := Time.get_ticks_msec() * 0.001
		_hold_slot.rotation = Vector3(sin(tt * 2.1) * 0.05, 0, sin(tt * 2.7) * 0.1)

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
		S.HANGING:
			_hanging(delta, tap)
		S.FIGHT:
			if _fish and is_instance_valid(_fish) and _fish.state == "ground":
				player.assist_toward(_fish.global_position, 3.0 * float(_diff["aim_assist"]), delta)
			if tap:
				_punch()
		S.PICKUP:
			_pickup(tap)


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
	hud.show_tension(_tension, _zone, maxf(_dist - LIFT_DIST, 0.0))
	if _dist <= LIFT_DIST:
		_lift()


# --- Otomatik pilot (yalnızca test) -----------------------------------------

func _log(s: String) -> void:
	if not autopilot:
		return
	print("[balık] ", s)
	# Geliştirme: BALIK_SHOT=klasör ise her aşamanın ekran görüntüsü alınır.
	var dir := OS.get_environment("BALIK_SHOT")
	if dir != "":
		var tag := s.split(" ")[0]
		var delay: float = {"sar": 1.5, "asılı": 0.8, "bırak": 1.4, "öldü": 0.5, "aldı": 0.5, "sattı": 0.3}.get(tag, -1.0)
		if delay >= 0.0:
			var n := _auto_log.size()
			_auto_log.append(tag)
			get_tree().create_timer(delay).timeout.connect(func():
				get_viewport().get_texture().get_image().save_png("%s/%02d_%s.png" % [dir, n, tag]))


var _auto_path: Array = []


## Oyuncuyu hedefe yürütür; varınca true döner.
func _auto_walk(target: Vector3, stop := 0.6) -> bool:
	var to: Vector3 = target - player.global_position
	to.y = 0.0
	if to.length() <= stop:
		touch.move_vector = Vector2.ZERO
		return true
	player.rotation.y = atan2(-to.x, -to.z)
	touch.move_vector = Vector2(0, -1)
	return false


func _auto_follow(path: Array) -> bool:
	while not path.is_empty():
		if _auto_walk(path[0]):
			path.pop_front()
		else:
			return false
	return true


func _autopilot(delta: float) -> Array:
	var tap := false
	var held := false
	match state:
		S.IDLE:
			if Game.bucket_full():
				if _auto_path.is_empty():
					_auto_path = [Vector3(-2, 0, -12), Vector3(4, 0, -6)]
					_log("satmaya gidiyor")
				if _auto_follow(_auto_path):
					var n := Game.bucket().size()
					world.call("_on_sell")
					_log("sattı %d balık, para=%d" % [n, Game.money()])
				return [false, false]
			if player.global_position.z > -29.0:
				if _auto_path.is_empty():
					_auto_path = [Vector3(-2, 0, -12), Vector3(-2, 0, -31)]
				_auto_follow(_auto_path)
				return [false, false]
			_auto_path.clear()
			touch.move_vector = Vector2.ZERO
			player.rotation.y = 0.0
			_timer -= delta
			if _timer < -0.5:
				_timer = 0.0
				tap = true
		S.BITE:
			tap = _timer < float(_diff["bite_window"]) * 0.6
		S.REELING:
			held = _tension < (_zone.x + _zone.y) * 0.5
		S.HANGING:
			if OS.has_environment("BALIK_DENIZ"):
				return [false, false]  # test: denize bakarken kendiliğinden düşsün
			player.rotation.y = PI  # karaya dön
			tap = _timer < HANG_TIME - 1.2
		S.FIGHT, S.PICKUP:
			if _fish and is_instance_valid(_fish):
				var near := _auto_walk(_fish.global_position, 1.4)
				player.assist_toward(_fish.global_position, 12.0, delta)
				if state == S.PICKUP:
					tap = near
				else:
					var d: float = _fish.global_position.distance_to(player.camera.global_position)
					tap = d < float(weapon["reach"]) and _fish.state == "ground"
	return [tap, held]
