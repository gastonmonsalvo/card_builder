## Modelo de datos y lógica que rige al enemigo durante el combate.
## Gestiona sus puntos de vida (HP), su intención de daño base 
## y la acumulación/resolución de estados alterados (Burn, Poison, Freeze, Shock, Hemorrhage).
extends RefCounted
class_name Enemy

var enemy_name: String = "Golem"
var max_hp: int = 120
var current_hp: int = 120

var is_boss : bool = false

## Contadores de acumulación para los cinco estados alterados posibles.
var burn: int = 0
var poison: int = 0
var freeze: int = 0
var shock: int = 0
var hemorrhage: int = 0

## Registra cuántas veces el enemigo ha sufrido una explosión de hemorragia durante este combate.
## Utilizado para escalar la dificultad del próximo estallido.
var hemorrhage_proc_count: int = 0
var intent_damage: int = 12

## Constructor. Recibe la plantilla del enemigo (Resource) y el número de planta
## para calcular los escalados de HP y Daño finales de este encuentro.
func _init(data: EnemyData, current_floor: int) -> void:
	enemy_name = data.enemy_name
	is_boss = data.is_boss
	
	# Escalamos la vida y el daño según la planta actual (usando las fórmulas que ya tenías)
	if is_boss:
		max_hp = data.base_hp + (current_floor - 1) * 45
		intent_damage = data.base_damage + (current_floor - 1) * 4
	else:
		max_hp = data.base_hp + (current_floor - 1) * 25
		intent_damage = data.base_damage + (current_floor - 1) * 3
		
	current_hp = max_hp

## Evalúa si el enemigo ha perdido toda su vida (HP <= 0).
func is_dead() -> bool:
	return current_hp <= 0

## Resta directamente la cantidad de daño especificada de la vida actual (`current_hp`), 
## asegurando mediante un límite inferior que la vida nunca caiga por debajo de 0.
func take_damage(amount: int) -> void:
	if amount > 0:
		current_hp = max(0, current_hp - amount)

## Inyecta y acumula nuevas cargas de estados alterados al enemigo simultáneamente.
## Ignora valores negativos.
func add_statuses(added_burn: int, added_poison: int, added_freeze:int, added_shock:int, added_hemorrhage:int) -> void:
	burn += max(0, added_burn)
	poison += max(0, added_poison)
	freeze += max(0,added_freeze)
	shock += max(0,added_shock)
	hemorrhage +=max(0,added_hemorrhage)
	
## Calcula el daño real que el enemigo infligirá en su turno.
## Si está bajo congelamiento absoluto (`freeze >= umbral`), retorna 0. En caso contrario, mitiga el daño en base a las cargas de `freeze`.
func get_effective_intent_damage() -> int:
	if freeze >= CombatConstants.FREEZE_STUN_THRESHOLD:
		return 0 # Congelado por completo (Stun)
	return max(0, intent_damage - freeze)

## Ejecuta la fase de daño por Quemadura: inflige daño directo igual a las cargas actuales,
## reduce las cargas a la mitad (50% de decaimiento) y retorna el daño infligido.
func apply_burn_tick() -> int:
	if is_dead() or burn <= 0:
		return 0
	var dmg: int = burn
	take_damage(dmg)
	burn = int(burn * 0.5)
	return dmg
	
## Ejecuta la fase de daño por Veneno: inflige daño directo igual a las cargas actuales,
## reduce la acumulación en el valor constante de decaimiento y retorna el daño infligido.
func apply_poison_tick() -> int:
	if is_dead() or poison <= 0:
		return 0
	var dmg: int = poison
	take_damage(dmg)
	poison = max(0, poison - CombatConstants.STATUS_DECAY_PER_TURN)
	return dmg

## Resuelve el estado de Congelamiento al inicio del turno del enemigo.
## Si alcanzó el umbral máximo, lo resetea a 0 (el hielo se rompe). 
## Si está parcialmente congelado, decae sus cargas de forma natural.
func apply_freeze_tick() -> void:
	if freeze >= CombatConstants.FREEZE_STUN_THRESHOLD:
		freeze = 0 # Se rompe el hielo tras cancelar el turno
	elif freeze > 0:
		freeze -= CombatConstants.STATUS_DECAY_PER_TURN

## Calcula la probabilidad porcentual de aturdimiento por electrocución.
## Escala combinando las cargas de `shock` y la estadística de `player_luck`, respetando el límite máximo (cap) establecido.

func get_shock_stun_chance(player_luck) -> float:
	if shock <= 0:
		return 0.0
	var raw_chance: float = (float(shock) * CombatConstants.SHOCK_STUN_CHANCE_PER_STACK) + (float(player_luck) * CombatConstants.SHOCK_LUCK_BONUS_PER_POINT)
	return clamp(raw_chance, 0.05, CombatConstants.SHOCK_MAX_STUN_CHANCE)
	
## Evalúa la activación del daño por Hemorragia en base a un umbral dinámico que crece con cada detonación.
## Si las cargas superan el umbral, detona infligiendo daño porcentual masivo (escalado por suerte) y resetea el contador.
## Si no alcanza el umbral, inflige daño base y aplica un decaimiento severo a las cargas.
func apply_hemorrhage_tick(player_luck) -> int:
	if hemorrhage <= 0:
		return 0
	var dmg: int = 0
	
	#Calculamos el umbral dinámico: base de 10, pero sube +5 por cada sangramiento previo
	var current_threshold: int = CombatConstants.HEMORRHAGE_BURST_THRESHOLD + (hemorrhage_proc_count * CombatConstants.HEMORRHAGE_THRESHOLD_SCALING)
	
	# Verificamos si la acumulación actual supera el umbral que le toca
	# Umbral requerido para activar la hemorragia 
	if hemorrhage >= current_threshold:
			
		# aumentamos el numero de hemorragias 
		hemorrhage_proc_count += 1
		# Cálculo del Porcentaje dinámico: escala suavemente entre el
		# 10% (0.10) y el 25% (0.25) Según la Suerte (techo de 12)
		
		var percentage_multiplier: float = RaritySystem.get_scaled_value_smooth(player_luck, 0.10, 0.25, 12)
		var percentage_dmg: int = int(round(float(current_hp) * percentage_multiplier))
		
		# sumar el daño acumulado normal + el porcentaje? 
		   #damage_dealt = hemorrhage + percentage_damage
		# el porcentaje reemplace/domine el golpe.? Aquí sumamos ambos para que sea devastador:
		dmg =  percentage_dmg
		
		# REDUCIR A 0 | Reducir un poco: hemorrhage -= 5
		hemorrhage = 0 
	
	else:
		dmg = hemorrhage
		
	# Aplicamos el daño a la vida actual del enemigo
	take_damage(dmg)
	
	# Reducimos las cargas de hemorragia por turno de forma natural (decay)
	hemorrhage = max(0, hemorrhage - (CombatConstants.BASE_DISCARDS_PER_COMBAT * 2))
	
	return dmg
	
## Tira los dados para determinar si la electrocución paraliza al enemigo este turno.
## Si acierta, descarga y resetea el `shock` a 0. Si falla, las cargas decaen de forma estándar. Retorna el veredicto.
func try_trigger_shock_stun(player_luck) -> bool:
	if shock <= 0:
		return false
	var chance: float = get_shock_stun_chance(player_luck)
	var stunned: bool = randf() < chance
	if stunned:
		shock = 0 # Descarga completa al paralizar
	else:
		shock = max(0, shock - CombatConstants.STATUS_DECAY_PER_TURN) # Decae en 1 si no se activó
	return stunned
	
## Construye un bloque de texto formateado multilínea para la interfaz gráfica del combate.
## Agrupa y formatea el nombre, HP, intención de daño con mitigación, 
## y lista detalladamente las cargas de todos los estados activos.
func get_status_text(player_luck) -> String:
	if is_dead():
		return "%s DERROTADO (0 / %d HP)" % [enemy_name, max_hp]
	
	var intent_str: String
	if freeze >= CombatConstants.FREEZE_STUN_THRESHOLD:
		intent_str = "¡CONGELADO! (No ataca)"

	elif freeze > 0:
		var eff_dmg: int = get_effective_intent_damage()
		intent_str = "Intencion: %d DMG (-%d por Hielo)" % [eff_dmg, freeze]
		
	else:
		intent_str = "Intencion: %d DMG" % intent_damage

	var text: String = "%s   |   HP: %d / %d   |   %s" % [
		enemy_name, current_hp, max_hp, intent_str
	]
	
	var active_statuses: Array[String] = []
	if burn > 0:
		active_statuses.append("Quemadura: %d" % burn)
	if poison > 0:
		active_statuses.append("Veneno: %d" % poison)
	if hemorrhage >0:
		active_statuses.append("Hemorragia: %d" % hemorrhage)
	if freeze > 0:
		active_statuses.append("Congelamiento: %d/%d" % [freeze, CombatConstants.FREEZE_STUN_THRESHOLD])
	if shock > 0:
		var pct: int = int(round(get_shock_stun_chance(player_luck) * 100.0))
		active_statuses.append("Electrocutado: %d (%d%% Stun)" % [shock, pct])
		
	if not active_statuses.is_empty():
		text += "\nEstados:  %s " % "  |  ".join(active_statuses)
		
	return text
