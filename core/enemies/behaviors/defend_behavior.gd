extends EnemyBehavior
class_name DefendBehavior

@export var block: int = 10
@export var every_n_turns: int = 3  # ej: cada 3 turnos

func decide(context: EnemyContext) -> EnemyIntent:
	if context.turn_count % every_n_turns != 0:
		return null
	return EnemyIntent.new(EnemyIntent.Type.DEFEND, 0, block, "Ganar %d block" % block)
