## Herramienta de depuración (QA y Testing) superpuesta.
## Proporciona un panel oculto activado por las teclas `F3` y `F4` que permite manipular
## el estado en tiempo real (inyectar oro, vida, alterar la suerte, 
## aplicar estados alterados a enemigos o forzar reliquias) sin tener que reiniciar la partida.
extends Control
class_name DebugOverlay

## Referencia en memoria al controlador visual de la mesa de combate.
var table: Variant = null
## Referencia en memoria al estado lógico de la expedición (inventario, semillas, vida, pisos).
var run: RunState = null
## Referencia en memoria al orquestador principal del juego (para transiciones de escena forzadas).
var director: RunDirector = null
# Referencia para la lista de armas
var weapons_box: VBoxContainer
var toggle_badge_btn: Button
var panel: Panel
var god_mode_btn: Button
var log_label: Label
var relics_box: VBoxContainer

## Constructor de la interfaz de depuración.
## Ensambla por código un botón flotante pequeño en la esquina superior izquierda,
## y un panel modal gigante centrado en pantalla que contiene columnas de botones para manipular el estado.
func _init() -> void:
	name = "DebugOverlay"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 200
	process_mode = Node.PROCESS_MODE_ALWAYS

	toggle_badge_btn = Button.new()
	toggle_badge_btn.text = "[F3] DEBUG"
	toggle_badge_btn.position = Vector2(10, 6)
	toggle_badge_btn.size = Vector2(140, 26)
	toggle_badge_btn.add_theme_font_size_override("font_size", 12)
	toggle_badge_btn.pressed.connect(toggle_panel)
	add_child(toggle_badge_btn)

	panel = Panel.new()
	panel.position = Vector2(76, 42)
	panel.size = Vector2(1000, 540)
	panel.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.09, 0.96)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.2, 0.9, 0.55)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var header := Label.new()
	header.text = "PANEL DE DESARROLLO & DEBUG (Presiona F3 para abrir/cerrar)"
	header.position = Vector2(24, 14)
	header.size = Vector2(950, 28)
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color(0.2, 0.95, 0.6))
	panel.add_child(header)

	log_label = Label.new()
	log_label.text = "Listo para debuguear. Usa los botones de abajo en cualquier momento (Mapa o Combate)."
	log_label.position = Vector2(24, 495)
	log_label.size = Vector2(950, 30)
	log_label.add_theme_font_size_override("font_size", 14)
	log_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	panel.add_child(log_label)

	_build_columns()
## Enlaza las dependencias de negocio (Mesa, Estado, Orquestador) al overlay 
## para que las acciones de depuración puedan modificar los datos reales de la partida.
func bind_context(p_table: Control, p_run: RunState, p_director: RunDirector) -> void:
	table = p_table
	run = p_run
	director = p_director
	_rebuild_relic_buttons()
	_refresh_god_mode_visuals()
## Intercepta globalmente las pulsaciones de teclado:
## - `F3`: Alterna la visibilidad del panel gigante de depuración.
## - `F4`: Alterna la visibilidad de TODA la herramienta (incluyendo el botón de la esquina).
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F3:
			# Si todo el overlay estaba oculto, lo volvemos a mostrar al tocar F3
			visible = true
			toggle_panel()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F4:
			# F4 oculta/muestra TODO (el botón [F3] DEBUG de la esquina y el panel)
			visible = not visible
			get_viewport().set_input_as_handled()
			
## Abre o cierra el panel principal de opciones. Al abrirse, regenera la lista de botones
## de reliquias por si se modificó el catálogo desde el editor de Godot.
func toggle_panel() -> void:
	panel.visible = not panel.visible
	if panel.visible:
		_rebuild_relic_buttons()
		_rebuild_weapon_buttons()
		_refresh_god_mode_visuals()
		
## Construye las 3 columnas principales de botones inyectando las lógicas agrupadas:
## Columna 1: God Mode y estadísticas RPG del jugador (STR, INT, DEX, LUCK, Energía, Oro, HP).
## Columna 2: Trucos de Combate, estados alterados, avance por el mapa e inyector de Armas.
## Columna 3: Inyector directo de Reliquias permanentes.
func _build_columns() -> void:
	# --- COLUMNA 1: GOD MODE & STATS RPG ---
	var col1 := VBoxContainer.new()
	col1.position = Vector2(24, 56)
	col1.custom_minimum_size = Vector2(290, 420)
	col1.add_theme_constant_override("separation", 8)
	panel.add_child(col1)

	col1.add_child(_make_section_label("1. GOD MODE & STATS RPG"))

	god_mode_btn = Button.new()
	god_mode_btn.custom_minimum_size = Vector2(290, 42)
	god_mode_btn.pressed.connect(_on_toggle_god_mode)
	col1.add_child(god_mode_btn)

	col1.add_child(_make_action_btn("+1 Fuerza (STR)", _on_add_str))
	col1.add_child(_make_action_btn("+1 Inteligencia (INT)", _on_add_int))
	col1.add_child(_make_action_btn("+1 Destreza (DEX)", _on_add_dex))
	col1.add_child(_make_action_btn("+2 Suerte (LUCK)", _on_add_luck))
	col1.add_child(_make_action_btn("+5 Energia en este Turno", _on_add_energy))
	col1.add_child(_make_action_btn("+100 Monedas (Gold)", _on_add_gold))
	col1.add_child(_make_action_btn("Curar Full HP", _on_heal_full))
	col1.add_child(_make_action_btn("Dejar en 1 HP", _on_set_one_hp))

	# --- COLUMNA 2: COMBATE, EXPLORACIÓN Y ARMAS ---
	var col2 := VBoxContainer.new()
	col2.position = Vector2(348, 56)
	col2.custom_minimum_size = Vector2(290, 420)
	col2.add_theme_constant_override("separation", 8)
	panel.add_child(col2)

	col2.add_child(_make_section_label("2. COMBATE & MAPA"))

	# Todas las acciones de esta columna comparten un solo scroll para que
	# también estén disponibles los controles de estados y el catálogo de armas.
	var actions_scroll := ScrollContainer.new()
	actions_scroll.custom_minimum_size = Vector2(290, 390)
	col2.add_child(actions_scroll)
	var actions_content := VBoxContainer.new()
	actions_content.add_theme_constant_override("separation", 6)
	actions_scroll.add_child(actions_content)

	actions_content.add_child(_make_action_btn("INSTA-KILL Enemigo", _on_instakill_enemy))
	actions_content.add_child(_make_action_btn("Revelar todo el mapa", _on_reveal_map))
	actions_content.add_child(_make_action_btn("Mostrar / Ocultar mapa (el mapa mismo)", _on_toggle_map_view))
	actions_content.add_child(_make_action_btn("Robar +1 carta", _on_draw_card))
	actions_content.add_child(_make_action_btn("+3 descartes", _on_add_discards))
	actions_content.add_child(_make_action_btn("Aplicar +5 Quemadura y Veneno", _on_status_enemy))
	actions_content.add_child(_make_action_btn("+3 Congelamiento", _on_freeze_enemy))
	actions_content.add_child(_make_action_btn("+3 Quemadura", _on_burn_enemy))
	actions_content.add_child(_make_action_btn("+3 Veneno", _on_poison_enemy))
	actions_content.add_child(_make_action_btn("+3 Electrocución", _on_shock_enemy))
	actions_content.add_child(_make_action_btn("+3 Hemorragia", _on_hemorrhage_enemy))
	actions_content.add_child(_make_action_btn("Combatir jefe ahora", _on_fight_boss_now))
	actions_content.add_child(_make_action_btn("Saltar a la siguiente planta", _on_next_floor))

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	actions_content.add_child(spacer)
	actions_content.add_child(_make_section_label(">> EQUIPAR ARMAS"))

	weapons_box = VBoxContainer.new()
	weapons_box.add_theme_constant_override("separation", 6)
	actions_content.add_child(weapons_box)

	# --- COLUMNA 3: INYECTAR RELIQUIAS ---
	var col3 := VBoxContainer.new()
	col3.position = Vector2(672, 56)
	col3.custom_minimum_size = Vector2(300, 420)
	col3.add_theme_constant_override("separation", 8)
	panel.add_child(col3)

	col3.add_child(_make_section_label("3. INYECTAR RELIQUIAS"))

	relics_box = VBoxContainer.new()
	relics_box.add_theme_constant_override("separation", 8)
	
	var scroll_relics = ScrollContainer.new()
	scroll_relics.custom_minimum_size = Vector2(300, 320)
	scroll_relics.add_child(relics_box)
	col3.add_child(scroll_relics)

	col3.add_child(_make_action_btn("Quitar Todas las Reliquias", _on_clear_relics))
## Lee el catálogo estático completo de reliquias y genera dinámicamente un botón por cada una
## para equiparla instantáneamente en el jugador y probar interacciones.
func _rebuild_relic_buttons() -> void:
	if not relics_box or not run:
		return
	for child in relics_box.get_children():
		child.queue_free()

	for relic: RelicData in run.relic_catalog:
		if relic == null:
			continue
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(300, 38)
		btn.text = "+ " + relic.title
		btn.tooltip_text = relic.get_effects_description()
		btn.pressed.connect(_on_give_relic.bind(relic))
		relics_box.add_child(btn)
		

## Crea una etiqueta estilizada de cabecera para separar secciones dentro de las columnas del panel de depuración.
func _make_section_label(txt: String) -> Label:
	var lbl := Label.new()
	lbl.text = txt
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.78, 1.0))
	return lbl

## Instancia un botón de acción estándar del panel de depuración y conecta su pulsación al `callback` indicado.
func _make_action_btn(txt: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.custom_minimum_size = Vector2(290, 38)
	btn.add_theme_font_size_override("font_size", 13)
	btn.pressed.connect(callback)
	return btn
	
	
## Sincroniza el texto y color del botón de God Mode y de la insignia `[F3]` según el estado activo en `RunState`.
func _refresh_god_mode_visuals() -> void:
	var active: bool = run != null and run.god_mode
	if god_mode_btn:
		god_mode_btn.text = "GOD MODE: ACTIVADO (ON)" if active else "GOD MODE: DESACTIVADO (OFF)"
		god_mode_btn.self_modulate = Color(0.25, 1.0, 0.45) if active else Color(0.85, 0.85, 0.85)
	if toggle_badge_btn:
		toggle_badge_btn.text = "[F3] GOD MODE ON" if active else "[F3] DEBUG"
		toggle_badge_btn.self_modulate = Color(0.25, 1.0, 0.45) if active else Color(1.0, 1.0, 1.0)

## Genera botones dinámicos para equipar armas desde el catálogo
func _rebuild_weapon_buttons() -> void:
	if weapons_box == null or run == null:
		return
	for child in weapons_box.get_children():
		child.queue_free()

	if run.weapon_catalog.is_empty():
		run.weapon_catalog = GameDatabase.load_all_weapons()

	for weapon: WeaponData in run.weapon_catalog:
		if weapon == null:
			continue
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(280, 32)

		var is_in_inventory: bool = false
		for owned_weapon: WeaponData in run.inventory_weapons:
			if owned_weapon and owned_weapon.weapon_id != "" and owned_weapon.weapon_id == weapon.weapon_id:
				is_in_inventory = true
				break

		if run.current_weapon and run.current_weapon.weapon_id != "" and run.current_weapon.weapon_id == weapon.weapon_id:
			btn.text = "[EQUIPADA] " + weapon.weapon_name
			btn.self_modulate = Color(0.2, 1.0, 0.5)
		elif is_in_inventory:
			btn.text = "[MOCHILA] " + weapon.weapon_name
		else:
			btn.text = weapon.weapon_name
			btn.self_modulate = Color(1.0, 1.0, 1.0)

		btn.pressed.connect(_on_equip_weapon.bind(weapon))
		weapons_box.add_child(btn)


# --- VALIDACIONES Y REFRESCO ---

## Verifica si existe una partida activa y jugable (fuera de menús de inicio/pausa y con el héroe con vida).
func _has_active_run() -> bool:
	if run == null or run.floor_data.is_empty() or run.is_player_dead():
		return false
	if director == null:
		return true
	if director.main_menu and director.main_menu.visible:
		return false
	if director.hero_select_view and director.hero_select_view.visible:
		return false
	if director.slot_view and director.slot_view.visible:
		return false
	if director.pause_menu and director.pause_menu.visible:
		return false
	return true

## Comprueba si es seguro mutar el estado de la run (hay partida activa y la mesa no está resolviendo animaciones).
func _can_modify_run() -> bool:
	# Evita modificar atributos, reliquias o equipo mientras una corrutina
	# está resolviendo cartas/estados del combate.
	return _has_active_run() and (table == null or not table.is_resolving)

## Evalúa si el jugador se encuentra actualmente dentro de un encuentro de combate activo y visible.
func _is_active_combat() -> bool:
	if table == null or table.enemy == null or table.enemy.is_dead() or table.is_resolving:
		return false
	if director == null:
		return true
	return not director.map_view.visible \
		and not director.main_menu.visible \
		and not director.hero_select_view.visible \
		and not director.shop_view.visible \
		and not director.slot_view.visible \
		and not director.pause_menu.visible

## Refresca la interfaz de combate y/o la vista del mapa tras aplicar una modificación desde el panel de debug.
func _refresh_after_run_change() -> void:
	if table and table.enemy:
		table.refresh_ui()
	if director and director.map_view and director.map_view.visible:
		director.open_map()

# --- LOGICA DE ACCIONES DE DEBUG (100% ENCAPSULADA AQUI) ---

## Activa o desactiva la invulnerabilidad total.
## Establece la salud máxima, fija la energía y descartes en `99`, 
## deshace la niebla de guerra en el mapa y permite clickear en salas no adyacentes.
func _on_toggle_god_mode() -> void:
	if not _can_modify_run() or not table or not director:
		log_label.text = "Inicia una partida antes de activar God Mode."
		return
	run.god_mode = not run.god_mode
	if run.god_mode:
		table.current_energy = 99
		table.discards_remaining = 99
		run.player_hp = run.max_player_hp
		run.reveal_entire_floor()
		director.map_view.free_travel_enabled = true
	else:
		table.current_energy = min(table.current_energy, run.max_energy)
		table.discards_remaining = min(table.discards_remaining, run.discards_per_combat)
		director.map_view.free_travel_enabled = false
	table.refresh_ui()
	if director.map_view.visible:
		director.open_map()
	_refresh_god_mode_visuals()
	log_label.text = "GOD MODE %s (Invulnerable, 99 Energia, 99 Descartes y Mapa Destapado)." % (
		"ACTIVADO" if run.god_mode else "DESACTIVADO"
	)
	
## Suma temporalmente +5 energia al jugador, ignorando su límite máximo, para probar combos largos.
func _on_add_energy() -> void:
	if not _is_active_combat():
		log_label.text = "Esta acción solo está disponible durante un combate."
		return
	table.current_energy += 5
	table.refresh_ui()
	log_label.text = "+5 de Energia agregada al turno actual."

## Inyecta `+2` estáticos al atributo de suerte (`player_luck`), recalculando e
## imprimiendo matemáticamente cómo afecta al algoritmo del `RaritySystem`.
func _on_add_luck() -> void:
	if not _can_modify_run() or not table or not director:
		return
	run.player_luck += 2
	table.refresh_ui()
	if director.map_view.visible:
		director.open_map("[DEBUG] Suerte aumentada a %d!" % run.player_luck)
	log_label.text = "Suerte +2 (Actual: %d) -> Probabilidades: %s" % [
		run.player_luck, RaritySystem.get_probabilities_summary(run.current_floor, run.player_luck)
	]
## Suma 100 de oro al tesoro del jugador. Si la tienda está abierta en ese momento,
## emite un re-cálculo para que se habiliten dinámicamente los botones de compra bloqueados.
func _on_add_gold() -> void:
	if not _can_modify_run() or not table or not director:
		return
	run.player_gold += 100
	table.refresh_ui()
	if director.shop_view and director.shop_view.visible:
		director.shop_view.update_after_purchase(run.player_gold)
	if director.map_view.visible:
		director.open_map("[DEBUG] Oro aumentado a %d!" % run.player_gold)
	log_label.text = "Oro +100 (Actual: %d)" % run.player_gold
	
## Fuerza al `DeckManager` a robar una carta al instante y colocarla en el `CardBoardController`.
func _on_draw_card() -> void:
	if not _is_active_combat():
		log_label.text = "Solo puedes robar cartas durante un combate."
		return
	table.draw_cards(1)
	table.refresh_ui()

	log_label.text = "Robaste +1 carta del Mazo."
	
## Restaura inmediatamente los puntos de golpe del héroe a su límite máximo actual.
func _on_heal_full() -> void:
	if not _can_modify_run() or not table:
		return
	run.player_hp = run.max_player_hp
	_refresh_after_run_change()
	log_label.text = "HP restaurado al maximo (%d/%d)." % [run.player_hp, run.max_player_hp]
## Reduce drásticamente la vida del héroe a `1 HP`.
func _on_set_one_hp() -> void:
	if not _can_modify_run() or not table:
		return
	run.player_hp = 1
	_refresh_after_run_change()
	log_label.text = "Jugador dejado en 1 HP (desactiva God Mode si quieres probar el Game Over)."
	
## Suma fichas temporales para probar la mecánica táctica de descarte de cartas.
func _on_add_discards() -> void:
	if not _is_active_combat():
		log_label.text = "Solo puedes agregar descartes durante un combate."
		return
	table.discards_remaining += 3
	table.refresh_ui()
	log_label.text = "+3 Descartes agregados a este combate."
	
## Dispara `99999` de daño directo al enemigo actual, forzando la emisión inmediata de la señal `combat_won`.
func _on_instakill_enemy() -> void:
	if not _is_active_combat() or table.is_resolving:
		log_label.text = "No hay un combate activo para eliminar."
		return
	table.enemy.take_damage(99999)
	table.refresh_ui()
	# La señal delega la transición de victoria al RunDirector.
	table.combat_won.emit()
	panel.visible = false
	log_label.text = "Enemigo eliminado instantáneamente."
	
## Inyecta el estado Quemadura (+5) y Veneno (+5) simultáneamente.
func _on_status_enemy() -> void:
	if not _is_active_combat():
		log_label.text = "No hay un enemigo activo."
		return
	# Enemy.add_statuses recibe quemadura, veneno, congelamiento,
	# electrocución y hemorragia, en ese orden.
	table.enemy.add_statuses(5, 5, 0, 0, 0)
	table.refresh_ui()
	log_label.text = "Aplicado +5 Quemadura y +5 Veneno al enemigo actual."
## Pone a todas las celdas de la planta matemática como `discovered = true` 
## y rompe las reglas de adyacencia (`free_travel_enabled = true`).
func _on_reveal_map() -> void:
	if not _can_modify_run() or not director:
		log_label.text = "Inicia una partida antes de revelar el mapa."
		return
	run.reveal_entire_floor()
	director.map_view.free_travel_enabled = true
	director.open_map("[DEBUG] Niebla de guerra eliminada y Viaje Libre habilitado.")
	log_label.text = "Mapa 7x7 completamente revelado y desbloqueado."
## Busca la celda catalogada como `BOSS` dentro del diccionario del mapa actual,
## teletransporta la posición del héroe y lo arroja directamente a la `BattleTable`.
func _on_fight_boss_now() -> void:
	if not _has_active_run() or not table or not director:
		return
	if table.is_resolving:
		log_label.text = "Espera a que termine la acción actual antes de iniciar el jefe."
		return
	var rooms: Dictionary = run.floor_data.get("rooms", {})
	var boss_room: RoomData = null
	for pos in rooms.keys():
		var room: RoomData = rooms[pos] as RoomData
		if room and room.room_type == RoomData.Type.BOSS and not room.cleared:
			boss_room = room
			break
	if boss_room == null:
		log_label.text = "No se encontró un jefe pendiente en esta planta."
		return

	run.player_grid_pos = boss_room.grid_pos
	run.current_room = boss_room
	director.main_menu.visible = false
	director.shop_view.visible = false
	director.map_view.visible = false
	table.start_combat_encounter(true)
	panel.visible = false
	log_label.text = "Iniciando combate contra el jefe."
## Purga el nivel actual e invoca el generador procedural 
## para crear la siguiente planta topológica, asignando una nueva sub-semilla.
func _on_next_floor() -> void:
	if not _has_active_run() or not director or not table:
		return
	if table.is_resolving:
		log_label.text = "No puedes cambiar de planta mientras se resuelve un turno."
		return
	# Devolvemos al mazo las cartas que quedaron en mano/combo antes de saltar.
	if table.board:
		var remaining_cards: Array[CardData] = table.board.clear_all_and_extract_data()
		table.deck.reset_for_new_combat(remaining_cards)
	table.player_block = 0
	table.is_resolving = false
	table.attack_button.disabled = false

	run.start_floor(run.current_floor + 1)
	director.map_view.free_travel_enabled = run.god_mode
	if run.god_mode:
		run.reveal_entire_floor()
	director.shop_view.visible = false
	director.open_map("[DEBUG] Saltaste directo a la Planta %d!" % run.current_floor)
	log_label.text = "Generada Planta %d con nueva sub-semilla." % run.current_floor
## Intercambia violentamente las vistas del orquestador (Facade) entre el combate y el mapa topológico.
func _on_toggle_map_view() -> void:
	if not _can_modify_run() or not director or not director.map_view:
		log_label.text = "No hay una partida disponible para cambiar de vista."
		return
	if director.map_view.visible:
		director.map_view.visible = false
		log_label.text = "Vista de Mapa ocultada (mostrando Mesa de Combate)."
	else:
		director.shop_view.visible = false
		director.open_map("[DEBUG] Mapa abierto manualmente.")
		log_label.text = "Vista de Mapa abierta."
## Conecta con el catálogo de Reliquias y equipa la especificada. Llama a `trigger_on_combat_start()`
##  inmediatamente si el jugador ya se encuentra en batalla.
func _on_give_relic(relic: RelicData) -> void:
	if not _can_modify_run() or not table or not director or relic == null:
		return
	run.equip_specific_relic(relic, table.enemy)
	table.refresh_ui()
	if director.map_view.visible:
		director.open_map("[DEBUG] Reliquia inyectada: " + relic.get_effects_description())
	log_label.text = "Equipada reliquia: %s" % relic.get_inspector_text()
## Elimina forzosamente todas las reliquias en inventario y resetea los atributos base del héroe
## (Vida Máxima, Energía, Descartes y Suerte) a sus valores iniciales de clase.
func _on_clear_relics() -> void:
	if not _can_modify_run() or not table or not director:
		return
	run.active_relics.clear()

	# Restauramos las bases del héroe actual, no valores globales fijos.
	# Esto evita que un Mago/Guerrero pierda sus atributos iniciales al testear.
	if run.selected_hero:
		run.max_player_hp = run.selected_hero.max_hp_base
		run.max_energy = run.selected_hero.energy_base
		run.target_hand_size = run.selected_hero.hand_size
		run.discards_per_combat = run.selected_hero.discards_base
		run.player_luck = run.selected_hero.lucky
	else:
		run.max_player_hp = CombatConstants.BASE_HEALTH
		run.max_energy = CombatConstants.BASE_MAX_ENERGY
		run.target_hand_size = CombatConstants.BASE_HAND_SIZE
		run.discards_per_combat = CombatConstants.BASE_DISCARDS_PER_COMBAT
		run.player_luck = CombatConstants.BASE_LUCKY
	run.player_hp = min(run.player_hp, run.max_player_hp)
	table.current_energy = min(table.current_energy, run.max_energy)
	table.discards_remaining = min(table.discards_remaining, run.discards_per_combat)
	_refresh_after_run_change()
	log_label.text = "Reliquias eliminadas; estadísticas base del héroe restauradas."
## Inyecta el estado (Stun acumulativo).
func _on_freeze_enemy() -> void:
	if not _is_active_combat():
		log_label.text = "No hay un enemigo activo."
		return
	table.enemy.freeze += 3
	table.refresh_ui()
	log_label.text = "Aplicado +3 Congelamiento al enemigo actual (Total: %d)." % table.enemy.freeze
## Inyecta daño residual constante al fin de cada turno enemigo.
func _on_burn_enemy() -> void:
	if not _is_active_combat():
		log_label.text = "No hay un enemigo activo."
		return
	table.enemy.burn += 3
	table.refresh_ui()
	log_label.text = "Aplicado +3 Quemadura al enemigo actual (Total: %d)." % table.enemy.burn
## Inyecta +3 acumulaciones de Veneno (daño directo por turno con decaimiento lineal) al enemigo activo.
func _on_poison_enemy() -> void:
	if not _is_active_combat():
		log_label.text = "No hay un enemigo activo."
		return
	table.enemy.poison += 3
	table.refresh_ui()
	log_label.text = "Aplicado +3 Veneno al enemigo actual (Total: %d)." % table.enemy.poison
## Inyecta +3 acumulaciones de Electrocutado (probabilidad de aturdir al enemigo en su turno escalada con `player_luck`).
func _on_shock_enemy() -> void:
	if not _is_active_combat() or not run:
		log_label.text = "No hay un enemigo activo."
		return
	table.enemy.shock += 3
	table.refresh_ui()
	var pct: int = int(round(table.enemy.get_shock_stun_chance(run.player_luck) * 100.0))
	log_label.text = "Aplicado +3 Electrocutado (Total: %d | Suerte: %d -> %d%% chance de Stun)." % [
		table.enemy.shock, run.player_luck, pct
	]
	
## Inyecta +3 acumulaciones de Hemorragia (daño por sangrado con estallido porcentual al alcanzar el umbral dinámico).
func _on_hemorrhage_enemy() -> void:
	if not _is_active_combat():
		log_label.text = "No hay un enemigo activo."
		return
	table.enemy.hemorrhage += 3
	table.refresh_ui()
	log_label.text = "Aplicado +3 Hemorragia al enemigo actual (Total: %d)." % table.enemy.hemorrhage

## Incrementa en +1 la estadística permanente de Fuerza (`player_str`) del héroe durante la run actual.
func _on_add_str() -> void:
	if not _can_modify_run() or not table: return
	run.player_str += 1
	_refresh_after_run_change()
	log_label.text = "Fuerza (STR) aumentada a %d." % run.player_str

## Incrementa en +1 la estadística permanente de Inteligencia (`player_int`) del héroe durante la run actual.
func _on_add_int() -> void:
	if not _can_modify_run() or not table: return
	run.player_int += 1
	_refresh_after_run_change()
	log_label.text = "Inteligencia (INT) aumentada a %d." % run.player_int

## Incrementa en +1 la estadística permanente de Destreza (`player_dex`) del héroe durante la run actual.
func _on_add_dex() -> void:
	if not _can_modify_run() or not table: return
	run.player_dex += 1
	_refresh_after_run_change()
	log_label.text = "Destreza (DEX) aumentada a %d." % run.player_dex

## Agrega el arma seleccionada del catálogo a la mochila del jugador (`inventory_weapons`) y refresca los botones de equipo.
func _on_equip_weapon(weapon: WeaponData) -> void:
	if not _can_modify_run() or not table or weapon == null:
		return
	if not run.add_weapon_to_inventory(weapon):
		log_label.text = "No se pudo equipar %s. Revisá el espacio de la mochila." % weapon.weapon_name
		return

	table.refresh_ui()
	_rebuild_weapon_buttons()
	if director and director.map_view.visible:
		director.open_map()
	log_label.text = "Arma equipada: %s (Daño base: %d)" % [weapon.weapon_name, weapon.base_damage]
