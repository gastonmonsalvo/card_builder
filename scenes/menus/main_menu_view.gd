## Vista principal del Menú de Inicio (`MainMenuView`) construida proceduralmente.
## Presenta el estado del perfil activo ya cargado (nombre, ranura, récord de piso y victorias),
## informa el resultado de la última expedición (si hubo Game Over o abandono) y coordina el acceso
## hacia la pantalla dedicada de selección de héroe (`HeroSelectView`), el cambio de perfil o el cierre del juego.
extends Control
class_name MainMenuView

## Emitida cuando el jugador presiona "NUEVA EXPEDICIÓN" para abrir `HeroSelectView`.
signal new_run_requested()
## Emitida cuando el jugador desea regresar a la pantalla de selección de ranura (`SlotSelectView`).
signal change_slot_requested()
## Emitida al presionar el botón de salir, solicitando cerrar el juego por completo.
signal quit_requested()

## Panel central contenedor que se mantiene centrado dinámicamente según el tamaño del viewport.
var main_panel: Panel
## Etiqueta que muestra los datos en memoria del perfil activo (Slot, Nombre, Mejor Piso, Victorias).
var profile_info_label: Label
## Etiqueta de subtítulo e información de bienvenida.
var status_label: Label
## Etiqueta destacada para mostrar el mensaje de fin de partida (Game Over / Abandono) si corresponde.
var error_label: Label

## Constructor de la interfaz visual. Ensambla proceduralmente el panel central del menú principal,
## el bloque de estadísticas del perfil activo y la botonera de navegación principal.
func _init() -> void:
	name = "MainMenuView"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 120

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.05, 0.08, 0.98)
	add_child(bg)

	main_panel = Panel.new()
	var card_w: float = 640.0
	var card_h: float = 440.0
	main_panel.size = Vector2(card_w, card_h)
	main_panel.position = Vector2((1152.0 - card_w) * 0.5, (648.0 - card_h) * 0.5)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.11, 0.16, 1.0)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.35, 0.45, 0.65)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	main_panel.add_theme_stylebox_override("panel", style)
	add_child(main_panel)

	var title := Label.new()
	title.text = "ROGUELIKE DECKBUILDER"
	title.position = Vector2(30, 28)
	title.size = Vector2(card_w - 60.0, 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	main_panel.add_child(title)

	# Panel de información del perfil cargado
	var profile_box := Panel.new()
	profile_box.position = Vector2(50, 78)
	profile_box.size = Vector2(card_w - 100.0, 64)
	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color(0.06, 0.08, 0.12, 0.95)
	p_style.border_width_left = 1
	p_style.border_width_top = 1
	p_style.border_width_right = 1
	p_style.border_width_bottom = 1
	p_style.border_color = Color(0.28, 0.42, 0.62)
	p_style.corner_radius_top_left = 8
	p_style.corner_radius_top_right = 8
	p_style.corner_radius_bottom_left = 8
	p_style.corner_radius_bottom_right = 8
	profile_box.add_theme_stylebox_override("panel", p_style)
	main_panel.add_child(profile_box)

	profile_info_label = Label.new()
	profile_info_label.position = Vector2(12, 8)
	profile_info_label.size = Vector2(card_w - 124.0, 24)
	profile_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	profile_info_label.add_theme_font_size_override("font_size", 14)
	profile_info_label.modulate = Color(0.7, 0.88, 1.0)
	profile_box.add_child(profile_info_label)

	status_label = Label.new()
	status_label.text = "Perfil cargado y listo para iniciar una nueva expedición."
	status_label.position = Vector2(12, 34)
	status_label.size = Vector2(card_w - 124.0, 22)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override("font_color", Color(0.75, 0.82, 0.9))
	profile_box.add_child(status_label)

	error_label = Label.new()
	error_label.text = ""
	error_label.position = Vector2(40, 154)
	error_label.size = Vector2(card_w - 80.0, 28)
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	error_label.add_theme_font_size_override("font_size", 14)
	error_label.add_theme_color_override("font_color", Color(1.0, 0.42, 0.42))
	main_panel.add_child(error_label)

	var btn_new_run := Button.new()
	btn_new_run.text = "NUEVA EXPEDICIÓN (ELEGIR HÉROE)"
	btn_new_run.position = Vector2((card_w - 420.0) * 0.5, 198)
	btn_new_run.size = Vector2(420, 52)
	btn_new_run.add_theme_font_size_override("font_size", 17)
	btn_new_run.pressed.connect(func(): new_run_requested.emit())
	main_panel.add_child(btn_new_run)

	var btn_change_slot := Button.new()
	btn_change_slot.text = "CAMBIAR DE PERFIL / RANURA"
	btn_change_slot.position = Vector2((card_w - 420.0) * 0.5, 268)
	btn_change_slot.size = Vector2(420, 44)
	btn_change_slot.add_theme_font_size_override("font_size", 14)
	btn_change_slot.pressed.connect(func(): change_slot_requested.emit())
	main_panel.add_child(btn_change_slot)

	var btn_quit := Button.new()
	btn_quit.text = "SALIR DEL JUEGO"
	btn_quit.position = Vector2((card_w - 420.0) * 0.5, 328)
	btn_quit.size = Vector2(420, 44)
	btn_quit.add_theme_font_size_override("font_size", 14)
	btn_quit.modulate = Color(1.0, 0.45, 0.45)
	btn_quit.pressed.connect(func(): quit_requested.emit())
	main_panel.add_child(btn_quit)

## Centra el panel principal usando el tamaño real del viewport, no una resolución fija.
func _ready() -> void:
	_layout_for_viewport()
	get_viewport().size_changed.connect(_layout_for_viewport)

## Recalcula la posición del panel principal para mantenerlo centrado respecto al tamaño actual del viewport.
func _layout_for_viewport() -> void:
	if not is_instance_valid(main_panel):
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	main_panel.position = (viewport_size - main_panel.size) * 0.5

## Despliega el menú principal leyendo la metadata del perfil activo desde `PersistenceManager`
## (Nombre, Slot, Mejor Piso, Victorias) y mostrando en rojo el mensaje de fin de expedición si se provee.
func show_menu(game_over_msg: String = "") -> void:
	visible = true

	if PersistenceManager.current_slot > 0:
		var p_name: String = PersistenceManager.profile_data.get("player_name", "Aventurero")
		var stats: Dictionary = PersistenceManager.profile_data.get("stats", {})
		var best_floor: int = stats.get("highest_floor", 1)
		var wins: int = stats.get("runs_won", 0)
		profile_info_label.text = "Perfil: %s (Ranura %d)  |  Mejor Piso: %d  |  Victorias: %d" % [p_name, PersistenceManager.current_slot, best_floor, wins]
	else:
		profile_info_label.text = "Sin perfil seleccionado"

	if game_over_msg != "":
		error_label.text = game_over_msg
		error_label.visible = true
	else:
		error_label.text = ""
		error_label.visible = false
