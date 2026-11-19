extends Node
## Güncelleme kontrolü: GitHub'daki en son sürümü oyunun sürümüyle karşılaştırır.
## Yeni sürüm varsa APK indirme bağlantısı tarayıcıda açılır, Android kurulumu başlatır.

signal update_available(version: String)

const REPO := "ozguryilmazz/howtocis"
const LATEST_API := "https://api.github.com/repos/%s/releases/latest"
const APK_URL := "https://github.com/%s/releases/latest/download/howtocis.apk"

var latest_version := ""
var has_update := false


func check() -> void:
	var http := HTTPRequest.new()
	http.timeout = 10.0
	add_child(http)
	var err := http.request(LATEST_API % REPO,
		["User-Agent: howtocis-game", "Accept: application/vnd.github+json"])
	if err != OK:
		http.queue_free()
		return
	var res: Array = await http.request_completed
	http.queue_free()
	if res[0] != HTTPRequest.RESULT_SUCCESS or res[1] != 200:
		return
	var j = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	if not (j is Dictionary):
		return
	latest_version = str(j.get("tag_name", "")).trim_prefix("v")
	if is_newer(latest_version, Game.version()):
		has_update = true
		update_available.emit(latest_version)


func open_download() -> void:
	OS.shell_open(APK_URL % REPO)


static func is_newer(candidate: String, current: String) -> bool:
	var a := candidate.split(".")
	var b := current.split(".")
	for i in range(max(a.size(), b.size())):
		var x := int(a[i]) if i < a.size() else 0
		var y := int(b[i]) if i < b.size() else 0
		if x != y:
			return x > y
	return false
