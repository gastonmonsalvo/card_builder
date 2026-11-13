## Pantalla de recompensas post-batalla con animaciones estilo Balatro.
## Construye toda la UI en código (sin .tscn) para evitar problemas de layout.
## Muestra oro ganado, oferta de 3 cartas (según RaritySystem) y reliquia opcional.
## Al elegir o skippear, transiciona la FSM de REWARD → MAP.
extends Control
class_name RewardView


signal reward_completed()           
signal card_chosen(card_data: CardData) 
signal skipped()                         


var run: RunState
var state_machine: RunStateMachine
var table: Control

var offered_cards: Array[CardData] = []
var gold_reward: int = 0
var relic_reward: RelicData = null
var xp_result: Dictionary = {}
var card_ui_scene: PackedScene = preload(CombatConstants.CARD_UI_SCN)

# Nodos UI (creados en código)
var _root_panel: Panel
var _center_container: CenterContainer
var _vbox: VBoxContainer
var _title_label: Label
var _gold_label: Label
var _xp_label: Label
var _level_up_label: Label
var _stat_alloc_box: VBoxContainer
var _stat_alloc_title: Label
var _stat_btn_str: Button
var _stat_btn_dex: Button
var _stat_btn_int: Button
var _stat_btn_crit: Button
var _relic_label: Label
var _card_options: HBoxContainer
var _skip_button: Button

# Estado de animación estilo Balatro
var _card_wrappers: Array[Control] = []
var _card_nodes: Array[CardUI] = []
var _hovered_card: CardUI = null
var _is_selecting: bool = false
var _time: float = 0.0

const CARD_SIZE := Vector2(180, 240)

## Inicializa la vista. Recibe las recompensas YA GENERADAS por RunState.
func setup(
	p_run: RunState, 
	p_state_machine: RunStateMachine, 
	p_table: Control, 
	rewards: Dictionary
) -> void:
	run = p_run
	state_machine = p_state_machine
	table = p_table
	gold_reward = rewards.gold
	offered_cards = rewards.cards
	relic_reward = rewards.relic
	xp_result = rewards.get("xp_result", {})
	
	if not is_inside_tree():
		await tree_entered
	
	_build_ui()
	_render_rewards()

## Actualiza cuadro a cuadro la animación de flotación idle y el efecto de imán/tilt al pasar el mouse.
func _process(delta: float) -> void:
	if _is_selecting:
		return
		
	_time += delta
	var mouse_pos := get_global_mouse_position()

	for i in range(_card_nodes.size()):
		var card := _card_nodes[i]
		if not is_instance_valid(card):
			continue
			
		# Fase desfasada por índice para que cada carta respire a distinto ritmo
		var phase := _time * 2.8 + (i * 1.35)
		
		if card == _hovered_card:
			# --- COMPORTAMIENTO HOVER (Imán al mouse + Tilt ) ---
			var card_center := card.global_position + (CARD_SIZE * 0.5)
			var offset := (mouse_pos - card_center) / (CARD_SIZE * 0.5)
			offset = offset.clamp(Vector2(-1.0, -1.0), Vector2(1.0, 1.0))
			
			var target_pos := Vector2(offset.x * 12.0, -18.0 + offset.y * 8.0)
			var target_rot := deg_to_rad(offset.x * 9.0 - offset.y * 4.0)
			var target_scale := Vector2(1.18, 1.18)
			
			card.position = card.position.lerp(target_pos, delta * 16.0)
			card.rotation = lerp_angle(card.rotation, target_rot, delta * 16.0)
			card.scale = card.scale.lerp(target_scale, delta * 16.0)
			card.z_index = 20
		else:
			# --- COMPORTAMIENTO IDLE (Flotación suave con ondas senoidales) ---
			var float_y := sin(phase) * 5.0
			var float_rot := deg_to_rad(cos(phase * 0.8) * 2.2)
			
			card.position = card.position.lerp(Vector2(0.0, float_y), delta * 10.0)
			card.rotation = lerp_angle(card.rotation, float_rot, delta * 10.0)
			card.scale = card.scale.lerp(Vector2.ONE, delta * 10.0)
			card.z_index = 1


## Construye toda la jerarquía de nodos UI en código forzando el tamaño del viewport y centrado en pantalla.
func _build_ui() -> void:
	top_level = true
	z_index = 100
	var vp_size := get_viewport_rect().size
	global_position = Vector2.ZERO
	size = vp_size
	custom_minimum_size = vp_size
	mouse_filter = Control.MOUSE_FILTER_STOP

	_root_panel = Panel.new()
	_root_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root_panel.custom_minimum_size = vp_size
	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = Color(0.08, 0.08, 0.12, 0.98)
	stylebox.set_border_width_all(3)
	stylebox.border_color = Color(0.5, 0.5, 0.6)
	_root_panel.add_theme_stylebox_override("panel", stylebox)
	add_child(_root_panel)

	_center_container = CenterContainer.new()
	_center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_center_container.custom_minimum_size = vp_size
	_root_panel.add_child(_center_container)

	_vbox = VBoxContainer.new()
	_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_vbox.add_theme_constant_override("separation", 9)
	_center_container.add_child(_vbox)

	var vp := get_viewport()
	if vp and not vp.size_changed.is_connected(_layout_for_viewport):
		vp.size_changed.connect(_layout_for_viewport)

	_title_label = Label.new()
	_title_label.text = "VICTORIA"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 32)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_vbox.add_child(_title_label)

	_gold_label = Label.new()
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gold_label.add_theme_font_size_override("font_size", 20)
	_gold_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.3))
	_vbox.add_child(_gold_label)

	_xp_label = Label.new()
	_xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_xp_label.add_theme_font_size_override("font_size", 16)
	_xp_label.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
	_vbox.add_child(_xp_label)

	_level_up_label = Label.new()
	_level_up_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_up_label.add_theme_font_size_override("font_size", 15)
	_level_up_label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.58))
	_level_up_label.visible = false
	_vbox.add_child(_level_up_label)

	_stat_alloc_box = VBoxContainer.new()
	_stat_alloc_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_stat_alloc_box.add_theme_constant_override("separation", 6)
	_stat_alloc_box.visible = false
	_vbox.add_child(_stat_alloc_box)

	_stat_alloc_title = Label.new()
	_stat_alloc_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stat_alloc_title.add_theme_font_size_override("font_size", 14)
	_stat_alloc_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	_stat_alloc_box.add_child(_stat_alloc_title)

	var stat_btns_row := HBoxContainer.new()
	stat_btns_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stat_btns_row.add_theme_constant_override("separation", 12)
	_stat_alloc_box.add_child(stat_btns_row)

	_stat_btn_str = _create_stat_button("str", Color(1.0, 0.52, 0.42))
	_stat_btn_dex = _create_stat_button("dex", Color(0.45, 0.95, 0.62))
	_stat_btn_int = _create_stat_button("int", Color(0.52, 0.78, 1.0))
	_stat_btn_crit = _create_stat_button("crit", Color(1.0, 0.84, 0.32))
	stat_btns_row.add_child(_stat_btn_str)
	stat_btns_row.add_child(_stat_btn_dex)
	stat_btns_row.add_child(_stat_btn_int)
	stat_btns_row.add_child(_stat_btn_crit)

	_relic_label = Label.new()
	_relic_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_relic_label.add_theme_font_size_override("font_size", 16)
	_relic_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	_relic_label.visible = false
	_vbox.add_child(_relic_label)

	var choose_label := Label.new()
	choose_label.text = "Elegí una carta para tu mazo:"
	choose_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	choose_label.add_theme_font_size_override("font_size", 17)
	choose_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	_vbox.add_child(choose_label)

	_card_options = HBoxContainer.new()
	_card_options.alignment = BoxContainer.ALIGNMENT_CENTER
	_card_options.add_theme_constant_override("separation", 42)
	_card_options.custom_minimum_size = Vector2(680, 248)
	_vbox.add_child(_card_options)

	_skip_button = Button.new()
	_skip_button.text = "SALTAR"
	_skip_button.custom_minimum_size = Vector2(320, 42)
	_skip_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_skip_button.add_theme_font_size_override("font_size", 17)
	_vbox.add_child(_skip_button)


## Instancia las cartas dentro de wrappers contenedores, conecta señales y ejecuta la animación de entrada.
func _render_rewards() -> void:
	_gold_label.text = "+ %d Oro" % gold_reward

	if not xp_result.is_empty():
		var xp_gained: int = int(xp_result.get("xp_gained", 0))
		var cur_lvl: int = int(xp_result.get("new_level", run.player_level if run else 1))
		var cur_xp: int = int(xp_result.get("current_xp", run.player_xp if run else 0))
		var next_xp: int = int(xp_result.get("next_level_xp", run.get_xp_required_for_next_level() if run else 75))
		_xp_label.text = "+ %d XP   |   Nivel %d (XP: %d / %d)" % [xp_gained, cur_lvl, cur_xp, next_xp]
		_xp_label.visible = true

		var lvls_gained: int = int(xp_result.get("levels_gained", 0))
		if lvls_gained > 0 and run != null:
			var hp_max_up: int = int(xp_result.get("hp_max_gained", 0))
			var hp_healed: int = int(xp_result.get("hp_healed", 0))
			_level_up_label.text = "✨ ¡SUBISTE A NIVEL %d! (+%d HP Máx | +%d HP Curado | +%d%% Daño Global)" % [
				cur_lvl,
				hp_max_up,
				hp_healed,
				run.get_level_damage_bonus_pct()
			]
			_level_up_label.visible = true
		else:
			_level_up_label.visible = false
	else:
		_xp_label.visible = false
		_level_up_label.visible = false

	_refresh_stat_alloc_ui()

	if relic_reward:
		_relic_label.text = "Reliquia obtenida: %s" % relic_reward.title
		_relic_label.visible = true

	for child in _card_options.get_children():
		child.free()
	_card_wrappers.clear()
	_card_nodes.clear()

	for i in range(offered_cards.size()):
		var card_data := offered_cards[i]
		
		# Wrapper invisible que reserva el espacio fijo en el HBoxContainer
		var wrapper := Control.new()
		wrapper.custom_minimum_size = CARD_SIZE
		wrapper.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		wrapper.mouse_filter = Control.MOUSE_FILTER_PASS
		_card_options.add_child(wrapper)
		_card_wrappers.append(wrapper)

		# Instancia de CardUI libre para rotar y escalar dentro del wrapper
		var card_ui := card_ui_scene.instantiate() as CardUI
		card_ui.card_data = card_data
		card_ui.custom_minimum_size = CARD_SIZE
		card_ui.size = CARD_SIZE
		card_ui.pivot_offset = CARD_SIZE * 0.5
		
		wrapper.add_child(card_ui)
		
		card_ui.top_level = false
		card_ui.set_process(false)
		card_ui.set_physics_process(false)
		card_ui.setup_card(card_data)
		
		card_ui.mouse_entered.connect(_on_card_mouse_entered.bind(card_ui))
		card_ui.mouse_exited.connect(_on_card_mouse_exited.bind(card_ui))
		if not card_ui.card_clicked.is_connected(_on_card_clicked_reward):
			card_ui.card_clicked.connect(_on_card_clicked_reward.bind(card_data))

		_card_nodes.append(card_ui)

		# Animación de entrada escalonada (Pop-in elástico)
		card_ui.scale = Vector2.ZERO
		card_ui.rotation = deg_to_rad(randf_range(-15.0, 15.0))
		var intro_tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		intro_tween.tween_interval(i * 0.09)
		intro_tween.tween_property(card_ui, "scale", Vector2.ONE, 0.35)

	if not _skip_button.pressed.is_connected(_on_skip_button_pressed):
		_skip_button.pressed.connect(_on_skip_button_pressed)


## Construye un botón estilizado para invertir un punto de atributo al subir de nivel.
func _create_stat_button(stat_key: String, accent_color: Color) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(215, 34)
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", accent_color)
	btn.pressed.connect(_on_stat_button_pressed.bind(stat_key))
	return btn


## Actualiza la visibilidad y los textos en vivo del selector de atributos de subida de nivel.
func _refresh_stat_alloc_ui() -> void:
	if run == null or _stat_alloc_box == null:
		return

	var pts: int = run.unspent_stat_points
	var lvls_gained: int = int(xp_result.get("levels_gained", 0))
	if pts <= 0 and lvls_gained <= 0:
		_stat_alloc_box.visible = false
		return

	_stat_alloc_box.visible = true
	_stat_btn_str.text = "💪 +1 STR (Actual: %d)" % run.player_str
	_stat_btn_dex.text = "🗡️ +1 DEX (Actual: %d)" % run.player_dex
	_stat_btn_int.text = "🔮 +1 INT (Actual: %d)" % run.player_int
	_stat_btn_crit.text = "🎯 +Crítico (%.1f%% → %.1f%%)" % [
		run.get_crit_chance_pct(),
		run.get_next_crit_chance_pct()
	]

	var has_pts: bool = pts > 0
	_stat_btn_str.visible = has_pts
	_stat_btn_dex.visible = has_pts
	_stat_btn_int.visible = has_pts
	_stat_btn_crit.visible = has_pts

	if has_pts:
		_stat_alloc_title.text = "⚡ Puntos de Atributo disponibles: %d — Elegí qué mejorar (o guardalo para tu Inventario):" % pts
		_stat_alloc_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	else:
		_stat_alloc_title.text = "✅ ¡Atributo mejorado! (STR: %d | DEX: %d | INT: %d | Crítico: %.1f%%)" % [
			run.player_str,
			run.player_dex,
			run.player_int,
			run.get_crit_chance_pct()
		]
		_stat_alloc_title.add_theme_color_override("font_color", Color(0.45, 1.0, 0.65))


## Invierte un punto de atributo desde la pantalla de victoria y refresca los valores en vivo.
func _on_stat_button_pressed(stat_key: String) -> void:
	if _is_selecting or run == null:
		return
	if run.spend_stat_point(stat_key):
		if table and table.has_method("refresh_ui"):
			table.refresh_ui()
		_refresh_stat_alloc_ui()


## Detecta cuando el mouse entra a una carta, la marca como activa y aplica un impulso elástico de escala.
func _on_card_mouse_entered(card: CardUI) -> void:
	if _is_selecting:
		return
	_hovered_card = card
	var punch := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	punch.tween_property(card, "scale", Vector2(1.24, 1.24), 0.18)


## Limpia la referencia de la carta activa cuando el cursor sale de su área.
func _on_card_mouse_exited(card: CardUI) -> void:
	if _hovered_card == card:
		_hovered_card = null


## Maneja el clic en una carta, ejecuta la coreografía de selección/descarte y luego aplica la recompensa.
func _on_card_clicked_reward(clicked_card: CardUI, card_data: CardData) -> void:
	if _is_selecting:
		return
	_is_selecting = true
	_skip_button.disabled = true

	var tween := create_tween().set_parallel(true)

	for card in _card_nodes:
		if card == clicked_card:
			card.z_index = 50
			var seq := create_tween()
			seq.tween_property(card, "scale", Vector2(1.38, 1.38), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			seq.parallel().tween_property(card, "rotation", deg_to_rad(randf_range(-6.0, 6.0)), 0.14)
			seq.parallel().tween_property(card, "position:y", card.position.y - 35.0, 0.14)
			
			seq.tween_interval(0.12)
			
			seq.tween_property(card, "scale", Vector2.ZERO, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			seq.parallel().tween_property(card, "modulate:a", 0.0, 0.2)
		else:
			tween.tween_property(card, "position:y", card.position.y + 90.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tween.tween_property(card, "modulate:a", 0.0, 0.2)
			tween.tween_property(card, "scale", Vector2(0.8, 0.8), 0.25)

	await get_tree().create_timer(0.48).timeout
	_select_card_reward(card_data)

## Emite la señal de finalización y elimina la vista del árbol de escenas.

func _close() -> void:
	reward_completed.emit()
	queue_free()

## Emite la señal `card_chosen` con la carta seleccionada hacia el `RunDirector` y cierra la vista de recompensas.
func _select_card_reward(card_data: CardData) -> void:
	# Ya no mutamos run ni deck directamente desde acá
	# Solo emitimos la señal con los datos elegidos
	card_chosen.emit(card_data)
	_close()

## Maneja el botón de omitir recompensa de carta, emitiendo `skipped` y cerrando la vista.
func _on_skip_button_pressed() -> void:
	if _is_selecting:
		return
	_is_selecting = true
	skipped.emit()
	_close()

## Adapta el tamaño del contenedor raíz de recompensas cuando cambia la resolución de la ventana.
func _layout_for_viewport() -> void:
	var vp_size := get_viewport_rect().size
	size = vp_size
	custom_minimum_size = vp_size
	if is_instance_valid(_root_panel):
		_root_panel.custom_minimum_size = vp_size
	if is_instance_valid(_center_container):
		_center_container.custom_minimum_size = vp_size
