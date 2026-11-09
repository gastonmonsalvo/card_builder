## Objeto de transferencia de datos (DTO) que encapsula el contexto del combate
## para que los `EnemyBehavior` tomen decisiones sobre su próxima intención.
extends RefCounted
class_name EnemyContext

var enemy: Enemy
var run: RunState
var turn_count: int  # turnos transcurridos en el combate

## Inicializa el contexto de evaluación con la instancia viva del enemigo, el `RunState` y el turno actual.
func _init(p_enemy: Enemy, p_run: RunState, p_turn: int = 0) -> void:
	enemy = p_enemy
	run = p_run
	turn_count = p_turn
