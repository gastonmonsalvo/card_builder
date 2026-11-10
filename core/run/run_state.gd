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

## Nivel actual del jugador dentro de la run (progresión sin tope cerrado, inicia en 1).
var player_level: int = 1
## Experiencia acumulada hacia el siguiente nivel.
var player_xp: int = 0
## Experiencia histórica total acumulada a lo largo de toda la run actual.
var total_xp_earned: int = 0
## Puntos de atributo pendientes de asignar obtenidos al subir de nivel.
var unspent_stat_points: int = 0
## Puntos de Rating de Crítico adicionales acumulados manualmente por elección del jugador.
var bonus_crit_rating: int = 0


	
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
	player_level = 1
	player_xp = 0
	total_xp_earned = 0
	unspent_stat_points = 0
	bonus_crit_rating = 0
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

## Sortea, adquiere y equipa una reliquia delegando en `LootGenerator.grant_random_relic()`.
func grant_random_relic(bonus_fortune: float = 0.0) -> String:
	return LootGenerator.grant_random_relic(self, bonus_fortune)
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
	# 3. Sorteamos uno al azar de forma determinista según la semilla maestra, piso y coordenada de la sala
	var rng := RandomNumberGenerator.new()
	var pos_x: int = int(player_grid_pos.x) if player_grid_pos else 0
	var pos_y: int = int(player_grid_pos.y) if player_grid_pos else 0
	rng.seed = abs(hash("%d_ENEMY_F%d_X%d_Y%d" % [master_seed, current_floor, pos_x, pos_y]))
	var chosen_data: EnemyData = candidates[rng.randi_range(0, candidates.size() - 1)]
	
	# 4. Instanciamos al enemigo VIVO con el Data, el piso actual y si la sala es ÉLITE
	var is_elite_encounter: bool = not is_boss_encounter and current_room != null and current_room.room_type == RoomData.Type.ELITE
	var new_enemy: Enemy = Enemy.new(chosen_data, current_floor, is_elite_encounter)

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
	
## Sortea y devuelve un arreglo de `count` cartas únicas del catálogo para el stock de la tienda delegando en `LootGenerator`.
func generate_shop_cards(room_pos: Vector2i, count: int = 3, bonus_fortune: float = 0.0) -> Array[CardData]:
	return LootGenerator.generate_shop_cards(self, room_pos, count, bonus_fortune)

## Sortea y devuelve un arreglo de reliquias para el comercio delegando en `LootGenerator`.
func generate_shop_relics(room_pos: Vector2i, count: int = 2, bonus_fortune: float = 0.0) -> Array[RelicData]:
	return LootGenerator.generate_shop_relics(self, room_pos, count, bonus_fortune)

## Itera sobre el inventario inicial definido en el archivo `.tres` del héroe 
## y equipa clones funcionales de esas reliquias al iniciar la expedición.
func grant_starting_relics(hero: HeroData) -> void:
	for relic in hero.starting_relic:
		if relic != null:
			equip_specific_relic(relic.duplicate())

## Serializa todo el estado vivo delegando en `RunSerializer.to_dict()`.
func to_dict(deck_data: Array) -> Dictionary:
	return RunSerializer.to_dict(self, deck_data)

## Reconstruye el estado de la run desde un JSON delegando en `RunSerializer.from_dict()`.
func from_dict(data: Dictionary, deck: DeckManager) -> void:
	RunSerializer.from_dict(self, data, deck)

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

## Genera las recompensas de un combate ganado de forma determinista delegando en `LootGenerator`.
func generate_combat_rewards(combat_index: int = 0) -> Dictionary:
	return LootGenerator.generate_combat_rewards(self, combat_index)

## Aplica las recompensas elegidas por el jugador al estado de la run.
func apply_combat_rewards(
	chosen_card: CardData, gold: int, relic: RelicData, deck: DeckManager
) -> void:
	deck.draw_pile.add_card(chosen_card)
	player_gold += gold
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

# =============================================================================
#  FACHADA DE PROGRESIÓN DE NIVEL (DELEGA EN `LevelProgression`)
# =============================================================================

## Calcula la experiencia requerida (Δ) para avanzar al siguiente nivel delegando en `LevelProgression`.
func get_xp_required_for_next_level(level: int = player_level) -> int:
	return LevelProgression.get_xp_required_for_next_level(level)

## Calcula la recompensa de experiencia otorgada al superar un encuentro delegando en `LevelProgression`.
func get_combat_xp_reward(room_type: int = -1, floor_num: int = current_floor) -> int:
	var effective_type: int = room_type
	if effective_type < 0:
		effective_type = current_room.room_type if current_room != null else RoomData.Type.COMBAT
	return LevelProgression.get_combat_xp_reward(effective_type, floor_num)

## Otorga experiencia al jugador y resuelve las subidas de nivel delegando en `LevelProgression`.
func gain_xp(amount: int) -> Dictionary:
	return LevelProgression.apply_xp_gain(self, amount)

## Invierte 1 punto de atributo pendiente (`unspent_stat_points`) en la estadística elegida:
## `"str"` (+1 Fuerza), `"dex"` (+1 Destreza), `"int"` (+1 Inteligencia) o `"crit"` (+15 Rating de Crítico).
## Retorna `true` si el punto fue consumido con éxito.
func spend_stat_point(stat_key: String) -> bool:
	if unspent_stat_points <= 0:
		return false
	match stat_key.to_lower():
		"str":
			player_str += 1
		"dex":
			player_dex += 1
		"int":
			player_int += 1
		"crit":
			bonus_crit_rating += CombatConstants.CRIT_RATING_PER_STAT_POINT
		_:
			return false
	unspent_stat_points -= 1
	return true

## Devuelve el Rating de Crítico total (base de Nivel 1 + puntos invertidos manualmente en Crítico).
func get_crit_rating() -> int:
	return LevelProgression.get_crit_rating(player_level, bonus_crit_rating)

## Calcula la probabilidad de Golpe Crítico [0.0 .. 0.50] mediante curva asintótica.
func get_crit_chance() -> float:
	return LevelProgression.get_crit_chance(player_level, bonus_crit_rating)

## Devuelve la probabilidad de Golpe Crítico expresada en porcentaje (ej. 14.7 para 14.7%).
func get_crit_chance_pct() -> float:
	return get_crit_chance() * 100.0

## Calcula cuál sería el porcentaje de Golpe Crítico si el jugador invirtiera 1 punto adicional en Crítico.
func get_next_crit_chance_pct() -> float:
	var next_rating: int = get_crit_rating() + CombatConstants.CRIT_RATING_PER_STAT_POINT
	return LevelProgression.get_crit_chance_from_rating(next_rating) * 100.0

## Devuelve el porcentaje de bonificación de daño global aportado por el nivel: (Nivel - 1) * 2%.
func get_level_damage_bonus_pct() -> int:
	return LevelProgression.get_level_damage_bonus_pct(player_level)

## Devuelve el multiplicador escalar de daño saliente aportado por el nivel: 1.0 + ((Nivel - 1) * 2 / 100).
func get_level_damage_multiplier() -> float:
	return LevelProgression.get_level_damage_multiplier(player_level)


## Resetea el RNG de combate para un nuevo encuentro.
func reset_combat_rng() -> void:
	var pos_x := int(player_grid_pos.x) if player_grid_pos else 0
	var pos_y := int(player_grid_pos.y) if player_grid_pos else 0
	var seed_value: int = abs(hash("%d_COMBAT_F%d_X%d_Y%d" % [
		master_seed, current_floor, pos_x, pos_y
	]))
	combat_rng.seed = seed_value
