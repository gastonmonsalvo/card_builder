## Motor matemático sin estado (Stateless) para la curva de nivel y progresión de atributos por run.
## Encapsula las fórmulas polinómicas de XP requerida, recompensas de XP por tipo de sala (`COMBAT`, `ELITE`, `BOSS`),
## escalado aritmético de Vida Máxima con sustain (15%), probabilidad asintótica de Golpe Crítico por Rating
## y multiplicador porcentual de Daño Global.
extends RefCounted
class_name LevelProgression

## Calcula la experiencia requerida (Δ) para avanzar desde `level` hacia `level + 1`:
## XP_Requerida(L) = floor(55 * L^1.45 + 20 * L)
static func get_xp_required_for_next_level(level: int) -> int:
	var eff_level: float = float(max(1, level))
	return int(floor(55.0 * pow(eff_level, 1.45) + 20.0 * eff_level))

## Calcula la recompensa de experiencia otorgada al superar un encuentro según el piso actual (`floor_num`)
## y la categoría de la sala (`COMBAT`, `ELITE`, `BOSS`).
static func get_combat_xp_reward(room_type: int, floor_num: int) -> int:
	var p: float = float(max(1, floor_num))
	var common_xp: int = int(floor(60.0 * (1.0 + 0.35 * p)))
	if room_type == RoomData.Type.BOSS:
		return int(floor(float(common_xp) * 5.0))
	elif room_type == RoomData.Type.ELITE:
		return int(floor(float(common_xp) * 2.5))
	return common_xp

## Otorga experiencia al `run` activo y resuelve automáticamente una o más subidas de nivel.
## Retorna un diccionario con el desglose completo (`xp_gained`, `levels_gained`, `hp_max_gained`, `hp_healed`, etc.).
static func apply_xp_gain(run: RunState, amount: int) -> Dictionary:
	var safe_amount: int = max(0, amount)
	var old_level: int = run.player_level
	var levels_gained: int = 0
	var hp_max_gained: int = 0
	var total_healed: int = 0
	var stat_points_gained: int = 0

	run.player_xp += safe_amount
	run.total_xp_earned += safe_amount

	while run.player_xp >= get_xp_required_for_next_level(run.player_level):
		var req_xp: int = get_xp_required_for_next_level(run.player_level)
		run.player_xp -= req_xp
		run.player_level += 1
		levels_gained += 1

		run.unspent_stat_points += CombatConstants.STAT_POINTS_PER_LEVEL_UP
		stat_points_gained += CombatConstants.STAT_POINTS_PER_LEVEL_UP

		run.max_player_hp += CombatConstants.LEVEL_UP_MAX_HP_BONUS
		hp_max_gained += CombatConstants.LEVEL_UP_MAX_HP_BONUS

		var sustain_target: int = max(1, int(round(float(run.max_player_hp) * CombatConstants.LEVEL_UP_HEAL_RATIO)))
		var actual_heal: int = min(sustain_target, run.max_player_hp - run.player_hp)
		run.player_hp += actual_heal
		total_healed += actual_heal

		SignalBus.player_leveled_up.emit(run.player_level)

	return {
		"xp_gained": safe_amount,
		"levels_gained": levels_gained,
		"stat_points_gained": stat_points_gained,
		"old_level": old_level,
		"new_level": run.player_level,
		"hp_max_gained": hp_max_gained,
		"hp_healed": total_healed,
		"current_xp": run.player_xp,
		"next_level_xp": get_xp_required_for_next_level(run.player_level)
	}

## Devuelve el Rating de Crítico total combinando la base inicial de Nivel 1 (10 pts = ~3.8%)
## más el `bonus_rating` que el jugador haya elegido invertir manualmente al subir de nivel.
static func get_crit_rating(_level: int = 1, bonus_rating: int = 0) -> int:
	return CombatConstants.LEVEL_CRIT_RATING_PER_LEVEL + max(0, bonus_rating)

## Calcula la probabilidad de Golpe Crítico [0.0 .. 0.50] a partir de un Rating de Crítico arbitrario:
## CritChance = (RatingCrit / (RatingCrit + 120)) * 50%
static func get_crit_chance_from_rating(rating_pts: int) -> float:
	var rating: float = float(max(0, rating_pts))
	if rating <= 0.0:
		return 0.0
	return (rating / (rating + CombatConstants.LEVEL_CRIT_ASYMPTOTE_K)) * CombatConstants.LEVEL_CRIT_MAX_CAP

## Calcula la probabilidad de Golpe Crítico [0.0 .. 0.50] mediante curva asintótica protegida.
static func get_crit_chance(level: int = 1, bonus_rating: int = 0) -> float:
	return get_crit_chance_from_rating(get_crit_rating(level, bonus_rating))

## Devuelve el porcentaje de bonificación de daño global aportado por el nivel: (Nivel - 1) * 2%.
static func get_level_damage_bonus_pct(level: int) -> int:
	return max(0, (level - 1) * CombatConstants.LEVEL_DAMAGE_PCT_PER_LEVEL)

## Devuelve el multiplicador escalar de daño saliente aportado por el nivel: 1.0 + ((Nivel - 1) * 2 / 100).
static func get_level_damage_multiplier(level: int) -> float:
	return 1.0 + (float(get_level_damage_bonus_pct(level)) / 100.0)
