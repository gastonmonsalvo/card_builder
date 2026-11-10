## Servicio sin estado (Stateless) responsable de serializar y deserializar `RunState` hacia/desde diccionarios JSON.
## Extraído de `RunState` para cumplir con el Principio de Responsabilidad Única (SRP).
extends RefCounted
class_name RunSerializer

## Transforma el estado vivo de `run` (estadísticas, nivel, ubicaciones en el mapa, inventarios, mazos y reliquias)
## en un diccionario de primitivas seguro para persistir en disco.
static func to_dict(run: RunState, deck_data: Array) -> Dictionary:
	var relic_paths: Array[String] = []
	for relic in run.active_relics:
		if relic:
			var path: String = relic.resource_path
			if path == "" and relic.resource_name != "":
				path = relic.resource_name
			if path != "":
				relic_paths.append(path)

	var inventory_weapon_paths: Array[String] = []
	var inventory_weapon_ids: Array[String] = []
	for weapon in run.inventory_weapons:
		if weapon:
			inventory_weapon_paths.append(get_weapon_resource_path(run, weapon))
			inventory_weapon_ids.append(weapon.weapon_id)
				
	var cleared_rooms: Array[Array] = []
	var discovered_rooms: Array[Array] = []
	var rooms_dict: Dictionary = run.floor_data.get("rooms", {})
	
	for pos in rooms_dict.keys():
		var room: RoomData = rooms_dict[pos]
		if room.cleared:
			cleared_rooms.append([pos.x, pos.y])
		if room.discovered:
			discovered_rooms.append([pos.x, pos.y])

	return {
		"master_seed": run.master_seed,
		"current_floor": run.current_floor,
		"selected_hero_path": run.selected_hero.resource_path if run.selected_hero else "",
		"current_weapon_path": get_weapon_resource_path(run, run.current_weapon),
		"current_weapon_id": run.current_weapon.weapon_id if run.current_weapon else "",
		"inventory_weapon_paths": inventory_weapon_paths,
		"inventory_weapon_ids": inventory_weapon_ids,
		"player_pos": [run.player_grid_pos.x, run.player_grid_pos.y],
		"stats": {
			"hp": run.player_hp,
			"max_hp": run.max_player_hp,
			"gold": run.player_gold,
			"energy": run.max_energy,
			"hand_size": run.target_hand_size,
			"discards": run.discards_per_combat,
			"luck": run.player_luck,
			"str": run.player_str,
			"int": run.player_int,
			"dex": run.player_dex,
			"level": run.player_level,
			"xp": run.player_xp,
			"total_xp": run.total_xp_earned,
			"stat_points": run.unspent_stat_points,
			"bonus_crit_rating": run.bonus_crit_rating
		},
		"deck": deck_data,
		"relics": relic_paths,
		"map_state": {
			"cleared": cleared_rooms,
			"discovered": discovered_rooms
		}
	}

## Reconstruye el estado de `run` desde un diccionario JSON manteniendo retrocompatibilidad con guardados previos.
static func from_dict(run: RunState, data: Dictionary, deck: DeckManager) -> void:
	run.master_seed = int(data.get("master_seed", 0))
	run.current_floor = int(data.get("current_floor", 1))
	
	run.selected_hero = null
	var hero_path: String = str(data.get("selected_hero_path", ""))
	if hero_path != "" and ResourceLoader.exists(hero_path):
		run.selected_hero = load(hero_path) as HeroData

	var stats: Dictionary = data.get("stats", {})
	run.player_hp = int(stats.get("hp", 60))
	run.max_player_hp = int(stats.get("max_hp", 60))
	run.player_gold = int(stats.get("gold", 0))
	run.max_energy = int(stats.get("energy", 3))
	run.target_hand_size = int(stats.get("hand_size", 5))
	run.discards_per_combat = int(stats.get("discards", 2))
	run.player_luck = int(stats.get("luck", 0))
	run.player_str = int(stats.get("str", run.selected_hero.base_str if run.selected_hero else CombatConstants.BASE_STR))
	run.player_int = int(stats.get("int", run.selected_hero.base_int if run.selected_hero else CombatConstants.BASE_INT))
	run.player_dex = int(stats.get("dex", run.selected_hero.base_dex if run.selected_hero else CombatConstants.BASE_DEX))
	run.player_level = max(1, int(stats.get("level", 1)))
	run.player_xp = max(0, int(stats.get("xp", 0)))
	run.total_xp_earned = max(0, int(stats.get("total_xp", 0)))
	run.unspent_stat_points = max(0, int(stats.get("stat_points", 0)))
	run.bonus_crit_rating = max(0, int(stats.get("bonus_crit_rating", 0)))

	if run.weapon_catalog.is_empty():
		run.weapon_catalog = GameDatabase.load_all_weapons()
	run.current_weapon = resolve_weapon(
		run,
		str(data.get("current_weapon_path", "")),
		str(data.get("current_weapon_id", ""))
	)
	if not run.current_weapon and run.selected_hero and run.selected_hero.starting_weapon:
		run.current_weapon = run.selected_hero.starting_weapon
	if not run.current_weapon:
		run.current_weapon = CombatConstants.BASIC_WEAPON

	run.inventory_weapons.clear()
	var saved_weapon_paths: Array = data.get("inventory_weapon_paths", [])
	var saved_weapon_ids: Array = data.get("inventory_weapon_ids", [])
	var saved_weapon_count: int = max(saved_weapon_paths.size(), saved_weapon_ids.size())
	for index in range(saved_weapon_count):
		var saved_path: String = str(saved_weapon_paths[index]) if index < saved_weapon_paths.size() else ""
		var saved_id: String = str(saved_weapon_ids[index]) if index < saved_weapon_ids.size() else ""
		var weapon := resolve_weapon(run, saved_path, saved_id)
		if weapon and not run._same_weapon(weapon, run.current_weapon) and run._find_inventory_weapon_index(weapon) == -1:
			run.inventory_weapons.append(weapon)

	run.active_relics.clear()
	var relic_paths: Array = data.get("relics", [])
	for r_path in relic_paths:
		if ResourceLoader.exists(r_path):
			var relic_res := load(r_path) as RelicData
			if relic_res:
				var copy := relic_res.duplicate()
				copy.resource_name = r_path
				run.active_relics.append(copy)
	
	deck.from_dict(data.get("deck", []))

	run.floor_data = FloorGenerator.generate_floor(
		run.master_seed, run.current_floor, 8, -1, run.player_luck
	)
	
	var p_pos_arr: Array = data.get("player_pos", [4, 4])
	run.player_grid_pos = Vector2i(p_pos_arr[0], p_pos_arr[1])
	
	var rooms_dict: Dictionary = run.floor_data.get("rooms", {})
	var map_state: Dictionary = data.get("map_state", {})
	
	for coord in map_state.get("cleared", []):
		var v := Vector2i(coord[0], coord[1])
		if rooms_dict.has(v):
			rooms_dict[v].cleared = true

	for coord in map_state.get("discovered", []):
		var v := Vector2i(coord[0], coord[1])
		if rooms_dict.has(v):
			rooms_dict[v].discovered = true

	run.current_room = null
	if rooms_dict.has(run.player_grid_pos):
		run.current_room = rooms_dict[run.player_grid_pos] as RoomData

## Restaura los datos de un arma usando primero su ruta y luego su ID como respaldo.
static func resolve_weapon(run: RunState, path: String, weapon_id: String = "") -> WeaponData:
	if path != "" and ResourceLoader.exists(path):
		var loaded_weapon := load(path) as WeaponData
		if loaded_weapon:
			return loaded_weapon

	if weapon_id != "":
		for catalog_weapon in run.weapon_catalog:
			if catalog_weapon and catalog_weapon.weapon_id == weapon_id:
				return catalog_weapon
	return null

## Devuelve la ruta original de un arma, incluso si es una copia en memoria.
static func get_weapon_resource_path(run: RunState, weapon: WeaponData) -> String:
	if not weapon:
		return ""
	if weapon.resource_path != "":
		return weapon.resource_path
	if weapon.resource_name.begins_with("res://"):
		return weapon.resource_name
	for catalog_weapon in run.weapon_catalog:
		if catalog_weapon and catalog_weapon.weapon_id == weapon.weapon_id:
			return catalog_weapon.resource_path
	return ""
