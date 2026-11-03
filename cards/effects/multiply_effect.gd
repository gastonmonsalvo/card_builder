extends CardEffect
class_name MultiplyEffect

@export var factor: float = 2.0

func apply(combo_state: Dictionary) -> void:
	combo_state["dmg"] *= factor
	
	# Trackear el multiplicador para mostrarlo en el banner del HUD
	if not combo_state.has("multipliers"):
		combo_state["multipliers"] = []
	combo_state["multipliers"].append(factor)

func get_description() -> String:
	return "x%.1f Daño" % factor

func get_color() -> Color:
	return Color(0.65, 0.22, 0.88)
