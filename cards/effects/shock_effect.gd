## Efecto de estado eléctrico. Acumula cargas de Electrocutado (`shock`) en el `combo_state`.
extends CardEffect
class_name ShockEffect

@export var amount: int = 3

## Inicializa el efecto marcándolo por defecto como mágico/elemental.
func _init() -> void:
	is_magical = true

## Suma las cargas de Electrocutado (`shock`) al diccionario de evaluación del combo.
func apply(combo_state: Dictionary) -> void:
	combo_state["shock"] = combo_state.get("shock", 0) + amount

## Devuelve el texto descriptivo con las cargas de Electrocutado para la interfaz de la carta.
func get_description() -> String:
	return "+%d Electrocutado" % amount

## Retorna el color amarillo eléctrico representativo del estado de Electrocutado.
func get_color() -> Color:
	return Color(1.0, 0.92, 0.2)

## Indica que el efecto se resuelve dentro de la secuencia de la zona de combo y no de forma instantánea.
func is_instant() -> bool:
	return false
