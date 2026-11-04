class_name EconomyCatalog
extends RefCounted
# New bounded adapter for the recovered FlightModel inventory API. These prices
# are prototype reconstruction values; original FFE markets/factions are stage11.
const SOURCE_PROFILE := "reconstructed-adapted-economy-v1"
var goods: Dictionary = {
	"medicines": {"id": "medicines", "name": "Медикаменты", "name_ru": "Медикаменты", "unit": "т", "base_price": 100, "price": 100, "space": 1},
	"food": {"id": "food", "name": "Продовольствие", "name_ru": "Продовольствие", "unit": "т", "base_price": 30, "price": 30, "space": 1},
	"metals": {"id": "metals", "name": "Металлы", "name_ru": "Металлы", "unit": "т", "base_price": 60, "price": 60, "space": 1},
	"machines": {"id": "machines", "name": "Машины", "name_ru": "Машины", "unit": "т", "base_price": 180, "price": 180, "space": 1},
	"electronics": {"id": "electronics", "name": "Электроника", "name_ru": "Электроника", "unit": "т", "base_price": 250, "price": 250, "space": 1},
	"luxury": {"id": "luxury", "name": "Предметы роскоши", "name_ru": "Предметы роскоши", "unit": "т", "base_price": 400, "price": 400, "space": 1}
}
var equipment: Dictionary = {
	"shield": {"id": "shield", "name": "Усиленные щиты", "name_ru": "Усиленные щиты", "price": 800, "space": 4, "description": "Увеличивают запас щитов корабля."},
	"cooler": {"id": "cooler", "name": "Усиленное охлаждение", "name_ru": "Усиленное охлаждение", "price": 600, "space": 2, "description": "Ускоряет охлаждение оружия."},
	"engine": {"id": "engine", "name": "Усилитель тяги", "name_ru": "Усилитель тяги", "price": 1200, "space": 4, "description": "Повышает доступное ускорение на 20%."},
	"hyperdrive": {"id": "hyperdrive", "name": "Усиленный гипердвигатель", "name_ru": "Усиленный гипердвигатель", "price": 1600, "space": 6, "description": "Увеличивает дальность прыжка на 25%."}
}
var ship_prices: Dictionary = {"cobra": 20000, "eagle": 12000, "shuttle": 5000}

func empty_manifest() -> Dictionary:
	var result: Dictionary = {}
	for id in goods: result[id] = 0
	return result

func good(id: String) -> Dictionary:
	return goods[id].duplicate(true) if goods.has(id) else {}

func item(id: String) -> Dictionary:
	return equipment[id].duplicate(true) if equipment.has(id) else {}
