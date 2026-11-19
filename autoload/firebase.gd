extends Node
## Firebase REST istemcisi: anonim giriş ve Firestore'da oyun kaydı.
## Ayarlar res://config/firebase.json dosyasından okunur. Dosya boşsa oyun
## çevrimdışı çalışır ve kayıtlar yalnızca telefonda tutulur.

signal signed_in
signal status_changed(text: String)

const AUTH_PATH := "user://auth.json"
const CONFIG_PATH := "res://config/firebase.json"

var api_key := ""
var project_id := ""
var uid := ""
var status := "Çevrimdışı"

var _id_token := ""
var _refresh_token := ""
var _token_expiry := 0.0


func _ready() -> void:
	var f := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if f:
		var cfg = JSON.parse_string(f.get_as_text())
		if cfg is Dictionary:
			api_key = str(cfg.get("api_key", ""))
			project_id = str(cfg.get("project_id", ""))


func is_configured() -> bool:
	return api_key != "" and project_id != ""


func is_signed_in() -> bool:
	return uid != "" and _id_token != ""


func _set_status(text: String) -> void:
	status = text
	status_changed.emit(text)


func sign_in() -> void:
	if not is_configured():
		_set_status("Bulut ayarlanmadı")
		return
	_set_status("Bağlanıyor…")
	_load_auth()
	var ok := false
	if _refresh_token != "":
		ok = await _refresh()
	if not ok:
		ok = await _sign_up()
	if ok:
		_save_auth()
		_set_status("Bulut bağlı")
		signed_in.emit()
	else:
		_set_status("Çevrimdışı")


func _sign_up() -> bool:
	var url := "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=%s" % api_key
	var res := await _request(url, HTTPClient.METHOD_POST,
		["Content-Type: application/json"], JSON.stringify({"returnSecureToken": true}))
	if not res.ok or not (res.body is Dictionary):
		return false
	uid = str(res.body.get("localId", ""))
	_id_token = str(res.body.get("idToken", ""))
	_refresh_token = str(res.body.get("refreshToken", ""))
	_token_expiry = Time.get_unix_time_from_system() + float(res.body.get("expiresIn", "3600"))
	return uid != ""


func _refresh() -> bool:
	var url := "https://securetoken.googleapis.com/v1/token?key=%s" % api_key
	var body := "grant_type=refresh_token&refresh_token=%s" % _refresh_token.uri_encode()
	var res := await _request(url, HTTPClient.METHOD_POST,
		["Content-Type: application/x-www-form-urlencoded"], body)
	if not res.ok or not (res.body is Dictionary):
		return false
	uid = str(res.body.get("user_id", ""))
	_id_token = str(res.body.get("id_token", ""))
	_refresh_token = str(res.body.get("refresh_token", _refresh_token))
	_token_expiry = Time.get_unix_time_from_system() + float(res.body.get("expires_in", "3600"))
	return uid != ""


func _ensure_token() -> bool:
	if not is_signed_in():
		return false
	if Time.get_unix_time_from_system() < _token_expiry - 60.0:
		return true
	var ok := await _refresh()
	if ok:
		_save_auth()
	return ok


func _save_doc_url() -> String:
	return "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents/saves/%s" % [project_id, uid]


## Buluttaki kaydı döndürür. Kayıt yoksa ya da bağlantı yoksa boş sözlük döner.
func load_save() -> Dictionary:
	if not await _ensure_token():
		return {}
	var res := await _request(_save_doc_url(), HTTPClient.METHOD_GET,
		["Authorization: Bearer %s" % _id_token], "")
	if not res.ok or not (res.body is Dictionary):
		return {}
	var fields: Dictionary = res.body.get("fields", {})
	var raw := str(fields.get("data", {}).get("stringValue", ""))
	var parsed = JSON.parse_string(raw)
	return parsed if parsed is Dictionary else {}


func save(data: Dictionary) -> bool:
	if not await _ensure_token():
		return false
	var doc := {
		"fields": {
			"data": {"stringValue": JSON.stringify(data)},
			"updatedAt": {"integerValue": str(int(data.get("updated_at", 0)))},
		}
	}
	var res := await _request(_save_doc_url(), HTTPClient.METHOD_PATCH,
		["Authorization: Bearer %s" % _id_token, "Content-Type: application/json"], JSON.stringify(doc))
	return res.ok


func _request(url: String, method: int, headers: PackedStringArray, body: String) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 15.0
	add_child(http)
	var err := http.request(url, headers, method, body)
	if err != OK:
		http.queue_free()
		return {"ok": false, "code": 0, "body": null}
	var res: Array = await http.request_completed
	http.queue_free()
	var text: String = (res[3] as PackedByteArray).get_string_from_utf8()
	var parsed = JSON.parse_string(text) if text != "" else null
	var code: int = res[1]
	return {"ok": res[0] == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300, "code": code, "body": parsed}


func _load_auth() -> void:
	var f := FileAccess.open(AUTH_PATH, FileAccess.READ)
	if not f:
		return
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		_refresh_token = str(d.get("refresh_token", ""))


func _save_auth() -> void:
	var f := FileAccess.open(AUTH_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"refresh_token": _refresh_token, "uid": uid}))
