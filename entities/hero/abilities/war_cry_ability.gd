# core/hero/abilities/war_cry_ability.gd
## Habilidad activa del Guerrero orientada a la potenciación temporal de daño.
## Aplica una bonificación temporal de fuerza a través del gestor de modificadores.
class_name WarCryAbility
extends HeroAbility

## Cantidad de fuerza que se sumará temporalmente a las estadísticas del jugador.
@export var strength_bonus: int = 3

## Cantidad de turnos durante los cuales permanecerá activo el modificador.
@export var duration_turns: int = 2


## Inicializa los valores por defecto de nombre, descripción formateada y usos por combate.
func _init() -> void:
	ability_name = "Grito de Guerra"
	description = "Gana +%d Fuerza por %d turnos." % [strength_bonus, duration_turns]
	uses_per_combat = 1


## Registra el modificador temporal de fuerza en el gestor de estadísticas del jugador.
## Consume un uso y emite el registro informativo en la consola.
func activate(context: Dictionary) -> void:
	if not can_activate():
		return
	uses_remaining -= 1
	
	var run = context.get("run")
	if run and run.temp_stats:
		# Agregar mod temporal: +3 STR por 2 turnos
		run.temp_stats.add_mod("str", strength_bonus, duration_turns)
		print("[HeroAbility] Grito de Guerra: +%d STR por %d turnos." % [strength_bonus, duration_turns])


## Construye el mensaje para el banner de la mesa reflejando la bonificación y la duración.
func get_activation_message() -> String:
	return "¡Grito de Guerra! +%d Fuerza por %d turnos." % [strength_bonus, duration_turns]
