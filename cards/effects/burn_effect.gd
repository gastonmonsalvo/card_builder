extends CardEffect
class_name BurnEffect

@export var amount: int = 6

func apply(combo_state: Dictionary) -> void:
	combo_state["burn"] += amount

func get_description() -> String:
	return "+%d Quemadura" % amount

func get_color() -> Color:
	return Color(1.0, 0.37, 0.1)
