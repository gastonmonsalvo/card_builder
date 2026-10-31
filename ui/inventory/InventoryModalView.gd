## Vista modal reutilizable para inspeccionar el equipo actual (Arma y Stats de RPG) del héroe.
class_name InventoryModalView
extends Control

var panel: PanelContainer
var content_label: Label
var close_btn: Button

func _init() -> void:
	name = "InventoryModalView"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	z_index = 140 # Por encima de mapas y HUDs normales

	# Fondo semitransparente bloqueador de clicks
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.03, 0.05, 0.8)
	add_child(bg)

	# Panel central
	panel = PanelContainer.new()
	var m_w: float = 420.0
	var m_h: float = 380.0
	panel.size = Vector2(m_w, m_h)
	panel.position = Vector2((1152.0 - m_w) * 0.5, (648.0 - m_h) * 0.5)

	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color(0.08, 0.10, 0.15, 0.98)
	p_style.border_width_left = 2
	p_style.border_width_top = 2
	p_style.border_width_right = 2
	p_style.border_width_bottom = 2
	p_style.border_color = Color(0.35, 0.45, 0.65)
	p_style.corner_radius_top_left = 10
	p_style.corner_radius_top_right = 10
	p_style.corner_radius_bottom_left = 10
	p_style.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", p_style)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "EQUIPO Y ATRIBUTOS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	vbox.add_child(title)

	content_label = Label.new()
	content_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_label.add_theme_font_size_override("font_size", 14)
	content_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	vbox.add_child(content_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	close_btn = Button.new()
	close_btn.text = "CERRAR"
	close_btn.custom_minimum_size = Vector2(120, 38)
	close_btn.pressed.connect(func(): visible = false)
	
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_child(close_btn)
	vbox.add_child(btn_row)

## Abre el modal recopilando la información en tiempo real del `RunState`.
func open_inventory(run: RunState) -> void:
	if not run:
		return
	
	var w_name: String = run.current_weapon.weapon_name if run.current_weapon else "Sin Arma (Desarmado)"
	var w_dmg: int = run.current_weapon.base_damage if run.current_weapon else 1
	var w_class: String = WeaponData.Class.keys()[run.current_weapon.weapon_class] if run.current_weapon else "NINGUNA"
	
	var text: String = "⚔️ ARMA EQUIPADA:\n"
	text += "• Nombre: %s\n" % w_name
	text += "• Clase: %s\n" % w_class
	text += "• Daño Base: %d\n\n" % w_dmg
	
	text += "📊 ATRIBUTOS RPG:\n"
	text += "• Fuerza (STR): %d\n" % run.player_str
	text += "• Inteligencia (INT): %d\n" % run.player_int
	text += "• Destreza (DEX): %d\n" % run.player_dex
	text += "• Suerte (LUCK): %d\n" % run.player_luck
	
	content_label.text = text
	visible = true
