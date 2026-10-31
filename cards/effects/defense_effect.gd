extends CardEffect
class_name DefenseEffect

@export var amount: int = 8

func apply(combo_state: Dictionary) -> void:
	combo_state["block"] += amount

func get_description() -> String:
	return "+%d Escudo" % amount

func get_color() -> Color:
	return Color(0.18, 0.52, 0.88)
