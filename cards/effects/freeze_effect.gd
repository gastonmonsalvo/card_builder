## Efecto de estado elemental gélido. Acumula cargas de Congelamiento (`freeze`) en el `combo_state`.
extends CardEffect
class_name FreezeEffect

@export var amount: int = 2

## Inicializa el efecto marcándolo por defecto como mágico/elemental.
func _init() -> void:
	is_magical = true

## Suma las cargas de Congelamiento (`freeze`) configuradas al diccionario de evaluación del combo.
func apply(combo_state: Dictionary) -> void:
	combo_state["freeze"] += amount

## Devuelve el texto descriptivo con las cargas de Congelamiento para la interfaz de la carta.
func get_description() -> String:
	return "+%d Congelamiento" % amount

## Retorna el color celeste gélido representativo del estado de Congelamiento.
func get_color() -> Color:
	return Color(0.35, 0.85, 1.0)

## Indica que el efecto no es instantáneo y debe evaluarse dentro de la secuencia de la zona de combo.
func is_instant() -> bool:
	return false

func is_status_effect() -> bool:
	return true

func get_status_icon() -> String:
	return "❄️"

func get_emblem_icon() -> String:
	return "❄️"
