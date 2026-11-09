## Orquestador de IA enemiga. Itera los behaviors declarados en EnemyData
## y devuelve el primer intent no-null. Si ninguno aplica, usa un intent por defecto.
extends RefCounted
class_name EnemyAI

## Evalúa el patrón de comportamientos (`intent_pattern`) del enemigo según el contexto del turno actual
## y retorna el `EnemyIntent` correspondiente (o un ataque básico de respaldo si ningún behavior aplica).
static func decide_intent(enemy: Enemy, run: RunState, turn_count: int) -> EnemyIntent:
	var context := EnemyContext.new(enemy, run, turn_count)
	
	var data: EnemyData = enemy.data
	if data and data.intent_pattern.size() > 0:
		for behavior in data.intent_pattern:
			if behavior == null:
				continue
			var intent := behavior.decide(context)
			if intent != null:
				return intent
	
	# Fallback: atacar por intent_damage
	return EnemyIntent.new(
		EnemyIntent.Type.ATTACK,
		enemy.get_effective_intent_damage(),
		0,
		"Atacar por %d" % enemy.get_effective_intent_damage()
	)
