## Define las propiedades base de un arma, sus requisitos y su factor de escalada.
extends Resource
class_name WeaponData

enum Class { ANY, SWORD, HEAVY, STAFF, DAGGER, KATANA }
@export_group("Identity")
@export var weapon_id: String = "weapon_base"
@export var weapon_name: String = "Arma Base"
@export var weapon_class: Class = Class.ANY
@export var rarity: RaritySystem.Tier = RaritySystem.Tier.COMMON
## Sprite 2D opcional del arma que se renderiza sobre el pedestal en `WeaponUI`.
@export var artwork: Texture2D
## Párrafo narrativo en cursiva (Lore / Descripción del objeto) para el bloque inferior de `WeaponUI`.
@export_multiline var lore: String = ""

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

## Devuelve el nombre localizado de la familia de arma.
func get_class_display_name() -> String:
	match weapon_class:
		Class.SWORD:
			return "Espada"
		Class.HEAVY:
			return "Pesada"
		Class.STAFF:
			return "Báculo"
		Class.DAGGER:
			return "Daga"
		Class.KATANA:
			return "Katana"
		_:
			return "Cualquier Clase"

## Genera el texto de la píldora central de tipo de arma en `WeaponUI` (misma estética que `CardUI`).
func get_weapon_tag_text() -> String:
	return "🏷️ Tipo de Arma: %s" % get_class_display_name()

## Devuelve un glifo/emblema representativo para el pedestal cuando `artwork` no está asignado.
func get_placeholder_emblem() -> String:
	match weapon_class:
		Class.SWORD:
			return "⚔️"
		Class.HEAVY:
			return "🪓"
		Class.STAFF:
			return "🪄"
		Class.DAGGER:
			return "🗡️"
		Class.KATANA:
			return "⚔️"
		_:
			return "🪵"

## Construye el resumen estructurado de estadísticas clave, escalado, requisitos y efectos pasivos On-Hit para `WeaponUI`.
func get_stats_and_scaling_text() -> String:
	var lines: Array[String] = []
	lines.append("• Daño Base: %d" % base_damage)

	var scale_parts: Array[String] = []
	if scale_str > 0.0:
		scale_parts.append("+%.1f/STR" % scale_str)
	if scale_int > 0.0:
		scale_parts.append("+%.1f/INT" % scale_int)
	if scale_dex > 0.0:
		scale_parts.append("+%.1f/DEX" % scale_dex)
	if not scale_parts.is_empty():
		lines.append("• Escalado: %s" % ", ".join(scale_parts))

	var req_parts: Array[String] = []
	if req_str > 0:
		req_parts.append("%d STR" % req_str)
	if req_int > 0:
		req_parts.append("%d INT" % req_int)
	if req_dex > 0:
		req_parts.append("%d DEX" % req_dex)
	if not req_parts.is_empty():
		lines.append("• Requisitos: %s" % ", ".join(req_parts))

	var passive_parts: Array[String] = []
	if inflict_hemorrhage > 0:
		passive_parts.append("+%d Hemorragia" % inflict_hemorrhage)
	if inflict_burn > 0:
		passive_parts.append("+%d Quemadura" % inflict_burn)
	if inflict_poison > 0:
		passive_parts.append("+%d Veneno" % inflict_poison)
	if inflict_shock > 0:
		passive_parts.append("+%d Electrocución" % inflict_shock)

	if not passive_parts.is_empty():
		lines.append("• Efecto Pasivo: \"Las cartas de %s aplican %s.\"" % [
			get_class_display_name().to_upper(),
			" y ".join(passive_parts)
		])
	else:
		lines.append("• Efecto Pasivo: Sin estado adicional por golpe.")

	return "\n".join(lines)

## Devuelve el párrafo narrativo de historia (Lore) entre comillas para el bloque inferior de `WeaponUI`.
func get_lore_text() -> String:
	var raw: String = lore.strip_edges()
	if raw == "":
		raw = "Un arma forjada para sobrevivir a los horrores de la mazmorra."
	if raw.begins_with("\"") and raw.ends_with("\""):
		return raw
	return "\"%s\"" % raw
