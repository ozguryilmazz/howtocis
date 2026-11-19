extends RefCounted
## Market eşyaları: kamışlar, solucan ve bıçak.
##
## Kamış: hangi balıkların tutulabileceğini belirler (tier). Bir kamış kendi ve
##   altındaki seviyedeki balıkları tutar.
## Solucan: her kamışın aralığındaki pahalı balıklar (worm: true) için gereklidir.
##   Böyle bir balık oltaya takılınca bir solucan harcanır.
##   Kural: solucan fiyatı, solucanla tutulabilecek en ucuz balığın en düşük
##   fiyatından her zaman küçüktür (worm_price_ok ile denetlenir).
## Bıçak: yumruk yerine bıçakla vurulur, vuruş gücü artar.

const C := preload("res://scripts/creatures.gd")

const RODS := {
	"baslangic": {"name": "Başlangıç Kamışı", "tier": 1, "price": 0,
		"model": "res://models/items/kamis_baslangic.glb", "reel": 1.0, "yaw": 0.0, "reel_y": 0.3},
	"altin": {"name": "Altın Kamış", "tier": 2, "price": 350,
		"model": "res://models/items/kamis_altin.glb", "reel": 1.25, "yaw": 0.0, "reel_y": 0.18},
}

const WORM_PRICE := 4
const WORM_PACK := 5

const FISTS := {"name": "Yumruk", "damage": 1, "reach": 3.0, "cooldown": 0.32}
const KNIFE := {"name": "Bıçak", "damage": 2, "reach": 3.2, "cooldown": 0.3, "price": 120,
	"model": "res://models/items/bicak.glb"}


## Bu kamış ve solucan durumuyla oltaya gelebilecek türler.
static func catchable(rod_tier: int, has_worm: bool) -> Array:
	var out: Array = []
	for k in C.SPECIES:
		var s: Dictionary = C.SPECIES[k]
		if int(s.get("tier", 1)) > rod_tier:
			continue
		if s.get("worm", false) and not has_worm:
			continue
		out.append(k)
	return out


## Solucanla tutulabilecek balıkların en düşük olası satış fiyatı (boy 0.7, gösteri ×1).
static func cheapest_worm_catch() -> int:
	var low := 1 << 30
	for k in C.SPECIES:
		if C.SPECIES[k].get("worm", false):
			low = mini(low, C.price(k, 0.7, 1.0, false, 1.0))
	return low


static func worm_price_ok() -> bool:
	return WORM_PRICE < cheapest_worm_catch()
