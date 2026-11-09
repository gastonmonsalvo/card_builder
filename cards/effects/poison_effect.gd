## Efecto de estado tóxico. Acumula cargas de Veneno (`poison`) en el `combo_state`.
extends CardEffect
class_name PoisonEffect

@export var amount: int = 5

## Suma las acumulaciones de Veneno (`poison`) configuradas al diccionario de evaluación del combo.
func apply(combo_state: Dictionary) -> void:
	combo_state["poison"] += amount

## Devuelve el texto descriptivo con las cargas de Veneno para la UI de la carta.
func get_description() -> String:
	return "+%d Veneno" % amount

## Retorna el color verde ácido representativo del estado de Veneno.
func get_color() -> Color:
	return Color(0.55, 0.85, 0.15)
