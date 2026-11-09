## Efecto de estado elemental ígneo. Acumula cargas de Quemadura (`burn`) en el `combo_state`.
extends CardEffect
class_name BurnEffect

@export var amount: int = 6

## Suma las acumulaciones de Quemadura (`burn`) configuradas al diccionario de resolución del combo.
func apply(combo_state: Dictionary) -> void:
	combo_state["burn"] += amount

## Devuelve el texto descriptivo del efecto con la cantidad de cargas de Quemadura para la UI.
func get_description() -> String:
	return "+%d Quemadura" % amount

## Retorna el color naranja ígneo representativo del efecto de Quemadura.
func get_color() -> Color:
	return Color(1.0, 0.37, 0.1)
