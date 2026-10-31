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

## Cantidad de puntos de energía disponibles para gastar en el turno actual. 
## Se reinicia al máximo (`max_energy`) al comienzo de cada ronda.
var current_energy: int = CombatConstants.BASE_MAX_ENERGY
## Cantidad de descartes tácticos restantes permitidos para el encuentro actual.
## Se restablece al inicio del combate.
var discards_remaining: int = CombatConstants.BASE_DISCARDS_PER_COMBAT
## Escudo físico temporal acumulado por el jugador en el turno actual.
## Absorbe el daño enemigo antes que los HP y se purga al iniciar la siguiente ronda.
var player_block: int = 0

## Bandera de exclusión mutua (Mutex). Bloquea la interacción del usuario con las cartas
## y botones mientras se reproducen las animaciones secuenciales del combo o el ataque del enemigo.
var is_resolving: bool = false:
	set(value):
		is_resolving = value
		if board:
			board.is_locked = value
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


	director = RunDirector.new(self, run)

	if OS.is_debug_build():
		var debug_overlay := DebugOverlay.new()
		add_child(debug_overlay)
		debug_overlay.bind_context(self, run, director)

# --- INICIO DE COMBATE Y TURNOS ---
## Resetea el tablero físico recolectando cualquier carta sobrante, ordena al `DeckManager` 
## que baraje el mazo para el nuevo encuentro,
## instancia al enemigo vivo a través del `RunState` y dispara el primer turno del combate.
func start_combat_encounter(is_boss: bool) -> void:
	is_resolving = false
	attack_button.disabled = false
	discards_remaining = 99 if run.god_mode else run.discards_per_combat

	var remaining_board_cards: Array[CardData] = board.clear_all_and_extract_data()
	deck.reset_for_new_combat(remaining_board_cards)

	enemy = run.create_enemy_for_room(is_boss)
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
	var drawn_data: Array[CardData] = deck.draw_cards_data(amount)
	board.spawn_cards_to_hand(drawn_data)

# --- INTERACCION CON CARTAS EN LA MESA ---
## Evalúa si la carta clickeada posee el atributo "Instantánea" (se consumen directamente sin pasar por el combo).
## Si hay energía disponible, debita su costo, delega la ejecución de su efecto al `CombatResolver` 
## y detiene el flujo de arrastre devolviendo `true`.
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
	
## Callback disparado al hacer clic (no arrastrar) sobre una carta. Si la carta estaba en la mano, 
## intenta aplicarla como instantánea o la sube a la zona de combo si la energía lo permite. 
## Si ya estaba en la zona de combo, la devuelve a la mano reembolsando su costo.
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
		
## Callback disparado al soltar una carta tras un arrastre manual (Drag & Drop). 
## Valida matemáticamente si el jugador posee la energía necesaria para soltarla en la zona de combo. 
## Si no le alcanza, rechaza el movimiento (rollback) y devuelve la carta a la mano.
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

## Ejecuta la acción táctica de descarte. Mueve todas las cartas temporalmente alojadas en la zona de combo
## hacia el pozo de descarte, devuelve la energía reservada al total del turno, 
## descuenta una ficha de descarte y roba inmediatamente la misma cantidad de cartas para reemplazarlas.
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
	
## Ejecuta la fase de resolución (End Turn). Bloquea la mesa (`is_resolving`),
##  invoca la corrutina asíncrona del `CombatResolver` para animar las cartas secuencialmente 
## y aplicar el daño. Si el enemigo sobrevive, invoca su turno de ataque de respuesta antes de
##  iniciar la siguiente ronda. Emite `combat_won` o `combat_lost` según corresponda.
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

## Purga por completo el estado efímero del tablero (útil al abandonar una partida o escapar).
## Elimina los nodos físicos de las cartas en mano y en combo, y resetea contadores temporales como la energía,
## descartes y bloqueo.
func clear_board_visuals() -> void:
	if board:
		board.clear_all_nodes()
	player_block = 0
	discards_remaining = CombatConstants.BASE_DISCARDS_PER_COMBAT
	current_energy = CombatConstants.BASE_MAX_ENERGY
	
## Solicita un cálculo matemático predictivo (Previsualización) de toda la cadena de cartas en la zona de combo.
## Con ese diccionario resultante, ordena al `BattleHUD` que actualice todas sus etiquetas visuales de salud, 
## escudo y daño. Ajusta también los textos y estados de los botones principales.
func refresh_ui() -> void:
	var preview: Dictionary = CombatResolver.calculate_sequential_preview(board.combo_cards, run)
	hud.refresh_all(run.player_hp, player_block, current_energy, run.max_energy, enemy, preview, run.max_player_hp, run.player_luck)
	discard_button.text = "DESCARTAR (%d)" % discards_remaining
	discard_button.disabled = (discards_remaining <= 0 or board.combo_cards.is_empty())
	attack_button.text = "EJECUTAR COMBO" if not board.combo_cards.is_empty() else "PASAR TURNO"

## Atrapa eventos de teclado/controlador globales no consumidos por los botones físicos de la UI 
## (ej. presionar la tecla ESC). Delega esta señal al `RunDirector` para gestionar el menú de pausa sin acoplar lógicas en la mesa de combate.
func _unhandled_input(event: InputEvent) -> void:
	if director:
		director.handle_unhandled_key(event)
