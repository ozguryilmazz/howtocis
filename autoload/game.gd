extends Node
## Oyun durumu: para, zorluk ve kayıt. Kayıt önce telefona yazılır,
## bulut bağlıysa birkaç saniye sonra Firestore'a da gönderilir.

signal money_changed(value: int)
signal data_loaded
signal bucket_changed

const SAVE_PATH := "user://save.json"
const BUCKET_MAX := 10
const CLOUD_SAVE_DELAY := 3.0

const DIFFICULTIES := {
	"kolay": {"label": "Kolay", "creature_hp": 0.7, "damage_taken": 0.5, "bite_window": 1.4, "aim_assist": 1.0, "sell_bonus": 1.0},
	"normal": {"label": "Normal", "creature_hp": 1.0, "damage_taken": 1.0, "bite_window": 1.0, "aim_assist": 0.5, "sell_bonus": 1.0},
	"zor": {"label": "Zor", "creature_hp": 1.4, "damage_taken": 1.5, "bite_window": 0.7, "aim_assist": 0.0, "sell_bonus": 1.2},
}

var data: Dictionary = {}
var _cloud_timer := -1.0


func _ready() -> void:
	data = _defaults()
	_load_local()
	Firebase.signed_in.connect(_on_signed_in)
	Firebase.sign_in()
	Updater.check()


func _defaults() -> Dictionary:
	return {"save_version": 2, "money": 0, "difficulty": "", "updated_at": 0,
		"bucket": [], "caught": 0, "since_shiny": 0, "best_show": 1.0}


# --- Kova: tutulan balıklar satılana kadar burada durur ----------------

func bucket() -> Array:
	if not (data.get("bucket") is Array):
		data["bucket"] = []
	return data["bucket"]


func bucket_max() -> int:
	return BUCKET_MAX


func bucket_full() -> bool:
	return bucket().size() >= BUCKET_MAX


func bucket_value() -> int:
	var v := 0
	for f in bucket():
		v += int(f.get("value", 0))
	return v


## Tutulan balığı kovaya koyar ve istatistikleri günceller.
func add_catch(entry: Dictionary) -> void:
	bucket().append(entry)
	data["caught"] = int(data.get("caught", 0)) + 1
	data["since_shiny"] = 0 if entry.get("shiny", false) else int(data.get("since_shiny", 0)) + 1
	data["best_show"] = maxf(float(data.get("best_show", 1.0)), float(entry.get("show", 1.0)))
	bucket_changed.emit()
	save()


## Kovadaki her şeyi satar, kazancı döner.
func sell_all() -> int:
	var total := bucket_value()
	data["bucket"] = []
	bucket_changed.emit()
	add_money(total)
	return total


func version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))


func has_difficulty() -> bool:
	return DIFFICULTIES.has(str(data.get("difficulty", "")))


func difficulty() -> Dictionary:
	return DIFFICULTIES.get(str(data.get("difficulty", "")), DIFFICULTIES["normal"])


func set_difficulty(key: String) -> void:
	if DIFFICULTIES.has(key):
		data["difficulty"] = key
		save()


func money() -> int:
	return int(data.get("money", 0))


func add_money(amount: int) -> void:
	data["money"] = max(0, money() + amount)
	money_changed.emit(money())
	save()


static func format_money(value: int) -> String:
	var s := str(abs(value))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if value < 0 else "") + s + out


func save() -> void:
	data["updated_at"] = int(Time.get_unix_time_from_system())
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
	_cloud_timer = CLOUD_SAVE_DELAY


func _process(delta: float) -> void:
	if _cloud_timer < 0.0:
		return
	_cloud_timer -= delta
	if _cloud_timer < 0.0 and Firebase.is_signed_in():
		Firebase.save(data)


func _load_local() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		return
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		data.merge(d, true)
	data_loaded.emit()


func _on_signed_in() -> void:
	var cloud: Dictionary = await Firebase.load_save()
	if cloud.is_empty():
		Firebase.save(data)
		return
	if int(cloud.get("updated_at", 0)) > int(data.get("updated_at", 0)):
		data = _defaults()
		data.merge(cloud, true)
		var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify(data))
		money_changed.emit(money())
		bucket_changed.emit()
		data_loaded.emit()
	elif int(cloud.get("updated_at", 0)) < int(data.get("updated_at", 0)):
		Firebase.save(data)
