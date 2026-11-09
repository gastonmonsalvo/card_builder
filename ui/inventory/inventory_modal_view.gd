## Modal unificado de Inventario General (`InventoryModalView`).
## Divide la pantalla en dos paneles paralelos:
## - Panel Izquierdo (`[ ⚔️ ARMAS Y EQUIPO ]`): muestra el Arma Equipada arriba y la Bolsa de Armas abajo (en grilla de 2 columnas con `WeaponUI` interactivas para equipar).
## - Panel Derecho (`[ 🔮 RELIQUIAS Y ATRIBUTOS ]`): muestra el bloque de Atributos del Jugador arriba y la Bolsa de Reliquias abajo (en grilla de 2 columnas con `RelicUI` y contador `"x1"` / `"xN"`).
class_name InventoryModalView
extends Control

signal weapon_selected_to_equip(weapon: WeaponData)

const WEAPON_SCENE: PackedScene = preload("res://ui/weapons/weapon_ui.tscn")
const RELIC_SCENE: PackedScene = preload("res://ui/relics/relic_ui.tscn")
const PANEL_SIZE := Vector2(1104.0, 612.0)
const PANEL_MARGIN := 12.0

var panel: PanelContainer
var equipped_slot_holder: VBoxContainer
var weapons_grid: GridContainer
var empty_backpack_label: Label
var stats_left_label: Label
var stats_right_label: Label
var relics_title_label: Label
var relics_grid: GridContainer
var empty_relics_label: Label
var close_btn: Button

## Configura el contenedor a pantalla completa, construye la interfaz interna del inventario general y la mantiene centrada ante cambios de resolución.
func _ready() -> void:
	name = "InventoryModalView"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	z_index = 200

	_build_ui()
	_center_panel()

	var viewport := get_viewport()
	if not viewport.size_changed.is_connected(_center_panel):
		viewport.size_changed.connect(_center_panel)

## Construye el layout de doble columna (`ARMAS Y EQUIPO` a la izquierda, `RELIQUIAS Y ATRIBUTOS` a la derecha) y la barra inferior.
func _build_ui() -> void:
	var background := ColorRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.02, 0.03, 0.05, 0.86)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(background)

	panel = PanelContainer.new()
	panel.size = PANEL_SIZE

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.08, 0.13, 0.98)
	panel_style.set_border_width_all(2)
	panel_style.border_color = Color(0.42, 0.72, 1.0)
	panel_style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	margin.add_child(main_vbox)

	# Cabecera Principal con Título Centrado y Botón [X] Arriba a la Derecha
	var header_bar := Control.new()
	header_bar.custom_minimum_size = Vector2(0, 34)
	header_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(header_bar)

	var title := Label.new()
	title.text = "INVENTARIO GENERAL"
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.32))
	header_bar.add_child(title)

	close_btn = Button.new()
	close_btn.text = "✕"
	close_btn.tooltip_text = "Cerrar Inventario (ESC)"
	close_btn.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	close_btn.offset_left = -36
	close_btn.offset_top = -16
	close_btn.offset_right = 0
	close_btn.offset_bottom = 16
	close_btn.add_theme_font_size_override("font_size", 15)
	close_btn.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
	close_btn.pressed.connect(_close_modal)
	header_bar.add_child(close_btn)

	var top_sep := HSeparator.new()
	main_vbox.add_child(top_sep)

	# Contenedor Principal en 2 Columnas Simétricas
	var body_hbox := HBoxContainer.new()
	body_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hbox.add_theme_constant_override("separation", 16)
	main_vbox.add_child(body_hbox)

	# ==========================================
	# PANEL IZQUIERDO: [ ⚔️ ARMAS Y EQUIPO ]
	# ==========================================
	var left_col := VBoxContainer.new()
	left_col.custom_minimum_size = Vector2(516, 0)
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_col.add_theme_constant_override("separation", 6)
	body_hbox.add_child(left_col)

	var left_header := _create_section_banner("[ ⚔️ ARMAS Y EQUIPO ]", Color(1.0, 0.82, 0.34))
	left_col.add_child(left_header)

	var left_scroll := ScrollContainer.new()
	left_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_col.add_child(left_scroll)

	var left_scroll_vbox := VBoxContainer.new()
	left_scroll_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll_vbox.add_theme_constant_override("separation", 10)
	left_scroll.add_child(left_scroll_vbox)

	var equipped_lbl := Label.new()
	equipped_lbl.text = "Arma Equipada:"
	equipped_lbl.add_theme_font_size_override("font_size", 14)
	equipped_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.38))
	left_scroll_vbox.add_child(equipped_lbl)

	equipped_slot_holder = VBoxContainer.new()
	equipped_slot_holder.alignment = BoxContainer.ALIGNMENT_CENTER
	equipped_slot_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll_vbox.add_child(equipped_slot_holder)

	var weapons_sep := HSeparator.new()
	left_scroll_vbox.add_child(weapons_sep)

	var bag_weapons_lbl := Label.new()
	bag_weapons_lbl.text = "Bolsa de Armas (Click para equipar):"
	bag_weapons_lbl.add_theme_font_size_override("font_size", 14)
	bag_weapons_lbl.add_theme_color_override("font_color", Color(0.48, 0.80, 1.0))
	left_scroll_vbox.add_child(bag_weapons_lbl)

	weapons_grid = GridContainer.new()
	weapons_grid.columns = 2
	weapons_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	weapons_grid.add_theme_constant_override("h_separation", 16)
	weapons_grid.add_theme_constant_override("v_separation", 14)
	left_scroll_vbox.add_child(weapons_grid)

	empty_backpack_label = Label.new()
	empty_backpack_label.text = "No tienes otras armas guardadas en la bolsa."
	empty_backpack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_backpack_label.add_theme_font_size_override("font_size", 13)
	empty_backpack_label.add_theme_color_override("font_color", Color(0.58, 0.64, 0.72))
	empty_backpack_label.visible = false
	left_scroll_vbox.add_child(empty_backpack_label)

	# Separador Central Vertical
	var center_vsep := VSeparator.new()
	body_hbox.add_child(center_vsep)

	# ==========================================
	# PANEL DERECHO: [ 🔮 RELIQUIAS Y ATRIBUTOS ]
	# ==========================================
	var right_col := VBoxContainer.new()
	right_col.custom_minimum_size = Vector2(516, 0)
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_col.add_theme_constant_override("separation", 6)
	body_hbox.add_child(right_col)

	var right_header := _create_section_banner("[ 🔮 RELIQUIAS Y ATRIBUTOS ]", Color(0.75, 0.52, 1.0))
	right_col.add_child(right_header)

	# Caja de Atributos del Jugador
	var stats_panel := PanelContainer.new()
	var stats_style := StyleBoxFlat.new()
	stats_style.bg_color = Color(0.09, 0.12, 0.18, 0.95)
	stats_style.set_border_width_all(1)
	stats_style.border_color = Color(0.35, 0.52, 0.78, 0.65)
	stats_style.set_corner_radius_all(6)
	stats_style.content_margin_left = 12
	stats_style.content_margin_right = 12
	stats_style.content_margin_top = 8
	stats_style.content_margin_bottom = 8
	stats_panel.add_theme_stylebox_override("panel", stats_style)
	right_col.add_child(stats_panel)

	var stats_vbox := VBoxContainer.new()
	stats_vbox.add_theme_constant_override("separation", 4)
	stats_panel.add_child(stats_vbox)

	var stats_title := Label.new()
	stats_title.text = "Atributos del Jugador:"
	stats_title.add_theme_font_size_override("font_size", 13)
	stats_title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.38))
	stats_vbox.add_child(stats_title)

	var stats_cols := HBoxContainer.new()
	stats_cols.add_theme_constant_override("separation", 18)
	stats_vbox.add_child(stats_cols)

	stats_left_label = Label.new()
	stats_left_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_left_label.add_theme_font_size_override("font_size", 12)
	stats_left_label.add_theme_color_override("font_color", Color(0.90, 0.95, 1.0))
	stats_cols.add_child(stats_left_label)

	stats_right_label = Label.new()
	stats_right_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_right_label.add_theme_font_size_override("font_size", 12)
	stats_right_label.add_theme_color_override("font_color", Color(0.90, 0.95, 1.0))
	stats_cols.add_child(stats_right_label)

	var relics_sep := HSeparator.new()
	right_col.add_child(relics_sep)

	relics_title_label = Label.new()
	relics_title_label.text = "Bolsa de Reliquias (0):"
	relics_title_label.add_theme_font_size_override("font_size", 14)
	relics_title_label.add_theme_color_override("font_color", Color(0.82, 0.58, 1.0))
	right_col.add_child(relics_title_label)

	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_col.add_child(right_scroll)

	var right_scroll_vbox := VBoxContainer.new()
	right_scroll_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.add_child(right_scroll_vbox)

	relics_grid = GridContainer.new()
	relics_grid.columns = 2
	relics_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	relics_grid.add_theme_constant_override("h_separation", 16)
	relics_grid.add_theme_constant_override("v_separation", 14)
	right_scroll_vbox.add_child(relics_grid)

	empty_relics_label = Label.new()
	empty_relics_label.text = "No tienes reliquias equipadas todavía."
	empty_relics_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_relics_label.add_theme_font_size_override("font_size", 13)
	empty_relics_label.add_theme_color_override("font_color", Color(0.58, 0.64, 0.72))
	empty_relics_label.visible = false
	right_scroll_vbox.add_child(empty_relics_label)

	# ==========================================
	# BARRA INFERIOR (FOOTER)
	# ==========================================
	var bottom_sep := HSeparator.new()
	main_vbox.add_child(bottom_sep)

	var footer_row := HBoxContainer.new()
	footer_row.alignment = BoxContainer.ALIGNMENT_CENTER
	footer_row.add_theme_constant_override("separation", 32)
	main_vbox.add_child(footer_row)

	var hint_lbl := Label.new()
	hint_lbl.text = "[Click] Equipar Arma de la Bolsa     |     [Hover] Inspeccionar Armas y Reliquias     |     [ESC / ✕] Volver"
	hint_lbl.add_theme_font_size_override("font_size", 12)
	hint_lbl.add_theme_color_override("font_color", Color(0.68, 0.75, 0.86))
	footer_row.add_child(hint_lbl)

## Construye un encabezado estilizado para cada mitad del inventario general.
func _create_section_banner(txt: String, color: Color) -> PanelContainer:
	var banner := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.10, 0.13, 0.20, 0.95)
	st.set_border_width_all(1)
	st.border_color = Color(color.r, color.g, color.b, 0.55)
	st.set_corner_radius_all(5)
	st.content_margin_top = 4
	st.content_margin_bottom = 4
	banner.add_theme_stylebox_override("panel", st)

	var lbl := Label.new()
	lbl.text = txt
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", color)
	banner.add_child(lbl)
	return banner

## Mantiene el panel centrado horizontal y verticalmente.
func _center_panel() -> void:
	if not is_instance_valid(panel):
		return
	var available_size: Vector2 = get_viewport_rect().size
	if available_size.x <= 0.0 or available_size.y <= 0.0:
		return
	var target_size := Vector2(
		minf(PANEL_SIZE.x, available_size.x - PANEL_MARGIN * 2.0),
		minf(PANEL_SIZE.y, available_size.y - PANEL_MARGIN * 2.0)
	)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -target_size.x / 2.0
	panel.offset_right = target_size.x / 2.0
	panel.offset_top = -target_size.y / 2.0
	panel.offset_bottom = target_size.y / 2.0

## Cierra el modal.
func _close_modal() -> void:
	visible = false

## Actualiza el bloque de Atributos del Jugador y la tarjeta `WeaponUI` del Arma Equipada.
func update_stats_display(run: RunState) -> void:
	for child in equipped_slot_holder.get_children():
		child.queue_free()

	if run == null:
		stats_left_label.text = "Sin partida activa."
		stats_right_label.text = ""
		return

	var hero_title: String = run.selected_hero.hero_name if run.selected_hero else "Héroe"
	var eff_str: int = run.get_effective_str()
	var eff_int: int = run.get_effective_int()
	var eff_dex: int = run.get_effective_dex()

	var weapon: WeaponData = run.current_weapon
	var weapon_base: int = weapon.base_damage if weapon else 0
	var weapon_scale: int = weapon.get_scaling_bonus(eff_str, eff_int, eff_dex) if weapon else 0
	var req_xp: int = run.get_xp_required_for_next_level()

	stats_left_label.text = "\n".join([
		"• Héroe: %s (Planta %d)" % [hero_title, run.current_floor],
		"• Nivel: %d (XP: %d / %d)" % [run.player_level, run.player_xp, req_xp],
		"• Vida (HP): %d / %d" % [run.player_hp, run.max_player_hp],
		"• Bono Nivel: +%d%% Daño | %.1f%% Crítico (%d pts)" % [
			run.get_level_damage_bonus_pct(),
			run.get_crit_chance_pct(),
			run.get_crit_rating()
		],
		"• Bono Arma: +%d (+%d escalado)" % [weapon_base, weapon_scale]
	])

	stats_right_label.text = "\n".join([
		"• Fuerza (STR): %d" % eff_str,
		"• Inteligencia (INT): %d" % eff_int,
		"• Destreza (DEX): %d" % eff_dex,
		"• Energía / Mano: %d⚡ / %d cartas" % [run.max_energy, run.target_hand_size],
		"• Suerte (LUCK): %d   |   Oro: %d" % [run.player_luck, run.player_gold]
	])

	if weapon == null:
		var none_lbl := Label.new()
		none_lbl.text = "• [ Sin arma equipada ]"
		none_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		equipped_slot_holder.add_child(none_lbl)
		return

	var card_holder := Control.new()
	card_holder.custom_minimum_size = Vector2(228, 320)
	card_holder.mouse_filter = Control.MOUSE_FILTER_PASS
	equipped_slot_holder.add_child(card_holder)

	var weapon_ui := WEAPON_SCENE.instantiate() as WeaponUI
	card_holder.add_child(weapon_ui)
	weapon_ui.setup_weapon(weapon, true)

	var status_lbl := Label.new()
	status_lbl.text = "• [%s — EQUIPADA]" % weapon.weapon_name
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_lbl.add_theme_font_size_override("font_size", 12)
	status_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.32))
	equipped_slot_holder.add_child(status_lbl)

## Reconstruye la grilla de 2 columnas con las tarjetas `WeaponUI` guardadas en la Bolsa de Armas.
func refresh_inventory(weapons: Array[WeaponData]) -> void:
	if not is_instance_valid(weapons_grid):
		return

	for child in weapons_grid.get_children():
		child.queue_free()

	if weapons.is_empty():
		empty_backpack_label.visible = true
		return

	empty_backpack_label.visible = false

	for weapon in weapons:
		if weapon == null:
			continue

		var slot := VBoxContainer.new()
		slot.alignment = BoxContainer.ALIGNMENT_CENTER
		slot.add_theme_constant_override("separation", 6)
		weapons_grid.add_child(slot)

		var card_holder := Control.new()
		card_holder.custom_minimum_size = Vector2(228, 320)
		card_holder.mouse_filter = Control.MOUSE_FILTER_PASS
		slot.add_child(card_holder)

		var weapon_ui := WEAPON_SCENE.instantiate() as WeaponUI
		card_holder.add_child(weapon_ui)
		weapon_ui.setup_weapon(weapon, false)
		weapon_ui.weapon_clicked.connect(_on_weapon_selected)

		var equip_btn := Button.new()
		equip_btn.text = "EQUIPAR [%s]" % weapon.weapon_name
		equip_btn.custom_minimum_size = Vector2(200, 28)
		equip_btn.pressed.connect(_on_weapon_selected.bind(weapon))
		slot.add_child(equip_btn)

## Reconstruye la grilla de 2 columnas con las tarjetas `RelicUI` en la Bolsa de Reliquias.
func refresh_relics(relics: Array[RelicData]) -> void:
	if not is_instance_valid(relics_grid):
		return

	for child in relics_grid.get_children():
		child.queue_free()

	relics_title_label.text = "Bolsa de Reliquias (%d):" % relics.size()

	if relics.is_empty():
		empty_relics_label.visible = true
		return

	empty_relics_label.visible = false

	var counts: Dictionary = {}
	var sample_relics: Dictionary = {}
	var ordered_titles: Array[String] = []

	for relic in relics:
		if relic == null:
			continue
		if not counts.has(relic.title):
			counts[relic.title] = 0
			sample_relics[relic.title] = relic
			ordered_titles.append(relic.title)
		counts[relic.title] += 1

	for title_key in ordered_titles:
		var count: int = counts[title_key]
		var sample: RelicData = sample_relics[title_key]
		relics_grid.add_child(_create_relic_slot(sample, count))

## Construye una celda en la Bolsa de Reliquias con su insignia `"x1"` / `"xN"` arriba y su `RelicUI` debajo.
func _create_relic_slot(relic_data: RelicData, count: int) -> Control:
	var slot := VBoxContainer.new()
	slot.custom_minimum_size = Vector2(232, 290)
	slot.alignment = BoxContainer.ALIGNMENT_CENTER
	slot.add_theme_constant_override("separation", 4)

	var badge_row := HBoxContainer.new()
	badge_row.alignment = BoxContainer.ALIGNMENT_CENTER
	slot.add_child(badge_row)

	var badge_panel := PanelContainer.new()
	badge_panel.custom_minimum_size = Vector2(44, 20)
	var badge_style := StyleBoxFlat.new()
	if count > 1:
		badge_style.bg_color = Color(0.22, 0.17, 0.05, 0.96)
		badge_style.border_color = Color(1.0, 0.82, 0.25, 0.95)
	else:
		badge_style.bg_color = Color(0.10, 0.14, 0.22, 0.94)
		badge_style.border_color = Color(0.50, 0.68, 0.90, 0.65)
	badge_style.set_border_width_all(1)
	badge_style.set_corner_radius_all(6)
	badge_style.content_margin_left = 8
	badge_style.content_margin_right = 8
	badge_style.content_margin_top = 1
	badge_style.content_margin_bottom = 1
	badge_panel.add_theme_stylebox_override("panel", badge_style)
	badge_row.add_child(badge_panel)

	var count_label := Label.new()
	count_label.text = "x%d" % count
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count_label.add_theme_font_size_override("font_size", 12)
	if count > 1:
		count_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.32))
	else:
		count_label.add_theme_color_override("font_color", Color(0.88, 0.94, 1.0))
	badge_panel.add_child(count_label)

	var relic_holder := Control.new()
	relic_holder.custom_minimum_size = Vector2(228, 260)
	relic_holder.mouse_filter = Control.MOUSE_FILTER_PASS
	slot.add_child(relic_holder)

	var relic_ui := RELIC_SCENE.instantiate() as RelicUI
	relic_holder.add_child(relic_ui)
	relic_ui.setup_relic(relic_data)

	return slot

## Emite el arma seleccionada para que `RunState.equip_weapon()` la intercambie con la equipada.
func _on_weapon_selected(weapon: WeaponData) -> void:
	if weapon != null:
		weapon_selected_to_equip.emit(weapon)

## Abre el modal unificado de Inventario General y sincroniza Armas, Atributos y Reliquias.
func open_inventory(run: RunState) -> void:
	if run == null:
		return

	update_stats_display(run)
	refresh_inventory(run.inventory_weapons)
	refresh_relics(run.active_relics)
	visible = true
	_center_panel()
