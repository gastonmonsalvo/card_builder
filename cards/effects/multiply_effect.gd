## Efecto amplificador de combo. Multiplica el daño acumulado hasta ese punto en la secuencia.
extends CardEffect
class_name MultiplyEffect

@export var factor: float = 2.0

## Multiplica el acumulador `dmg` del `combo_state` por `factor` y registra el multiplicador para el banner del HUD.
func apply(combo_state: Dictionary) -> void:
	combo_state["dmg"] *= factor
	
	# Trackear el multiplicador para mostrarlo en el banner del HUD
	if not combo_state.has("multipliers"):
		combo_state["multipliers"] = []
	combo_state["multipliers"].append(factor)

## Devuelve el texto descriptivo formateando el factor de multiplicación de daño.
func get_description() -> String:
	return "x%.1f Daño" % factor

## Retorna el color púrpura representativo de los efectos multiplicadores.
func get_color() -> Color:
	return Color(0.65, 0.22, 0.88)
