## Modal reutilizable para consultar atributos y cambiar el arma equipada.
class_name InventoryModalView
extends Control

signal weapon_selected_to_equip(weapon: WeaponData)

const PANEL_SIZE := Vector2(460.0, 500.0)
const PANEL_MARGIN := 16.0

var panel: PanelContainer
var content_label: Label
var weapons_box: VBoxContainer
var close_btn: Button


func _ready() -> void:
	name = "InventoryModalView"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	z_index = 140

	_build_ui()
	resized.connect(_center_panel)
	_center_panel()


## Construye el fondo, el panel, el resumen de atributos y los botones de la mochila.
func _build_ui() -> void:
	var background := ColorRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.02, 0.03, 0.05, 0.8)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(background)

	panel = PanelContainer.new()
	panel.size = PANEL_SIZE

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.10, 0.15, 0.98)
	panel_style.set_border_width_all(2)
	panel_style.border_color = Color(0.35, 0.45, 0.65)
	panel_style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "INVENTARIO Y ATRIBUTOS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	vbox.add_child(title)

	content_label = Label.new()
	content_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_label.add_theme_font_size_override("font_size", 13)
	content_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	vbox.add_child(content_label)

	var backpack_title := Label.new()
	backpack_title.text = "🎒 MOCHILA (Click para equipar):"
	backpack_title.add_theme_font_size_override("font_size", 14)
	backpack_title.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
	vbox.add_child(backpack_title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 130)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	weapons_box = VBoxContainer.new()
	weapons_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weapons_box.add_theme_constant_override("separation", 6)
	scroll.add_child(weapons_box)

	close_btn = Button.new()
	close_btn.text = "CERRAR"
	close_btn.custom_minimum_size = Vector2(140, 38)
	close_btn.pressed.connect(_close_modal)

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_child(close_btn)
	vbox.add_child(button_row)


## Mantiene el panel centrado y dentro del área disponible al cambiar la resolución.
func _center_panel() -> void:
	if not is_instance_valid(panel):
		return

	var available_size := size
	if available_size.x <= 0.0 or available_size.y <= 0.0:
		return

	var target_size := Vector2(
		minf(PANEL_SIZE.x, maxf(0.0, available_size.x - PANEL_MARGIN * 2.0)),
		minf(PANEL_SIZE.y, maxf(0.0, available_size.y - PANEL_MARGIN * 2.0))
	)
	panel.size = target_size
	panel.position = (available_size - target_size) * 0.5


## Cierra el modal.
func _close_modal() -> void:
	visible = false


## Actualiza el resumen del arma equipada y los atributos del jugador.
func update_stats_display(run: RunState) -> void:
	if run == null:
		content_label.text = "No hay una partida activa."
		return

	var weapon_name := "Sin Arma (Desarmado)"
	var weapon_damage := 1
	var weapon_class := "NINGUNA"

	if run.current_weapon != null:
		weapon_name = run.current_weapon.weapon_name
		weapon_damage = run.current_weapon.base_damage
		var class_names: Array = WeaponData.Class.keys()
		var class_index := int(run.current_weapon.weapon_class)
		if class_index >= 0 and class_index < class_names.size():
			weapon_class = str(class_names[class_index])
		else:
			weapon_class = "DESCONOCIDA"

	var summary := "⚔️ Arma: %s | Clase: %s | Daño: %d\n" % [
		weapon_name,
		weapon_class,
		weapon_damage
	]
	summary += "📊 STR: %d | INT: %d | DEX: %d | LUCK: %d" % [
		run.player_str,
		run.player_int,
		run.player_dex,
		run.player_luck
	]
	content_label.text = summary


## Reconstruye los botones de las armas guardadas en la mochila.
func refresh_inventory(weapons: Array[WeaponData]) -> void:
	if not is_instance_valid(weapons_box):
		return

	for child in weapons_box.get_children():
		child.queue_free()

	if weapons.is_empty():
		var empty_label := Label.new()
		empty_label.text = "La mochila está vacía."
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		weapons_box.add_child(empty_label)
		return

	for weapon in weapons:
		if weapon == null:
			continue

		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 32)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text = "%s (Daño: %d)" % [weapon.weapon_name, weapon.base_damage]
		button.pressed.connect(_on_weapon_button_pressed.bind(weapon))
		weapons_box.add_child(button)


## Emite el arma asociada al botón pulsado; el RunState decide si puede equiparla.
func _on_weapon_button_pressed(weapon: WeaponData) -> void:
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
