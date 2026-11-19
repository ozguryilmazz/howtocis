extends PanelContainer
## Market paneli: kamış, solucan ve bıçak satın alınır.

signal closed

const ITEMS := preload("res://scripts/items.gd")
const C := preload("res://scripts/creatures.gd")
const TERRA := Color("D85A30")
const BROWN := Color("4A2A12")
const BLUE := Color("185FA5")

var _list: VBoxContainer
var _money: Label
var _note: Label


func _ready() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("FFF8EC")
	sb.border_color = TERRA
	sb.set_border_width_all(5)
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 16
	sb.content_margin_bottom = 18
	add_theme_stylebox_override("panel", sb)
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	custom_minimum_size = Vector2(760, 0)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	var title := _label("Market", 38, TERRA)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_money = _label("", 26, Color("854F0B"))
	head.add_child(_money)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	box.add_child(_list)
	_note = _label("", 20, BLUE, true)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_note)
	var close := Button.new()
	close.text = "Kapat"
	close.custom_minimum_size = Vector2(0, 64)
	close.add_theme_font_size_override("font_size", 28)
	preload("res://scripts/main_menu.gd").style_button(close)
	close.pressed.connect(func(): closed.emit())
	box.add_child(close)
	Game.money_changed.connect(func(_v): _refresh())
	Game.items_changed.connect(_refresh)
	_refresh()


func _label(t: String, size_px: int, color: Color, wrap := false) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _fish_names(tier: int) -> String:
	var n: Array = []
	for k in C.SPECIES:
		if int(C.SPECIES[k].get("tier", 1)) <= tier:
			n.append(str(C.SPECIES[k]["name"]).trim_suffix(" Balığı"))
	return ", ".join(n)


func _row(title: String, desc: String, price: int, owned_text: String, id: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var txt := VBoxContainer.new()
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	txt.add_child(_label(title, 27, BROWN))
	var d := _label(desc, 18, Color("7A6A55"), true)
	d.custom_minimum_size = Vector2(420, 0)
	txt.add_child(d)
	row.add_child(txt)
	var b := Button.new()
	b.custom_minimum_size = Vector2(210, 64)
	b.add_theme_font_size_override("font_size", 24)
	preload("res://scripts/main_menu.gd").style_button(b)
	if owned_text != "":
		b.text = owned_text
		b.disabled = true
	else:
		b.text = "%s altın" % Game.format_money(price)
		b.disabled = Game.money() < price
		b.pressed.connect(func():
			if Game.buy(id):
				_note.text = "Satın aldın: %s" % title
			else:
				_note.text = "Yeterli altının yok.")
	row.add_child(b)
	_list.add_child(row)


func _refresh() -> void:
	if _list == null:
		return
	_money.text = "%s altın" % Game.format_money(Game.money())
	for c in _list.get_children():
		c.queue_free()
	var gold: Dictionary = ITEMS.RODS["altin"]
	_row(str(gold["name"]), "Daha iyi balıklar: %s. Daha hızlı sarar." % _fish_names(int(gold["tier"])),
		int(gold["price"]), "Sende" if Game.owns_rod("altin") else "", "rod:altin")
	var worm_fish: Array = []
	for k in C.SPECIES:
		if C.SPECIES[k].get("worm", false):
			worm_fish.append(str(C.SPECIES[k]["name"]).trim_suffix(" Balığı"))
	_row("Solucan ×%d  (sende: %d)" % [ITEMS.WORM_PACK, Game.worms()],
		"Pahalı balıklar için yem: %s. Balık oltaya takılınca 1 solucan gider." % ", ".join(worm_fish),
		ITEMS.WORM_PRICE * ITEMS.WORM_PACK, "", "worms")
	_row("Bıçak", "Yumruk yerine bıçak: her vuruş 2 kat güçlü.",
		int(ITEMS.KNIFE["price"]), "Sende" if Game.has_knife() else "", "knife")
