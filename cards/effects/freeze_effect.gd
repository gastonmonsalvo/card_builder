extends CardEffect
class_name FreezeEffect

@export var amount: int = 2

func apply(combo_state: Dictionary) -> void:
	combo_state["freeze"] =+ amount

func get_description() -> String:
	return "+%d Congelamiento" % amount

func get_color() -> Color:

	return Color(0.35, 0.85, 1.0)

func is_instant() -> bool:
	return false
