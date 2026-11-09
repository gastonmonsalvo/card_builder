## Efecto de aflicción física. Acumula cargas de Hemorragia (`hemorrhage`) en el `combo_state`.
extends CardEffect
class_name HemorrhageEffect

@export var amount: int = 3

## Suma las acumulaciones de Hemorragia (`hemorrhage`) al diccionario de evaluación del combo.
func apply(combo_state: Dictionary) -> void:
	combo_state["hemorrhage"] += amount

## Devuelve el texto descriptivo con la cantidad de Hemorragia aplicada para la UI.
func get_description() -> String:
	return "+%d Hemorragia" % amount

## Retorna el color rojo carmesí representativo del estado de Hemorragia.
func get_color() -> Color:
	return Color(0.995, 0.0, 0.101, 1.0)
