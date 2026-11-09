## Efecto de curación. Suma puntos de vida a restaurar en el campo `heal` del `combo_state`.
extends CardEffect
class_name HealEffect

@export var amount: int = 5

## Acumula la cantidad de curación (`heal`) en el diccionario del combo para aplicarla al resolver el turno.
func apply(combo_state: Dictionary) -> void:
	if not combo_state.has("heal"):
		combo_state["heal"] = 0
	combo_state["heal"] += amount

## Devuelve el texto descriptivo con la cantidad de HP a restaurar.
func get_description() -> String:
	return "+%d HP" % amount

## Retorna el color verde representativo de los efectos de curación.
func get_color() -> Color:
	return Color(0.2, 0.9, 0.3)

func get_emblem_icon() -> String:
	return "💚"
