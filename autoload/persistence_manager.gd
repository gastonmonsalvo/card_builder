## Singleton (Autoload) que gestiona el sistema de ranuras de guardado (slots).
## Controla la persistencia de perfiles de jugador, el guardado atómico de partidas en curso (runs)
## y la recuperación de metadatos.
extends Node

const BASE_SAVES_PATH: String = "user://saves"
const LAST_SLOT_PATH: String = "user://last_slot.cfg"
const MAX_SLOTS: int = 3

## Número de la ranura activa en memoria (1 a MAX_SLOTS). Vale -1 si no hay ninguna seleccionada.
var current_slot: int = -1 

## Diccionario que contiene las estadísticas persistentes y configuraciones del jugador para la ranura activa.
# Perfil del slot activo en memoria
var profile_data: Dictionary = {}

## Devuelve la ruta absoluta en user:// correspondiente al subdirectorio del slot indicado.
func get_slot_dir(slot: int) -> String:
	return "%s/slot_%d" % [BASE_SAVES_PATH, slot]
	
## Retorna la ruta al archivo JSON de perfil persistente (stats, héroes desbloqueados) del slot.
func get_profile_path(slot: int) -> String:
	return "%s/profile.json" % get_slot_dir(slot)
	
## Retorna la ruta al archivo JSON de la run viva en curso del slot.
func get_run_path(slot: int) -> String:
	return "%s/run.json" % get_slot_dir(slot)
	
## Verifica la existencia física del archivo profile.json en disco para determinar si la ranura está en uso.
func is_slot_occupied(slot: int) -> bool:
	return FileAccess.file_exists(get_profile_path(slot))



## Lee y parsea de forma liviana el encabezado de un slot sin cargar la partida entera en memoria.
## Retorna un diccionario con indicadores clave (vacío/ocupado, nombre, piso récord, victorias y estado de run activa) 
## para poblar la UI del selector.
func get_slot_summary(slot: int) -> Dictionary:
	if not is_slot_occupied(slot):
		return {"empty": true, "slot": slot}
	
	var file := FileAccess.open(get_profile_path(slot), FileAccess.READ)
	if file == null:
		return {"empty": true, "slot": slot}
		
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return {"empty": true, "slot": slot}
		
	var data: Dictionary = json.data
	return {
		"empty": false,
		"slot": slot,
		"player_name": data.get("player_name", "Sin Nombre"),
		"highest_floor": data.get("stats", {}).get("highest_floor", 1),
		"runs_won": data.get("stats", {}).get("runs_won", 0),
		"has_active_run": FileAccess.file_exists(get_run_path(slot))
	}

## Crea el directorio base del slot en `user://saves/` y persiste un nuevo `profile.json` con el nombre del jugador y estadísticas en cero.
## Asigna la ranura como activa, borra residuos de runs previas y actualiza el puntero de última partida jugada.
func create_new_slot(slot: int, player_name: String) -> bool:
	var slot_dir := get_slot_dir(slot)
	if not DirAccess.dir_exists_absolute(slot_dir):
		var err := DirAccess.make_dir_recursive_absolute(slot_dir)
		if err != OK:
			push_error("Error creando directorio para el slot %d" % slot)
			return false
			
	var clean_name := player_name.strip_edges()
	if clean_name == "":
		clean_name = "Jugador %d" % slot

	profile_data = {
		"player_name": clean_name,
		"created_at": Time.get_datetime_string_from_system(),
		"unlocked_heroes": ["warrior", "magic", "samurai"],
		"stats": {
			"runs_started": 0,
			"runs_won": 0,
			"highest_floor": 1,
			"total_enemies_killed": 0
		}
	}
	
	current_slot = slot
	
	set_last_played_slot(slot)
	# Borrar cualquier run fantasma previa
	delete_active_run()
	return save_profile()

## Fija el slot indicado como activo en el Autoload, sincroniza el archivo `last_slot` en disco 
## y deserializa su `profile.json` en memoria.
func select_slot(slot: int) -> bool:
	if not is_slot_occupied(slot):
		return false
	current_slot = slot
	set_last_played_slot(slot)
	return load_profile()
	
## Purga del sistema de archivos tanto el `profile.json` como el `run.json` del slot especificado.
## Si la ranura eliminada coincidía con la seleccionada o la última jugada, resetea los punteros y limpia la memoria.
func delete_slot(slot: int) -> void:
	var profile_p := get_profile_path(slot)
	var run_p := get_run_path(slot)
	
	if FileAccess.file_exists(run_p):
		DirAccess.remove_absolute(run_p)
	if FileAccess.file_exists(profile_p):
		DirAccess.remove_absolute(profile_p)
	# Si borran el slot que estaba marcado como último jugado, borrar el puntero
	if get_last_played_slot() == slot:
		if FileAccess.file_exists(LAST_SLOT_PATH):
			DirAccess.remove_absolute(LAST_SLOT_PATH)
		
	if current_slot == slot:
		current_slot = -1
		profile_data.clear()

# ==============================================================================
# OPERACIONES DEL SLOT ACTIVO
# ==============================================================================
## Carga el archivo profile.json del current_slot activo y almacena su
## contenido en el diccionario global profile_data.
func load_profile() -> bool:
	if current_slot <= 0:
		return false
	var path := get_profile_path(current_slot)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and typeof(json.data) == TYPE_DICTIONARY:
		profile_data = json.data
		return true
	return false
## Serializa atómicamente el estado actual de profile_data hacia el archivo profile.json del current_slot.
func save_profile() -> bool:
	if current_slot <= 0:
		return false
	return _write_atomic(get_profile_path(current_slot), profile_data)

## Registra las estadísticas de cierre de una partida (victoria o derrota) en el perfil activo.
## Incrementa el contador de partidas ganadas si corresponde, actualiza el récord de piso más alto alcanzado
## y persiste los cambios de forma atómica en el profile.json del slot actual.
func record_run_finished(won: bool, floor_reached: int) -> void:
	if current_slot <= 0 or profile_data.is_empty():
		return
	
	var stats: Dictionary = profile_data.get("stats", {})
	
	if won:
		stats["runs_won"] = stats.get("runs_won", 0) + 1
	
	if floor_reached > stats.get("highest_floor", 1):
		stats["highest_floor"] = floor_reached
	
	profile_data["stats"] = stats
	save_profile()
	
## Evalúa si existe un archivo run.json en el directorio del current_slot (partida no finalizada).
func has_active_run() -> bool:
	if current_slot <= 0:
		return false
	return FileAccess.file_exists(get_run_path(current_slot))
	
## Elimina el archivo run.json del current_slot. Se utiliza para aplicar la mecánica de muerte definitiva (permadeath).
func delete_active_run() -> void:
	if current_slot <= 0:
		return
	var path := get_run_path(current_slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		

## Serializa en formato JSON el snapshot completo de la partida en curso.
## Delega al `DeckManager` la serialización del mazo, incluyendo opcionalmente las cartas retenidas visualmente en la mesa (`board_cards`).
func save_current_run(run: RunState, deck: DeckManager, board_cards: Array[CardData] = []) -> bool:
	if current_slot <= 0 or run == null or run.is_player_dead():
		delete_active_run()
		return false

	# Le pasamos las cartas de la mesa al deck para que las guarde
	var deck_data := deck.to_dict(board_cards)
	var run_dict := run.to_dict(deck_data)

	return _write_atomic(get_run_path(current_slot), run_dict)
## Deserializa el run.json activo y reconstruye el estado en memoria.
func load_active_run(run: RunState, deck: DeckManager) -> bool:
	if current_slot <= 0 or not has_active_run():
		return false

	var file := FileAccess.open(get_run_path(current_slot), FileAccess.READ)
	if file == null:
		return false

	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or typeof(json.data) != TYPE_DICTIONARY:
		delete_active_run()
		return false

	# Le pasamos los datos crudos al RunState para que se auto-configure
	run.from_dict(json.data, deck)
	return true
	
## Escribe un Dictionary a disco usando el patrón de guardado atómico.
## Almacena primero en una ruta temporal .tmp y luego reemplaza el archivo final con rename para prevenir corrupción de datos ante caídas del sistema.
func _write_atomic(target_path: String, data: Dictionary) -> bool:
	var temp_path := target_path + ".tmp"
	var json_str := JSON.stringify(data, "\t")
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return false
	
	file.store_string(json_str)
	file.close()

	if FileAccess.file_exists(target_path):
		DirAccess.remove_absolute(target_path)
		
	var dir := DirAccess.open("user://")
	return dir.rename(temp_path, target_path) == OK

## Persiste en user://last_slot.cfg el número de la ranura seleccionada para auto-ingreso en futuros arranques.
func set_last_played_slot(slot: int) -> void:
	var file := FileAccess.open(LAST_SLOT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(str(slot))
		file.close()
	

## Lee `user://last_slot.cfg` para devolver el índice de la última ranura jugada.
## Retorna `-1` si el archivo no existe o si la ranura apuntada ya no contiene un perfil válido
func get_last_played_slot() -> int:
	if not FileAccess.file_exists(LAST_SLOT_PATH):
		return -1
	
	var file := FileAccess.open(LAST_SLOT_PATH, FileAccess.READ)
	if file == null:
		return -1
	
	var slot_num := file.get_as_text().strip_edges().to_int()
	file.close()
	
	# Validar que esté en rango y que la carpeta realmente exista con un perfil vivo
	if slot_num >= 1 and slot_num <= MAX_SLOTS and is_slot_occupied(slot_num):
		return slot_num
	
	return -1
