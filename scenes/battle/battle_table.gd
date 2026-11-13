## Controlador principal y fachada visual de la escena de combate (`battle_table.tscn`).
## Actúa como intermediario (Facade) coordinando el ciclo de turnos entre el tablero físico de cartas
## (`CardBoardController`), el mazo en memoria (`DeckManager`), el resolutor matemático (`CombatResolver`) 
## y la interfaz (`BattleHUD`).

extends Control

## Emitida cuando la salud del enemigo (`current_hp`) llega a cero o menos tras la ejecución de un combo.
signal combat_won()
## Emitida cuando la salud del jugador (`player_hp`) llega a cero o menos tras el turno de ataque enemigo.
signal combat_lost()

@onready var combo_zone: Panel = $ComboZone
@onready var hand_zone: Panel = $HandZone
@onready var attack_button: Button = $AttackButton
@onready var discard_button: Button = $DiscardButton
@onready var hud: BattleHUD = $HUD
@onready var ability_button: Button = $AbilityButton

var run: RunState = RunState.new()
var deck: DeckManager = DeckManager.new()
var board: CardBoardController = null
var director: RunDirector = null
var enemy: Enemy

## Indica si la mesa se encuentra en medio de una transición de turno o animación.
## Mientras sea true, se bloquean las cartas, los botones y la apertura del menú de pausa.
var is_resolving: bool = false:
	set(value):
		is_resolving = value
		if board:
			board.is_locked = value

## Cantidad de puntos de energía disponibles para gastar en el turno actual. 
## Se reinicia al máximo (`max_energy`) al comienzo de cada ronda.
var current_energy: int = CombatConstants.BASE_MAX_ENERGY

##Cantidad de energia libre en este turno (modificadores)
var energy_free_this_turn: bool = false

## Cantidad de descartes tácticos restantes permitidos para el encuentro actual.
## Se restablece al inicio del combate.
var discards_remaining: int = CombatConstants.BASE_DISCARDS_PER_COMBAT
## Escudo físico temporal acumulado por el jugador en el turno actual.
## Absorbe el daño enemigo antes que los HP y se purga al iniciar la siguiente ronda.
var player_block: int = 0

## Inicializa las clases de negocio enlazándolas con los nodos visuales inyectados (`hand_zone`, `combo_zone`).
## Conecta los eventos del tablero y de los botones de acción, y configura el `RunDirector`. 
## Si el entorno es un build de depuración, superpone el `DebugOverlay`.
func _ready() -> void:
	board = CardBoardController.new(hand_zone, combo_zone)
	board.card_clicked.connect(_on_board_card_clicked)
	board.card_dropped.connect(_on_board_card_dropped)
	board.board_order_changed.connect(refresh_ui)

	attack_button.pressed.connect(_on_attack_pressed)
	discard_button.pressed.connect(_on_discard_pressed)
	hud.bind_piles(deck.draw_pile, deck.discard_pile, deck.graveyard_pile)
	hud.equipment_changed.connect(refresh_ui)


	director = RunDirector.new(self, run)
	hud.bind_run_reference(run)

	if OS.is_debug_build():
		var debug_overlay := DebugOverlay.new()
		add_child(debug_overlay)
		debug_overlay.bind_context(self, run, director)
	if ability_button:
		ability_button.pressed.connect(_on_ability_pressed)
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	# El juego arranca sin enemigo; los botones de combate deben iniciar desactivados.
	refresh_ui()

## Recalcula el layout espacial de las cartas cuando cambia el tamaño de la ventana.
func _on_viewport_size_changed() -> void:
	if board:
		board.layout_cards.call_deferred()

# --- INICIO DE COMBATE Y TURNOS ---
## Resetea el tablero físico recolectando cualquier carta sobrante, ordena al `DeckManager` 
## que baraje el mazo para el nuevo encuentro,
## instancia al enemigo vivo a través del `RunState` y dispara el primer turno del combate.
func start_combat_encounter(is_boss: bool) -> void:
	if board == null or deck == null or run == null:
		push_error("[BattleTable] No se puede iniciar el combate: faltan dependencias.")
		return
		
	is_resolving = false
	attack_button.disabled = false
	discard_button.disabled = true
	discards_remaining = 99 if run.god_mode else run.discards_per_combat
	#limpiar mods del combate anterior
	run.temp_stats.clear()
	#Resetea el rng
	run.reset_combat_rng()
	var remaining_board_cards: Array[CardData] = board.clear_all_and_extract_data()
	deck.reset_for_new_combat(remaining_board_cards)
	
		# Resetear usos de la habilidad del héroe
	if run.current_ability:
		run.current_ability.reset_for_combat()
	
	enemy = run.create_enemy_for_room(is_boss)
	if enemy == null:
		push_error("[BattleTable] No se pudo crear el enemigo para este encuentro.")
		refresh_ui()
		return
	#Escuchar reacciones elementales del enemigo
	enemy.status_reaction_triggered.connect(_on_enemy_reaction)
	
	_start_new_turn()
## Orquesta el inicio de ronda para el jugador. 
## Pone el escudo en 0, restaura la energía al máximo y calcula matemáticamente 
## cuántas cartas le faltan a la mano física para alcanzar el `target_hand_size`, robándolas desde el mazo.
func _start_new_turn() -> void:
	current_energy = 99 if run.god_mode else run.max_energy
	player_block = 0

	var needed: int = max(0, run.target_hand_size - board.hand_cards.size())
	if needed > 0:
		draw_cards(needed)
	
	board.layout_cards()
	
	if enemy:
		enemy.update_intent(run)   # recalcular intent para este turno
	
	refresh_ui()
	
## Intermediario de robo. Solicita un conjunto de datos `CardData` vírgenes al `DeckManager` 
## e instruye al `CardBoardController` que instancie sus nodos 2D equivalentes en la zona de la mano.
func draw_cards(amount: int) -> void:
	if amount <= 0 or deck == null or board == null:
		return
	var drawn_data: Array[CardData] = deck.draw_cards_data(amount)
	board.spawn_cards_to_hand(drawn_data)

# --- INTERACCION CON CARTAS EN LA MESA ---
## Evalúa si la carta clickeada posee el atributo "Instantánea" (se consumen directamente sin pasar por el combo).
## Si hay energía disponible, debita su costo, delega la ejecución de su efecto al `CombatResolver` 
## y detiene el flujo de arrastre devolviendo `true`.
func _try_consume_instant_card(card: CardUI) -> bool:
	if card == null or not is_instance_valid(card) or card.card_data == null or not card.card_data.is_instant_card():
		return false
		
	var card_cost: int = 0 if energy_free_this_turn else card.card_data.cost

	if current_energy < card_cost:
		board.layout_cards()
		refresh_ui()
		hud.set_banner_message("SIN ENERGIA! Necesitas %d y tienes %d/%d" % [card_cost, current_energy, run.max_energy])
		return true

	is_resolving = true
	# Solo descontar si no está en modo free
	if not energy_free_this_turn:  
		current_energy -= card_cost
		
	refresh_ui() # Deshabilita atacar/descartar durante la animación de la carta instantánea.

	var title: String = card.card_data.title
	var cards_drawn: int = await consume_instant_card(card)  # ← sin get_tree() como parámetro
	if cards_drawn > 0:
		draw_cards(cards_drawn)

	is_resolving = false
	refresh_ui()
	hud.set_banner_message("USASTE [%s] -> ROBASTE +%d CARTA(S) (SIGUE TU TURNO)" % [title, cards_drawn])
	return true
	
## Callback disparado al hacer clic (no arrastrar) sobre una carta. Si la carta estaba en la mano, 
## intenta aplicarla como instantánea o la sube a la zona de combo si la energía lo permite. 
## Si ya estaba en la zona de combo, la devuelve a la mano reembolsando su costo.
func _on_board_card_clicked(card: CardUI) -> void:
	if is_resolving or enemy == null or enemy.is_dead() or run.is_player_dead():
		return
	if card == null or not is_instance_valid(card) or card.card_data == null:
		return
	if board.is_in_hand(card):
		if await _try_consume_instant_card(card):
			return
		var cost: int = 0 if energy_free_this_turn else card.card_data.cost 
		if current_energy >= cost or energy_free_this_turn:
			if not energy_free_this_turn:
				current_energy -= cost
			board.move_to_combo(card, false)
			refresh_ui()
		else:
			hud.set_banner_message("SIN ENERGIA! Necesitas %d y tienes %d/%d" % [cost, current_energy, run.max_energy])
	elif board.is_in_combo(card):
		var cost: int = card.card_data.cost if card.card_data else 1
		if not energy_free_this_turn:
			current_energy += cost
		board.move_to_hand(card, false)
		refresh_ui()
		
## Callback disparado al soltar una carta tras un arrastre manual (Drag & Drop). 
## Valida matemáticamente si el jugador posee la energía necesaria para soltarla en la zona de combo. 
## Si no le alcanza, rechaza el movimiento (rollback) y devuelve la carta a la mano.
func _on_board_card_dropped(card: CardUI, dropped_in_combo: bool) -> void:
	if is_resolving or enemy == null or enemy.is_dead() or run.is_player_dead():
		if board and card and is_instance_valid(card):
			board.layout_cards()
		return
	if card == null or not is_instance_valid(card) or card.card_data == null:
		return
	var cost: int = card.card_data.cost
	var rejected_by_energy: bool = false

	if dropped_in_combo:
		if await _try_consume_instant_card(card):
			return
		if not board.is_in_combo(card):
			var effective_cost: int = 0 if energy_free_this_turn else cost
			if current_energy >= effective_cost or energy_free_this_turn:
				if not energy_free_this_turn:
					current_energy -= effective_cost
				board.move_to_combo(card, true)
			else:
				rejected_by_energy = true
				board.layout_cards()
		else:
			board.layout_cards()
	else:
		if board.is_in_combo(card):
			if not energy_free_this_turn:
				current_energy += cost
			board.move_to_hand(card, true)
		else:
			board.layout_cards()

	refresh_ui()
	if rejected_by_energy:
		hud.set_banner_message("SIN ENERGIA! Necesitas %d y tienes %d/%d" % [cost, current_energy, run.max_energy])

# --- BOTONES DE COMBATE (DESCARTAR Y EJECUTAR TURNO) ---

## Ejecuta la acción táctica de descarte. Mueve todas las cartas temporalmente alojadas en la zona de combo
## hacia el pozo de descarte, devuelve la energía reservada al total del turno, 
## descuenta una ficha de descarte y roba inmediatamente la misma cantidad de cartas para reemplazarlas.
func _on_discard_pressed() -> void:
	if is_resolving or enemy == null or enemy.is_dead() or run.is_player_dead():
		return
	if discards_remaining <= 0:
		hud.set_banner_message("NO TE QUEDAN DESCARTES EN ESTE COMBATE!")
		return
	if board.combo_cards.is_empty():
		hud.set_banner_message("Sube primero a la Zona de Combo las cartas que quieras descartar")
		return

	discards_remaining -= 1
	var count_discarded: int = board.combo_cards.size()

	for card in board.combo_cards:
		var cost: int = card.card_data.cost if card.card_data else 1
		current_energy += cost
		deck.discard_card(card.card_data)
		card.queue_free()
	board.combo_cards.clear()

	draw_cards(count_discarded)
	refresh_ui()
	hud.set_banner_message("DESCARTASTE %d CARTA(S) Y ROBASTE REEMPLAZOS!" % count_discarded)
	
## Ejecuta la fase de resolución (End Turn). Bloquea la mesa (`is_resolving`),
##  invoca la corrutina asíncrona del `CombatResolver` para animar las cartas secuencialmente 
## y aplicar el daño. Si el enemigo sobrevive, invoca su turno de ataque de respuesta antes de
##  iniciar la siguiente ronda. Emite `combat_won` o `combat_lost` según corresponda.
func _on_attack_pressed() -> void:
	if is_resolving or enemy == null or enemy.is_dead() or run.is_player_dead():
		return

	is_resolving = true
	attack_button.disabled = true
	discard_button.disabled = true

	# 1. Ejecutar turno del jugador
	player_block = await execute_combo_turn(run, enemy, player_block)

	# 2. Verificar si el enemigo murió por el combo
	if enemy.is_dead():
		refresh_ui()
		hud.set_banner_message("🏆 ¡ENEMIGO DERROTADO!")
		await get_tree().create_timer(0.75).timeout
		is_resolving = false
		attack_button.disabled = true
		discard_button.disabled = true
		combat_won.emit()
		return

	refresh_ui() # Refresca por si hubo cambios de stats antes del golpe enemigo
	await get_tree().create_timer(0.55).timeout

	# 3. Ejecutar turno del enemigo
	var survived: bool = await execute_enemy_turn(run, enemy, player_block)
	
	if not survived:
		is_resolving = false          # ← NUEVO: liberar la mesa
		attack_button.disabled = true
		discard_button.disabled = true
		refresh_ui()
		combat_lost.emit()
		return

	# 4. Fin de ronda y preparación del siguiente turno
	await get_tree().create_timer(1.0).timeout
	_start_new_turn()
	attack_button.disabled = false
	is_resolving = false
	refresh_ui()
	
## Purga por completo el estado efímero del tablero (útil al abandonar una partida o escapar).
## Elimina los nodos físicos de las cartas en mano y en combo, y resetea contadores temporales.
func clear_board_visuals() -> void:
	is_resolving = false
	if board:
		board.clear_all_nodes()
	player_block = 0
	discards_remaining = run.discards_per_combat if run else CombatConstants.BASE_DISCARDS_PER_COMBAT
	current_energy = run.max_energy if run else CombatConstants.BASE_MAX_ENERGY
	attack_button.disabled = true
	discard_button.disabled = true
	
## Actualiza el estado visual completo de la interfaz de usuario en la mesa de combate.
## Refresca botones, etiquetas, contadores y las estadísticas del jugador y enemigo en el HUD.
## Omite el cálculo del preview si hay una resolución de combo en curso para preservar los mensajes del banner.
func refresh_ui() -> void:
	if board == null or run == null or hud == null:
		return

	# Estado y texto del botón de habilidad activa del héroe
	if ability_button and run.current_ability:
		ability_button.text = run.current_ability.get_hud_text()
		ability_button.disabled = not run.current_ability.can_activate() or is_resolving

	# Si estamos resolviendo el combo, no recalculamos el preview para mantener el banner actual
	if not is_resolving:
		var preview: Dictionary = CombatResolver.calculate_sequential_preview(board.combo_cards, run)
		hud.refresh_all(run.player_hp, player_block, current_energy, run.max_energy, enemy, preview, run.max_player_hp, run.player_luck)
	else:
		# Durante la resolución se envían los stats actualizados pero con preview vacío
		hud.refresh_all(run.player_hp, player_block, current_energy, run.max_energy, enemy, {}, run.max_player_hp, run.player_luck)

	discard_button.text = "DESCARTAR (%d)" % discards_remaining

	var encounter_active: bool = enemy != null and not enemy.is_dead() and not run.is_player_dead()
	attack_button.text = "EJECUTAR COMBO" if not board.combo_cards.is_empty() else "PASAR TURNO"
	attack_button.disabled = not encounter_active or is_resolving
	discard_button.disabled = not encounter_active or is_resolving or discards_remaining <= 0 or board.combo_cards.is_empty()

## Atrapa eventos de teclado/controlador globales no consumidos por los botones físicos de la UI 
## (ej. presionar la tecla ESC). Delega esta señal al `RunDirector` para gestionar el menú de pausa sin acoplar lógicas en la mesa de combate.
func _unhandled_input(event: InputEvent) -> void:
	if director:
		director.handle_unhandled_key(event)



# =============================================================================
#  ORQUESTACIÓN DE TURNOS — UI + ANIMACIONES
#  La lógica pura vive en CombatResolver. Acá solo orquestamos la vista.
# =============================================================================

## Orquesta la ejecución secuencial asíncrona del combo de cartas jugado.
## Llama a `CombatResolver` para la lógica pura y maneja la UI + animaciones entre medio.
## Retorna el block final acumulado.
func execute_combo_turn(p_run: RunState, p_enemy: Enemy, p_initial_block: int) -> int:
	var combo_state: Dictionary = CombatResolver.create_empty_combo_state(run, float(p_initial_block))
	var current_block: int = p_initial_block

	# 1. Procesar cada carta del combo (lógica + UI intercaladas)
	for card in board.combo_cards:
		if not card.card_data:
			continue
		
		var cdata: CardData = card.card_data
		card.pulse()  # UI
		
		# LÓGICA: delegar al resolver
		var delta: Dictionary = CombatResolver.process_card_in_combo(cdata, run, combo_state)
		
		# UI: robar cartas nuevas
		if delta["draw_delta"] > 0:
			draw_cards(delta["draw_delta"])
		
		# UI: actualizar block
		current_block = delta["block"]
		player_block = current_block
		refresh_ui()
		
		# UI: mensaje en el banner
		if delta["msg"] != "":
			hud.set_banner_message("[ %s ] %s" % [delta["title"], delta["msg"]])
		else:
			hud.set_banner_message("DISPARANDO:  %s " % delta["title"])
		
		await get_tree().create_timer(0.65).timeout

	# 2. Finalizar combo (lógica pura: reliquias + bono de nivel + tirada de crítico x1.5 en D100)
	current_block = CombatResolver.finalize_combo(run, combo_state, enemy, board.combo_cards.size())
	player_block = current_block

	if bool(combo_state.get("crit_rolled", false)):
		await hud.play_crit_dice_roll(combo_state, refresh_ui)
	else:
		refresh_ui()
		if not board.combo_cards.is_empty():
			await get_tree().create_timer(0.35).timeout

	# 3. Ruteo al descarte (UI + deck state)
	for card in board.combo_cards:
		deck.route_played_card(card.card_data)
		card.queue_free()
	board.combo_cards.clear()
	refresh_ui()

		
	# 4. APLICAR STATUSES AL ENEMIGO (¡ACÁ SE DISPARAN LAS REACCIONES!)
	var reaction := enemy.apply_statuses({
		"burn": int(combo_state["burn"]),
		"poison": int(combo_state["poison"]),
		"freeze": int(combo_state["freeze"]),
		"shock": int(combo_state["shock"]),
		"hemorrhage": int(combo_state["hemorrhage"])
	})

	var skip_statuses: Array[String] = []
	
	if not reaction.is_empty():
		var reaction_name: String = str(reaction.get("name", "¡REACCIÓN!"))
		var reaction_dmg: int = int(reaction.get("value", 0))
		
		hud.set_banner_message("%s -%d HP!" % [reaction_name, reaction_dmg])
		await get_tree().create_timer(1.2).timeout
		
		var consumes: Dictionary = reaction.get("consumes", {})
		for key in consumes.keys():
			skip_statuses.append(str(key))

	# 5. Ticks de statuses (lógica + UI)
	var ticks: Dictionary = CombatResolver.tick_enemy_statuses(enemy, run, skip_statuses)
	
	print("Ticks ejecutados: ", ticks)

	if ticks["burn"] > 0:
		refresh_ui()
		hud.set_banner_message("LAS LLAMAS QUEMAN AL ENEMIGO POR %d DE DAÑO FIJO!" % ticks["burn"])
		await get_tree().create_timer(1).timeout

	if ticks["poison"] > 0:
		refresh_ui()
		hud.set_banner_message("EL VENENO CONSUME AL ENEMIGO POR %d DE DAÑO FIJO!" % ticks["poison"])
		await get_tree().create_timer(1).timeout

	if ticks["hemorrhage"] > 0:
		refresh_ui()
		if ticks["hemorrhage_proc_count"] > 0:
			hud.set_banner_message("¡ESTALLIDO DE SANGRE! El enemigo sufre %d de daño por hemorragia." % ticks["hemorrhage"])
		else:
			hud.set_banner_message("¡HEMORRAGIA! El enemigo se desangra por %d de daño." % ticks["hemorrhage"])
		await get_tree().create_timer(1).timeout
		
	# CARTA DE HEAL :
	var heal_amount: int = int(combo_state.get("heal", 0))
	if heal_amount > 0:
		var actual_heal = min(heal_amount, run.max_player_hp - run.player_hp)
		run.player_hp += actual_heal
		hud.set_banner_message("TE CURASTE %d HP!" % actual_heal)
		await get_tree().create_timer(0.5).timeout
		
	# Se apaga al terminar el turno
	energy_free_this_turn = false  
	# Avanzar los mods temporales al fin del turno del jugador
	run.temp_stats.tick_turn()
	return current_block


## Resuelve el turno del enemigo: delega la lógica a `CombatResolver` y maneja la UI.
## Retorna `true` si el jugador sobrevive.
func execute_enemy_turn(p_run: RunState, p_enemy: Enemy, p_player_block: int) -> bool:
	# 1. LÓGICA: delegar al resolver (método puro, sin UI)
	var result: Dictionary = CombatResolver.resolve_enemy_turn(p_run, p_enemy, p_player_block)
	
	# 2. UI: mensajes según el resultado
	if result["frozen_solid"]:
		hud.set_banner_message("¡ENEMIGO CONGELADO! NO PUDO ATACAR ESTE TURNO.")
	elif result["shocked"]:
		hud.set_banner_message("¡PARÁLISIS ELÉCTRICA! EL ENEMIGO QUEDÓ ATURDIDO Y FALLÓ SU ATAQUE.")
	else:
		match result["outcome"]:
			"attack":
				if run.god_mode:
					hud.set_banner_message("ENEMIGO ATACA POR %d -> ANULADO POR GOD MODE!" % result["effective_dmg"])
				else:
					hud.set_banner_message("ENEMIGO ATACA POR %d (BLOQUEASTE %d)!" % [result["effective_dmg"], result["blocked"]])
			"defend":
				hud.set_banner_message("EL ENEMIGO GANA ESCUDO Y SE PREPARA.")
			"charge":
				hud.set_banner_message("EL ENEMIGO ESTÁ CARGANDO UN ATAQUE DEVASTADOR...")
			_:
				hud.set_banner_message("ENEMIGO EN ESPERA.")
	
	refresh_ui()
	# 3. Game Over o revive
	if not result["player_survives"]:
		return false
	
	if result["saving_relic"]:
		var relic: RelicData = result["saving_relic"]
		hud.set_banner_message("¡[%s] SE ROMPIO Y REVIVISTE CON %d HP!" % [relic.title, run.player_hp])
		await get_tree().create_timer(1.2).timeout
	
	return true


## Ejecuta la animación de consumo de una carta instantánea (`is_instant_card()`),
## delega el cálculo de su efecto a `CombatResolver` y la rutea al descarte o cementerio según `single_use`.
func consume_instant_card(card: CardUI) -> int:
	# 1. Guardar referencia a los datos de la carta ANTES de cualquier await/animación
	var card_data = card.card_data
	
	# 2. Desvincularla lógicamente del tablero
	board.remove_card(card)
	
	# 3. Traer la carta al frente visual por encima de todas las cartas y paneles de la mesa
	card.base_z_index = 140
	card.z_index = 140
	card.move_to_front()
	
	# 4. Posicionar explícitamente en el centro de la combo zone
	var target_pos: Vector2 = board.combo_zone.global_position + (board.combo_zone.size * 0.5) - (card.size * 0.5)
	card.global_position = target_pos
	card.home_position = target_pos
	
	# 5. Esperar la animación completa de consumo (Phasmophobia style)
	await card.play_consume_animation()
	
	# 6. Lógica: calcular efectos usando la referencia guardada
	var temp_state: Dictionary = CombatResolver.calculate_instant_card(card_data, run)
	
	# 7. Ruteo al cementerio / descarte y liberación de memoria
	deck.route_played_card(card_data)
	card.queue_free()
	
	return int(temp_state.get("draw", 0))
	
## Maneja la pulsación del botón de habilidad del héroe en la interfaz.
## Valida las condiciones del combate, ejecuta la habilidad con su contexto, verifica si el enemigo murió y actualiza la UI.
func _on_ability_pressed() -> void:
	if is_resolving or enemy == null or enemy.is_dead() or run.is_player_dead():
		return
	if not run.current_ability or not run.current_ability.can_activate():
		hud.set_banner_message("¡HABILIDAD NO DISPONIBLE!")
		return
	
	is_resolving = true
	# 1. Mostrar mensaje descriptivo de qué hace la habilidad
	hud.set_banner_message(run.current_ability.get_activation_message())
	
	# 2. Activar la habilidad pasando el contexto
	var context := {
		"table": self,
		"run": run,
		"deck": deck
	}
	run.current_ability.activate(context)
	refresh_ui()
	
	# 3. Pequeña pausa para que el jugador lea el mensaje
	await get_tree().create_timer(0.7).timeout
	
	# 4. Si la habilidad mató al enemigo (ej. Estocada Demoníaca o Corte Sangrante), cerrar el combate con victoria
	if enemy and enemy.is_dead():
		is_resolving = false
		attack_button.disabled = true
		discard_button.disabled = true
		refresh_ui()
		combat_won.emit()
		return

	is_resolving = false
	# 5. Refrescar la UI para actualizar el contador de usos del botón y el preview del combo
	refresh_ui()
	
	## Handler para cuando el enemigo sufre una reacción elemental.
func _on_enemy_reaction(reaction: Dictionary) -> void:
	hud.set_banner_message("%s -%d HP!" % [reaction["name"], int(reaction["value"])])
	await get_tree().create_timer(1.2).timeout
