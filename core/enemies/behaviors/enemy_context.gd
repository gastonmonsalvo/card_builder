## Contexto que reciben los behaviors para decidir su intent.
extends RefCounted
class_name EnemyContext

var enemy: Enemy
var run: RunState
var turn_count: int  # turnos transcurridos en el combate

func _init(p_enemy: Enemy, p_run: RunState, p_turn: int = 0) -> void:
	enemy = p_enemy
	run = p_run
	turn_count = p_turn
