## Recurso serializable (`.tres`) que define la plantilla de datos para cada clase o héroe seleccionable.
## Contiene sus estadísticas base (HP, energía, suerte), mazo inicial y reliquias de partida.
extends Resource
class_name HeroData

## Metadatos de identidad del héroe para la interfaz de selección.
## `accent_color` define el color temático representativo del personaje en la UI.
@export_group("Identity")
@export var hero_name: String = "Guerrero"
@export_multiline var description: String = "Especialista en combate cuerpo a cuerpo y resistencia."
@export var accent_color: Color = Color("e74c3c") 
## Estadísticas fundamentales con las que el héroe inicia cada partida.
## (La variable `lucky` afecta eventos RNG y probabilidades de estados alterados como parálisis o hemorragia).
@export_group("Stats")
@export var max_hp_base: int = CombatConstants.BASE_HEALTH
@export var energy_base: int = CombatConstants.BASE_MAX_ENERGY
@export var lucky: int = CombatConstants.BASE_LUCKY
@export var gold: int = CombatConstants.BASE_GOLD
@export var hand_size : int = CombatConstants.BASE_HAND_SIZE
@export var discards_base: int = CombatConstants.BASE_DISCARDS_PER_COMBAT
@export var sort_order: int = 0
## Inventario predeterminado del héroe:

## define las cartas exactas que conformarán su mazo base y las reliquias con las que arrancará la partida.
@export_group("Cards and Relics")
@export var starting_deck: Array[CardData] = []
## Reliquias inicales
@export var starting_relic: Array[RelicData] = []
##Orden para sort en menu

@export_group("RPG Stats")
@export var base_str: int = 1
@export var base_int: int = 1
@export var base_dex: int = 1

@export_group("Equipment")

## Arma inicial que porta el héroe al arrancar la run.
@export var starting_weapon: WeaponData

## Retorna el nombre del arma inicial de forma segura, o un texto por defecto si está desarmado.
func get_starting_weapon_name() -> String:
	if starting_weapon and "weapon_name" in starting_weapon:
		return starting_weapon.weapon_name
	return "Sin Arma"
