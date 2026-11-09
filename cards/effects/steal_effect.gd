## Efecto táctico de robo inmediato. Incrementa el contador `draw` y se ejecuta sin pasar por la zona de combo.
extends CardEffect
class_name StealEffect

@export var cards_to_draw: int = 1

## Suma la cantidad de cartas a robar (`cards_to_draw`) en el campo `draw` del diccionario de estado.
func apply(combo_state: Dictionary) -> void:
	combo_state["draw"] += cards_to_draw

## Devuelve el texto descriptivo indicando la cantidad de robo y su condición de ejecución instantánea.
func get_description() -> String:
	return "Roba +%d carta(s) [INSTANTANEO]" % cards_to_draw

## Retorna el color esmeralda representativo de las cartas utilitarias de robo.
func get_color() -> Color:
	return Color(0.18, 0.72, 0.35)

## Retorna `true` para que la carta se consuma inmediatamente al seleccionarla desde la mano.
func is_instant() -> bool:
	return true
