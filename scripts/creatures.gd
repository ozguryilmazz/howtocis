extends RefCounted
## Ege Koyu'nun canlıları ve fiyat / gösteri hesapları.
## Sayılar bu oyuna özeldir: base = temel fiyat (altın), hp = yumruk sayısı,
## pull = misinayı çekme gücü (0..1), weight = ne sık geldiği.

## Her tür kendi 3B modelini (glb, Quaternius, CC0) ve animasyonlarını kullanır.
## model_len: modelin ölçeksiz boyu (m); oyundaki balık boyuna göre ölçeklenir.
## body / fin: model yüklenemezse kullanılan yedek renkler.
## bites: yerdeyken yakındaki oyuncuya zarar verir. puffs: ilk vuruşta şişer.
const SPECIES := {
	"palyaco": {"name": "Palyaço Balığı", "base": 9, "hp": 1, "pull": 0.25, "weight": 30, "cm": 15,
		"model": "res://models/fish/palyaco.glb", "model_len": 5.27, "body": "F28C28", "fin": "FFFFFF"},
	"japon": {"name": "Mavi Japon Balığı", "base": 13, "hp": 2, "pull": 0.35, "weight": 26, "cm": 20,
		"model": "res://models/fish/japon.glb", "model_len": 5.64, "body": "3C7DD9", "fin": "9CC3F0"},
	"balon": {"name": "Balon Balığı", "base": 22, "hp": 2, "pull": 0.45, "weight": 18, "cm": 30,
		"model": "res://models/fish/balon.glb", "model_len": 4.02, "body": "D9C27A", "fin": "8A7A4A",
		"puffs": true},
	"fener": {"name": "Fener Balığı", "base": 30, "hp": 3, "pull": 0.5, "weight": 14, "cm": 45,
		"model": "res://models/fish/fener.glb", "model_len": 5.53, "body": "5A2A1E", "fin": "A8A27A"},
	"aslan": {"name": "Aslan Balığı", "base": 48, "hp": 3, "pull": 0.65, "weight": 7, "cm": 35,
		"model": "res://models/fish/aslan.glb", "model_len": 6.35, "body": "C0392B", "fin": "F5E6D3",
		"bites": true, "bite_text": "Dikeni battı!"},
}

## Tüm balık modellerinde ortak animasyon adları
const ANIM_FLOP := "Fish_Armature|Out_Of_Water"
const ANIM_DIE := "Fish_Armature|Death"

## Eski kayıtlardaki artık olmayan türler için yedek
const FALLBACK := "palyaco"

const SHINY_CHANCE := 0.01
const SHINY_PITY := 150
const SHINY_MULT := 3.0
const SHOW_CAP := 5.0

## Gösteri bonusları. Her biri çarpana eklenir: 1 + toplam, en fazla SHOW_CAP.
const BONUS := {
	"head": ["Kafadan", 1.0],
	"spin": ["360", 1.0],
	"one": ["Tek vuruş", 0.5],
	"noscope": ["Nişansız", 0.5],
}


static func roll_species(rng: RandomNumberGenerator) -> String:
	var total := 0
	for k in SPECIES:
		total += int(SPECIES[k]["weight"])
	var r := rng.randi_range(1, total)
	for k in SPECIES:
		r -= int(SPECIES[k]["weight"])
		if r <= 0:
			return k
	return FALLBACK


## Boy çarpanı 0.7..1.5; büyükler daha nadir.
static func roll_size(rng: RandomNumberGenerator) -> float:
	var t := pow(rng.randf(), 1.8)
	return snappedf(0.7 + t * 0.8, 0.01)


## Parlak (shiny) şansı; SHINY_PITY tutuştan sonra garanti.
static func roll_shiny(rng: RandomNumberGenerator, since_last: int) -> bool:
	return since_last + 1 >= SHINY_PITY or rng.randf() < SHINY_CHANCE


## bonuses: ["air", "head", "juggle", "juggle", ...] -> çarpan
static func show_multiplier(bonuses: Array) -> float:
	var m := 1.0
	for b in bonuses:
		if BONUS.has(b):
			m += float(BONUS[b][1])
	return minf(m, SHOW_CAP)


static func price(species: String, size: float, show: float, shiny: bool, sell_bonus := 1.0, cook := 1.0) -> int:
	var base := float(SPECIES[species]["base"])
	var v := base * size * show * cook * (SHINY_MULT if shiny else 1.0) * sell_bonus
	return maxi(1, int(round(v)))


## Bonus listesini ekranda göstermek için gruplar: [["Havada", "+1"], ["Zincir ×3", "+0.75"]]
static func bonus_lines(bonuses: Array) -> Array:
	var counts := {}
	var order: Array = []
	for b in bonuses:
		if not counts.has(b):
			order.append(b)
			counts[b] = 0
		counts[b] += 1
	var out: Array = []
	for b in order:
		var n: int = counts[b]
		var label: String = BONUS[b][0]
		if n > 1:
			label += " ×%d" % n
		out.append([label, "+%s" % _num(float(BONUS[b][1]) * n)])
	return out


static func _num(v: float) -> String:
	if is_equal_approx(v, round(v)):
		return str(int(round(v)))
	return str(snappedf(v, 0.01))
