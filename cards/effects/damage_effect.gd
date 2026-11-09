## Efecto ofensivo directo. Suma daño plano adicional al acumulador `dmg` del `combo_state`.
extends CardEffect
class_name DamageEffect

@export var amount: int = 10

## Incrementa el daño acumulado (`dmg`) del combo con el valor base configurado en el efecto.
func apply(combo_state: Dictionary) -> void:
	combo_state["dmg"] += amount

## Devuelve el texto descriptivo del daño base aportado para mostrar en la carta.
func get_description() -> String:
	return "+%d Daño Base" % amount

## Retorna el color rojo carmesí representativo de las cartas de ataque directo.
func get_color() -> Color:
	return Color(0.82, 0.20, 0.22, 1.0)
