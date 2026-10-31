## vista de seleccion de partida
class_name SlotSelectView
extends Control

signal slot_chosen()

var cards_box: HBoxContainer
var name_modal: PanelContainer
var name_input: LineEdit
var pending_slot_for_creation: int = -1

## Constructor del selector de partidas.
## Configura la jerarquía visual de pantalla completa (1152x648) 
## bloqueando inputs con MOUSE_FILTER_STOP,
## monta el panel principal con borde y título, e inicializa el contenedor horizontal de las 3 ranuras 
##y el modal emergente.
func _init() -> void:
	name = "SlotSelectView"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 120

	# 1. Fondo opaco que cubra toda la resolución nativa (1152x648)
	var bg := ColorRect.new()
	bg.size = Vector2(1152, 648)
	bg.color = Color(0.04, 0.05, 0.08, 0.98)
	add_child(bg)

	# 2. Tarjeta central contenedora (ancho 820 para que entren sobradas las 3 ranuras)
	var main_panel := Panel.new()
	var panel_w: float = 840.0
	var panel_h: float = 520.0
	main_panel.size = Vector2(panel_w, panel_h)
	main_panel.position = Vector2((1152.0 - panel_w) * 0.5, (648.0 - panel_h) * 0.5)

	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color(0.08, 0.10, 0.15, 1.0)
	p_style.border_width_left = 2
	p_style.border_width_top = 2
	p_style.border_width_right = 2
	p_style.border_width_bottom = 2
	p_style.border_color = Color(0.35, 0.45, 0.65)
	p_style.corner_radius_top_left = 12
	p_style.corner_radius_top_right = 12
	p_style.corner_radius_bottom_left = 12
	p_style.corner_radius_bottom_right = 12
	main_panel.add_theme_stylebox_override("panel", p_style)
	add_child(main_panel)

	# 3. Título centrado en el panel
	var title := Label.new()
	title.text = "SELECCIONAR PARTIDA"
	title.position = Vector2(20, 24)
	title.size = Vector2(panel_w - 40, 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	main_panel.add_child(title)

	# 4. Fila horizontal con las 3 ranuras (240px * 3 + 20px gap * 2 = 760px)
	cards_box = HBoxContainer.new()
	var cards_w: float = 760.0
	cards_box.size = Vector2(cards_w, 380)
	cards_box.position = Vector2((panel_w - cards_w) * 0.5, 80)
	cards_box.add_theme_constant_override("separation", 20)
	main_panel.add_child(cards_box)

	# 5. Modal emergente para ingresar nombre (centrado en la pantalla absoluta)
	_build_name_modal()
	
## Construye e inyecta en el árbol el cuadro de diálogo modal para el ingreso del nombre del jugador.
## Configura el PanelContainer centrado en coordenadas absolutas con z_index elevado,
## el campo LineEdit y los botones de confirmación y cancelación.
func _build_name_modal() -> void:
	name_modal = PanelContainer.new()
	name_modal.visible = false
	var m_w: float = 380.0
	var m_h: float = 200.0
	name_modal.size = Vector2(m_w, m_h)
	name_modal.position = Vector2((1152.0 - m_w) * 0.5, (648.0 - m_h) * 0.5)
	name_modal.z_index = 130 # Por encima del panel principal

	var m_style := StyleBoxFlat.new()
	m_style.bg_color = Color(0.05, 0.07, 0.11, 1.0)
	m_style.border_width_left = 2
	m_style.border_width_top = 2
	m_style.border_width_right = 2
	m_style.border_width_bottom = 2
	m_style.border_color = Color(1.0, 0.8, 0.3)
	m_style.corner_radius_top_left = 8
	m_style.corner_radius_top_right = 8
	m_style.corner_radius_bottom_left = 8
	m_style.corner_radius_bottom_right = 8
	name_modal.add_theme_stylebox_override("panel", m_style)
	add_child(name_modal)

	var m_box := VBoxContainer.new()
	m_box.add_theme_constant_override("separation", 14)
	name_modal.add_child(m_box)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	m_box.add_child(margin)

	var inner_box := VBoxContainer.new()
	inner_box.add_theme_constant_override("separation", 14)
	margin.add_child(inner_box)

	var lbl := Label.new()
	lbl.text = "Ingresá tu nombre:"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 16)
	inner_box.add_child(lbl)

	name_input = LineEdit.new()
	name_input.placeholder_text = "Nombre del héroe..."
	name_input.max_length = 16
	name_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner_box.add_child(name_input)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	inner_box.add_child(btn_row)

	var btn_ok := Button.new()
	btn_ok.text = "CREAR"
	btn_ok.custom_minimum_size = Vector2(90, 32)
	btn_ok.pressed.connect(_on_confirm_create_slot)
	btn_row.add_child(btn_ok)

	var btn_cancel := Button.new()
	btn_cancel.text = "CANCELAR"
	btn_cancel.custom_minimum_size = Vector2(90, 32)
	btn_cancel.pressed.connect(func(): name_modal.visible = false)
	btn_row.add_child(btn_cancel)
	
## Escanea el almacenamiento local mediante PersistenceManager y redibuja en vivo las 3 tarjetas de ranura.
## Limpia instancias previas del contenedor y genera los paneles visuales mostrando el estado actual:
## ranura vacía con botón de creación, o datos de 
## perfil (nombre, récord, victorias y estado de la partida) con botones de selección y borrado.
func refresh_slots() -> void:
	for child in cards_box.get_children():
		child.queue_free()

	for i in range(1, PersistenceManager.MAX_SLOTS + 1):
		var summary: Dictionary = PersistenceManager.get_slot_summary(i)
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(240, 360)

		var slot_style := StyleBoxFlat.new()
		slot_style.bg_color = Color(0.12, 0.15, 0.22, 1.0)
		slot_style.border_width_left = 1
		slot_style.border_width_top = 1
		slot_style.border_width_right = 1
		slot_style.border_width_bottom = 1
		slot_style.border_color = Color(0.25, 0.35, 0.5)
		slot_style.corner_radius_top_left = 8
		slot_style.corner_radius_top_right = 8
		slot_style.corner_radius_bottom_left = 8
		slot_style.corner_radius_bottom_right = 8
		panel.add_theme_stylebox_override("panel", slot_style)

		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 14)
		margin.add_theme_constant_override("margin_top", 14)
		margin.add_theme_constant_override("margin_right", 14)
		margin.add_theme_constant_override("margin_bottom", 14)
		panel.add_child(margin)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 12)
		margin.add_child(vbox)

		var slot_lbl := Label.new()
		slot_lbl.text = "RANURA %d" % i
		slot_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_lbl.add_theme_font_size_override("font_size", 16)
		slot_lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
		vbox.add_child(slot_lbl)

		if summary.get("empty", true):
			var empty_lbl := Label.new()
			empty_lbl.text = "[ VACÍO ]"
			empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty_lbl.add_theme_font_size_override("font_size", 14)
			empty_lbl.modulate = Color.DIM_GRAY
			vbox.add_child(empty_lbl)

			var spacer := Control.new()
			spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
			vbox.add_child(spacer)

			var btn_new := Button.new()
			btn_new.text = "NUEVA PARTIDA"
			btn_new.custom_minimum_size = Vector2(0, 40)
			btn_new.pressed.connect(func(): _prompt_name(i))
			vbox.add_child(btn_new)
		else:
			var name_lbl := Label.new()
			name_lbl.text = summary.get("player_name", "Sin Nombre")
			name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_lbl.add_theme_font_size_override("font_size", 17)
			name_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
			vbox.add_child(name_lbl)

			var record_lbl := Label.new()
			record_lbl.text = "Mejor Piso: %d\nVictorias: %d" % [
				summary.get("highest_floor", 1),
				summary.get("runs_won", 0)
			]
			record_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			record_lbl.add_theme_font_size_override("font_size", 13)
			vbox.add_child(record_lbl)

			var has_run: bool = summary.get("has_active_run", false)
			var run_status := Label.new()
			run_status.text = "Partida en pausa" if has_run else "En descanso"
			run_status.modulate = Color(1.0, 0.85, 0.3) if has_run else Color.DIM_GRAY
			run_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			run_status.add_theme_font_size_override("font_size", 12)
			vbox.add_child(run_status)

			var spacer := Control.new()
			spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
			vbox.add_child(spacer)

			var btn_select := Button.new()
			btn_select.text = "CONTINUAR" if has_run else "SELECCIONAR"
			btn_select.custom_minimum_size = Vector2(0, 36)
			btn_select.pressed.connect(func(): _on_slot_selected(i))
			vbox.add_child(btn_select)

			var btn_del := Button.new()
			btn_del.text = "BORRAR"
			btn_del.custom_minimum_size = Vector2(0, 30)
			btn_del.modulate = Color(1.0, 0.4, 0.4)
			btn_del.pressed.connect(func(): _on_slot_deleted(i))
			vbox.add_child(btn_del)

		cards_box.add_child(panel)
		
## Abre el modal de creación de partida asignando la ranura seleccionada como pendiente.
## Limpia el texto del campo LineEdit, visibiliza el modal y le asigna el foco de teclado para escritura inmediata.
func _prompt_name(slot: int) -> void:
	pending_slot_for_creation = slot
	name_input.text = ""
	name_modal.visible = true
	name_input.grab_focus()
	
## Callback del botón "CREAR". Valida y ejecuta la inicialización del slot en PersistenceManager con el nombre ingresado.
## Oculta el modal tras completar la escritura en disco y emite la señal slot_chosen hacia RunDirector.
func _on_confirm_create_slot() -> void:
	if pending_slot_for_creation > 0:
		PersistenceManager.create_new_slot(pending_slot_for_creation, name_input.text)
		name_modal.visible = false
		slot_chosen.emit()
		
## Callback del botón "SELECCIONAR" o "CONTINUAR".
## Invoca PersistenceManager.select_slot para cargar en memoria el perfil correspondiente
## y emite slot_chosen para avanzar el flujo del juego.
func _on_slot_selected(slot: int) -> void:
	if PersistenceManager.select_slot(slot):
		slot_chosen.emit()
		
## Callback del botón "BORRAR".
## Elimina de forma definitiva los archivos de perfil y 
## de partida activa del slot indicado en disco y regenera la interfaz llamando a refresh_slots.
func _on_slot_deleted(slot: int) -> void:
	PersistenceManager.delete_slot(slot)
	refresh_slots()
