## Motor estático sin estado (Stateless) que orquesta y resuelve la lógica del combate.
## Evalúa el impacto numérico de los combos y ejecuta secuencialmente las fases del turno 
## tanto para el jugador como para el enemigo.
extends RefCounted
class_name CombatResolver

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

## Ejecuta y descarta de forma aislada una carta clasificada como `single_use/instantánea`
## sin cerrar el turno general.
## Evalúa sus efectos (como robar cartas o ganar oro)
## y la envía directamente al cementerio o descarte tras animarla.
static func consume_instant_card(
	tree: SceneTree,
	card: CardUI,
	board: CardBoardController,
	deck: DeckManager
) -> int:
	board.remove_card(card)
	card.home_position = board.combo_zone.global_position + (board.combo_zone.size * 0.5) - (card.size * 0.5)
	card.pulse()

	var temp_state: Dictionary = {"dmg": 0.0, "block": 0.0, "draw": 0, "burn": 0, "poison": 0, "freeze":0, "shock":0, "hemorrhage":0}
	card.card_data.apply_effects(temp_state)

	await tree.create_timer(0.45).timeout

	deck.route_played_card(card.card_data)
	card.queue_free()
	return int(temp_state["draw"])

## Orquesta la ejecución secuencial asíncrona (de izquierda a derecha) del combo de cartas jugado.
## Actúa como la Única Fuente de Verdad (Single Source of Truth) del combate:
##  despoja a la carta de su auto-ejecución 
## y delega el cálculo duro al motor matemático (`calculate_final_card_damage`).
## Evalúa en tiempo real las sinergias del arma equipada, los atributos RPG del héroe
##  (Fuerza, Inteligencia, Destreza) 
## y aplica penalizaciones u otorgamientos de estados (Veneno, Hemorragia, etc.) según corresponda.
## Además, gestiona el feedback dinámico en el HUD, las animaciones de impacto, las sinergias de reliquias

static func execute_combo_turn(
	tree: SceneTree,
	run: RunState,
	enemy: Enemy,
	board: CardBoardController,
	deck: DeckManager,
	hud: BattleHUD,
	initial_block: int,
	draw_callback: Callable,
	ui_refresh_callback: Callable
) -> int:
	var combo_state: Dictionary = {
		"dmg": 0.0,
		"block": float(initial_block),
		"draw": 0,
		"burn": 0,
		"freeze": 0,
		"poison": 0,
		"shock": 0,
		"hemorrhage": 0
	}
	var current_block: int = initial_block

	# 1. Disparar cada carta del combo secuencialmente de izquierda a derecha
	for card in board.combo_cards:
		if card.card_data:
			var cdata: CardData = card.card_data
			
			var prev_draw: int = combo_state["draw"]
			var prev_burn: int = combo_state["burn"]
			var prev_poison: int = combo_state["poison"]
			var prev_freeze: int = combo_state["freeze"]
			var prev_shock: int = combo_state["shock"]
			var prev_hemorrhage : int = combo_state["hemorrhage"]
			
			card.pulse()
			
			var calc: Dictionary = calculate_final_card_damage(
				cdata, run.current_weapon, run.player_str, run.player_int, run.player_dex
			)
			_apply_card_effects_to_combo(cdata, calc, combo_state)

			enemy.add_statuses(
				combo_state["burn"] - prev_burn, 
				combo_state["poison"] - prev_poison, 
				combo_state["freeze"]- prev_freeze, 
				combo_state["shock"]-prev_shock,
				combo_state["hemorrhage"]-prev_hemorrhage
			)
			
			current_block = int(round(combo_state["block"]))

			var newly_drawn: int = combo_state["draw"] - prev_draw
			if newly_drawn > 0:
				draw_callback.call(newly_drawn)

			ui_refresh_callback.call(current_block)
			
			# HUD Dinámico: Feedback visual inmediato de la penalización
			if calc.msg != "":
				hud.set_banner_message("[ %s ] %s" % [cdata.title, calc.msg]) # Ej: "[ Tajo ] Arma incorrecta: Golpe torpe."
			else:
				hud.set_banner_message("DISPARANDO: [ %s ]" % cdata.title)
				
			await tree.create_timer(0.45).timeout

	# 2. Aplicar sinergias de Reliquias al combo completo y golpear al enemigo
	run.apply_relics_to_combo(combo_state, board.combo_cards.size())
	current_block = int(round(combo_state["block"]))
	enemy.take_damage(int(round(combo_state["dmg"])))
	ui_refresh_callback.call(current_block)

	if not board.combo_cards.is_empty():
		await tree.create_timer(0.35).timeout

	# 3. Enrutar cartas jugadas al Descarte o Cementerio
	for card in board.combo_cards:
		deck.route_played_card(card.card_data)
		card.queue_free()
	board.combo_cards.clear()
	ui_refresh_callback.call(current_block)

	# 4. Tick de Quemadura del enemigo
	var burn_dmg: int = enemy.apply_burn_tick()
	if burn_dmg > 0:
		ui_refresh_callback.call(current_block)
		hud.set_banner_message("LAS LLAMAS QUEMAN AL ENEMIGO POR %d DE DAÑO FIJO!" % burn_dmg)
		await tree.create_timer(1).timeout

	# 5. Tick de Veneno del enemigo
	var poison_dmg: int = enemy.apply_poison_tick()
	if poison_dmg > 0:
		ui_refresh_callback.call(current_block)
		hud.set_banner_message("EL VENENO CONSUME AL ENEMIGO POR %d DE DAÑO FIJO!" % poison_dmg)
		await tree.create_timer(1).timeout
		
	# 5-bis. Tick de Hemorragia
	var hemorrhage_dmg : int = enemy.apply_hemorrhage_tick(run.player_luck)
	if hemorrhage_dmg > 0:
		ui_refresh_callback.call(current_block)
		
		# Verificamos si el enemigo ya tiene acumulados estallidos previos para hacerlo más épico
		if enemy.hemorrhage_proc_count > 0:
			hud.set_banner_message("¡ESTALLIDO DE SANGRE! El enemigo sufre %d de daño por hemorragia." % [ hemorrhage_dmg])
		else:
			hud.set_banner_message("¡HEMORRAGIA! El enemigo se desangra por %d de daño." % hemorrhage_dmg)
			
		await tree.create_timer(1).timeout

	return current_block

## Resuelve la fase de ataque del oponente y la mitigación de daño.
## Evalúa bloqueos absolutos (por Congelamiento severo) y probabilidades de aturdimiento (por Electrocución).
## Si el ataque es efectivo, calcula el daño neto (tras escudo/God Mode).
## Si el daño resulta letal, consulta al `RunState` si alguna reliquia permite revivir.
##  Retorna `true` si el jugador sobrevive al turno.
static func execute_enemy_turn(tree: SceneTree, run: RunState, enemy: Enemy, hud: BattleHUD, player_block: int) -> bool:
	var was_frozen_solid: bool = enemy.freeze >= CombatConstants.FREEZE_STUN_THRESHOLD

	if was_frozen_solid:
		enemy.apply_freeze_tick()
		# Si también tenía shock, decae en 1 sin gastar la descarga
		if enemy.shock > 0:
			enemy.shock -= CombatConstants.STATUS_DECAY_PER_TURN
		hud.set_banner_message("¡ENEMIGO CONGELADO! NO PUDO ATACAR ESTE TURNO.")
	elif enemy.try_trigger_shock_stun(run.player_luck):
		enemy.apply_freeze_tick()
		hud.set_banner_message("¡PARÁLISIS ELÉCTRICA! EL ENEMIGO QUEDÓ ATURDIDO Y FALLÓ SU ATAQUE.")
	else:
		var effective_dmg: int = enemy.get_effective_intent_damage()
		var blocked: int = min(player_block, effective_dmg)
		var net_dmg: int = 0 if run.god_mode else max(0, effective_dmg - player_block)
		run.player_hp = max(0, run.player_hp - net_dmg)

		enemy.apply_freeze_tick()

		if run.god_mode:
			hud.set_banner_message("ENEMIGO ATACA POR %d -> ANULADO POR GOD MODE!" % effective_dmg)
		else:
			hud.set_banner_message("ENEMIGO ATACA POR %d (BLOQUEASTE %d)!" % [effective_dmg, blocked])
	
	if run.is_player_dead():
		var saving_relic: RelicData = run.try_consume_revive_relic()
		if saving_relic:
			hud.set_banner_message("¡[%s] SE ROMPIO Y REVIVISTE CON %d HP!" % [saving_relic.title, run.player_hp])
			await tree.create_timer(1.2).timeout
			return true # Sobrevivió gracias a la reliquia
		else:
			return false # Game Over

	return true # Sobrevivió el turno normalmente
	
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
