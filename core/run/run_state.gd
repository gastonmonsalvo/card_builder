## Gestor del estado vivo de la partida en curso (State Container).
## Almacena las estadísticas dinámicas del jugador, el inventario de reliquias,
## la semilla matemática y el estado del mapa actual. 
## Se encarga de serializar y deserializar estos datos para el sistema de guardado.
extends RefCounted
class_name RunState

signal weapon_equipped(new_weapon: WeaponData)

## Semilla matemática raíz que rige la aleatoriedad de toda la run.
var master_seed: int = 0
## Número del piso o planta actual en el que se encuentra el jugador (inicia en 1).
var current_floor: int = 1
#Diccionario devuelto por `FloorGenerator
## Estructura de datos generada por `FloorGenerator`
## que contiene el grafo topológico (`rooms`) y parámetros del mapa actual.
var floor_data: Dictionary = {}
## Coordenada vectorial `(X, Y)` que ubica al jugador dentro de la matriz topológica actual.
var player_grid_pos: Vector2i = Vector2i(3, 3)
## Referencia en memoria a la instancia de la celda donde el jugador se encuentra parado actualmente.
var current_room: RoomData = null
## Recurso de datos (`HeroData`) del personaje elegido al iniciar la partida.
var selected_hero: HeroData = null
## Repositorio local de cartas disponibles para realizar sorteos procedurales (ej. tiendas).
var available_card_pool :Array[CardData] = []
## Moneda acumulada por el jugador durante la expedición, utilizada para transacciones comerciales.
var player_gold: int =  CombatConstants.BASE_GOLD

## Límite máximo de salud física del jugador.
var max_player_hp: int = CombatConstants.BASE_HEALTH
## Salud física actual del jugador. Si llega a 0, termina la partida (Permadeath).
var player_hp: int = CombatConstants.BASE_HEALTH
## Límite máximo de energía disponible para jugar cartas al inicio de cada turno.
var max_energy: int = CombatConstants.BASE_MAX_ENERGY
## Cantidad objetivo de cartas que el jugador robará al iniciar su turno para rellenar la mano.
var target_hand_size: int = CombatConstants.BASE_HAND_SIZE
## Cantidad permitida de descartes tácticos por cada encuentro de combate.
var discards_per_combat: int = CombatConstants.BASE_DISCARDS_PER_COMBAT
## Estadística que altera la curva de probabilidades del `RaritySystem`
## y la chance de estados alterados (como parálisis por Shock).
var player_luck: int = CombatConstants.BASE_LUCKY

## Catálogo global e inmutable cargado en memoria desde `res://relics/data/`.
var relic_catalog: Array[RelicData] = []
## Colección de reliquias que el jugador ha adquirido y que se encuentran pasivamente equipadas.
var active_relics: Array[RelicData] = []
## Bandera de depuración (Debug) que anula el daño recibido y elimina la niebla de guerra.
var god_mode: bool = false

##Lista de enemigos en la run actual.
var enemy_catalog: Array[EnemyData] = []

## El arma que empuña actualmente en combate.
var current_weapon: WeaponData
## Mochila: Armas guardadas que puede cambiar.
var inventory_weapons: Array[WeaponData] = []
## Catálogo general con todas las armas disponibles en el juego
var weapon_catalog: Array[WeaponData] = []
## Habilidad del personaje
var current_ability: HeroAbility = null
## Instancia del gestor de modificadores temporales de estadísticas para el combate actual.
var temp_stats: TempStatManager = TempStatManager.new()

##RNG Del combate
var combat_rng: RandomNumberGenerator = RandomNumberGenerator.new()

var player_str: int = 1
var player_int: int = 1
var player_dex: int = 1


	
## Constructor. Precarga en memoria el catálogo universal de reliquias
## y cartas consultando la base de datos al instanciarse la clase.
func _init() -> void:
	relic_catalog = GameDatabase.load_all_relics()
	available_card_pool = GameDatabase.load_all_cards()
	enemy_catalog = GameDatabase.load_all_enemies()
	weapon_catalog = GameDatabase.load_all_weapons()
	
## Configura un estado virgen para iniciar una expedición. 
## Inyecta el héroe seleccionado, aplica sus estadísticas base 
##  purga el inventario, otorga las reliquias iniciales y genera la planta 1 basándose en la semilla.
func start_new_run(custom_seed: int , hero: HeroData) -> void:
	
	# 1. Limpiamos los datos que pertenecen a una run anterior.
	inventory_weapons.clear()
	active_relics.clear()
	god_mode = false
	selected_hero = hero
	if hero:
		max_player_hp = hero.max_hp_base
		player_hp = hero.max_hp_base
		player_luck = hero.lucky
		player_gold = hero.gold
		max_energy = hero.energy_base
		discards_per_combat = hero.discards_base
		target_hand_size = hero.hand_size
		current_weapon = hero.starting_weapon if hero.starting_weapon else CombatConstants.BASIC_WEAPON

		player_str = hero.base_str
		player_int = hero.base_int
		player_dex = hero.base_dex
	else:
		max_player_hp = CombatConstants.BASE_HEALTH
		player_hp = max_player_hp
		player_luck = CombatConstants.BASE_LUCKY
		player_gold = CombatConstants.BASE_GOLD
		max_energy = CombatConstants.BASE_MAX_ENERGY
		discards_per_combat = CombatConstants.BASE_DISCARDS_PER_COMBAT	
		target_hand_size = CombatConstants.BASE_HAND_SIZE
		current_weapon = CombatConstants.BASIC_WEAPON
		player_str = CombatConstants.BASE_STR
		player_int = CombatConstants.BASE_INT
		player_dex = CombatConstants.BASE_DEX
		
	# Resetear modificaciones temporales
	temp_stats.clear() 
	# Duplicar la habilidad para que esta run tenga su instancia propia
	if hero and hero.ability:
		current_ability = hero.ability.duplicate()
		current_ability.reset_for_combat()
	else:
		current_ability = null
	
	# Nos aseguramos de tener los catálogos llenos por si se vaciaron
	if relic_catalog.is_empty(): relic_catalog = GameDatabase.load_all_relics()
	if available_card_pool.is_empty(): available_card_pool = GameDatabase.load_all_cards()
	if weapon_catalog.is_empty(): weapon_catalog = GameDatabase.load_all_weapons()
	if hero:
		grant_starting_relics(hero)
	
	if custom_seed >= 0:
		master_seed = custom_seed
	else:
		master_seed = FloorGenerator.generate_master_seed()
	start_floor(1)

## Evalúa matemáticamente si el jugador ha perdido toda su salud (`hp <= 0`).
func is_player_dead() -> bool:
	return player_hp <= 0

## Orquesta la generación topológica de un nuevo piso. Invoca a `FloorGenerator`,
## asigna la estructura al estado y ubica al jugador en el punto de partida (Start).
func start_floor(floor_num: int) -> void:
	current_floor = floor_num
	var target_rooms: int = FloorGenerator.get_target_rooms_for_floor(current_floor)
	floor_data = FloorGenerator.generate_floor(
		master_seed,
		current_floor,
		FloorGenerator.GRID_SIZE_DEFAULT,
		target_rooms,
		player_luck
	)
	player_grid_pos = floor_data["start_pos"]
	current_room = floor_data["rooms"][player_grid_pos]
	
## Compila una cadena de texto plana con los nombres de las reliquias activas (útil para el HUD resumido).
##  Retorna "Ninguna" si el inventario está vacío.
func get_relics_summary() -> String:
	if active_relics.is_empty():
		return "Ninguna"
	var names: Array[String] = []
	for r in active_relics:
		names.append(r.get_full_description())
	return " | ".join(names)
	
## Compila un listado de texto enriquecido, numerando cada reliquia activa junto con su tier de rareza
## y descripción completa, ideal para leerse en paneles laterales o menús de inventario.
func get_relics_detailed_text() -> String:
	if active_relics.is_empty():
		return "Todavía no tienes reliquias equipadas en esta partida."
	var lines: Array[String] = []
	for i in range(active_relics.size()):
		var r: RelicData = active_relics[i]
		if r:
			lines.append("%d. %s" % [i + 1, r.get_inspector_text()])
	return "\n\n".join(lines)

## Actualiza topológicamente la sala actual marcándola como completada (`cleared = true`). 
## Luego, recorre sus salas vecinas descubriéndolas en el mapa para disipar la niebla de guerra.
func clear_and_discover_room(room: RoomData) -> void:
	if not room:
		return
	room.cleared = true
	var rooms: Dictionary = floor_data.get("rooms", {})
	for n_pos in room.neighbors:
		if rooms.has(n_pos):
			rooms[n_pos].discovered = true
			
## Ejecuta la mecánica de descanso. Calcula una curación escalada suavemente por la Suerte del héroe,
## asegurando no desbordar la vida máxima. Retorna la cantidad matemática de vida sanada.
func rest_at_campfire() -> int:
	var target_heal: int = int(round(RaritySystem.get_scaled_value_smooth(player_luck, 25.0, 50.0, 12)))
	var healed: int = min(target_heal, max_player_hp - player_hp)
	player_hp += healed
	return healed
	
## Efecto de Bendición 1.
## Otorga una reliquia aleatoria inyectando un bonus de fortuna por cada piso superado (tope máximo de +4.0).
##  Piso 1 = +0.0 | Piso 3 = +2.0 | Piso 5 o más = +4.0 (Tope máximo)
## luego recupera la salud del jugador de manera escalada por su Suerte, garantizando al menos un 25% de HP.
func apply_sanctuary_relic_and_full_heal() -> String:
	# Calculamos el bonus según el piso actual. 
	
	var floor_bonus: float = min(4.0, float(current_floor - 1))
	# Inyectamos ese bonus dinámico al sorteo de la reliquia
	var relic_desc: String = grant_random_relic(floor_bonus)
	var quarter_life: float = max_player_hp/4.0
	var half_life: float = max_player_hp/2.0
	var target_hp: int = int(round(RaritySystem.get_scaled_value_smooth(player_luck, float(quarter_life), float(half_life), 12)))
	# Aplicamos el nuevo HP asegurando que no supere el máximo y que al menos recupere el mínimo
	player_hp = min(max_player_hp, player_hp + target_hp)
	return "Obtuviste [%s] y restauraste tu HP hasta %d/%d!" % [relic_desc, player_hp, max_player_hp]

## Efecto de Bendición 2. Incrementa permanente la salud máxima del jugador mediante un cálculo suavizado por Suerte.
##  Sincroniza la vida actual con el nuevo techo y retorna el reporte formateado.
func apply_sanctuary_max_hp_blessing() -> String:
	# Llamamos al sistema de suavizado pidiéndole el rango de 5 a 25
	var final_bonus: int = int(round(RaritySystem.get_scaled_value_smooth(player_luck, 5, 25, 12)))
	
	max_player_hp += final_bonus

	player_hp = min(max_player_hp, player_hp + final_bonus)

	return "Aumentaste +%d tu HP Maximo permanente (HP actual: %d/%d)!" % [final_bonus, player_hp, max_player_hp]

## Sortea, adquiere y equipa una reliquia utilizando un motor RNG determinista.
## Implementa filtros en cascada para evitar duplicados en el inventario activo,
## aplicando `bonus_fortune` para aumentar la posibilidad de tiers superiores.
func grant_random_relic(bonus_fortune: float = 0.0) -> String:
	if relic_catalog.is_empty():
		relic_catalog = GameDatabase.load_all_relics()
	if relic_catalog.is_empty():
		return "Sin reliquias en res://relics/data"

	var rng := RandomNumberGenerator.new()
	rng.seed = FloorGenerator.get_floor_subseed(master_seed, current_floor * 100 + active_relics.size())

	var rolled_tier: RaritySystem.Tier = RaritySystem.roll_tier(rng, current_floor, player_luck, bonus_fortune)

	var candidates: Array[RelicData] = []
	for r in relic_catalog:
		if r.rarity == rolled_tier and not active_relics.has(r):
			candidates.append(r)

	if candidates.is_empty():
		for r in relic_catalog:
			if r.rarity == rolled_tier:
				candidates.append(r)

	if candidates.is_empty():
		for r in relic_catalog:
			if not active_relics.has(r):
				candidates.append(r)
	if candidates.is_empty():
		candidates = relic_catalog

	var chosen: RelicData = candidates[rng.randi_range(0, candidates.size() - 1)]
	equip_specific_relic(chosen)
	return chosen.get_effects_description()
## Función imperativa para forzar la adquisición de una reliquia (útil para items iniciales o herramientas de Debug).
##  Registra la reliquia, emite la señal de interfaz y ejecuta sus ganchos de combate si hay un enemigo activo.
func equip_specific_relic(relic: RelicData, current_enemy: Enemy = null) -> void:
	if not relic:
		return
	active_relics.append(relic)
	relic.trigger_on_equipped(self)
	SignalBus.relic_acquired.emit(relic)
	if current_enemy and not current_enemy.is_dead():
		relic.trigger_on_combat_start(current_enemy)
		
## Equipa un arma guardada en la mochila. El arma anterior ocupa el lugar liberado.
## `force_debug` permite equipar armas del catálogo aunque no estén en la mochila.
func equip_weapon(weapon: WeaponData, force_debug: bool = false) -> bool:
	if not weapon:
		return false
	if _same_weapon(weapon, current_weapon):
		return false
	
	var weapon_index: int = _find_inventory_weapon_index(weapon)
	if weapon_index == -1:
		if not add_weapon_to_inventory(weapon, force_debug):
			return false
		weapon_index = _find_inventory_weapon_index(weapon)

	if weapon_index == -1:
		return false

	# Retiramos primero la seleccionada; ese espacio se usa para guardar la anterior.
	inventory_weapons.remove_at(weapon_index)
	var previous_weapon: WeaponData = current_weapon
	current_weapon = weapon
	
	if previous_weapon and not _same_weapon(previous_weapon, current_weapon):
		inventory_weapons.append(previous_weapon)

	print("Arma equipada: %s" % weapon.weapon_name)
	weapon_equipped.emit(current_weapon)
	return true

## Comprueba si dos recursos representan la misma arma, aunque sean instancias distintas.
func _same_weapon(first: WeaponData, second: WeaponData) -> bool:
	if first == null or second == null:
		return false
	if first == second:
		return true
	return first.weapon_id != "" and first.weapon_id == second.weapon_id

## Busca un arma por referencia o por identificador único dentro de la mochila.
func _find_inventory_weapon_index(weapon: WeaponData) -> int:
	if not weapon:
		return -1
	for index in range(inventory_weapons.size()):
		if _same_weapon(inventory_weapons[index], weapon):
			return index
	return -1

## Herramienta de depuración. Itera sobre cada nodo de la matriz topológica y 
## fuerza su estado a `discovered = true` para disipar la niebla de guerra.
func reveal_entire_floor() -> void:
	var rooms: Dictionary = floor_data.get("rooms", {})
	for pos in rooms.keys():
		rooms[pos].discovered = true
		
## Retransmite el estado en vivo de un combo (daño, robo, escudos, etc.) hacia todas las reliquias equipadas 
## para que estas inyecten bonificaciones (ej. "Añade +3 daño si jugaste 5 cartas").
func apply_relics_to_combo(combo_state: Dictionary, card_count: int) -> void:
	if card_count <= 0:
		return
	for relic in active_relics:
		if relic:
			relic.trigger_on_combo_evaluated(combo_state, card_count)


## Filtra el catálogo global estático de enemigos (`EnemyData`) según si la sala corresponde a un Jefe o a un combate estándar.
## Sortea un candidato al azar, instancia el objeto vivo `Enemy` (inyectando el escalado de dificultad por planta actual)
## y notifica a las reliquias activas para que apliquen sus efectos de inicio de combate.

func create_enemy_for_room(is_boss_encounter: bool) -> Enemy:
	# 1. Cargamos el bestiario llamando a tu función directamente
	var all_enemies: Array[EnemyData] = GameDatabase.load_all_enemies()
	
	# 2. Filtramos según si necesitamos un Jefe o un enemigo común
	var candidates: Array[EnemyData] = []
	for e_data in all_enemies:
		if e_data.is_boss == is_boss_encounter:
			candidates.append(e_data)
			
	# Fallback de seguridad por si te olvidaste de crear archivos .tres
	if candidates.is_empty():
		push_warning("[RunState] No se encontraron archivos EnemyData. Generando enemigo de emergencia temporal.")
		var dummy_data := EnemyData.new()
		dummy_data.enemy_name = "JEFE Dummy " if is_boss_encounter else "Enemigo Dummy "
		dummy_data.base_hp = 50
		dummy_data.base_damage = 5
		dummy_data.is_boss = is_boss_encounter
		candidates.append(dummy_data)
	# 3. Sorteamos uno al azar
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var chosen_data: EnemyData = candidates[rng.randi_range(0, candidates.size() - 1)]
	
	# 4. Instanciamos al enemigo VIVO con el Data y el piso actual
	var new_enemy: Enemy = Enemy.new(chosen_data, current_floor)

	# 5. Disparamos reliquias de inicio de combate
	for relic in active_relics:
		if relic:
			relic.trigger_on_combat_start(new_enemy)

	return new_enemy

## Gancho defensivo. Al recibir daño letal, itera sobre las reliquias equipadas pidiendo intervención. 
## Si alguna posee capacidad de resurrección, la ejecuta, se consume (eliminándose del inventario) y 
## detiene la muerte.
func try_consume_revive_relic() -> RelicData:
	for i in range(active_relics.size()):
		var relic: RelicData = active_relics[i]
		if relic and relic.trigger_on_lethal_damage(self):
			active_relics.remove_at(i)
			return relic
	return null
	
## Instancia un motor de entropía aislada para gestionar el bazar. Combina la semilla maestra, el piso y
## las coordenadas de la tienda para asegurar que el stock sea el mismo si el jugador carga la partida.
func _get_shop_rng(room_pos: Vector2i) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	var shop_seed: int = abs(hash("%d_FLOOR_%d_SHOP_%d_%d" % [master_seed, current_floor, room_pos.x, room_pos.y]))
	rng.seed = shop_seed
	return rng
	
## Instancia un motor de entropía aislada para gestionar el bazar. 
## Combina la semilla maestra, el piso y las coordenadas de la tienda para asegurar 
## que el stock sea el mismo si el jugador carga la partida.
func generate_shop_cards(room_pos: Vector2i, count: int = 3, bonus_fortune: float = 0.0) -> Array[CardData]:
	var rng: RandomNumberGenerator = _get_shop_rng(room_pos)
	var result: Array[CardData] = []
	
	var pool_card: Array[CardData] = available_card_pool.filter(func(c: CardData): return c != null)
	if pool_card.is_empty():
		return result

	for i in range(min(count, pool_card.size())):
		var target_tier: RaritySystem.Tier = RaritySystem.roll_tier(rng, current_floor, player_luck, bonus_fortune)
		var picked: CardData = _pick_from_pool_by_tier_cards(pool_card, target_tier, rng)
		if picked:
			result.append(picked.duplicate())
			pool_card.erase(picked) # Evita que la misma carta salga 2 veces en la misma tienda

	return result

## Sortea y devuelve un arreglo de reliquias para el comercio, 
## asegurando excluir las que el jugador ya tenga equipadas.
func generate_shop_relics(room_pos: Vector2i, count: int = 2, bonus_fortune: float = 0.0) -> Array[RelicData]:
	var rng: RandomNumberGenerator = _get_shop_rng(room_pos)
	# Desfasamos el estado del RNG para no acoplar la tirada con la de las cartas
	rng.randi()
	
	var result: Array[RelicData] = []
	var owned_titles: Array[String] = []
	for owned in active_relics:
		if owned:
			owned_titles.append(owned.title)

	var pool: Array[RelicData] = relic_catalog.filter(
		func(r: RelicData): return r != null and not owned_titles.has(r.title)
	)
	if pool.is_empty():
		return result

	for i in range(min(count, pool.size())):
		var target_tier: RaritySystem.Tier = RaritySystem.roll_tier(rng, current_floor, player_luck, bonus_fortune)
		var picked: RelicData = _pick_from_pool_by_tier_relics(pool, target_tier, rng)
		if picked:
			result.append(picked)
			pool.erase(picked) # Evita duplicados en el mostrador

	return result
## Función auxiliar. Selecciona una carta al azar filtrando por el tier (rareza) solicitado. 
## Si el grupo de esa rareza está vacío,  ejecuta un rescate (fallback) 
## ampliando la búsqueda a todo el pool global.
func _pick_from_pool_by_tier_cards(pool: Array[CardData], tier: RaritySystem.Tier, rng: RandomNumberGenerator) -> CardData:
	var candidates: Array[CardData] = pool.filter(func(c: CardData): return c.rarity == tier)
	# Fallback: si no quedan cartas de ese tier exacto en el pool, elige de las disponibles
	if candidates.is_empty():
		candidates = pool
	return candidates[rng.randi_range(0, candidates.size() - 1)]
	
## Función auxiliar. Ejecuta el mismo filtro estricto con fallback global que su homólogo de cartas,
##  pero aplicado al catálogo de reliquias disponibles.
func _pick_from_pool_by_tier_relics(pool: Array[RelicData], tier: RaritySystem.Tier, rng: RandomNumberGenerator) -> RelicData:
	var candidates: Array[RelicData] = pool.filter(func(r: RelicData): return r.rarity == tier)
	if candidates.is_empty():
		candidates = pool
	return candidates[rng.randi_range(0, candidates.size() - 1)]

## Itera sobre el inventario inicial definido en el archivo `.tres` del héroe 
## y equipa clones funcionales de esas reliquias al iniciar la expedición.
func grant_starting_relics(hero: HeroData) -> void:
	# Si hero.starting_relic es un array, lo iteramos
	for relic in hero.starting_relic:
		if relic != null:
			equip_specific_relic(relic.duplicate())

## Motor de serialización. Transforma todo el estado vivo
## (estadísticas, ubicaciones en el mapa, inventarios, mazos y reliquias)
##  en un diccionario de primitivas seguro para escribirse en formato JSON o binario en disco.
func to_dict(deck_data: Array) -> Dictionary:
	var relic_paths: Array[String] = []
	for relic in active_relics:
		if relic:
			var path: String = relic.resource_path
			if path == "" and relic.resource_name != "":
				path = relic.resource_name
			if path != "":
				relic_paths.append(path)

	var inventory_weapon_paths: Array[String] = []
	var inventory_weapon_ids: Array[String] = []
	for weapon in inventory_weapons:
		if weapon:
			inventory_weapon_paths.append(_get_weapon_resource_path(weapon))
			inventory_weapon_ids.append(weapon.weapon_id)
				
	var cleared_rooms: Array[Array] = []
	var discovered_rooms: Array[Array] = []
	var rooms_dict: Dictionary = floor_data.get("rooms", {})
	
	for pos in rooms_dict.keys():
		var room: RoomData = rooms_dict[pos]
		if room.cleared:
			cleared_rooms.append([pos.x, pos.y])
		if room.discovered:
			discovered_rooms.append([pos.x, pos.y])

	return {
		"master_seed": master_seed,
		"current_floor": current_floor,
		"selected_hero_path": selected_hero.resource_path if selected_hero else "",
		"current_weapon_path": _get_weapon_resource_path(current_weapon),
		"current_weapon_id": current_weapon.weapon_id if current_weapon else "",
		"inventory_weapon_paths": inventory_weapon_paths,
		"inventory_weapon_ids": inventory_weapon_ids,
		"player_pos": [player_grid_pos.x, player_grid_pos.y],
		"stats": {
			"hp": player_hp,
			"max_hp": max_player_hp,
			"gold": player_gold,
			"energy": max_energy,
			"hand_size": target_hand_size,
			"discards": discards_per_combat,
			"luck": player_luck,
			"str": player_str,
			"int": player_int,
			"dex": player_dex
		},
		"deck": deck_data,
		"relics": relic_paths,
		"map_state": {
			"cleared": cleared_rooms,
			"discovered": discovered_rooms
		}
	}

## Restaura los datos de un arma usando primero su ruta y luego su ID como respaldo.
func _resolve_weapon(path: String, weapon_id: String = "") -> WeaponData:
	if path != "" and ResourceLoader.exists(path):
		var loaded_weapon := load(path) as WeaponData
		if loaded_weapon:
			return loaded_weapon

	if weapon_id != "":
		for catalog_weapon in weapon_catalog:
			if catalog_weapon and catalog_weapon.weapon_id == weapon_id:
				return catalog_weapon
	return null

## Devuelve la ruta original de un arma, incluso si es una copia en memoria.
func _get_weapon_resource_path(weapon: WeaponData) -> String:
	if not weapon:
		return ""
	if weapon.resource_path != "":
		return weapon.resource_path
	if weapon.resource_name.begins_with("res://"):
		return weapon.resource_name
	for catalog_weapon in weapon_catalog:
		if catalog_weapon and catalog_weapon.weapon_id == weapon.weapon_id:
			return catalog_weapon.resource_path
	return ""

## Reconstruye el estado de la run desde un JSON. También acepta partidas guardadas
## antes de incorporar el sistema de armas (sin las nuevas claves de equipo).
func from_dict(data: Dictionary, deck: DeckManager) -> void:
	master_seed = int(data.get("master_seed", 0))
	current_floor = int(data.get("current_floor", 1))
	
	selected_hero = null
	var hero_path: String = str(data.get("selected_hero_path", ""))
	if hero_path != "" and ResourceLoader.exists(hero_path):
		selected_hero = load(hero_path) as HeroData

	var stats: Dictionary = data.get("stats", {})
	player_hp = int(stats.get("hp", 60))
	max_player_hp = int(stats.get("max_hp", 60))
	player_gold = int(stats.get("gold", 0))
	max_energy = int(stats.get("energy", 3))
	target_hand_size = int(stats.get("hand_size", 5))
	discards_per_combat = int(stats.get("discards", 2))
	player_luck = int(stats.get("luck", 0))
	player_str = int(stats.get("str", selected_hero.base_str if selected_hero else CombatConstants.BASE_STR))
	player_int = int(stats.get("int", selected_hero.base_int if selected_hero else CombatConstants.BASE_INT))
	player_dex = int(stats.get("dex", selected_hero.base_dex if selected_hero else CombatConstants.BASE_DEX))

	# Equipo: las claves pueden no existir en partidas creadas antes del sistema de armas.
	if weapon_catalog.is_empty():
		weapon_catalog = GameDatabase.load_all_weapons()
	current_weapon = _resolve_weapon(
		str(data.get("current_weapon_path", "")),
		str(data.get("current_weapon_id", ""))
	)
	if not current_weapon and selected_hero and selected_hero.starting_weapon:
		current_weapon = selected_hero.starting_weapon
	if not current_weapon:
		current_weapon = CombatConstants.BASIC_WEAPON

	inventory_weapons.clear()
	var saved_weapon_paths: Array = data.get("inventory_weapon_paths", [])
	var saved_weapon_ids: Array = data.get("inventory_weapon_ids", [])
	var saved_weapon_count: int = max(saved_weapon_paths.size(), saved_weapon_ids.size())
	for index in range(saved_weapon_count):
		var saved_path: String = str(saved_weapon_paths[index]) if index < saved_weapon_paths.size() else ""
		var saved_id: String = str(saved_weapon_ids[index]) if index < saved_weapon_ids.size() else ""
		var weapon := _resolve_weapon(saved_path, saved_id)
		if weapon and not _same_weapon(weapon, current_weapon) and _find_inventory_weapon_index(weapon) == -1:
			inventory_weapons.append(weapon)

	active_relics.clear()
	var relic_paths: Array = data.get("relics", [])
	for r_path in relic_paths:
		if ResourceLoader.exists(r_path):
			var relic_res := load(r_path) as RelicData
			if relic_res:
				var copy := relic_res.duplicate()
				copy.resource_name = r_path
				active_relics.append(copy)
	
	deck.from_dict(data.get("deck", []))

	floor_data = FloorGenerator.generate_floor(
		master_seed, current_floor, 8, -1, player_luck
	)
	
	var p_pos_arr: Array = data.get("player_pos", [4, 4])
	player_grid_pos = Vector2i(p_pos_arr[0], p_pos_arr[1])
	
	var rooms_dict: Dictionary = floor_data.get("rooms", {})
	var map_state: Dictionary = data.get("map_state", {})
	
	for coord in map_state.get("cleared", []):
		var v := Vector2i(coord[0], coord[1])
		if rooms_dict.has(v):
			rooms_dict[v].cleared = true

	for coord in map_state.get("discovered", []):
		var v := Vector2i(coord[0], coord[1])
		if rooms_dict.has(v):
			rooms_dict[v].discovered = true

	current_room = null
	if rooms_dict.has(player_grid_pos):
		current_room = rooms_dict[player_grid_pos] as RoomData

## Intenta agregar un arma a la mochila. Evita duplicados, incluyendo el arma equipada.
## `force_debug` solo omite el límite de capacidad para las herramientas de depuración.
func add_weapon_to_inventory(weapon: WeaponData, force_debug: bool = false) -> bool:
	if not weapon:
		return false
	if _same_weapon(weapon, current_weapon) or _find_inventory_weapon_index(weapon) != -1:
		return false
	if not force_debug and inventory_weapons.size() >= CombatConstants.MAX_INVENTORY_SIZE:
		print("Mochila llena: no se pudo agregar %s." % weapon.weapon_name)
		return false
	inventory_weapons.append(weapon)
	print("Arma agregada a la mochila: %s" % weapon.weapon_name)
	return true
## Genera las recompensas de un combate ganado de forma determinista.
## Usa la semilla maestra + piso + contador para garantizar reproducibilidad.
func generate_combat_rewards(combat_index: int = 0) -> Dictionary:
	# Oro base escalado por piso
	var gold := 10 + (current_floor * 2) + randi() % 5
	
	# Crear un RNG determinista basado en la semilla maestra y el piso actual
	var rng := RandomNumberGenerator.new()
	var reward_seed := FloorGenerator.get_floor_subseed(
		master_seed, 
		current_floor * 1000 + combat_index
	)
	rng.seed = reward_seed
	
	# 3 cartas sin repetir según RaritySystem
	var cards: Array[CardData] = []
	var pool: Array[CardData] = available_card_pool.filter(func(c): return c != null)
	
	for i in range(3):
		if pool.is_empty():
			break
		var tier := RaritySystem.roll_tier(rng, current_floor, player_luck)
		var card := _pick_card_by_tier(pool, tier, rng)
		if card:
			cards.append(card.duplicate())
			pool.erase(card)
	
	# 30% chance de relic (determinista)
	var relic: RelicData = null
	if rng.randf() < 0.3 and not relic_catalog.is_empty():
		relic = relic_catalog[rng.randi_range(0, relic_catalog.size() - 1)]
	
	return {
		"gold": gold,
		"cards": cards,
		"relic": relic
	}


## Selecciona una carta del pool filtrando por tier. Fallback al pool completo si el tier está vacío.
## (Este método lo movemos desde RewardView hacia acá, RunState)
func _pick_card_by_tier(
	pool: Array[CardData], tier: RaritySystem.Tier, rng: RandomNumberGenerator
) -> CardData:
	var candidates: Array[CardData] = pool.filter(func(c): return c.rarity == tier)
	if candidates.is_empty():
		candidates = pool
	if candidates.is_empty():
		return null
	return candidates[rng.randi_range(0, candidates.size() - 1)]
	
## Aplica las recompensas elegidas por el jugador al estado de la run.
func apply_combat_rewards(
	chosen_card: CardData, gold: int, relic: RelicData, deck: DeckManager
) -> void:
	# 1. Agregar carta elegida al mazo (DrawPile)
	deck.draw_pile.add_card(chosen_card)
	
	# 2. Sumar oro
	player_gold += gold
	
	# 3. Equipar relic si la hubo
	if relic:
		equip_specific_relic(relic)

## Devuelve la fuerza efectiva (base + mods temporales).
func get_effective_str() -> int:
	return player_str + temp_stats.get_total_mod("str")

## Devuelve la inteligencia efectiva (base + mods temporales).
func get_effective_int() -> int:
	return player_int + temp_stats.get_total_mod("int")

## Devuelve la destreza efectiva (base + mods temporales).
func get_effective_dex() -> int:
	return player_dex + temp_stats.get_total_mod("dex")


## Resetea el RNG de combate para un nuevo encuentro.
func reset_combat_rng() -> void:
	var pos_x := int(player_grid_pos.x) if player_grid_pos else 0
	var pos_y := int(player_grid_pos.y) if player_grid_pos else 0
	var seed_value: int = abs(hash("%d_COMBAT_F%d_X%d_Y%d" % [
		master_seed, current_floor, pos_x, pos_y
	]))
	combat_rng.seed = seed_value
