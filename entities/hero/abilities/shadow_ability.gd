# core/hero/abilities/bloody_slash_ability.gd
## Habilidad activa del Samurái enfocada en daño físico combinado con aflicción por estado.
## Inflige daño inmediato y acumula acumulaciones de hemorragia sobre el enemigo activo.
class_name BloodySlashAbility
extends HeroAbility

## Cantidad base de daño directo infligido al objetivo al activarse.
@export var base_damage: int = 7

## Cantidad de acumulaciones de hemorragia a transferir al enemigo.
@export var hemorrhage_stacks: int = 10


## Asigna los valores por defecto de nombre, descripción formateada y límite de usos.
func _init() -> void:
	ability_name = "Corte Sangrante"
	description = "Inflige %d de daño y aplica +%d de Hemorragia." % [base_damage, hemorrhage_stacks]
	uses_per_combat = 1


## Aplica el daño y el estado alterado sobre el enemigo a través de la mesa de combate.
## Consume un uso y emite el registro correspondiente en la consola.
func activate(context: Dictionary) -> void:
	if not can_activate():
		return
	uses_remaining -= 1
	
	var table = context.get("table")
	if table and table.enemy:
		# 1. Daño directo
		table.enemy.take_damage(base_damage)
		
		# 2. Aplicar hemorragia (add_statuses: burn, poison, freeze, shock, hemorrhage)
		table.enemy.add_statuses(0, 0, 0, 0, hemorrhage_stacks)
		
		print("[HeroAbility] Corte Sangrante: %d daño + %d hemorragia." % [base_damage, hemorrhage_stacks])


## Devuelve el texto descriptivo para el banner de la mesa reflejando el daño y la hemorragia.
func get_activation_message() -> String:
	return "¡Corte Sangrante! %d daño y +%d Hemorragia al enemigo." % [base_damage, hemorrhage_stacks]
