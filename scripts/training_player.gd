extends CharacterBody3D
## Model Training: üçüncü şahıs karakter. Kamera karakterin arkasında ve üstünde
## bir kolun (SpringArm3D) ucundadır; ekranı kaydırınca karakterin etrafında döner.
## Karakter yürüdüğü yöne döner; geri yürüyünce kamera dönmez, karakterin önü görünür.
## Kamera ile karakter arasına duvar girerse kol kısalır, kamera duvarın içine girmez.

const MODEL := "res://models/characters/manken.glb"
const WALK := 2.0
const JOG := 4.6
const SPRINT := 7.0
const JUMP_VELOCITY := 5.5
const GRAVITY := 14.0
const LOOK_SENS := 0.005
const ARM_LEN := 4.2
const TURN_SPEED := 12.0

var touch: Node = null
## Animasyon tarayıcısından oynatılan gösteri animasyonu (yürüyünce biter).
var showcase := ""

var anim: AnimationPlayer
var model: Node3D
var camera: Camera3D
var _yaw_node: Node3D
var _pitch_node: Node3D
var _arm: SpringArm3D
var _yaw := 0.0
var _pitch := -0.32
var _action_t := 0.0      # yumruk/iniş gibi kısa animasyon süresince yürüme yok
var _punch_left := false
var _was_floor := true
var _current := ""


func _ready() -> void:
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.8
	col.shape = cap
	col.position.y = 0.9
	add_child(col)

	model = (load(MODEL) as PackedScene).instantiate()
	# Modelin önü +Z'ye bakar; Godot'da ileri -Z olduğu için çevrilir.
	model.rotation.y = PI
	add_child(model)
	anim = model.find_children("*", "AnimationPlayer", true, false)[0]
	for n in anim.get_animation_list():
		if n.ends_with("_Loop") or n in ["Sword_Idle"]:
			anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	anim.animation_finished.connect(_on_anim_finished)

	# Kamera kolu: karakterle birlikte dönmesin diye top_level; konumu her karede izlenir.
	_yaw_node = Node3D.new()
	_yaw_node.top_level = true
	add_child(_yaw_node)
	_pitch_node = Node3D.new()
	_yaw_node.add_child(_pitch_node)
	_arm = SpringArm3D.new()
	_arm.spring_length = ARM_LEN
	_arm.margin = 0.2
	var s := SphereShape3D.new()
	s.radius = 0.25
	_arm.shape = s
	_arm.add_excluded_object(get_rid())
	_pitch_node.add_child(_arm)
	camera = Camera3D.new()
	camera.fov = 65.0
	camera.far = 500.0
	_arm.add_child(camera)
	camera.current = true
	_yaw_node.global_position = global_position + Vector3(0, 1.5, 0)
	_yaw = rotation.y
	_play("Idle_Loop")


func triangle_count() -> int:
	var n := 0
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = (mi as MeshInstance3D).mesh
		for si in m.get_surface_count():
			var arr := m.surface_get_arrays(si)
			var idx = arr[Mesh.ARRAY_INDEX]
			n += (idx.size() if idx != null else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return n


## Godot içe aktarırken "_Loop" sonekini silip animasyonu döngüye alır; iki adı da kabul et.
func _resolve(name: String) -> String:
	if anim.has_animation(name):
		return name
	return name.trim_suffix("_Loop")


func _play(name: String, blend := 0.2, speed := 1.0) -> void:
	name = _resolve(name)
	if _current == name and anim.is_playing():
		anim.speed_scale = speed
		return
	_current = name
	anim.play(name, blend)
	anim.speed_scale = speed


## Animasyon tarayıcısı: istenen animasyonu oynatır; karakter yürüyünce normal hâline döner.
func play_showcase(name: String) -> void:
	showcase = name
	_current = ""
	_play(name, 0.25)


func punch() -> void:
	if _action_t > 0.0 or not is_on_floor():
		return
	showcase = ""
	_punch_left = not _punch_left
	var n := "Punch_Jab" if _punch_left else "Punch_Cross"
	_current = ""
	_play(n, 0.1, 1.3)
	n = _current
	_action_t = anim.get_animation(n).length / 1.3 * 0.8


func _on_anim_finished(name: String) -> void:
	if name == showcase:
		showcase = ""
	_current = ""


func _physics_process(delta: float) -> void:
	var look := Vector2.ZERO
	var move := Vector2.ZERO
	var jump := false
	var act := false
	if touch:
		look = touch.consume_look()
		move = touch.move_vector
		jump = touch.consume_jump()
		act = touch.consume_action()
	var keys := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	var sprint_key := Input.is_physical_key_pressed(KEY_SHIFT)
	if keys != Vector2.ZERO:
		move = keys.normalized() * (1.0 if sprint_key else 0.7)
	if Input.is_physical_key_pressed(KEY_SPACE):
		jump = true
	if act:
		punch()

	# Kamera: kaydırma karakterin etrafında döndürür (karakteri döndürmez).
	_yaw -= look.x * LOOK_SENS
	_pitch = clampf(_pitch - look.y * LOOK_SENS, -1.25, 0.45)
	_yaw_node.rotation = Vector3(0, _yaw, 0)
	_pitch_node.rotation = Vector3(_pitch, 0, 0)

	_action_t -= delta
	var busy := _action_t > 0.0
	var amount := minf(move.length(), 1.0)
	if busy:
		amount = 0.0
	# Hareket kameraya göre: kol yukarı = kameranın baktığı yöne.
	var dir := Vector3.ZERO
	if amount > 0.08:
		dir = (Basis(Vector3.UP, _yaw) * Vector3(move.x, 0, move.y)).normalized()
		showcase = ""
	var speed := WALK
	if amount > 0.55:
		speed = JOG
	if amount > 0.97 and sprint_key:
		speed = SPRINT
	var target := dir * speed * (amount if amount <= 0.55 else 1.0)
	velocity.x = move_toward(velocity.x, target.x, 30.0 * delta)
	velocity.z = move_toward(velocity.z, target.z, 30.0 * delta)
	if dir != Vector3.ZERO:
		var want := atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, want, 1.0 - exp(-TURN_SPEED * delta))

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif jump and not busy:
		velocity.y = JUMP_VELOCITY
		showcase = ""
		_current = ""
		_play("Jump_Start", 0.1)
	move_and_slide()

	# Kamera kolu karakteri yumuşakça izler.
	var follow := global_position + Vector3(0, 1.45, 0)
	_yaw_node.global_position = _yaw_node.global_position.lerp(follow, 1.0 - exp(-14.0 * delta))

	_animate(Vector2(velocity.x, velocity.z).length())
	if global_position.y < -20.0:
		global_position = Vector3(0, 1, 6)
		velocity = Vector3.ZERO


func _animate(hspeed: float) -> void:
	var on_floor := is_on_floor()
	if on_floor and not _was_floor:
		_play("Jump_Land", 0.1, 1.4)
		_action_t = 0.18
	_was_floor = on_floor
	if not on_floor:
		if _current != "Jump_Start" or not anim.is_playing():
			_play("Jump_Loop", 0.2)
		return
	if _action_t > 0.0 and (_current.begins_with("Punch") or _current == "Jump_Land"):
		return
	if showcase != "":
		return
	if hspeed > 5.6:
		_play("Sprint_Loop", 0.2)
	elif hspeed > 2.6:
		_play("Jog_Fwd_Loop", 0.2, hspeed / JOG)
	elif hspeed > 0.25:
		_play("Walk_Loop", 0.2, clampf(hspeed / WALK, 0.6, 1.3))
	else:
		_play("Idle_Loop", 0.25)
