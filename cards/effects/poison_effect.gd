extends CardEffect
class_name PoisonEffect

@export var amount: int = 5

func apply(combo_state: Dictionary) -> void:
	combo_state["poison"] += amount

func get_description() -> String:
	return "+%d Veneno" % amount

func get_color() -> Color:
	return Color(0.55, 0.85, 0.15)
