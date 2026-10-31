## Define las propiedades base de un arma, sus requisitos y su factor de escalada.
extends Resource
class_name WeaponData

enum Class { ANY, SWORD, HEAVY, STAFF, DAGGER, KATANA }
@export_group("Identity")
@export var weapon_id: String = "weapon_base"
@export var weapon_name: String = "Arma Base"
@export var weapon_class: Class = Class.ANY

@export_group("Dmg")
@export var base_damage: int = 3

@export_group("Effects (On-Hit)")
## Cantidad de estado que aplica el arma por CADA GOLPE exitoso.
@export var inflict_poison: int = 0
@export var inflict_burn: int = 0
@export var inflict_hemorrhage: int = 0
@export var inflict_shock: int = 0

@export_group("Requirements")
@export var req_str: int = 0
@export var req_int: int = 0
@export var req_dex: int = 0

@export_group("Scale (Reducido: 0.1 = +1 Daño cada 10 pts)")
@export var scale_str: float = 0.0
@export var scale_int: float = 0.0
@export var scale_dex: float = 0.0

## Calcula cuántos puntos le faltan al héroe para dominar el arma.
## Retorna 0 si cumple todo. Si retorna > 0, es el déficit total.
func get_stat_deficit(h_str: int, h_int: int, h_dex: int) -> int:
	var deficit: int = 0
	if h_str < req_str: deficit += (req_str - h_str)
	if h_int < req_int: deficit += (req_int - h_int)
	if h_dex < req_dex: deficit += (req_dex - h_dex)
	return deficit


## Calcula el bonus de daño puro basado en los stats del héroe y el multiplicador del arma.
func get_scaling_bonus(h_str: int, h_int: int, h_dex: int) -> int:
	var bonus: float = (h_str * scale_str) + (h_int * scale_int) + (h_dex * scale_dex)
	return int(floor(bonus))
