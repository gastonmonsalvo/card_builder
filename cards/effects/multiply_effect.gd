extends CardEffect
class_name MultiplyEffect

@export var factor: float = 2.0

func apply(combo_state: Dictionary) -> void:
	combo_state["dmg"] *= factor

func get_description() -> String:
	return "x%.1f Daño" % factor

func get_color() -> Color:
	return Color(0.65, 0.22, 0.88)
