## Base de datos estática centralizada para la carga de recursos.
## Escanea el sistema de archivos mediante `ResourceLoader` para instanciar en memoria
## los catálogos globales de héroes, cartas y reliquias.class_name 
extends Node

## Escanea el directorio especificado, instancia los recursos `.tres`/`.res` de tipo `HeroData`
## y devuelve un arreglo ordenado de menor a mayor según su `sort_order`.

func load_all_heroes(dir_path: String = CombatConstants.HERO_PATH) -> Array[HeroData]:
	var heroes_list: Array[HeroData] = []
	if not DirAccess.dir_exists_absolute(dir_path):
		return heroes_list
		
	var entries: PackedStringArray = ResourceLoader.list_directory(dir_path)
	for entry in entries:
		if entry.ends_with(".tres") or entry.ends_with(".res"):
			var res: Resource = ResourceLoader.load(dir_path.path_join(entry))
			if res is HeroData:
				heroes_list.append(res)
				
	heroes_list.sort_custom(func(a, b): return a.sort_order < b.sort_order)
	return heroes_list

## Escanea recursivamente el directorio instanciando los recursos `CardData`.
## Ignora intencionalmente las subcarpetas nombradas "effects/" para aislar la carga de cartas base.
func load_all_cards(dir_path: String = CombatConstants.CARD_PATH) -> Array[CardData]:
	var cards_list: Array[CardData] = []
	if not DirAccess.dir_exists_absolute(dir_path):
		return cards_list

	var entries: PackedStringArray = ResourceLoader.list_directory(dir_path)
	for entry in entries:
		var full_path: String = dir_path.path_join(entry)
		if entry.ends_with("/"):
			if entry != "effects/":
				cards_list.append_array(load_all_cards(full_path))
		elif entry.ends_with(".tres") or entry.ends_with(".res"):
			var res: Resource = ResourceLoader.load(full_path)
			if res is CardData:
				cards_list.append(res)
	return cards_list
	
## Escanea el directorio especificado y devuelve un arreglo plano con todas las instancias `RelicData`
## encontradas para poblar el catálogo de la partida.
func load_all_relics(dir_path: String = CombatConstants.RELIC_PATH) -> Array[RelicData]:
	var relics_list: Array[RelicData] = []
	if not DirAccess.dir_exists_absolute(dir_path):
		return relics_list
		
	var entries: PackedStringArray = ResourceLoader.list_directory(dir_path)
	for entry in entries:
		if entry.ends_with(".tres") or entry.ends_with(".res"):
			var res: Resource = ResourceLoader.load(dir_path.path_join(entry))
			if res is RelicData:
				relics_list.append(res)
				
	return relics_list
	
## Escanea el directorio especificado y carga todos los recursos estáticos de tipo `EnemyData`.
## Filtra automáticamente otros tipos de archivos (como .import) para evitar errores.
func load_all_enemies(dir_path: String = CombatConstants.ENEMY_PATH) -> Array[EnemyData]:
	var enemies_list: Array[EnemyData] = []
	if not DirAccess.dir_exists_absolute(dir_path):
		return enemies_list
		
	var entries: PackedStringArray = ResourceLoader.list_directory(dir_path)
	for entry in entries:
		if entry.ends_with(".tres") or entry.ends_with(".res"):
			var res: Resource = ResourceLoader.load(dir_path.path_join(entry))
			if res is EnemyData:
				enemies_list.append(res)
				
	return enemies_list
	
## Carga masivamente todos los recursos de armas (.tres / .res) desde una ruta específica.
func load_all_weapons(dir_path: String = CombatConstants.WEAPON_PATH) -> Array[WeaponData]:
	var weapons_list: Array[WeaponData] = []
	if not DirAccess.dir_exists_absolute(dir_path):
		return weapons_list
		
	var entries: PackedStringArray = ResourceLoader.list_directory(dir_path)
	for entry in entries:
		if entry.ends_with(".tres") or entry.ends_with(".res"):
			var res: Resource = ResourceLoader.load(dir_path.path_join(entry))
			if res is WeaponData: # Asegurate de que tu clase de recursos de armas sea WeaponData
				weapons_list.append(res)
				
	return weapons_list
