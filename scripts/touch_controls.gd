extends Control
## Dokunmatik kontroller: sol tarafta sanal hareket kolu, sağ tarafta bakış
## kaydırma ve zıplama düğmesi. Bilgisayarda fare de dokunma gibi çalışır.

const STICK_RADIUS := 90.0
const TOP_RESERVED := 100.0
const JUMP_RADIUS := 70.0

var move_vector := Vector2.ZERO

var _look := Vector2.ZERO
var _jump := false
var _stick_id := -1
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _look_id := -1


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()


func _jump_center() -> Vector2:
	return Vector2(size.x - 130.0, size.y - 130.0)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			if t.position.distance_to(_jump_center()) <= JUMP_RADIUS:
				_jump = true
			elif t.position.y < TOP_RESERVED:
				return
			elif t.position.x < size.x * 0.45 and _stick_id == -1:
				_stick_id = t.index
				_stick_origin = t.position
				_stick_pos = t.position
			elif _look_id == -1:
				_look_id = t.index
		else:
			if t.index == _stick_id:
				_stick_id = -1
				move_vector = Vector2.ZERO
			if t.index == _look_id:
				_look_id = -1
		queue_redraw()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _stick_id:
			var off := d.position - _stick_origin
			if off.length() > STICK_RADIUS:
				off = off.normalized() * STICK_RADIUS
			_stick_pos = _stick_origin + off
			move_vector = off / STICK_RADIUS
			queue_redraw()
		elif d.index == _look_id:
			_look += d.relative


func consume_look() -> Vector2:
	var l := _look
	_look = Vector2.ZERO
	return l


func consume_jump() -> bool:
	var j := _jump
	_jump = false
	return j


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var jc := _jump_center()
	draw_circle(jc, JUMP_RADIUS, Color(0.85, 0.35, 0.19, 0.85))
	draw_string(font, jc + Vector2(-36, 10), "Zıpla", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color.WHITE)
	if _stick_id != -1:
		draw_circle(_stick_origin, STICK_RADIUS, Color(1, 1, 1, 0.25))
		draw_circle(_stick_pos, 38.0, Color(1, 1, 1, 0.85))
	else:
		var hint := Vector2(150.0, size.y - 150.0)
		draw_circle(hint, STICK_RADIUS, Color(1, 1, 1, 0.18))
		draw_circle(hint, 38.0, Color(1, 1, 1, 0.5))
