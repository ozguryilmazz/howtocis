extends Control
## Ana menü: başlık, zorluk seçimi, oyna düğmesi, bulut ve güncelleme durumu.

const SAND := Color("F7E3C6")
const SEA := Color("3C8DBF")
const TERRACOTTA := Color("D85A30")
const DARK := Color("4A2A12")

var _diff_buttons := {}
var _hint: Label
var _status: Label
var _update_btn: Button


static func _box(color: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = border
	s.set_border_width_all(4)
	s.set_corner_radius_all(18)
	return s


## Ege temalı düğme: beyaz zemin, kiremit yazı; seçiliyken kiremit zemin.
static func style_button(b: Button) -> void:
	b.add_theme_stylebox_override("normal", _box(Color.WHITE, TERRACOTTA))
	b.add_theme_stylebox_override("hover", _box(Color("FFF4E0"), TERRACOTTA))
	b.add_theme_stylebox_override("pressed", _box(TERRACOTTA, TERRACOTTA))
	b.add_theme_stylebox_override("hover_pressed", _box(TERRACOTTA, TERRACOTTA))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_focus_color"]:
		b.add_theme_color_override(c, TERRACOTTA)
	for c in ["font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, Color.WHITE)


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = SAND
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	var sea := ColorRect.new()
	sea.color = SEA
	sea.anchor_top = 0.74
	sea.anchor_right = 1.0
	sea.anchor_bottom = 1.0
	add_child(sea)

	var center := CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)

	var title := Label.new()
	title.text = "HOW TO ÇİŞ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 84)
	title.add_theme_color_override("font_color", TERRACOTTA)
	title.add_theme_color_override("font_outline_color", Color.WHITE)
	title.add_theme_constant_override("outline_size", 14)
	box.add_child(title)

	var sub := Label.new()
	sub.text = "Ege kıyılarında balık avı"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 26)
	sub.add_theme_color_override("font_color", DARK)
	box.add_child(sub)

	var diff_label := Label.new()
	diff_label.text = "Zorluk"
	diff_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	diff_label.add_theme_font_size_override("font_size", 24)
	diff_label.add_theme_color_override("font_color", DARK)
	box.add_child(diff_label)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	var group := ButtonGroup.new()
	for key in ["kolay", "normal", "zor"]:
		var b := Button.new()
		b.text = Game.DIFFICULTIES[key]["label"]
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(170, 70)
		b.add_theme_font_size_override("font_size", 30)
		b.pressed.connect(_on_difficulty.bind(key))
		style_button(b)
		row.add_child(b)
		_diff_buttons[key] = b

	var play := Button.new()
	play.text = "Oyna"
	play.custom_minimum_size = Vector2(360, 90)
	play.add_theme_font_size_override("font_size", 42)
	play.pressed.connect(_on_play)
	style_button(play)
	play.add_theme_stylebox_override("normal", _box(TERRACOTTA, Color.WHITE))
	play.add_theme_stylebox_override("hover", _box(Color("C24E26"), Color.WHITE))
	for c in ["font_color", "font_hover_color", "font_focus_color"]:
		play.add_theme_color_override(c, Color.WHITE)
	box.add_child(play)

	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 22)
	_hint.add_theme_color_override("font_color", TERRACOTTA)
	box.add_child(_hint)

	_update_btn = Button.new()
	_update_btn.text = "Güncellemeleri kontrol et"
	_update_btn.custom_minimum_size = Vector2(0, 64)
	_update_btn.add_theme_font_size_override("font_size", 26)
	_update_btn.pressed.connect(_on_update_pressed)
	style_button(_update_btn)
	box.add_child(_update_btn)

	_status = Label.new()
	_status.anchor_left = 0.0
	_status.anchor_top = 1.0
	_status.anchor_right = 1.0
	_status.anchor_bottom = 1.0
	_status.offset_top = -44
	_status.offset_left = 20
	_status.add_theme_font_size_override("font_size", 20)
	_status.add_theme_color_override("font_color", Color.WHITE)
	add_child(_status)

	Firebase.status_changed.connect(func(_t): _refresh_status())
	Game.data_loaded.connect(_sync_difficulty)
	Updater.update_available.connect(_on_update)
	if Updater.has_update:
		_on_update(Updater.latest_version)
	_sync_difficulty()
	_refresh_status()


func _sync_difficulty() -> void:
	var key := str(Game.data.get("difficulty", ""))
	for k in _diff_buttons:
		_diff_buttons[k].button_pressed = (k == key)
	_hint.text = "" if Game.has_difficulty() else "Önce bir zorluk seç"


func _on_difficulty(key: String) -> void:
	Game.set_difficulty(key)
	_hint.text = ""


func _on_play() -> void:
	if not Game.has_difficulty():
		_hint.text = "Önce bir zorluk seç"
		return
	get_tree().change_scene_to_file("res://scenes/world.tscn")


func _on_update(version: String) -> void:
	_update_btn.text = "Yeni sürüm var: v%s  —  İndir ve kur" % version
	_update_btn.disabled = false


## Güncelleme varsa indirir; yoksa GitHub'a yeniden sorar ve sonucu düğmede gösterir.
func _on_update_pressed() -> void:
	if Updater.has_update:
		Updater.open_download()
		return
	_update_btn.text = "Kontrol ediliyor…"
	_update_btn.disabled = true
	var result: String = await Updater.check()
	_update_btn.disabled = false
	match result:
		"yeni":
			_on_update(Updater.latest_version)
		"guncel":
			_update_btn.text = "En son sürümdesin (v%s)  —  Tekrar kontrol et" % Game.version()
		_:
			_update_btn.text = "İnternete bağlanılamadı  —  Tekrar dene"


func _refresh_status() -> void:
	_status.text = "Sürüm %s   ·   %s" % [Game.version(), Firebase.status]
