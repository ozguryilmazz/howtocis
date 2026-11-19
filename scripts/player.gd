extends CharacterBody3D
## Birinci şahıs oyuncu. Dokunmatik kol ve bakış kaydırmasıyla, bilgisayarda
## WASD + boşluk + fareyle sürükleyerek kontrol edilir.

const SPEED := 5.0
const JUMP_VELOCITY := 5.5
const GRAVITY := 14.0
const LOOK_SENS := 0.004

var touch: Node = null
var camera: Camera3D

var _head: Node3D
var _pitch := 0.0
var _spawn := Vector3.ZERO
var _spawn_yaw := 0.0


func _ready() -> void:
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	col.shape = cap
	col.position.y = 0.85
	add_child(col)

	_head = Node3D.new()
	_head.position.y = 1.55
	add_child(_head)
	camera = Camera3D.new()
	camera.fov = 70.0
	camera.far = 700.0
	_head.add_child(camera)
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

	rotate_y(-look.x * LOOK_SENS)
	_pitch = clamp(_pitch - look.y * LOOK_SENS, deg_to_rad(-75.0), deg_to_rad(75.0))
	_head.rotation.x = _pitch

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


func respawn() -> void:
	global_position = _spawn
	rotation.y = _spawn_yaw
	velocity = Vector3.ZERO
