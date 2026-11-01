extends EnemyBehavior
class_name ChargeBehavior

## Carga un turno (no ataca) y marca al siguiente turno para hacer daño bonus.
@export var bonus_multiplier: float = 1.5
@export var every_n_turns: int = 3  # cada 3 turnos: carga, golpea, ataca normal

func decide(context: EnemyContext) -> EnemyIntent:
	var phase: int = context.turn_count % every_n_turns
	if phase == 0:
		return EnemyIntent.new(EnemyIntent.Type.CHARGE, 0, 0, "Cargando ataque...")
	if phase == 1:
		var bonus_dmg := int(context.enemy.intent_damage * bonus_multiplier)
		return EnemyIntent.new(EnemyIntent.Type.ATTACK, bonus_dmg, 0, "¡Golpe cargado! %d daño" % bonus_dmg)
	return null  # turno normal, lo decide otro behavior
