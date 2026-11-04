# core/hero/abilities/demon_thrust_ability.gd
## Habilidad activa del Samurái enfocada en daño directo de ejecución.
## Aplica un golpe fijo al enemigo ignorando mecánicas de armas y escalando con la suerte.
class_name DemonThrustAbility
extends HeroAbility

## Cantidad base de daño directo infligido al objetivo.
@export var base_damage: int = 20


## Asigna los valores por defecto de nombre, descripción formateada y límite de usos.
func _init() -> void:
	ability_name = "Estocada Demoníaca"
	description = "Inflige %d de daño directo al enemigo (ignora arma)." % base_damage
	uses_per_combat = 1


## Calcula el daño final sumando el escalado por suerte del jugador y lo aplica al enemigo.
## Consume un uso y emite el registro correspondiente en la consola.
func activate(context: Dictionary) -> void:
	if not can_activate():
		return
	uses_remaining -= 1
	
	var table = context.get("table")
	var run = context.get("run")
	
	if table and table.enemy and run:
		# El daño escala ligeramente con la suerte
		var bonus = int(run.player_luck * 0.5)
		var total_dmg = base_damage + bonus
		table.enemy.take_damage(total_dmg)
		print("[HeroAbility] Estocada Demoníaca: %d daño directo." % total_dmg)


## Devuelve el texto descriptivo para el banner de la mesa al disparar el ataque.
func get_activation_message() -> String:
	return "¡Estocada Demoníaca! Inflige %d de daño directo." % base_damage
