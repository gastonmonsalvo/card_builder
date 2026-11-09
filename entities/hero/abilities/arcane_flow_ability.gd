## Habilidad activa del Mago que permite robar cartas adicionales sin costo de recursos.
## Consume un uso por encuentro y delega el robo a la mesa de combate.
class_name ArcaneFlowAbility
extends HeroAbility


## Asigna los valores por defecto de nombre, descripción y límite de usos de la habilidad.
func _init() -> void:
	ability_name = "Flujo Arcano"
	description = "Roba 3 cartas del mazo sin gastar energía."
	uses_per_combat = 1


## Ejecuta el robo de cartas interactuando con la mesa de combate si quedan usos disponibles.
## Reduce el contador de usos y notifica la acción en la consola.
func activate(context: Dictionary) -> void:
	if not can_activate():
		return
	uses_remaining -= 1
	
	# Robar 3 cartas usando el método del BattleTable
	var table = context.get("table")
	if table and table.has_method("draw_cards"):
		table.draw_cards(3)
		print("[HeroAbility] Flujo Arcano activado: +3 cartas robadas.")

## Devuelve el texto descriptivo para el banner de la mesa al activar el robo arcano.
func get_activation_message() -> String:
	return "¡Flujo Arcano! Robas 3 cartas del mazo."
