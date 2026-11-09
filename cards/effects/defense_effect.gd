## Efecto defensivo. Acumula puntos de bloqueo (`block`) para el jugador en el `combo_state`.
extends CardEffect
class_name DefenseEffect

@export var amount: int = 8

## Suma la cantidad de escudo configurada al acumulador `block` del diccionario del combo.
func apply(combo_state: Dictionary) -> void:
	combo_state["block"] += amount

## Devuelve el texto descriptivo con los puntos de escudo otorgados para la UI de la carta.
func get_description() -> String:
	return "+%d Escudo" % amount

## Retorna el color azul defensivo representativo del bloqueo.
func get_color() -> Color:
	return Color(0.18, 0.52, 0.88)
