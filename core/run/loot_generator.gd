## Generador determinista sin estado (Stateless) de botín de combate, sorteos de reliquias y stock de tienda.
## Extraído de `RunState` para cumplir el Principio de Responsabilidad Única (SRP).
extends RefCounted
class_name LootGenerator

## Sortea, adquiere y equipa una reliquia en `run` utilizando un motor RNG determinista.
## Implementa filtros en cascada para evitar duplicados en el inventario activo.
static func grant_random_relic(run: RunState, bonus_fortune: float = 0.0) -> String:
	if run.relic_catalog.is_empty():
		run.relic_catalog = GameDatabase.load_all_relics()
	if run.relic_catalog.is_empty():
		return "Sin reliquias en res://relics/data"

	var rng := RandomNumberGenerator.new()
	rng.seed = FloorGenerator.get_floor_subseed(run.master_seed, run.current_floor * 100 + run.active_relics.size())

	var rolled_tier: RaritySystem.Tier = RaritySystem.roll_tier(rng, run.current_floor, run.player_luck, bonus_fortune)

	var candidates: Array[RelicData] = []
	for r in run.relic_catalog:
		if r.rarity == rolled_tier and not run.active_relics.has(r):
			candidates.append(r)

	if candidates.is_empty():
		for r in run.relic_catalog:
			if r.rarity == rolled_tier:
				candidates.append(r)

	if candidates.is_empty():
		for r in run.relic_catalog:
			if not run.active_relics.has(r):
				candidates.append(r)
	if candidates.is_empty():
		candidates = run.relic_catalog

	var chosen: RelicData = candidates[rng.randi_range(0, candidates.size() - 1)]
	run.equip_specific_relic(chosen)
	return chosen.get_effects_description()

## Instancia un motor de entropía aislada para gestionar el bazar combinando semilla maestra, piso y coordenadas.
static func get_shop_rng(run: RunState, room_pos: Vector2i) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	var shop_seed: int = abs(hash("%d_FLOOR_%d_SHOP_%d_%d" % [run.master_seed, run.current_floor, room_pos.x, room_pos.y]))
	rng.seed = shop_seed
	return rng

## Sortea y devuelve un arreglo de `count` cartas únicas del catálogo para el stock de la tienda.
static func generate_shop_cards(run: RunState, room_pos: Vector2i, count: int = 3, bonus_fortune: float = 0.0) -> Array[CardData]:
	var rng: RandomNumberGenerator = get_shop_rng(run, room_pos)
	var result: Array[CardData] = []
	
	var pool_card: Array[CardData] = run.available_card_pool.filter(func(c: CardData): return c != null)
	if pool_card.is_empty():
		return result

	for i in range(min(count, pool_card.size())):
		var target_tier: RaritySystem.Tier = RaritySystem.roll_tier(rng, run.current_floor, run.player_luck, bonus_fortune)
		var picked: CardData = pick_from_pool_by_tier_cards(pool_card, target_tier, rng)
		if picked:
			var copy: CardData = picked.duplicate() as CardData
			copy.resource_name = picked.resource_path if picked.resource_path != "" else picked.resource_name
			result.append(copy)
			pool_card.erase(picked)

	return result

## Sortea y devuelve un arreglo de reliquias para el comercio excluyendo las que el jugador ya tenga equipadas.
static func generate_shop_relics(run: RunState, room_pos: Vector2i, count: int = 2, bonus_fortune: float = 0.0) -> Array[RelicData]:
	var rng: RandomNumberGenerator = get_shop_rng(run, room_pos)
	rng.randi()
	
	var result: Array[RelicData] = []
	var owned_titles: Array[String] = []
	for owned in run.active_relics:
		if owned:
			owned_titles.append(owned.title)

	var pool: Array[RelicData] = run.relic_catalog.filter(
		func(r: RelicData): return r != null and not owned_titles.has(r.title)
	)
	if pool.is_empty():
		return result

	for i in range(min(count, pool.size())):
		var target_tier: RaritySystem.Tier = RaritySystem.roll_tier(rng, run.current_floor, run.player_luck, bonus_fortune)
		var picked: RelicData = pick_from_pool_by_tier_relics(pool, target_tier, rng)
		if picked:
			result.append(picked)
			pool.erase(picked)

	return result

## Genera las recompensas de un combate ganado de forma 100% determinista (Oro, XP, Nivel, Cartas y Reliquia).
static func generate_combat_rewards(run: RunState, combat_index: int = 0) -> Dictionary:
	var room_type: int = run.current_room.room_type if run.current_room != null else RoomData.Type.COMBAT
	var is_boss: bool = (room_type == RoomData.Type.BOSS)
	var is_elite: bool = (room_type == RoomData.Type.ELITE)

	var rng := RandomNumberGenerator.new()
	var reward_seed := FloorGenerator.get_floor_subseed(
		run.master_seed, 
		run.current_floor * 1000 + combat_index + (run.player_grid_pos.x * 17) + (run.player_grid_pos.y * 31)
	)
	rng.seed = reward_seed

	# 1. Oro base escalado de forma 100% determinista por piso y tipo de encuentro
	var base_gold: int = 10 + (run.current_floor * 2) + rng.randi_range(0, 4)
	var gold: int = base_gold
	if is_boss:
		gold = int(round(float(base_gold) * 2.5))
	elif is_elite:
		gold = int(round(float(base_gold) * 1.6))

	# 2. Otorgar Experiencia (XP) según el tipo de encuentro (Común x1.0, Élite x2.5, Jefe x5.0)
	var xp_amount: int = run.get_combat_xp_reward(room_type, run.current_floor)
	var xp_result: Dictionary = run.gain_xp(xp_amount)
	
	# 3. 3 cartas sin repetir según RaritySystem (con bonus de fortuna en Élite y Jefe)
	var bonus_fortune: float = 2.5 if is_boss else (1.25 if is_elite else 0.0)
	var cards: Array[CardData] = []
	var pool: Array[CardData] = run.available_card_pool.filter(func(c): return c != null)
	
	for i in range(3):
		if pool.is_empty():
			break
		var tier := RaritySystem.roll_tier(rng, run.current_floor, run.player_luck, bonus_fortune)
		var card := pick_from_pool_by_tier_cards(pool, tier, rng)
		if card:
			var copy: CardData = card.duplicate() as CardData
			copy.resource_name = card.resource_path if card.resource_path != "" else card.resource_name
			cards.append(copy)
			pool.erase(card)
	
	# 4. Chance de reliquia determinista (30% Común, 65% Élite, 100% Jefe)
	var relic_chance: float = 1.0 if is_boss else (0.65 if is_elite else 0.30)
	var relic: RelicData = null
	if rng.randf() < relic_chance and not run.relic_catalog.is_empty():
		relic = run.relic_catalog[rng.randi_range(0, run.relic_catalog.size() - 1)]
	
	return {
		"gold": gold,
		"cards": cards,
		"relic": relic,
		"xp_result": xp_result
	}

## Selecciona una carta al azar filtrando por `tier` con fallback al pool completo.
static func pick_from_pool_by_tier_cards(pool: Array[CardData], tier: RaritySystem.Tier, rng: RandomNumberGenerator) -> CardData:
	var candidates: Array[CardData] = pool.filter(func(c: CardData): return c.rarity == tier)
	if candidates.is_empty():
		candidates = pool
	return candidates[rng.randi_range(0, candidates.size() - 1)]

## Selecciona una reliquia al azar filtrando por `tier` con fallback al pool completo.
static func pick_from_pool_by_tier_relics(pool: Array[RelicData], tier: RaritySystem.Tier, rng: RandomNumberGenerator) -> RelicData:
	var candidates: Array[RelicData] = pool.filter(func(r: RelicData): return r.rarity == tier)
	if candidates.is_empty():
		candidates = pool
	return candidates[rng.randi_range(0, candidates.size() - 1)]
