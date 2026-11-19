extends Control
## Dokunmatik kontroller: sol tarafta sanal hareket kolu, sağ tarafta bakış
## kaydırma, zıplama ve büyük eylem düğmesi (At / Çek / Sar / Vur).
## Bilgisayarda fare de dokunma gibi çalışır; F tuşu eylem düğmesidir.

const STICK_RADIUS := 90.0
const TOP_RESERVED := 100.0
const JUMP_RADIUS := 62.0
const ACTION_RADIUS := 92.0

var move_vector := Vector2.ZERO
## Eylem düğmesi şu an basılı mı (sarmak için basılı tutulur).
var action_held := false

var _look := Vector2.ZERO
var _jump := false
var _action_tap := false
var _action_id := -1
var _key_was := false
var _stick_id := -1
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _look_id := -1

var _action_text := "At"
var _action_visible := true
var _action_urgent := false
var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()


func _jump_center() -> Vector2:
	return Vector2(size.x - 100.0, size.y - 100.0)


func _action_center() -> Vector2:
	return Vector2(size.x - 270.0, size.y - 175.0)


func set_action(text: String, visible_ := true, urgent := false) -> void:
	if text == _action_text and visible_ == _action_visible and urgent == _action_urgent:
		return
	_action_text = text
	_action_visible = visible_
	_action_urgent = urgent
	queue_redraw()


func _process(delta: float) -> void:
	# Klavye: F tuşu eylem düğmesi gibi çalışır.
	var k := Input.is_physical_key_pressed(KEY_F)
	if k and not _key_was:
		_action_tap = true
	if k != _key_was:
		_key_was = k
		action_held = k or _action_id != -1
	if _action_urgent:
		_t += delta
		queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			if _action_visible and t.position.distance_to(_action_center()) <= ACTION_RADIUS and _action_id == -1:
				_action_id = t.index
				action_held = true
				_action_tap = true
			elif t.position.distance_to(_jump_center()) <= JUMP_RADIUS:
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
			if t.index == _action_id:
				_action_id = -1
				action_held = _key_was
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
		elif d.index == _look_id or d.index == _action_id:
			# Eylem düğmesine basılıyken parmak kaydırılırsa da bakış döner (vururken nişan için).
			_look += d.relative


func consume_look() -> Vector2:
	var l := _look
	_look = Vector2.ZERO
	return l


func consume_jump() -> bool:
	var j := _jump
	_jump = false
	return j


func consume_action() -> bool:
	var a := _action_tap
	_action_tap = false
	return a


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var jc := _jump_center()
	draw_circle(jc, JUMP_RADIUS, Color(1, 1, 1, 0.55))
	draw_string(font, jc + Vector2(-60, 9), "Zıpla", HORIZONTAL_ALIGNMENT_CENTER, 120, 24, Color("4A2A12"))

	if _action_visible:
		var ac := _action_center()
		var col := Color(0.85, 0.35, 0.19, 0.9)
		var r := ACTION_RADIUS
		if _action_urgent:
			var pulse := 0.5 + 0.5 * sin(_t * 18.0)
			col = Color(0.85, 0.35, 0.19).lerp(Color("F2C94C"), pulse)
			r += pulse * 8.0
		if action_held:
			col = col.darkened(0.2)
		draw_circle(ac, r, col)
		draw_arc(ac, r, 0, TAU, 48, Color.WHITE, 5.0, true)
		var fs := 40 if _action_text.length() <= 5 else 30
		draw_string(font, ac + Vector2(-r, fs * 0.35), _action_text, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, Color.WHITE)

	if _stick_id != -1:
		draw_circle(_stick_origin, STICK_RADIUS, Color(1, 1, 1, 0.25))
		draw_circle(_stick_pos, 38.0, Color(1, 1, 1, 0.85))
	else:
		var hint := Vector2(150.0, size.y - 150.0)
		draw_circle(hint, STICK_RADIUS, Color(1, 1, 1, 0.18))
		draw_circle(hint, 38.0, Color(1, 1, 1, 0.5))
