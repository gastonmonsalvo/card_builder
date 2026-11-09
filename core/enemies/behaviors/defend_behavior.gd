## Comportamiento defensivo periódico para la IA enemiga.
## Otorga bloqueo (`DEFEND`) al enemigo cuando el número de turno es múltiplo de `every_n_turns`.
extends EnemyBehavior
class_name DefendBehavior

@export var block: int = 10
@export var every_n_turns: int = 3  # ej: cada 3 turnos

## Evalúa si corresponde activar la defensa en el turno actual y retorna el `EnemyIntent` con el bloqueo configurado.
func decide(context: EnemyContext) -> EnemyIntent:
	if context.turn_count % every_n_turns != 0:
		return null
	return EnemyIntent.new(EnemyIntent.Type.DEFEND, 0, block, "Ganar %d block" % block)
