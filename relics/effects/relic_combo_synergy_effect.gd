## Efecto de reliquia diseñado para premiar al jugador al armar secuencias largas en el tablero.
## Inyecta bonificaciones de daño y escudo al resolver el turno si se alcanza el mínimo de cartas.
extends RelicEffect
class_name RelicComboSynergyEffect

## Umbral mínimo de cartas requeridas en el combo y los valores de bonificación a otorgar.
@export var min_cards_required: int = CombatConstants.BASE_MIN_CARDS_REQUIERED
@export var bonus_damage: int = CombatConstants.BASE_BONUS_DMG
@export var bonus_block: int = CombatConstants.BASE_BONUS_SHIELD

## Verifica si la cantidad de cartas jugadas (`card_count`) cumple el requisito mínimo, 
## e inyecta el daño y escudo adicional directamente en el diccionario `combo_state`.
func on_combo_evaluated(combo_state: Dictionary, card_count: int) -> void:
	if card_count >= min_cards_required:
		combo_state["dmg"] = combo_state.get("dmg", 0.0) + float(bonus_damage)
		combo_state["block"] = combo_state.get("block", 0.0) + float(bonus_block)
		
## Genera el texto dinámico detallando la condición del combo y sus respectivas recompensas.
func get_description() -> String:
	var parts: Array[String] = []
	if bonus_damage > 0:
		parts.append("+%d Daño" % bonus_damage)
	if bonus_block > 0:
		parts.append("+%d Escudo" % bonus_block)
	return "Combo de %d+ cartas: %s" % [min_cards_required, " y ".join(parts)]
