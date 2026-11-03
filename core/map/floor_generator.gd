## Generador procedural estático de mapas para el juego. Stateless y metodos Static
## Construye un grafo ortogonal interconectado sobre una matriz (8x8),
## aplicando reglas de expansión de frontera (Spanning Tree)
## y asignación determinista de eventos basada en distancia Manhattan y suerte.

extends RefCounted
class_name FloorGenerator

const GRID_SIZE_DEFAULT: int = 8
const BASE_START_ROOMS: int = 7
const MAX_ROOMS_CAP: int = 28

const DIRS: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(0, 1),
	Vector2i(-1, 0),
	Vector2i(1, 0)
]

## Genera una semilla maestra de alta entropía (impredecibilidad) operando a nivel de bits
## la hora del sistema en milisegundos y los ciclos del procesador en microsegundos.
static func generate_master_seed() -> int:
	var time_ms: int = int(Time.get_unix_time_from_system() * 1000.0)
	var cpu_quantum: int = Time.get_ticks_usec()
	return abs((time_ms ^ (cpu_quantum << 13)) ^ (cpu_quantum * 73856093))
	
## Deriva una sub-semilla determinista para cada planta mezclando la semilla maestra con el número de piso.
static func get_floor_subseed(master_seed: int, floor_number: int) -> int:
	return abs(hash("%d_FLOOR_%d" % [master_seed, floor_number]))

## Calcula progresivamente la cantidad de salas a generar para la planta actual.
## El tamaño del mapa crece gradualmente hasta alcanzar el tope estricto definido por `MAX_ROOMS_CAP`.
## P1=7, P2=9 (+2), P3=12 (+3), P4=16 (+4), P5=21 (+5), P6=27 (+6), P7+=28 (CAP)
static func get_target_rooms_for_floor(floor_number: int) -> int:
	var total: int = BASE_START_ROOMS
	for f in range(2, floor_number + 1):
		total += f
		if total >= MAX_ROOMS_CAP:
			return MAX_ROOMS_CAP
	return min(total, MAX_ROOMS_CAP)
	
## Corrutina de 4 fases que orquesta la generación total de la planta:
## 1. Posiciona la sala de inicio (START) en el cuadrante central y expande la frontera de pasillos 
## (evitando bloques 2x2).
## 2. Conecta bidireccionalmente las aristas ortogonales de las salas adyacentes.
## 3. Identifica "callejones sin salida" (hojas del grafo), los ordena por lejanía e inyecta salas clave 
## (BOSS, TREASURE, REST, SHOP) se garantiza 1 tienda por planta.
## 4. Revela la niebla de guerra de las salas inmediatamente vecinas al START.
## Retorna un diccionario con los parámetros base y el grafo completo (`rooms`).

static func generate_floor(
	master_seed: int,
	floor_number: int,
	grid_size: int = GRID_SIZE_DEFAULT,
	max_rooms: int = -1,
	player_luck: int = 0
) -> Dictionary:
	if max_rooms <= 0:
		max_rooms = get_target_rooms_for_floor(floor_number)

	var sub_seed: int = get_floor_subseed(master_seed, floor_number)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = sub_seed

	var rooms: Dictionary = {}
	# En una matriz par (8x8), el corazon central son las 4 celdas (3,3), (4,3), (3,4), (4,4).
	# Elegimos una de esas 4 de forma determinista con la sub_seed de la planta.
	var half: int = int((grid_size - 1) / 2)
	var center: Vector2i = Vector2i(
		half + rng.randi_range(0, 1 - (grid_size % 2)),
		half + rng.randi_range(0, 1 - (grid_size % 2))
	)

	var start_room: RoomData = RoomData.new(center, RoomData.Type.START)
	rooms[center] = start_room

	# Paso 1: Expansión de la frontera
	_expand_frontier(rooms, center, max_rooms, grid_size, rng)

	# Paso 2: Conectar aristas
	_connect_rooms(rooms)

	# Paso 3: Asignar salas especiales
	_assign_special_rooms(rooms, center, floor_number, player_luck, rng)

	# Paso 4: Descubrir adyacentes al inicio
	for n_pos in start_room.neighbors:
		rooms[n_pos].discovered = true

	return {
		"sub_seed": sub_seed,
		"start_pos": center,
		"grid_size": grid_size,
		"rooms": rooms
	}

# --- SUB-PASOS DE GENERACIÓN ---

## Paso 1: Expansión. Crece el mapa anexando salas aleatorias desde los bordes conocidos.
## Implementa una regla "anti-apelotonamiento" que rechaza celdas con demasiados vecinos
## para forzar la creación de pasillos serpenteantes.
static func _expand_frontier(rooms: Dictionary, center: Vector2i, max_rooms: int, grid_size: int, rng: RandomNumberGenerator) -> void:
	var frontier: Array[Vector2i] = [center]
	var safety_attempts: int = 0

	while rooms.size() < max_rooms and safety_attempts < 500:
		safety_attempts += 1
		var current_pos: Vector2i = frontier[rng.randi_range(0, frontier.size() - 1)]
		var dir: Vector2i = DIRS[rng.randi_range(0, DIRS.size() - 1)]
		var next_pos: Vector2i = current_pos + dir

		if not _is_inside_grid(next_pos, grid_size):
			continue
		if rooms.has(next_pos):
			continue

		# Regla anti-apelotonamiento: evita bloques 2x2 mientras queden intentos
		if _count_occupied_neighbors(rooms, next_pos) >= 2 and safety_attempts < 320:
			continue

		var new_room: RoomData = RoomData.new(next_pos, RoomData.Type.COMBAT)
		rooms[next_pos] = new_room
		frontier.append(next_pos)

## Paso 2: Conexión. Escanea la matriz y vincula cada sala con sus vecinas ortogonales reales,
## construyendo las referencias de navegación dentro de cada instancia `RoomData`.
static func _connect_rooms(rooms: Dictionary) -> void:
	for pos in rooms.keys():
		var room_a: RoomData = rooms[pos]
		for dir in DIRS:
			var neighbor_pos: Vector2i = pos + dir
			if rooms.has(neighbor_pos):
				room_a.add_neighbor(neighbor_pos)

## Paso 3: Asignación. Filtra las salas que tienen una sola puerta de entrada (Dead Ends)
## y las ordena por distancia de lejanía para emplazar al Jefe, Tesoros, Hogueras, Tiendas y Eventos de Suerte.
## Incluye métodos de respaldo (fallbacks) en caso de que el algoritmo no arroje suficientes callejones.
static func _assign_special_rooms(rooms: Dictionary, center: Vector2i, floor_number: int, player_luck: int, rng: RandomNumberGenerator) -> void:
	var dead_ends: Array[Vector2i] = []
	for pos in rooms.keys():
		if pos == center:
			continue
		var r: RoomData = rooms[pos]
		if r.is_dead_end():
			dead_ends.append(pos)

	# Ordenamos de mayor a menor distancia Manhattan respecto al inicio
	dead_ends.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var dist_a: int = abs(a.x - center.x) + abs(a.y - center.y)
		var dist_b: int = abs(b.x - center.x) + abs(b.y - center.y)
		return dist_a > dist_b
	)

	# A) El callejon mas lejano es siempre el JEFE de la planta
	if not dead_ends.is_empty():
		var boss_pos: Vector2i = dead_ends.pop_front()
		rooms[boss_pos].room_type = RoomData.Type.BOSS
	else:
		var furthest: Vector2i = _get_furthest_pos(rooms, center)
		rooms[furthest].room_type = RoomData.Type.BOSS

	# B) El segundo callejon es la Sala de Reliquia (TREASURE)
	if not dead_ends.is_empty():
		var treasure_pos: Vector2i = dead_ends.pop_front()
		rooms[treasure_pos].room_type = RoomData.Type.TREASURE

	# C) El tercer callejon es una Hoguera (REST)
	if not dead_ends.is_empty():
		var rest_pos: Vector2i = dead_ends.pop_front()
		rooms[rest_pos].room_type = RoomData.Type.REST
		
	# E) Ubicar la TIENDA (SHOP)
	if not dead_ends.is_empty():
		var shop_pos: Vector2i = dead_ends.pop_front()
		rooms[shop_pos].room_type = RoomData.Type.SHOP
	else:
		# Si se acabaron los callejones sin salida, buscamos una sala de COMBAT
		var combat_candidates: Array[Vector2i] = []
		for pos in rooms.keys():
			if rooms[pos].room_type == RoomData.Type.COMBAT:
				var dist: int = abs(pos.x - center.x) + abs(pos.y - center.y)
				# Preferimos salas que no estén inmediatamente al lado del START
				if dist > 1:
					combat_candidates.append(pos)
		
		# Fallback: si el mapa es muy compacto
		if combat_candidates.is_empty():
			for pos in rooms.keys():
				if rooms[pos].room_type == RoomData.Type.COMBAT:
					combat_candidates.append(pos)
					
		if not combat_candidates.is_empty():
			var chosen_shop_pos: Vector2i = combat_candidates[rng.randi_range(0, combat_candidates.size() - 1)]
			rooms[chosen_shop_pos].room_type = RoomData.Type.SHOP

	# D) Eventos influenciados por el avance de Planta y SUERTE
	if floor_number >= 3 and not dead_ends.is_empty():
		var extra_rest_pos: Vector2i = dead_ends.pop_front()
		rooms[extra_rest_pos].room_type = RoomData.Type.REST

	if floor_number >= 4 and not dead_ends.is_empty():
		var sanctuary_chance: float = clamp(0.45 + float(floor_number - 4) * 0.08 + float(player_luck) * 0.07, 0.10, 0.92)
		if rng.randf() <= sanctuary_chance:
			var sanctuary_pos: Vector2i = dead_ends.pop_front()
			rooms[sanctuary_pos].room_type = RoomData.Type.SANCTUARY
		else:
			var extra_treasure_pos: Vector2i = dead_ends.pop_front()
			rooms[extra_treasure_pos].room_type = RoomData.Type.TREASURE
	elif floor_number >= 2 and player_luck > 0 and not dead_ends.is_empty():
		var lucky_treasure_chance: float = clamp(float(player_luck) * 0.08, 0.0, 0.65)
		if rng.randf() <= lucky_treasure_chance:
			var extra_treasure_pos: Vector2i = dead_ends.pop_front()
			rooms[extra_treasure_pos].room_type = RoomData.Type.TREASURE

# --- HELPERS ---

## Función de utilidad. 
## Verifica matemáticamente que un vector (x,y) propuesto no desborde los límites de la matriz.
static func _is_inside_grid(pos: Vector2i, grid_size: int) -> bool:
	return pos.x >= 0 and pos.x < grid_size and pos.y >= 0 and pos.y < grid_size

## Función de utilidad. 
## Cuenta la cantidad de salas adyacentes a una coordenada vacía (utilizado para evitar bloques 2x2).
static func _count_occupied_neighbors(rooms: Dictionary, pos: Vector2i) -> int:
	var count: int = 0
	for dir in DIRS:
		if rooms.has(pos + dir):
			count += 1
	return count

## Función de utilidad (Fallback). 
## Busca mediante fuerza bruta la sala más lejana posible al inicio cuando la topología generada carece de "callejones sin salida".
static func _get_furthest_pos(rooms: Dictionary, center: Vector2i) -> Vector2i:
	var best_pos: Vector2i = center
	var best_dist: int = -1
	for pos in rooms.keys():
		if pos == center:
			continue
		var d: int = abs(pos.x - center.x) + abs(pos.y - center.y)
		if d > best_dist:
			best_dist = d
			best_pos = pos
	return best_pos
