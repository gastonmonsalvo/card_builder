class_name PauseMenuView
extends Control

signal resume_requested()
signal abandon_run_requested()
signal quit_game_requested()

var confirm_modal: PanelContainer
var confirm_label: Label
var on_confirm_callback: Callable

## Constructor del Menú de Pausa.
## Configura el fondo oscuro semitransparente que cubre la pantalla (1152x648),
## el panel central con los botones de acción y el modal secundario de confirmación.
func _init() -> void:
	name = "PauseMenuView"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 150
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	# Fondo oscuro difuminado
	var bg := ColorRect.new()
	bg.size = Vector2(1152, 648)
	bg.color = Color(0.02, 0.03, 0.05, 0.85)
	add_child(bg)

	# Panel central
	var panel := Panel.new()
	var p_w: float = 380.0
	var p_h: float = 360.0
	panel.size = Vector2(p_w, p_h)
	panel.position = Vector2((1152.0 - p_w) * 0.5, (648.0 - p_h) * 0.5)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.15, 0.98)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.4, 0.5, 0.7)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	# Título
	var title := Label.new()
	title.text = "PAUSA"
	title.position = Vector2(20, 24)
	title.size = Vector2(p_w - 40, 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	panel.add_child(title)

	# Contenedor vertical de botones
	var vbox := VBoxContainer.new()
	vbox.position = Vector2(50, 80)
	vbox.size = Vector2(p_w - 100, 240)
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var btn_resume := Button.new()
	btn_resume.text = "CONTINUAR"
	btn_resume.custom_minimum_size = Vector2(0, 42)
	btn_resume.pressed.connect(_on_resume_pressed)
	vbox.add_child(btn_resume)

	var btn_abandon := Button.new()
	btn_abandon.text = "ABANDONAR PARTIDA"
	btn_abandon.custom_minimum_size = Vector2(0, 42)
	btn_abandon.pressed.connect(_on_abandon_pressed)
	vbox.add_child(btn_abandon)

	var btn_save_quit := Button.new()
	btn_save_quit.text = "GUARDAR Y SALIR"
	btn_save_quit.custom_minimum_size = Vector2(0, 42)
	btn_save_quit.pressed.connect(_on_save_and_quit_pressed)
	vbox.add_child(btn_save_quit)

	_build_confirm_modal()

## Construye el modal de advertencia para evitar abandonos accidentales.
func _build_confirm_modal() -> void:
	confirm_modal = PanelContainer.new()
	confirm_modal.visible = false
	var m_w: float = 400.0
	var m_h: float = 180.0
	confirm_modal.size = Vector2(m_w, m_h)
	confirm_modal.position = Vector2((1152.0 - m_w) * 0.5, (648.0 - m_h) * 0.5)
	confirm_modal.z_index = 160

	var m_style := StyleBoxFlat.new()
	m_style.bg_color = Color(0.06, 0.08, 0.12, 1.0)
	m_style.border_width_left = 2
	m_style.border_width_top = 2
	m_style.border_width_right = 2
	m_style.border_width_bottom = 2
	m_style.border_color = Color(0.9, 0.35, 0.35)
	m_style.corner_radius_top_left = 8
	m_style.corner_radius_top_right = 8
	m_style.corner_radius_bottom_left = 8
	m_style.corner_radius_bottom_right = 8
	confirm_modal.add_theme_stylebox_override("panel", m_style)
	add_child(confirm_modal)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	confirm_modal.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	confirm_label = Label.new()
	confirm_label.text = "¿Seguro que deseas abandonar la run actual?"
	confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirm_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(confirm_label)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(hbox)

	var btn_yes := Button.new()
	btn_yes.text = "CONFIRMAR"
	btn_yes.custom_minimum_size = Vector2(100, 34)
	btn_yes.modulate = Color(1.0, 0.4, 0.4)
	btn_yes.pressed.connect(func():
		confirm_modal.visible = false
		if on_confirm_callback.is_valid():
			on_confirm_callback.call()
	)
	hbox.add_child(btn_yes)

	var btn_no := Button.new()
	btn_no.text = "CANCELAR"
	btn_no.custom_minimum_size = Vector2(100, 34)
	btn_no.pressed.connect(func(): confirm_modal.visible = false)
	hbox.add_child(btn_no)

## Abre la vista de pausa deteniendo el bucle del SceneTree.
func open_pause() -> void:
	confirm_modal.visible = false
	visible = true
	get_tree().paused = true

## Cierra el menú de pausa y reanuda el SceneTree.
func close_pause() -> void:
	confirm_modal.visible = false
	visible = false
	get_tree().paused = false

## Maneja la pulsación de la tecla ESC para alternar el menú de pausa.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if visible:
				if confirm_modal.visible:
					confirm_modal.visible = false
				else:
					_on_resume_pressed()
				get_viewport().set_input_as_handled()

## Callback del botón "CONTINUAR".
## Cierra el panel de pausa, descongela el SceneTree y emite resume_requested hacia el RunDirector.
func _on_resume_pressed() -> void:
	close_pause()
	resume_requested.emit()
	
## Callback del botón "ABANDONAR PARTIDA".
## Configura el mensaje de advertencia en el modal secundario, asigna la acción de confirmación
## para emitir abandon_run_requested y despliega el diálogo emergente de confirmación.
func _on_abandon_pressed() -> void:
	confirm_label.text = "¿Abandonar la run actual?\nEl progreso no guardado de este intento se perderá."
	on_confirm_callback = func():
		close_pause()
		abandon_run_requested.emit()
	confirm_modal.visible = true
	
## Callback del botón "GUARDAR Y SALIR".
## Cierra la vista de pausa, descongela el SceneTree y emite quit_game_requested para que RunDirector
## ejecute el guardado atómico de la run activa y proceda al cierre ordenado del juego.
func _on_save_and_quit_pressed() -> void:
	close_pause()
	quit_game_requested.emit()
