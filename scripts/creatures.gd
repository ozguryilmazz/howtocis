extends RefCounted
## Ege Koyu'nun canlıları ve fiyat / gösteri hesapları.
## Sayılar bu oyuna özeldir: base = temel fiyat (altın), hp = yumruk sayısı,
## pull = misinayı çekme gücü (0..1), weight = ne sık geldiği.

## shape "model" olan türler kendi 3B model dosyasını (glb) ve animasyonlarını kullanır.
## model_len: modelin ölçeksiz boyu (m); balık boyuna göre ölçeklenir.
const SPECIES := {
	"istavrit": {"name": "İstavrit", "base": 8, "hp": 1, "pull": 0.25, "weight": 30, "cm": 18,
		"body": "8FB3C9", "fin": "4E7A96", "shape": "fish"},
	"kefal": {"name": "Kefal", "base": 12, "hp": 2, "pull": 0.35, "weight": 24, "cm": 30,
		"body": "B9C2C7", "fin": "6F7E86", "shape": "fish"},
	"cipura": {"name": "Çipura", "base": 16, "hp": 2, "pull": 0.4, "weight": 18, "cm": 28,
		"body": "D9D4C4", "fin": "C9A227", "shape": "round"},
	"barbunya": {"name": "Barbunya", "base": 22, "hp": 2, "pull": 0.45, "weight": 12, "cm": 20,
		"body": "E07A5F", "fin": "F2CC8F", "shape": "fish"},
	"fener": {"name": "Fener Balığı", "base": 30, "hp": 3, "pull": 0.5, "weight": 14, "cm": 45,
		"body": "5A2A1E", "fin": "A8A27A", "shape": "model",
		"model": "res://models/anglerfish.glb", "model_len": 5.5,
		"anim_flop": "Fish_Armature|Out_Of_Water", "anim_die": "Fish_Armature|Death"},
	"levrek": {"name": "Levrek", "base": 28, "hp": 3, "pull": 0.55, "weight": 9, "cm": 45,
		"body": "A7B4AE", "fin": "4F5D57", "shape": "fish"},
	"murekkep": {"name": "Mürekkep Balığı", "base": 38, "hp": 3, "pull": 0.6, "weight": 5, "cm": 35,
		"body": "C98BB9", "fin": "8E5A85", "shape": "squid", "ink": true},
	"kirlangic": {"name": "Kırlangıç", "base": 55, "hp": 4, "pull": 0.75, "weight": 2, "cm": 40,
		"body": "D1495B", "fin": "3D85C6", "shape": "fish", "bites": true},
}

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
	return "istavrit"


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
