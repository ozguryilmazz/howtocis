extends CharacterBody3D
## Birinci şahıs oyuncu. Dokunmatik kol ve bakış kaydırmasıyla, bilgisayarda
## WASD + boşluk + fareyle sürükleyerek kontrol edilir.

signal hp_changed(hp: float)
signal fainted

const SPEED := 5.0
const JUMP_VELOCITY := 5.5
const GRAVITY := 14.0
const LOOK_SENS := 0.004
const MAX_HP := 100.0
const SPIN_WINDOW := 1.5

var touch: Node = null
var camera: Camera3D
var head: Node3D
## Misina sararken yürümek kapalıdır.
var locked := false
var hp := MAX_HP

var _pitch := 0.0
var _spawn := Vector3.ZERO
var _spawn_yaw := 0.0
var _spin_log: Array = []  # [zaman, dönüş]
var _since_hurt := 99.0


func _ready() -> void:
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	col.shape = cap
	col.position.y = 0.85
	add_child(col)

	head = Node3D.new()
	head.position.y = 1.55
	add_child(head)
	camera = Camera3D.new()
	camera.fov = 70.0
	camera.far = 700.0
	head.add_child(camera)
	camera.current = true

	_spawn = global_position
	_spawn_yaw = rotation.y


func _physics_process(delta: float) -> void:
	var look := Vector2.ZERO
	var move := Vector2.ZERO
	var jump := false
	if touch:
		look = touch.consume_look()
		move = touch.move_vector
		jump = touch.consume_jump()

	var keys := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	if keys != Vector2.ZERO:
		move = keys.normalized()
	if Input.is_physical_key_pressed(KEY_SPACE):
		jump = true
	if locked:
		move = Vector2.ZERO
		jump = false

	var yaw := -look.x * LOOK_SENS
	rotate_y(yaw)
	_log_spin(yaw)
	_pitch = clamp(_pitch - look.y * LOOK_SENS, deg_to_rad(-80.0), deg_to_rad(80.0))
	head.rotation.x = _pitch

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif jump:
		velocity.y = JUMP_VELOCITY

	var dir := transform.basis * Vector3(move.x, 0.0, move.y)
	velocity.x = dir.x * SPEED
	velocity.z = dir.z * SPEED
	move_and_slide()

	if global_position.y < -3.0:
		respawn()

	_since_hurt += delta
	if _since_hurt > 3.0 and hp < MAX_HP:
		hp = minf(MAX_HP, hp + 8.0 * delta)
		hp_changed.emit(hp)


func respawn() -> void:
	global_position = _spawn
	rotation.y = _spawn_yaw
	velocity = Vector3.ZERO


## Bakış yönü (kameranın önü).
func aim() -> Vector3:
	return -camera.global_transform.basis.z


## Yatay bakış yönü.
func facing() -> Vector3:
	var f := -global_transform.basis.z
	f.y = 0.0
	return f.normalized()


## Nişan yardımı: kamerayı hedefe doğru yavaşça çevirir. strength 0 ise hiçbir şey yapmaz.
func assist_toward(target: Vector3, strength: float, delta: float) -> void:
	if strength <= 0.0:
		return
	var to := target - camera.global_position
	if to.length() < 0.3:
		return
	var k := 1.0 - exp(-strength * delta)
	var local := global_transform.basis.inverse() * to
	var want_yaw := atan2(-local.x, -local.z)
	rotate_y(want_yaw * k)
	var flat := Vector2(local.x, local.z).length()
	var want_pitch := atan2(local.y, flat)
	_pitch = clamp(lerp_angle(_pitch, want_pitch, k), deg_to_rad(-80.0), deg_to_rad(80.0))
	head.rotation.x = _pitch


func _log_spin(yaw: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if yaw != 0.0:
		_spin_log.append([now, yaw])
	while not _spin_log.is_empty() and now - float(_spin_log[0][0]) > SPIN_WINDOW:
		_spin_log.pop_front()


## Son 1,5 saniyede aynı yöne ne kadar dönüldü (derece).
func spin_recent() -> float:
	var s := 0.0
	for e in _spin_log:
		s += float(e[1])
	return absf(rad_to_deg(s))


func take_damage(amount: float) -> void:
	hp -= amount * float(Game.difficulty()["damage_taken"])
	_since_hurt = 0.0
	if hp <= 0.0:
		hp = MAX_HP
		respawn()
		fainted.emit()
	hp_changed.emit(hp)
