## Motor estático sin estado (Stateless) que orquesta y resuelve la lógica del combate.
## Evalúa el impacto numérico de los combos y ejecuta secuencialmente las fases del turno 
## tanto para el jugador como para el enemigo.
extends RefCounted
class_name CombatResolver

# ============================================================
# 				MÉTODOS PURAMENTE DE CÁLCULO 
# ============================================================

## Calcula matemáticamente el resultado proyectado de ejecutar las cartas dispuestas en la zona de combo.
## Actúa como un simulador predictivo: itera la cadena de izquierda a derecha delegando la evaluación
##  de cada carta a `calculate_final_card_damage()`.
## Analiza los requisitos del arma equipada, cruza los stats del héroe (Fuerza, Inteligencia, Destreza) 
## para aplicar escalados o penalizaciones,
## e incorpora los estados alterados (veneno, quemadura, etc.) generados tanto por la carta como por el arma.
## Retorna un diccionario plano (Payload) con el pronóstico absoluto para refrescar el `BattleHUD` 
## en vivo sin alterar el estado real del juego.
static func calculate_sequential_preview(combo_cards: Array, run: RunState) -> Dictionary:
	var combo_state: Dictionary = {
		"dmg": 0.0,
		"block": 0.0,
		"draw": 0,
		"burn": 0,
		"freeze": 0,
		"poison": 0,
		"shock": 0,
		"hemorrhage": 0
	}

	for card_node in combo_cards:
		var card_data: CardData = card_node.card_data
		if not card_data:
			continue

		var calc: Dictionary = calculate_final_card_damage(
			card_data,
			run.current_weapon,
			run.player_str,
			run.player_int,
			run.player_dex
		)
		_apply_card_effects_to_combo(card_data, calc, combo_state)

	run.apply_relics_to_combo(combo_state, combo_cards.size())
	return {
		"dmg": int(round(combo_state["dmg"])),
		"block": int(round(combo_state["block"])),
		"draw": int(combo_state["draw"]),
		"burn": int(combo_state["burn"]),
		"poison": int(combo_state["poison"]),
		"freeze": int(combo_state["freeze"]),
		"shock": int(combo_state["shock"]),
		"hemo": int(combo_state["hemorrhage"])
	}

## Calcula el daño base de la carta y aplica las bonificaciones/penalizaciones del arma.
## Los demás efectos de CardData se procesan por separado en `_apply_card_effects_to_combo`.
static func calculate_final_card_damage(
	card: CardData,
	current_weapon: WeaponData,
	h_str: int,
	h_int: int,
	h_dex: int
) -> Dictionary:
	var card_base_damage: int = 0
	for effect in card.effects:
		if effect is DamageEffect:
			card_base_damage += effect.amount

	var accepts_any_weapon: bool = card.required_weapon_class.is_empty() \
		or card.required_weapon_class.has(WeaponData.Class.ANY)
	var weapon_matches: bool = accepts_any_weapon
	if not accepts_any_weapon:
		weapon_matches = current_weapon != null and card.required_weapon_class.has(current_weapon.weapon_class)

	if not weapon_matches:
		return {
			"final_damage": card.fallback_damage,
			"apply_status": false,
			"bonus_poison": 0,
			"bonus_burn": 0,
			"bonus_hemo": 0,
			"bonus_shock": 0,
			"msg": "Arma incorrecta: Golpe torpe."
		}

	var final_damage: int = card_base_damage
	var bonus_poison: int = 0
	var bonus_burn: int = 0
	var bonus_hemo: int = 0
	var bonus_shock: int = 0
	var stat_deficit: int = 0

	if current_weapon and card.uses_weapon_damage:
		final_damage += current_weapon.base_damage
		final_damage += current_weapon.get_scaling_bonus(h_str, h_int, h_dex)
		bonus_poison = current_weapon.inflict_poison
		bonus_burn = current_weapon.inflict_burn
		bonus_hemo = current_weapon.inflict_hemorrhage
		bonus_shock = current_weapon.inflict_shock
		stat_deficit = current_weapon.get_stat_deficit(h_str, h_int, h_dex)

	if stat_deficit > 0:
		var penalty_pct: float = min(1.0, stat_deficit * 0.25)
		final_damage = int(floor(final_damage * (1.0 - penalty_pct)))
		return {
			"final_damage": max(1, final_damage),
			"apply_status": false,
			"bonus_poison": 0,
			"bonus_burn": 0,
			"bonus_hemo": 0,
			"bonus_shock": 0,
			"msg": "Stats insuficientes: Penalización de daño y anulación de efectos."
		}

	return {
		"final_damage": final_damage,
		"apply_status": true,
		"bonus_poison": bonus_poison,
		"bonus_burn": bonus_burn,
		"bonus_hemo": bonus_hemo,
		"bonus_shock": bonus_shock,
		"msg": ""
	}

## Aplica los efectos de una carta respetando el orden del combo.
## DamageEffect se contabiliza con el cálculo del arma; los estados se anulan si el arma no es apta.
static func _apply_card_effects_to_combo(card: CardData, calc: Dictionary, combo_state: Dictionary) -> void:
	var damage_was_added: bool = false

	for effect in card.effects:
		if not effect:
			continue

		if effect is DamageEffect:
			if not damage_was_added:
				combo_state["dmg"] += calc.final_damage
				damage_was_added = true
			continue

		if _is_status_effect(effect) and not calc.apply_status:
			continue

		effect.apply(combo_state)

	# Cartas sin DamageEffect pueden tener daño aportado únicamente por el arma.
	if not damage_was_added:
		combo_state["dmg"] += calc.final_damage

	if calc.apply_status:
		combo_state["poison"] += calc.get("bonus_poison", 0)
		combo_state["burn"] += calc.get("bonus_burn", 0)
		combo_state["hemorrhage"] += calc.get("bonus_hemo", 0)
		combo_state["shock"] += calc.get("bonus_shock", 0)

## Identifica los efectos de estado que dependen de que el arma se use correctamente.
static func _is_status_effect(effect: CardEffect) -> bool:
	return effect is BurnEffect \
		or effect is PoisonEffect \
		or effect is FreezeEffect \
		or effect is ShockEffect \
		or effect is HemorrhageEffect


# ============================================================
#  		extracción de la lógica de execute_combo_turn
# Cada uno hace UNA cosa y es puro (sin UI, sin await)
# ============================================================

## Procesa UNA carta del combo. Retorna los deltas para que la escena los aplique.
static func process_card_in_combo(
	card_data: CardData, 
	run: RunState, 
	combo_state: Dictionary
) -> Dictionary:
	var prev := {
		"burn": combo_state["burn"],
		"poison": combo_state["poison"],
		"freeze": combo_state["freeze"],
		"shock": combo_state["shock"],
		"hemorrhage": combo_state["hemorrhage"],
		"draw": combo_state["draw"],
	}
	
	var calc := calculate_final_card_damage(
		card_data, run.current_weapon, 
		run.player_str, run.player_int, run.player_dex
	)
	_apply_card_effects_to_combo(card_data, calc, combo_state)
	
	return {
		"calc": calc,
		"burn_delta": combo_state["burn"] - prev["burn"],
		"poison_delta": combo_state["poison"] - prev["poison"],
		"freeze_delta": combo_state["freeze"] - prev["freeze"],
		"shock_delta": combo_state["shock"] - prev["shock"],
		"hemorrhage_delta": combo_state["hemorrhage"] - prev["hemorrhage"],
		"draw_delta": combo_state["draw"] - prev["draw"],
		"block": int(round(combo_state["block"])),
		"title": card_data.title,
		"msg": calc.msg,
	}

## Aplica reliquias finales y daño al enemigo. Retorna block final.
static func finalize_combo(
	run: RunState, 
	combo_state: Dictionary, 
	enemy: Enemy, 
	combo_size: int
) -> int:
	run.apply_relics_to_combo(combo_state, combo_size)
	var current_block := int(round(combo_state["block"]))
	enemy.take_damage(int(round(combo_state["dmg"])))
	return current_block

## Aplica los ticks de fin de turno. Retorna un dict con los daños por status.
static func tick_enemy_statuses(enemy: Enemy, run: RunState) -> Dictionary:
	return {
		"burn": enemy.apply_burn_tick(),
		"poison": enemy.apply_poison_tick(),
		"hemorrhage": enemy.apply_hemorrhage_tick(run.player_luck),
		"hemorrhage_proc_count": enemy.hemorrhage_proc_count,
	}

## Resuelve el ataque enemigo. Retorna resultado puro (sin HUD ni animaciones).
static func resolve_enemy_turn(
	run: RunState, 
	enemy: Enemy, 
	player_block: int
) -> Dictionary:
	var was_frozen_solid := enemy.freeze >= CombatConstants.FREEZE_STUN_THRESHOLD
	var shocked := false
	var effective_dmg := 0
	var blocked := 0
	var net_dmg := 0
	var saving_relic: RelicData = null
	
	if was_frozen_solid:
		enemy.apply_freeze_tick()
		if enemy.shock > 0:
			enemy.shock -= CombatConstants.STATUS_DECAY_PER_TURN
	elif enemy.try_trigger_shock_stun(run.player_luck):
		enemy.apply_freeze_tick()
		shocked = true
	else:
		effective_dmg = enemy.get_effective_intent_damage()
		blocked = min(player_block, effective_dmg)
		net_dmg = 0 if run.god_mode else max(0, effective_dmg - player_block)
		run.player_hp = max(0, run.player_hp - net_dmg)
		enemy.apply_freeze_tick()
	
	var player_survives := true
	if run.is_player_dead():
		saving_relic = run.try_consume_revive_relic()
		player_survives = saving_relic != null
	
	var outcome := "frozen" if was_frozen_solid else ("shocked" if shocked else "attack")
	
	return {
		"outcome": outcome,
		"effective_dmg": effective_dmg,
		"blocked": blocked,
		"net_dmg": net_dmg,
		"player_survives": player_survives,
		"saving_relic": saving_relic,
		"frozen_solid": was_frozen_solid,
		"shocked": shocked,
	}

## Calcula el resultado de consumir una carta instantánea, sin tocar UI.
static func calculate_instant_card(card_data: CardData) -> Dictionary:
	var temp_state: Dictionary = {
		"dmg": 0.0, "block": 0.0, "draw": 0,
		"burn": 0, "poison": 0, "freeze": 0, "shock": 0, "hemorrhage": 0
	}
	card_data.apply_effects(temp_state)
	return temp_state
