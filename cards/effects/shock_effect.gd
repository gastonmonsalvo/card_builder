extends CardEffect
class_name ShockEffect

@export var amount: int = 3

func apply(combo_state: Dictionary) -> void:
	combo_state["shock"] = combo_state.get("shock", 0) + amount

func get_description() -> String:
	return "+%d Electrocutado" % amount

func get_color() -> Color:
	# Amarillo eléctrico intenso
	return Color(1.0, 0.92, 0.2)

func is_instant() -> bool:
	return false
