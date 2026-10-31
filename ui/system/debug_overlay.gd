## Herramienta de depuración (QA y Testing) superpuesta.
## Proporciona un panel oculto activado por las teclas `F3` y `F4` que permite manipular
## el estado en tiempo real (inyectar oro, vida, alterar la suerte, 
## aplicar estados alterados a enemigos o forzar reliquias) sin tener que reiniciar la partida.
extends Control
class_name DebugOverlay

## Referencia en memoria al controlador visual de la mesa de combate.
var table: Control = null
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
## Columna 1: Trucos sobre el Jugador.
## Columna 2: Trucos de Combate y Avance por el mapa.
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

	# --- COLUMNA 2: COMBATE, EXPLORACIÓN Y ARMAS ---
	var col2 := VBoxContainer.new()
	col2.position = Vector2(348, 56)
	col2.custom_minimum_size = Vector2(290, 420)
	col2.add_theme_constant_override("separation", 8)
	panel.add_child(col2)

	col2.add_child(_make_section_label("2. COMBATE & MAPA"))
	col2.add_child(_make_action_btn("INSTA-KILL Enemigo", _on_instakill_enemy))
	col2.add_child(_make_action_btn("Revelar Todo el Mapa", _on_reveal_map))
	col2.add_child(_make_action_btn("Mostrar / Ocultar Mapa", _on_toggle_map_view))
	
	# Agregamos la sub-sección de armas en la columna 2
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	col2.add_child(spacer)
	col2.add_child(_make_section_label(">> EQUIPAR ARMAS"))
	
	weapons_box = VBoxContainer.new()
	weapons_box.add_theme_constant_override("separation", 8)
	
	# ScrollContainer para las armas por si tenés muchas
	var scroll_weapons = ScrollContainer.new()
	scroll_weapons.custom_minimum_size = Vector2(290, 180)
	scroll_weapons.add_child(weapons_box)
	col2.add_child(scroll_weapons)

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
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(300, 38)
		btn.text = "+ " + relic.title
		btn.tooltip_text = relic.get_effects_description()
		btn.pressed.connect(func(): _on_give_relic(relic))
		relics_box.add_child(btn)
		

func _make_section_label(txt: String) -> Label:
	var lbl := Label.new()
	lbl.text = txt
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.78, 1.0))
	return lbl

func _make_action_btn(txt: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.custom_minimum_size = Vector2(290, 38)
	btn.add_theme_font_size_override("font_size", 13)
	btn.pressed.connect(callback)
	return btn
	
	
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
	if not weapons_box or not run:
		return
	for child in weapons_box.get_children():
		child.queue_free()

	if "weapon_catalog" in run:
		for weapon: WeaponData in run.weapon_catalog:
			var btn := Button.new()
			btn.custom_minimum_size = Vector2(280, 32)
			
			# Marcamos visualmente si es el arma que tenemos equipada
			if run.current_weapon and run.current_weapon.weapon_id == weapon.weapon_id:
				btn.text = "[E] " + weapon.weapon_name
				btn.self_modulate = Color(0.2, 1.0, 0.5)
			else:
				btn.text = weapon.weapon_name
				btn.self_modulate = Color(1.0, 1.0, 1.0)
				
			btn.pressed.connect(func(): _on_equip_weapon(weapon))
			weapons_box.add_child(btn)



# --- LOGICA DE ACCIONES DE DEBUG (100% ENCAPSULADA AQUI) ---

## Activa o desactiva la invulnerabilidad total.
## Establece la salud máxima, fija la energía y descartes en `99`, 
## deshace la niebla de guerra en el mapa y permite clickear en salas no adyacentes.
func _on_toggle_god_mode() -> void:
	if not run or not table or not director:
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
	if not table:
		return
	table.current_energy += 5
	table.refresh_ui()
	log_label.text = "+5 de Energia agregada al turno actual."

## Inyecta `+2` estáticos al atributo de suerte (`player_luck`), recalculando e
## imprimiendo matemáticamente cómo afecta al algoritmo del `RaritySystem`.
func _on_add_luck() -> void:
	if not run or not table or not director:
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
	if not run or not table or not director:
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
	if not table:
		return
	table.draw_cards(1)
	table.refresh_ui()

	log_label.text = "Robaste +1 carta del Mazo."
	
## Restaura inmediatamente los puntos de golpe del héroe a su límite máximo actual.
func _on_heal_full() -> void:
	if not run or not table:
		return
	run.player_hp = run.max_player_hp
	table.refresh_ui()
	log_label.text = "HP restaurado al maximo (%d/%d)." % [run.player_hp, run.max_player_hp]
## Reduce drásticamente la vida del héroe a `1 HP`.
func _on_set_one_hp() -> void:
	if not run or not table:
		return
	run.player_hp = 1
	table.refresh_ui()
	log_label.text = "Jugador dejado en 1 HP (desactiva God Mode si quieres probar el Game Over)."
	
## Suma fichas temporales para probar la mecánica táctica de descarte de cartas.
func _on_add_discards() -> void:
	if not table:
		return
	table.discards_remaining += 3
	table.refresh_ui()
	log_label.text = "+3 Descartes agregados a este combate."
	
## Dispara `99999` de daño directo al enemigo actual, forzando la emisión inmediata de la señal `combat_won`.
func _on_instakill_enemy() -> void:
	if not table or not director:
		return
	if table.is_resolving or director.map_view.visible or director.main_menu.visible:
		return
	panel.visible = false
	table.enemy.take_damage(99999)
	table.refresh_ui()
	table.combat_won.emit()
	log_label.text = "Enemigo eliminado instantaneamente!"
	
## Inyecta el estado Quemadura (+5) y Veneno (+5) simultáneamente.
func _on_status_enemy() -> void:
	if not table or not table.enemy:
		return
	table.enemy.add_statuses(5, 5)
	table.refresh_ui()
	log_label.text = "Aplicado +5 Quemadura y +5 Veneno al enemigo actual."
## Pone a todas las celdas de la planta matemática como `discovered = true` 
## y rompe las reglas de adyacencia (`free_travel_enabled = true`).
func _on_reveal_map() -> void:
	if not run or not director:
		return
	run.reveal_entire_floor()
	director.map_view.free_travel_enabled = true
	director.open_map("[DEBUG] Niebla de guerra eliminada y Viaje Libre habilitado.")
	log_label.text = "Mapa 7x7 completamente revelado y desbloqueado."
## Busca la celda catalogada como `BOSS` dentro del diccionario del mapa actual,
## teletransporta la posición del héroe y lo arroja directamente a la `BattleTable`.
func _on_fight_boss_now() -> void:
	if not table or not run or not director:
		return
	panel.visible = false
	director.main_menu.visible = false
	director.map_view.visible = false
	var rooms: Dictionary = run.floor_data.get("rooms", {})
	for pos in rooms.keys():
		var r: RoomData = rooms[pos]
		if r.room_type == RoomData.Type.BOSS:
			run.player_grid_pos = pos
			run.current_room = r
			break
	table.start_combat_encounter(true)
## Purga el nivel actual e invoca el generador procedural 
## para crear la siguiente planta topológica, asignando una nueva sub-semilla.
func _on_next_floor() -> void:
	if not run or not director:
		return
	run.start_floor(run.current_floor + 1)
	if run.god_mode:
		run.reveal_entire_floor()
		director.map_view.free_travel_enabled = true
	director.open_map("[DEBUG] Saltaste directo a la Planta %d!" % run.current_floor)
	log_label.text = "Generada Planta %d con nueva sub-semilla." % run.current_floor
## Intercambia violentamente las vistas del orquestador (Facade) entre el combate y el mapa topológico.
func _on_toggle_map_view() -> void:
	if not director or not director.map_view:
		return
	if director.map_view.visible:
		director.map_view.visible = false
		log_label.text = "Vista de Mapa ocultada (mostrando Mesa de Combate)."
	else:
		director.open_map("[DEBUG] Mapa abierto manualmente.")
		log_label.text = "Vista de Mapa abierta."
## Conecta con el catálogo de Reliquias y equipa la especificada. Llama a `trigger_on_combat_start()`
##  inmediatamente si el jugador ya se encuentra en batalla.
func _on_give_relic(relic: RelicData) -> void:
	if not run or not table or not director:
		return
	run.equip_specific_relic(relic, table.enemy)
	table.refresh_ui()
	if director.map_view.visible:
		director.open_map("[DEBUG] Reliquia inyectada: " + relic.get_effects_description())
	log_label.text = "Equipada reliquia: %s" % relic.get_inspector_text()
## Elimina forzosamente todas las reliquias en inventario y resetea atributos estáticos del héroe
##  (Energía, Suerte, Descartes y Tamaño de Mano) a sus valores vanilla.
func _on_clear_relics() -> void:
	if not run or not table or not director:
		return
	run.active_relics.clear()
	run.max_energy = 3
	run.target_hand_size = 5
	run.discards_per_combat = 2
	run.player_luck = 0
	table.refresh_ui()
	if director.map_view.visible:
		director.open_map("[DEBUG] Reliquias eliminadas y stats base reseteados.")
	log_label.text = "Todas las reliquias fueron removidas."
## Inyecta el estado (Stun acumulativo).
func _on_freeze_enemy() -> void:
	if not table or not table.enemy:
		return
	table.enemy.freeze += 3
	table.refresh_ui()
	log_label.text = "Aplicado +3 Congelamiento al enemigo actual (Total: %d)." % table.enemy.freeze
## Inyecta daño residual constante al fin de cada turno enemigo.
func _on_burn_enemy() -> void:
	if not table or not table.enemy:
		return
	table.enemy.burn += 3
	table.refresh_ui()
	log_label.text = "Aplicado +3 Quemadura al enemigo actual (Total: %d)." % table.enemy.burn
## Inyecta daño residual escalado por porcentajes según el HP faltante.
func _on_poison_enemy() -> void:
	if not table or not table.enemy:
		return
	table.enemy.poison += 3
	table.refresh_ui()
	log_label.text = "Aplicado +3 Veneno al enemigo actual (Total: %d)." % table.enemy.poison
## Inyecta la condición que aturde temporalmente a un enemigo paralizando su turno, 
## dependiente de un chequeo dinámico de Suerte (`player_luck`).
func _on_shock_enemy() -> void:
	if not table or not table.enemy or not run:
		return
	table.enemy.shock += 3
	table.refresh_ui()
	var pct: int = int(round(table.enemy.get_shock_stun_chance(run.player_luck) * 100.0))
	log_label.text = "Aplicado +3 Electrocutado (Total: %d | Suerte: %d -> %d%% chance de Stun)." % [
		table.enemy.shock, run.player_luck, pct
	]
	
## Inyecta daño físico residual desencadenado únicamente si la unidad ataca (o recibe ataques).
func _on_hemorrhage_enemy() -> void:
	if not table or not table.enemy:
		return
	table.enemy.hemorrhage += 3
	table.refresh_ui()
	log_label.text = "Aplicado +3 Hemorragia al enemigo actual (Total: %d)." % table.enemy.hemorrhage

func _on_add_str() -> void:
	if not run or not table: return
	run.player_str += 1
	table.refresh_ui()
	log_label.text = "Fuerza (STR) aumentada a %d." % run.player_str

func _on_add_int() -> void:
	if not run or not table: return
	run.player_int += 1
	table.refresh_ui()
	log_label.text = "Inteligencia (INT) aumentada a %d." % run.player_int

func _on_add_dex() -> void:
	if not run or not table: return
	run.player_dex += 1
	table.refresh_ui()
	log_label.text = "Destreza (DEX) aumentada a %d." % run.player_dex

func _on_equip_weapon(weapon: WeaponData) -> void:
	if not run or not table: return
	
	if run.has_method("equip_weapon"):
		run.equip_weapon(weapon)
	else:
		run.current_weapon = weapon
		
	# Refrescamos la UI para ver cómo cambian los números en el Preview
	table.refresh_ui() 
	
	# Regeneramos la lista para mover el marcador "[E]" de arma equipada
	_rebuild_weapon_buttons() 
	
	log_label.text = "Arma equipada: %s (Daño Base: %d)" % [weapon.weapon_name, weapon.base_damage]
