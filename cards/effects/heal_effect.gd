## Efecto de curación. Suma al campo "heal" del combo_state.
extends CardEffect
class_name HealEffect

@export var amount: int = 5

func apply(combo_state: Dictionary) -> void:
	if not combo_state.has("heal"):
		combo_state["heal"] = 0
	combo_state["heal"] += amount

func get_description() -> String:
	return "+%d HP" % amount

func get_color() -> Color:
	return Color(0.2, 0.9, 0.3)  # Verde
