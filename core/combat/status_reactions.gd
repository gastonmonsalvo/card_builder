## Motor estático para detectar y aplicar Reacciones Elementales.
extends RefCounted
class_name StatusReactions

# Definición de reacciones (data-driven, fácil de extender)
const REACTIONS: Array[Dictionary] = [
	{
		"id": "vaporize",
		"name": "¡VAPORIZACIÓN!",
		"requires": {"burn": 1, "freeze": 1},
		"consumes": {"burn": 3, "freeze": 3},
		"effect": "DAMAGE_FLAT",
		"value": 15
	},
	{
		"id": "superconductor",
		"name": "¡SUPERCONDUCTOR!",
		"requires": {"freeze": 1, "shock": 1},
		"consumes": {"freeze": 2, "shock": 2},
		"effect": "DAMAGE_FLAT",
		"value": 20
	},
	{
		"id": "combustion",
		"name": "¡COMBUSTIÓN TÓXICA!",
		"requires": {"burn": 1, "poison": 1},
		"consumes": {"poison": 99},
		"effect": "DAMAGE_PER_STACK",
		"value": 10
	}
]

## Verifica si al aplicar `incoming` sobre el `enemy` actual se desencadena una reacción.
static func check(enemy: Enemy, incoming: Dictionary) -> Dictionary:
	# Simular el estado futuro: estado actual + lo que viene
	var future := {
		"burn": enemy.burn + int(incoming.get("burn", 0)),
		"poison": enemy.poison + int(incoming.get("poison", 0)),
		"freeze": enemy.freeze + int(incoming.get("freeze", 0)),
		"shock": enemy.shock + int(incoming.get("shock", 0)),
		"hemorrhage": enemy.hemorrhage + int(incoming.get("hemorrhage", 0))
	}
	
	# Buscar la primera reacción que se pueda detonar
	for reaction in REACTIONS:
		var req: Dictionary = reaction["requires"]
		var can_trigger := true
		
		for key in req.keys():
			if int(future.get(key, 0)) < int(req[key]):
				can_trigger = false
				break
		
		if can_trigger:
			return reaction
	
	return {}


## Aplica la reacción al enemigo: consume los statuses necesarios y aplica el efecto.
static func apply(enemy: Enemy, reaction: Dictionary) -> void:
	var consumes: Dictionary = reaction.get("consumes", {})
	
	# 1. Consumir statuses (el mínimo entre lo que la reacción pide y lo disponible)
	var total_consumed: int = 0
	for key in consumes.keys():
		var key_str: String = str(key)
		var amount_to_consume: int = int(consumes[key])
		var current_amount: int = int(enemy.get(key_str))
		var consumed: int = min(current_amount, amount_to_consume)
		enemy.set(key_str, current_amount - consumed)
		total_consumed += consumed
		
	# 2. Aplicar el efecto de la reacción
	var effect_type: String = str(reaction.get("effect", ""))
	var value: int = int(reaction.get("value", 0))
	
	match effect_type:
		"DAMAGE_FLAT":
			enemy.take_damage(value)
		"DAMAGE_PER_STACK":
			enemy.take_damage(value * total_consumed)
