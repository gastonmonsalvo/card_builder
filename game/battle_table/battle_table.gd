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

	# El juego arranca sin enemigo; los botones de combate deben iniciar desactivados.
	refresh_ui()

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

	var remaining_board_cards: Array[CardData] = board.clear_all_and_extract_data()
	deck.reset_for_new_combat(remaining_board_cards)

	enemy = run.create_enemy_for_room(is_boss)
	if enemy == null:
		push_error("[BattleTable] No se pudo crear el enemigo para este encuentro.")
		refresh_ui()
		return
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

	var card_cost: int = card.card_data.cost
	if current_energy < card_cost:
		board.layout_cards()
		refresh_ui()
		hud.set_banner_message("SIN ENERGIA! Necesitas %d y tienes %d/%d" % [card_cost, current_energy, run.max_energy])
		return true

	is_resolving = true
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
		var cost: int = card.card_data.cost if card.card_data else 1
		if current_energy >= cost:
			current_energy -= cost
			board.move_to_combo(card, false)
			refresh_ui()
		else:
			hud.set_banner_message("SIN ENERGIA! Necesitas %d y tienes %d/%d" % [cost, current_energy, run.max_energy])
	elif board.is_in_combo(card):
		var cost: int = card.card_data.cost if card.card_data else 1
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
			if current_energy >= cost:
				current_energy -= cost
				board.move_to_combo(card, true)
			else:
				rejected_by_energy = true
				board.layout_cards()
		else:
			board.layout_cards()
	else:
		if board.is_in_combo(card):
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
		combat_won.emit()
		return

	refresh_ui() # Refresca por si hubo cambios de stats antes del golpe enemigo

	# 3. Ejecutar turno del enemigo
	var survived: bool = await execute_enemy_turn(run, enemy, player_block)
	
	if not survived:
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
	
## Solicita un cálculo matemático predictivo (Previsualización) de toda la cadena de cartas en la zona de combo.
## Con ese diccionario resultante, ordena al `BattleHUD` que actualice todas sus etiquetas visuales de salud, 
## escudo y daño. Ajusta también los textos y estados de los botones principales.
func refresh_ui() -> void:
	if board == null or run == null or hud == null:
		return

	var preview: Dictionary = CombatResolver.calculate_sequential_preview(board.combo_cards, run)
	hud.refresh_all(run.player_hp, player_block, current_energy, run.max_energy, enemy, preview, run.max_player_hp, run.player_luck)
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
func execute_combo_turn(run: RunState, enemy: Enemy, initial_block: int) -> int:
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

	# 1. Procesar cada carta del combo (lógica + UI intercaladas)
	for card in board.combo_cards:
		if not card.card_data:
			continue
		
		var cdata: CardData = card.card_data
		card.pulse()  # UI
		
		# LÓGICA: delegar al resolver
		var delta: Dictionary = CombatResolver.process_card_in_combo(cdata, run, combo_state)
		
		# Aplicar statuses al enemigo
		enemy.add_statuses(
			delta["burn_delta"],
			delta["poison_delta"],
			delta["freeze_delta"],
			delta["shock_delta"],
			delta["hemorrhage_delta"]
		)
		
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
			hud.set_banner_message("DISPARANDO: [ %s ]" % delta["title"])
		
		await get_tree().create_timer(0.45).timeout

	# 2. Finalizar combo (lógica pura)
	current_block = CombatResolver.finalize_combo(run, combo_state, enemy, board.combo_cards.size())
	player_block = current_block
	refresh_ui()

	if not board.combo_cards.is_empty():
		await get_tree().create_timer(0.35).timeout

	# 3. Ruteo al descarte (UI + deck state)
	for card in board.combo_cards:
		deck.route_played_card(card.card_data)
		card.queue_free()
	board.combo_cards.clear()
	refresh_ui()

	# 4. Ticks de statuses (lógica pura + UI)
	var ticks: Dictionary = CombatResolver.tick_enemy_statuses(enemy, run)

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

	return current_block


## Resuelve el turno del enemigo: delega la lógica a `CombatResolver` y maneja la UI.
## Retorna `true` si el jugador sobrevive.
func execute_enemy_turn(run: RunState, enemy: Enemy, player_block: int) -> bool:
	# 1. LÓGICA: delegar al resolver (método puro, sin UI)
	var result: Dictionary = CombatResolver.resolve_enemy_turn(run, enemy, player_block)
	
	# 2. UI: mensajes según el resultado
	if result["frozen_solid"]:
		hud.set_banner_message("¡ENEMIGO CONGELADO! NO PUDO ATACAR ESTE TURNO.")
	elif result["shocked"]:
		hud.set_banner_message("¡PARÁLISIS ELÉCTRICA! EL ENEMIGO QUEDÓ ATURDIDO Y FALLÓ SU ATAQUE.")
	else:
		if run.god_mode:
			hud.set_banner_message("ENEMIGO ATACA POR %d -> ANULADO POR GOD MODE!" % result["effective_dmg"])
		else:
			hud.set_banner_message("ENEMIGO ATACA POR %d (BLOQUEASTE %d)!" % [result["effective_dmg"], result["blocked"]])
	
	# 3. Game Over o revive
	if not result["player_survives"]:
		return false
	
	if result["saving_relic"]:
		var relic: RelicData = result["saving_relic"]
		hud.set_banner_message("¡[%s] SE ROMPIO Y REVIVISTE CON %d HP!" % [relic.title, run.player_hp])
		await get_tree().create_timer(1.2).timeout
	
	return true


## Ejecuta y descarta una carta instantánea (`single_use`).
## Delegar cálculo a `CombatResolver`, manejar UI + animación.
func consume_instant_card(card: CardUI) -> int:
	board.remove_card(card)
	card.home_position = board.combo_zone.global_position + (board.combo_zone.size * 0.5) - (card.size * 0.5)
	card.pulse()
	
	# LÓGICA: calcular efectos sin tocar UI
	var temp_state: Dictionary = CombatResolver.calculate_instant_card(card.card_data)
	
	await get_tree().create_timer(0.45).timeout
	
	deck.route_played_card(card.card_data)
	card.queue_free()
	return int(temp_state["draw"])
