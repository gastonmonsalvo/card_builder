## Fachada principal de la escena de combate (`battle_table.tscn`).
## Coordina el ciclo de turnos entre el tablero de cartas, el mazo, el resolutor de combate y el HUD.

extends Control
## señales
signal combat_won()
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

## Energía disponible en el turno actual.
var current_energy: int = CombatConstants.BASE_MAX_ENERGY
## Descartes restantes en el combate actual.
var discards_remaining: int = CombatConstants.BASE_DISCARDS_PER_COMBAT
## Escudo acumulado por el jugador en el turno actual.
var player_block: int = 0

## Bloquea inputs mientras se ejecutan las animaciones secuenciales del combo o del turno enemigo.
var is_resolving: bool = false:
	set(value):
		is_resolving = value
		if board:
			board.is_locked = value
## Inicializa `RunState`, `DeckManager`, `CardBoardController`, `BattleHUD` y `RunDirector`. 
## Si es un build de debug (`OS.is_debug_build()`), instancia `DebugOverlay` (F3).
func _ready() -> void:
	board = CardBoardController.new(hand_zone, combo_zone)
	board.card_clicked.connect(_on_board_card_clicked)
	board.card_dropped.connect(_on_board_card_dropped)
	board.board_order_changed.connect(refresh_ui)

	attack_button.pressed.connect(_on_attack_pressed)
	discard_button.pressed.connect(_on_discard_pressed)
	hud.bind_piles(deck.draw_pile, deck.discard_pile, deck.graveyard_pile)


	director = RunDirector.new(self, run)

	if OS.is_debug_build():
		var debug_overlay := DebugOverlay.new()
		add_child(debug_overlay)
		debug_overlay.bind_context(self, run, director)

# --- INICIO DE COMBATE Y TURNOS ---
## Resetea y baraja todas las cartas hacia el mazo (`deck.reset_for_new_combat`), 
## restaura `discards_remaining`, crea el enemigo escalado (`run.create_enemy_for_room(is_boss)`) 
## e inicia el primer turno.
func start_combat_encounter(is_boss: bool) -> void:
	is_resolving = false
	attack_button.disabled = false
	discards_remaining = 99 if run.god_mode else run.discards_per_combat

	var remaining_board_cards: Array[CardData] = board.clear_all_and_extract_data()
	deck.reset_for_new_combat(remaining_board_cards)

	enemy = run.create_enemy_for_room(is_boss)
	_start_new_turn()
## Reinicia `player_block = 0` y `current_energy = run.max_energy`, 
## calcula cuántas cartas faltan en `hand_cards` para llegar a 
## `run.target_hand_size` (`max(0, target - hand.size())`), las roba y refresca la UI.
func _start_new_turn() -> void:
	
	current_energy = 99 if run.god_mode else run.max_energy
	player_block = 0

	var needed: int = max(0, run.target_hand_size - board.hand_cards.size())
	if needed > 0:
		draw_cards(needed)

	board.layout_cards()
	refresh_ui()
	
## Pide `amount` datos de cartas a `deck.draw_cards_data(amount)`,
##  instancia sus nodos `CardUI` y los registra en `board.spawn_card_in_hand()`.
func draw_cards(amount: int) -> void:
	var drawn_data: Array[CardData] = deck.draw_cards_data(amount)
	board.spawn_cards_to_hand(drawn_data)

# --- INTERACCION CON CARTAS EN LA MESA ---
## Evalúa si la carta jugada es de tipo instantánea.
## De ser así (y si hay energía disponible), descuenta su costo, delega su ejecución directa al `CombatResolver` 
## y retorna `true` para confirmar su consumo sin encolarla en el tablero.
func _try_consume_instant_card(card: CardUI) -> bool:
	if not card.card_data or not card.card_data.is_instant_card():
		return false

	var card_cost: int = card.card_data.cost
	if current_energy < card_cost:
		board.layout_cards()
		refresh_ui()
		hud.set_banner_message("SIN ENERGIA! Necesitas %d y tienes %d/%d" % [card_cost, current_energy, run.max_energy])
		return true

	is_resolving = true
	current_energy -= card_cost
	var title: String = card.card_data.title
	var cards_drawn: int = await CombatResolver.consume_instant_card(get_tree(), card, board, deck)
	if cards_drawn > 0:
		draw_cards(cards_drawn)

	refresh_ui()
	hud.set_banner_message("USASTE [%s] -> ROBASTE +%d CARTA(S) (SIGUE TU TURNO)" % [title, cards_drawn])
	is_resolving = false
	return true
	
## Si la carta está en `HandZone`, intenta consumirla como instantánea o la sube a `ComboZone` 
## si alcanza la energía disponible. Si ya estaba en `ComboZone`, la devuelve a `HandZone`.
func _on_board_card_clicked(card: CardUI) -> void:
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
		
## Procesa el final de un arrastre manual validando el costo de energía 
## antes de aceptar la carta en `ComboZone`.
func _on_board_card_dropped(card: CardUI, dropped_in_combo: bool) -> void:
	var cost: int = card.card_data.cost if card.card_data else 1
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

## Si hay cartas seleccionadas en `ComboZone` y quedan `discards_remaining > 0`, 
## descarta esas cartas hacia `discard_pile`, libera su energía reservada 
## y roba la misma cantidad de reemplazos.
func _on_discard_pressed() -> void:
	if is_resolving or enemy.is_dead():
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
	
## Descuenta la energía reservada por las cartas en `ComboZone` e invoca la corrutina 
## `CombatResolver.execute_combo_turn(...)`. Al finalizar, emite `combat_won`, `combat_lost` 
## o inicia el siguiente turno.
func _on_attack_pressed() -> void:
	if is_resolving or enemy.is_dead():
		return

	is_resolving = true
	attack_button.disabled = true
	discard_button.disabled = true

	# 1. Ejecutar turno del jugador
	player_block = await CombatResolver.execute_combo_turn(
		get_tree(), run, enemy, board, deck, hud, player_block, draw_cards,
		func(new_block: int):
			player_block = new_block
			refresh_ui()
	)

	# 2. Verificar si el enemigo murió por el combo
	if enemy.is_dead():
		refresh_ui()
		combat_won.emit()
		return

	refresh_ui() # Refresca por si hubo cambios de stats antes del golpe enemigo

	# 3. Ejecutar turno del enemigo
	var survived: bool = await CombatResolver.execute_enemy_turn(
		get_tree(), run, enemy, hud, player_block
	)
	
	if not survived:
		combat_lost.emit()
		return

	# 4. Fin de ronda y preparación del siguiente turno
	await get_tree().create_timer(1.0).timeout
	_start_new_turn()
	attack_button.disabled = false
	is_resolving = false
	refresh_ui()

## Elimina todos los nodos CardUI activos en mesa y resetea las estadísticas efímeras del combate.
## Purga las cartas de la mano y de la zona de combo mediante el controlador del tablero,
## restablece el bloqueo del jugador a 0 y reinicia la energía y los descartes a sus valores base.
func clear_board_visuals() -> void:
	if board:
		board.clear_all_nodes()
	player_block = 0
	discards_remaining = CombatConstants.BASE_DISCARDS_PER_COMBAT
	current_energy = CombatConstants.BASE_MAX_ENERGY
	
##  Calcula la previsualización matemática de la fila en `ComboZone` (`CombatResolver.calculate_sequential_preview`),
##  actualiza el estado de los botones (`EJECUTAR COMBO`, `DESCARTAR`) y refresca `hud.update_all(...)`.
func refresh_ui() -> void:
	var preview: Dictionary = CombatResolver.calculate_sequential_preview(board.combo_cards, run)
	hud.refresh_all(run.player_hp, player_block, current_energy, run.max_energy, enemy, preview, run.max_player_hp, run.player_luck)
	discard_button.text = "DESCARTAR (%d)" % discards_remaining
	discard_button.disabled = (discards_remaining <= 0 or board.combo_cards.is_empty())
	attack_button.text = "EJECUTAR COMBO" if not board.combo_cards.is_empty() else "PASAR TURNO"

## Delega el control de inputs del sistema al orquestador (RunDirector), manteniendo desacoplada
## la lógica de comandos globales (tecla Escape / Pausa) de la escena de la mesa de combate.
func _unhandled_input(event: InputEvent) -> void:
	if director:
		director.handle_unhandled_key(event)
