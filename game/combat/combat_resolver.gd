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
	var p_dmg: int = 0
	var p_block: int = 0
	var p_draw: int = 0
	
	# Variables para estados (incluyendo los del arma)
	var p_burn: int = 0
	var p_poison: int = 0
	var p_hemo: int = 0
	var p_shock: int = 0

	for card_node in combo_cards:
		var cdata: CardData = card_node.card_data
		if not cdata: continue
		
		# 1. EVALUAMOS EL DAÑO Y LOS ESTADOS REALES
		var calc = calculate_final_card_damage(cdata, run.current_weapon, run.player_str, run.player_int, run.player_dex)
		
		# 2. Sumamos el daño procesado
		p_dmg += calc.final_damage
		p_block += cdata.block # El escudo suele ser independiente del arma
		p_draw += cdata.draw_cards
		
		# 3. Sumamos los estados SOLO si la evaluación dice que es apto
		if calc.apply_status:
			# Sumamos lo que trae el arma (calculado) + lo que trae la carta base
			p_burn += calc.bonus_burn + cdata.burn
			p_poison += calc.bonus_poison + cdata.poison
			p_hemo += calc.bonus_hemo + cdata.hemorrhage
			p_shock += calc.bonus_shock + cdata.shock

	return {
		"dmg": p_dmg, "block": p_block, "draw": p_draw,
		"burn": p_burn, "poison": p_poison, "hemo": p_hemo, "shock": p_shock
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
			
			# --- NUEVO MOTOR DE ARMAS Y STATS ---
			# Borramos el 'apply_effects()'. Ahora el Resolver manda.
			var calc: Dictionary = calculate_final_card_damage(
				cdata, run.current_weapon, run.player_str, run.player_int, run.player_dex
			)
			
			# Sumamos daño, escudo y robo calculados
			combo_state["dmg"] += calc.final_damage
			combo_state["block"] += cdata.block 
			combo_state["draw"] += cdata.draw_cards
			
			# Sumamos estados alterados SOLO si el héroe supo usar el arma (apply_status = true)
			if calc.apply_status:
				combo_state["burn"] += calc.get("bonus_burn", 0) + cdata.burn
				combo_state["poison"] += calc.get("bonus_poison", 0) + cdata.poison
				combo_state["freeze"] += calc.get("bonus_freeze", 0) + cdata.freeze
				combo_state["shock"] += calc.get("bonus_shock", 0) + cdata.shock
				combo_state["hemorrhage"] += calc.get("bonus_hemo", 0) + cdata.hemorrhage
			# ------------------------------------

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
	
## Calcula el daño real final de una carta basándose en el arma equipada y los stats del héroe.
static func calculate_final_card_damage(card: CardData, current_weapon: WeaponData, h_str: int, h_int: int, h_dex: int) -> Dictionary:
	
	# 1. FALLBACK: Chequear si tiene el tipo de arma correcta
	# Primero validamos si la carta NO acepta ANY.
	if not card.required_weapon_class.has(WeaponData.Class.ANY):
		# Si no acepta ANY, chequeamos si el arma actual del jugador está en la lista permitida
		if not card.required_weapon_class.has(current_weapon.weapon_class):
			# Tiene el arma equivocada. Penalidad extrema. Carta inútil.
			return {
				"final_damage": card.fallback_damage,
				"apply_status": false,
				"bonus_poison": 0, "bonus_burn": 0, "bonus_hemo": 0, "bonus_shock": 0,
				"msg": "Arma incorrecta: Golpe torpe."
			}
	
	# 2. Tiene el arma correcta. Evaluamos si el arma aporta daño y estados a esta carta.
	var calc_dmg: int = card.base_damage
	
	# Preparamos el payload de estados inyectados por el arma
	var w_poison: int = 0
	var w_burn: int = 0
	var w_hemo: int = 0
	var w_shock: int = 0

	if card.uses_weapon_damage:
		var bonus_stats: int = current_weapon.get_scaling_bonus(h_str, h_int, h_dex)
		calc_dmg += current_weapon.base_damage + bonus_stats
		
		# Extraemos los estados innatos del arma
		w_poison = current_weapon.inflict_poison
		w_burn = current_weapon.inflict_burn
		w_hemo = current_weapon.inflict_hemorrhage
		w_shock = current_weapon.inflict_shock
		
	# 3. PENALIZACIÓN POR STATS
	var deficit: int = current_weapon.get_stat_deficit(h_str, h_int, h_dex)
	var can_apply_status: bool = true
	
	if deficit > 0:
		var penalty_pct: float = min(1.0, deficit * 0.25)
		calc_dmg = int(floor(calc_dmg * (1.0 - penalty_pct)))
		can_apply_status = false # NO CUMPLE REQUISITOS -> NO APLICA NINGÚN EFECTO
		
		return {
			"final_damage": max(1, calc_dmg),
			"apply_status": false,
			# Mandamos los estados en CERO porque no supo usar el arma
			"bonus_poison": 0, "bonus_burn": 0, "bonus_hemo": 0, "bonus_shock": 0,
			"msg": "Stats insuficientes: Penalización de daño y anulación de efectos."
		}

	# 4. USO PERFECTO
	return {
		"final_damage": calc_dmg,
		"apply_status": true,
		# Mandamos el payload del arma para que se sume a lo que ya haga la carta
		"bonus_poison": w_poison, 
		"bonus_burn": w_burn, 
		"bonus_hemo": w_hemo, 
		"bonus_shock": w_shock,
		"msg": ""
	}
