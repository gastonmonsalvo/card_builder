## Motor estático sin estado (Stateless) que orquesta y resuelve la lógica del combate.
## Evalúa el impacto numérico de los combos y ejecuta secuencialmente las fases del turno 
## tanto para el jugador como para el enemigo.
extends RefCounted
class_name CombatResolver

## Calcula matemáticamente el resultado proyectado de jugar las cartas actualmente
## dispuestas en la zona de combo.
## Evalúa la cadena de efectos de izquierda a derecha y suma las sinergias de reliquias, 
## devolviendo un diccionario plano con el pronóstico final (usado para actualizar la UI en vivo).
static func calculate_sequential_preview(combo_cards: Array[CardUI], run: RunState) -> Dictionary:
	var combo_state: Dictionary = {
		"dmg": 0.0,
		"block": 0.0,
		"draw": 0,
		"burn": 0,
		"freeze": 0,
		"poison": 0,
		"shock" : 0,
		"hemorrhage":0
	}
	for card in combo_cards:
		if card.card_data:
			card.card_data.apply_effects(combo_state)
	run.apply_relics_to_combo(combo_state, combo_cards.size())
	return {
		"dmg": int(round(combo_state["dmg"])),
		"block": int(round(combo_state["block"])),
		"draw": int(combo_state["draw"]),
		"burn": int(combo_state["burn"]),
		"poison": int(combo_state["poison"]),
		"freeze":int(combo_state["freeze"]),
		"shock:":int(combo_state["shock"]),
		"hemorrhage":int(combo_state["hemorrhage"])
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

## Corrutina principal de resolución del turno del jugador.
## 1. Dispara secuencialmente las cartas del combo aplicando sus efectos, animándolas y 
## depositándolas en las pilas.
## 2. Inyecta el daño global al enemigo y recalcula el escudo del jugador.
## 3. Aplica los ticks de daño progresivos de los estados del enemigo (Quemadura, Veneno, Hemorragia).
## Retorna la cantidad de escudo final con el que el jugador esperará el ataque enemigo.

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
			var prev_draw: int = combo_state["draw"]
			var prev_burn: int = combo_state["burn"]
			var prev_poison: int = combo_state["poison"]
			var prev_freeze: int = combo_state["freeze"]
			var prev_shock: int = combo_state["shock"]
			var prev_hemorrhage : int = combo_state["hemorrhage"]
			
			card.pulse()
			card.card_data.apply_effects(combo_state)

			enemy.add_statuses(
				combo_state["burn"] - prev_burn, 
			combo_state["poison"] - prev_poison, 
			combo_state["freeze"]- prev_freeze, 
			combo_state["shock"]-prev_shock,
			combo_state["hemorrhage"]-prev_hemorrhage)
			
			current_block = int(round(combo_state["block"]))

			var newly_drawn: int = combo_state["draw"] - prev_draw
			if newly_drawn > 0:
				draw_callback.call(newly_drawn)

			ui_refresh_callback.call(current_block)
			hud.set_banner_message("DISPARANDO: [ %s ]" % card.card_data.title)
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
