## Comportamiento ofensivo periódico para la IA enemiga.
## Emite una intención de ataque directo cada `every_n_turns` turnos.
extends EnemyBehavior
class_name AttackBehavior

@export var damage: int = 8
@export var every_n_turns: int = 1  # 1 = cada turno, 2 = cada 2 turnos, etc.

## Evalúa si el turno actual coincide con la frecuencia `every_n_turns` y construye un `EnemyIntent` de ataque escalado por piso.
func decide(context: EnemyContext) -> EnemyIntent:
	if context.turn_count % every_n_turns != 0:
		return null
	var eff_dmg := damage + (context.enemy.intent_damage - 8)  # respeta escalado de floor
	return EnemyIntent.new(EnemyIntent.Type.ATTACK, eff_dmg, 0, "Atacar por %d" % eff_dmg)
