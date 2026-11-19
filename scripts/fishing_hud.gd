extends Control
## Balık tutma ekranı: mesajlar, gerginlik çubuğu, can, kova, vuruş yazıları ve tutuş kartı.

const INK := Color("2B1630")
const BROWN := Color("4A2A12")
const TERRA := Color("D85A30")

var _msg: Label
var _prompt: Label
var _pop: Label
var _bucket: Label
var _card: PanelContainer
var _card_text: VBoxContainer
var _ink: ColorRect

var _msg_time := 0.0
var _pop_time := 0.0
var _card_time := 0.0
var _ink_time := 0.0

var _tension_on := false
var _tension := 0.0
var _zone := Vector2(0.25, 0.8)
var _dist := 0.0
var _hp := 100.0


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE

	_ink = ColorRect.new()
	_ink.color = Color(INK, 0.0)
	_ink.mouse_filter = MOUSE_FILTER_IGNORE
	_ink.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(_ink)

	_msg = _label(30, BROWN)
	_msg.anchor_left = 0.0
	_msg.anchor_right = 1.0
	_msg.offset_top = 150
	_msg.offset_bottom = 200
	add_child(_msg)

	_prompt = _label(84, TERRA)
	_prompt.add_theme_constant_override("outline_size", 22)
	_prompt.anchor_left = 0.0
	_prompt.anchor_right = 1.0
	_prompt.anchor_top = 0.5
	_prompt.anchor_bottom = 0.5
	_prompt.offset_top = -170
	_prompt.offset_bottom = -70
	add_child(_prompt)

	_pop = _label(48, Color("C2410C"))
	_pop.anchor_left = 0.0
	_pop.anchor_right = 1.0
	_pop.anchor_top = 0.5
	_pop.anchor_bottom = 0.5
	_pop.offset_top = -60
	_pop.offset_bottom = 0
	add_child(_pop)

	_bucket = _label(24, Color("185FA5"))
	_bucket.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_bucket.position = Vector2(20, 96)
	add_child(_bucket)

	_card = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("FFF8EC")
	sb.border_color = TERRA
	sb.set_border_width_all(5)
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 34
	sb.content_margin_right = 34
	sb.content_margin_top = 20
	sb.content_margin_bottom = 22
	_card.add_theme_stylebox_override("panel", sb)
	_card.anchor_left = 0.5
	_card.anchor_right = 0.5
	_card.anchor_top = 0.5
	_card.anchor_bottom = 0.5
	_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_card.grow_vertical = Control.GROW_DIRECTION_BOTH
	_card.mouse_filter = MOUSE_FILTER_IGNORE
	_card.visible = false
	add_child(_card)
	_card_text = VBoxContainer.new()
	_card_text.add_theme_constant_override("separation", 2)
	_card.add_child(_card_text)


func _label(size_px: int, color: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.WHITE)
	l.add_theme_constant_override("outline_size", 10)
	l.mouse_filter = MOUSE_FILTER_IGNORE
	return l


func message(text: String, seconds := 2.4) -> void:
	_msg.text = text
	_msg.modulate.a = 1.0
	_msg_time = seconds


func prompt(text: String) -> void:
	_prompt.text = text


func popup(text: String) -> void:
	_pop.text = text
	_pop.modulate.a = 1.0
	_pop_time = 0.9


func set_bucket(n: int, max_n: int, value: int) -> void:
	_bucket.text = "Kova %d/%d  ·  %s altın değerinde" % [n, max_n, Game.format_money(value)] if n > 0 else "Kova boş"


func set_hp(hp: float) -> void:
	_hp = hp
	queue_redraw()


func ink() -> void:
	_ink_time = 2.0


func show_tension(tension: float, zone: Vector2, dist: float) -> void:
	_tension_on = true
	_tension = tension
	_zone = zone
	_dist = dist
	queue_redraw()


func hide_tension() -> void:
	if _tension_on:
		_tension_on = false
		queue_redraw()


## lines: [["Havada", "+1"], ...]
func show_catch(title: String, subtitle: String, lines: Array, show: float, value: int, shiny: bool) -> void:
	for c in _card_text.get_children():
		c.queue_free()
	var t := _label(40, TERRA if not shiny else Color("B7791F"))
	t.text = ("✦ PARLAK ✦  " if shiny else "") + title
	_card_text.add_child(t)
	var s := _label(24, BROWN)
	s.text = subtitle
	_card_text.add_child(s)
	for ln in lines:
		var row := _label(26, Color("185FA5"))
		row.text = "%s  %s" % [ln[0], ln[1]]
		_card_text.add_child(row)
	if lines.is_empty():
		var none := _label(22, Color("7A6A55"))
		none.text = "Havada vurursan değeri katlanır!"
		_card_text.add_child(none)
	var total := _label(36, BROWN)
	total.text = "Gösteri ×%s  →  %s altın" % [_fmt(show), Game.format_money(value)]
	_card_text.add_child(total)
	_card.visible = true
	_card.modulate.a = 1.0
	_card_time = 3.6


func _fmt(v: float) -> String:
	if is_equal_approx(v, round(v)):
		return str(int(round(v)))
	return str(snappedf(v, 0.01))


func _process(delta: float) -> void:
	if _msg_time > 0.0:
		_msg_time -= delta
		_msg.modulate.a = clampf(_msg_time / 0.4, 0.0, 1.0)
	if _pop_time > 0.0:
		_pop_time -= delta
		_pop.modulate.a = clampf(_pop_time / 0.3, 0.0, 1.0)
		_pop.offset_top = -60.0 - (0.9 - _pop_time) * 40.0
		_pop.offset_bottom = _pop.offset_top + 60.0
	if _card_time > 0.0:
		_card_time -= delta
		_card.modulate.a = clampf(_card_time / 0.5, 0.0, 1.0)
		if _card_time <= 0.0:
			_card.visible = false
	if _ink_time > 0.0:
		_ink_time -= delta
		_ink.color.a = clampf(_ink_time / 2.0, 0.0, 1.0) * 0.6


func _draw() -> void:
	var font := ThemeDB.fallback_font
	# Can çubuğu (sol üst, paranın altında değil, kovanın altında)
	var hp_rect := Rect2(20, 132, 220, 18)
	draw_rect(hp_rect, Color(1, 1, 1, 0.7))
	var hp_col := Color("3B9B5A") if _hp > 40.0 else Color("D1495B")
	draw_rect(Rect2(hp_rect.position, Vector2(hp_rect.size.x * clampf(_hp / 100.0, 0.0, 1.0), hp_rect.size.y)), hp_col)
	draw_rect(hp_rect, BROWN, false, 2.0)
	draw_string(font, hp_rect.position + Vector2(228, 16), "Can", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, BROWN)

	if not _tension_on:
		return
	var w := minf(560.0, size.x * 0.5)
	var bar := Rect2(size.x * 0.5 - w * 0.5, size.y - 110.0, w, 40.0)
	draw_rect(bar, Color(1, 1, 1, 0.85))
	draw_rect(Rect2(bar.position.x + bar.size.x * _zone.x, bar.position.y, bar.size.x * (_zone.y - _zone.x), bar.size.y), Color("7FC97F"))
	draw_rect(Rect2(bar.position.x + bar.size.x * 0.92, bar.position.y, bar.size.x * 0.08, bar.size.y), Color("D1495B"))
	var x := bar.position.x + bar.size.x * clampf(_tension, 0.0, 1.0)
	draw_rect(Rect2(x - 5.0, bar.position.y - 10.0, 10.0, bar.size.y + 20.0), BROWN)
	draw_rect(bar, BROWN, false, 3.0)
	draw_string(font, Vector2(bar.position.x, bar.position.y - 16.0), "Gerginlik: yeşilde tut", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, BROWN)
	draw_string(font, Vector2(bar.position.x, bar.position.y - 16.0), "%.1f m" % _dist, HORIZONTAL_ALIGNMENT_RIGHT, bar.size.x, 26, BROWN)
