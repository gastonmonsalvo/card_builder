extends CardEffect
class_name DamageEffect

@export var amount: int = 10

func apply(combo_state: Dictionary) -> void:
		combo_state["dmg"] += amount

func get_description() -> String:
		return "+%d Daño Base" % amount

func get_color() -> Color:
		return Color(0.0, 0.382, 0.009, 1.0)
