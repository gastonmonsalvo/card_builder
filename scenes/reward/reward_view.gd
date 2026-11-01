## Pantalla de recompensas post-batalla.
## Muestra oro ganado, oferta de 3 cartas (según RaritySystem) y opcional relic.
## Al elegir o skippear, transiciona la FSM de REWARD → MAP.
extends Control
class_name RewardView

signal reward_completed()

@onready var gold_label: Label = $Panel/MarginContainer/VBoxContainer/GoldLabel
@onready var card_options_container: HBoxContainer = $Panel/MarginContainer/VBoxContainer/CardOptions
@onready var skip_button: Button = $Panel/MarginContainer/VBoxContainer/SkipButton

var run: RunState
var state_machine: RunStateMachine
var table: Control  # Referencia al BattleTable para acceder al deck

var offered_cards: Array[CardData] = []
var gold_reward: int = 0
var relic_reward: RelicData = null
var card_ui_scene: PackedScene = preload(CombatConstants.CARD_UI_SCN)


## Inicializa la vista. Llamar después de add_child.
func setup(p_run: RunState, p_state_machine: RunStateMachine, p_table: Control) -> void:
	run = p_run
	state_machine = p_state_machine
	table = p_table
	_generate_rewards()
	_render_rewards()


## Genera oro, 3 cartas y chance de relic según el floor.
func _generate_rewards() -> void:
	# Oro garantizado: 10 + floor * 2 + random 0-5
	gold_reward = 10 + (run.current_floor * 2) + randi() % 5

	# 3 cartas según RaritySystem (ya existente en tu código)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var available_pool: Array[CardData] = run.available_card_pool.filter(
		func(c): return c != null
	)

	for i in range(3):
		if available_pool.is_empty():
			break
		var rolled_tier: RaritySystem.Tier = RaritySystem.roll_tier(
			rng, run.current_floor, run.player_luck
		)
		var card := _pick_card_by_tier(available_pool, rolled_tier, rng)
		if card:
			offered_cards.append(card.duplicate())
			available_pool.erase(card)

	# 30% chance de relic (no garantizada)
	if randf() < 0.3 and not run.relic_catalog.is_empty():
		relic_reward = run.relic_catalog[rng.randi_range(0, run.relic_catalog.size() - 1)]

	print("[RewardView] Generadas: %d oro, %d cartas, relic=%s" % [
		gold_reward, offered_cards.size(), relic_reward.title if relic_reward else "none"
	])


## Selecciona una carta del pool filtrando por tier. Fallback al pool completo si el tier está vacío.
func _pick_card_by_tier(
	pool: Array[CardData], tier: RaritySystem.Tier, rng: RandomNumberGenerator
) -> CardData:
	var candidates: Array[CardData] = pool.filter(func(c): return c.rarity == tier)
	if candidates.is_empty():
		candidates = pool
	if candidates.is_empty():
		return null
	return candidates[rng.randi_range(0, candidates.size() - 1)]


## Renderiza la UI: oro, 3 cartas y botón skip.
func _render_rewards() -> void:
	gold_label.text = "Oro ganado: + %d" % gold_reward

	# Limpiar cartas previas
	for child in card_options_container.get_children():
		child.queue_free()

	# Instanciar 3 cartas
	for card_data in offered_cards:
		var card_ui := card_ui_scene.instantiate() as CardUI
		card_options_container.add_child(card_ui)
		# Tu CardUI.setup() ya existe en tu código
		card_ui.setup(card_data)
		card_ui.gui_input.connect(_on_card_option_clicked.bind(card_data))

	# TODO futuro: renderizar relic_reward si no es null
	# (cuando tengas un RelicUI component)

	skip_button.pressed.connect(_on_skip_button_pressed)


## Maneja el clic en una carta de recompensa.
func _on_card_option_clicked(event: InputEvent, card_data: CardData) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_card_reward(card_data)


## Selección de carta: agrega al deck, da oro, transiciona a MAP.
func _select_card_reward(card_data: CardData) -> void:
	# 1. Agregar carta al deck del jugador (DrawPile)
	if table and table.deck:
		table.deck.draw_pile.add_card(card_data)
		print("[RewardView] Carta '%s' agregada al mazo." % card_data.title)

	# 2. Otorgar oro
	run.player_gold += gold_reward

	# 3. Otorgar relic si la había
	if relic_reward:
		run.equip_specific_relic(relic_reward)
		print("[RewardView] Reliquia '%s' adquirida." % relic_reward.title)

	# 4. Transición FSM: REWARD → MAP
	state_machine.transition_to(RunStateMachine.State.MAP)

	# 5. Cerrar vista
	_close()


## Skip: da oro pero no carta.
func _on_skip_button_pressed() -> void:
	run.player_gold += gold_reward
	if relic_reward:
		# Si skippea, pierde la relic pero se queda el oro
		pass
	state_machine.transition_to(RunStateMachine.State.MAP)
	_close()


## Cierra la vista y emite la señal.
func _close() -> void:
	reward_completed.emit()
	queue_free()
