## Comportamiento de carga para la IA enemiga.
## Prepara el golpe durante un turno (`CHARGE`) y en el turno siguiente ejecuta un ataque potenciado por `bonus_multiplier`.
extends EnemyBehavior
class_name ChargeBehavior

@export var bonus_multiplier: float = 1.5
@export var every_n_turns: int = 3  # cada 3 turnos: carga, golpea, ataca normal

## Determina la fase del ciclo de carga según `turn_count % every_n_turns`, devolviendo `CHARGE`, el `ATTACK` potenciado o `null`.
func decide(context: EnemyContext) -> EnemyIntent:
	var phase: int = context.turn_count % every_n_turns
	if phase == 0:
		return EnemyIntent.new(EnemyIntent.Type.CHARGE, 0, 0, "Cargando ataque...")
	if phase == 1:
		var bonus_dmg := int(context.enemy.intent_damage * bonus_multiplier)
		return EnemyIntent.new(EnemyIntent.Type.ATTACK, bonus_dmg, 0, "¡Golpe cargado! %d daño" % bonus_dmg)
	return null  # turno normal, lo decide otro behavior
