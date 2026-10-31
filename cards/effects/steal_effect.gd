extends CardEffect
class_name StealEffect

@export var cards_to_draw: int = 1

func apply(combo_state: Dictionary) -> void:
	combo_state["draw"] += cards_to_draw

func get_description() -> String:
	return "Roba +%d carta(s) [INSTANTANEO]" % cards_to_draw

func get_color() -> Color:
	return Color(0.18, 0.72, 0.35)

func is_instant() -> bool:
	return true
