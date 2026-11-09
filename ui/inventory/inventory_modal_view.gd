## Modal reutilizable para consultar atributos del héroe y gestionar visualmente las armas
## mediante instancias `WeaponUI` (permitiendo cambiar el arma equipada con un clic).
class_name InventoryModalView
extends Control

signal weapon_selected_to_equip(weapon: WeaponData)

const WEAPON_SCENE: PackedScene = preload("res://ui/weapons/weapon_ui.tscn")
const PANEL_SIZE := Vector2(1020.0, 560.0)
const PANEL_MARGIN := 16.0

var panel: PanelContainer
var content_label: Label
var equipped_slot_holder: VBoxContainer
var weapons_grid: HBoxContainer
var empty_backpack_label: Label
var close_btn: Button

## Configura el contenedor a pantalla completa, construye la interfaz interna del inventario y la mantiene centrada ante cambios de resolución.
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

## Construye el fondo, el panel principal dividido en columna de Arma Equipada (izquierda)
## y galería de Mochila con tarjetas `WeaponUI` interactivas (derecha).
func _build_ui() -> void:
	var background := ColorRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.02, 0.03, 0.05, 0.84)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(background)

	panel = PanelContainer.new()
	panel.size = PANEL_SIZE

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.07, 0.09, 0.14, 0.98)
	panel_style.set_border_width_all(2)
	panel_style.border_color = Color(0.4, 0.7, 1.0)
	panel_style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(main_vbox)

	var title := Label.new()
	title.text = "INVENTARIO DE ARMAS Y ATRIBUTOS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	main_vbox.add_child(title)

	content_label = Label.new()
	content_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_label.add_theme_font_size_override("font_size", 14)
	content_label.add_theme_color_override("font_color", Color(0.86, 0.92, 1.0))
	main_vbox.add_child(content_label)

	var body_hbox := HBoxContainer.new()
	body_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hbox.add_theme_constant_override("separation", 24)
	main_vbox.add_child(body_hbox)

	# Columna Izquierda: Arma Equipada
	var left_col := VBoxContainer.new()
	left_col.custom_minimum_size = Vector2(250, 0)
	left_col.alignment = BoxContainer.ALIGNMENT_BEGIN
	left_col.add_theme_constant_override("separation", 8)
	body_hbox.add_child(left_col)

	var equipped_title := Label.new()
	equipped_title.text = "⚔️ ARMA EQUIPADA"
	equipped_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	equipped_title.add_theme_font_size_override("font_size", 14)
	equipped_title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.32))
	left_col.add_child(equipped_title)

	equipped_slot_holder = VBoxContainer.new()
	equipped_slot_holder.alignment = BoxContainer.ALIGNMENT_CENTER
	left_col.add_child(equipped_slot_holder)

	# Separador vertical
	var v_sep := VSeparator.new()
	body_hbox.add_child(v_sep)

	# Columna Derecha: Mochila de Armas
	var right_col := VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_col.add_theme_constant_override("separation", 8)
	body_hbox.add_child(right_col)

	var backpack_title := Label.new()
	backpack_title.text = "🎒 MOCHILA DE ARMAS (Click en una tarjeta o botón para equipar)"
	backpack_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	backpack_title.add_theme_font_size_override("font_size", 14)
	backpack_title.add_theme_color_override("font_color", Color(0.45, 0.78, 1.0))
	right_col.add_child(backpack_title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_col.add_child(scroll)

	weapons_grid = HBoxContainer.new()
	weapons_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weapons_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	weapons_grid.alignment = BoxContainer.ALIGNMENT_CENTER
	weapons_grid.add_theme_constant_override("separation", 18)
	scroll.add_child(weapons_grid)

	empty_backpack_label = Label.new()
	empty_backpack_label.text = "La mochila está vacía."
	empty_backpack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_backpack_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty_backpack_label.add_theme_font_size_override("font_size", 15)
	empty_backpack_label.add_theme_color_override("font_color", Color(0.60, 0.65, 0.74))
	empty_backpack_label.visible = false
	right_col.add_child(empty_backpack_label)

	close_btn = Button.new()
	close_btn.text = "CERRAR"
	close_btn.custom_minimum_size = Vector2(160, 38)
	close_btn.pressed.connect(_close_modal)

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_child(close_btn)
	main_vbox.add_child(button_row)

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

## Actualiza los atributos RPG del héroe e instancia la tarjeta `WeaponUI` del arma actualmente equipada.
func update_stats_display(run: RunState) -> void:
	for child in equipped_slot_holder.get_children():
		child.queue_free()

	if run == null:
		content_label.text = "No hay una partida activa."
		return

	content_label.text = "📊 Atributos del Héroe ->   STR: %d   |   INT: %d   |   DEX: %d   |   SUERTE: %d" % [
		run.get_effective_str(),
		run.get_effective_int(),
		run.get_effective_dex(),
		run.player_luck
	]

	var weapon: WeaponData = run.current_weapon
	if weapon == null:
		var none_lbl := Label.new()
		none_lbl.text = "Sin arma equipada"
		none_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		equipped_slot_holder.add_child(none_lbl)
		return

	var card_holder := Control.new()
	card_holder.custom_minimum_size = Vector2(228, 320)
	equipped_slot_holder.add_child(card_holder)

	var weapon_ui := WEAPON_SCENE.instantiate() as WeaponUI
	card_holder.add_child(weapon_ui)
	weapon_ui.setup_weapon(weapon, true)

	var status_lbl := Label.new()
	status_lbl.text = "[ EN USO ACTUALMENTE ]"
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_lbl.add_theme_font_size_override("font_size", 11)
	status_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.32))
	equipped_slot_holder.add_child(status_lbl)

## Reconstruye las tarjetas interactivas `WeaponUI` de las armas guardadas en la mochila.
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
		slot.add_child(card_holder)

		var weapon_ui := WEAPON_SCENE.instantiate() as WeaponUI
		card_holder.add_child(weapon_ui)
		weapon_ui.setup_weapon(weapon, false)
		weapon_ui.weapon_clicked.connect(_on_weapon_selected)

		var equip_btn := Button.new()
		equip_btn.text = "EQUIPAR ARMA"
		equip_btn.custom_minimum_size = Vector2(180, 30)
		equip_btn.pressed.connect(_on_weapon_selected.bind(weapon))
		slot.add_child(equip_btn)

## Emite el arma seleccionada para que `RunState.equip_weapon()` la intercambie con la equipada.
func _on_weapon_selected(weapon: WeaponData) -> void:
	if weapon != null:
		weapon_selected_to_equip.emit(weapon)

## Abre el modal y actualiza los datos para reflejar el estado actual de la partida.
func open_inventory(run: RunState) -> void:
	if run == null:
		return

	update_stats_display(run)
	refresh_inventory(run.inventory_weapons)
	visible = true
	_center_panel()
