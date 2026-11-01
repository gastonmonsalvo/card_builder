## Clase base abstracta para estrategias de IA enemiga.
## Cada behavior decide qué intent tiene el enemigo en un turno dado.
extends Resource
class_name EnemyBehavior

## Retorna un EnemyIntent si este behavior aplica para el turno actual, o null si no.
## El EnemyAI itera los behaviors en orden y usa el primer intent no-null.
func decide(context: EnemyContext) -> EnemyIntent:
	push_error("EnemyBehavior.decide() must be overridden in subclass")
	return null
