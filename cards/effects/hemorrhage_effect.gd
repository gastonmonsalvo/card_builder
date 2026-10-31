extends CardEffect
class_name HemorrhageEffect

@export var amount: int = 3

func apply(combo_state: Dictionary) -> void:
	combo_state["hemorrhage"] += amount

func get_description() -> String:
	return "+%d Hemorragia" % amount

func get_color() -> Color:
	return Color(0.995, 0.0, 0.101, 1.0)
