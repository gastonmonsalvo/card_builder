## Vista dedicada de preparación de expedición y selección de héroe (`HeroSelectView`).
## Desacopla del menú principal toda la lógica de inspección de clases (`HeroCardView`),
## ficha técnica del héroe elegido (descripción, arma inicial, habilidad activa) e ingreso opcional de semilla (`seed`).
extends Control
class_name HeroSelectView

## Emitida al iniciar una nueva expedición con generación procedural aleatoria (`seed = -1`).
signal start_random_run_requested(hero: HeroData)
## Emitida al iniciar una expedición utilizando una semilla determinista ingresada por el jugador.
signal start_seeded_run_requested(hero: HeroData, custom_seed: int)
## Emitida cuando el jugador decide cancelar y regresar a `MainMenuView`.
signal cancelled()

## Panel central contenedor que se mantiene centrado dinámicamente según el tamaño del viewport.
var main_panel: Panel
## Etiqueta superior con el resumen del perfil activo.
var profile_info_label: Label
## Etiqueta de subtítulo e instrucciones de selección.
var status_label: Label
## Contenedor horizontal dinámico donde se instancian las tarjetas `HeroCardView`.
var heroes_container: HBoxContainer
## Panel de detalle que muestra la descripción extendida, habilidad activa y mazo del héroe actualmente seleccionado.
var hero_detail_label: Label
## Campo de texto opcional para ingresar una semilla numérica o alfanumérica.
var seed_input: LineEdit
## Etiqueta de validación para mostrar errores de entrada (ej. semilla vacía o sin héroe seleccionado).
var error_label: Label

## Catálogo en memoria de los héroes disponibles cargados por `GameDatabase`.
var available_heroes: Array[HeroData] = []
## Referencia al `HeroData` actualmente seleccionado por el jugador.
var selected_hero: HeroData = null
## Lista de tarjetas visuales `HeroCardView` instanciadas en el contenedor horizontal.
var hero_buttons: Array[HeroCardView] = []

## Constructor de la interfaz visual. Ensambla proceduralmente el panel de selección de héroe,
## el contenedor de tarjetas `HeroCardView`, el resumen detallado del héroe, el formulario de semilla y el botón de retorno.
func _init() -> void:
	name = "HeroSelectView"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 122

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.05, 0.08, 0.98)
	add_child(bg)

	main_panel = Panel.new()
	var panel_w: float = 980.0
	var panel_h: float = 600.0
	main_panel.size = Vector2(panel_w, panel_h)
	main_panel.position = Vector2((1152.0 - panel_w) * 0.5, (648.0 - panel_h) * 0.5)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.11, 0.16, 1.0)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.35, 0.50, 0.72)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	main_panel.add_theme_stylebox_override("panel", style)
	add_child(main_panel)

	var title := Label.new()
	title.text = "PREPARAR EXPEDICIÓN — ELIGE TU HÉROE"
	title.position = Vector2(30, 14)
	title.size = Vector2(panel_w - 60.0, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	main_panel.add_child(title)

	profile_info_label = Label.new()
	profile_info_label.position = Vector2(30, 44)
	profile_info_label.size = Vector2(panel_w - 60.0, 20)
	profile_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	profile_info_label.add_theme_font_size_override("font_size", 12)
	profile_info_label.modulate = Color(0.7, 0.85, 1.0)
	main_panel.add_child(profile_info_label)

	status_label = Label.new()
	status_label.text = "Haz clic sobre una clase para inspeccionar su equipamiento y habilidad activa."
	status_label.position = Vector2(30, 64)
	status_label.size = Vector2(panel_w - 60.0, 20)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override("font_color", Color(0.75, 0.82, 0.9))
	main_panel.add_child(status_label)

	heroes_container = HBoxContainer.new()
	heroes_container.position = Vector2(30, 90)
	heroes_container.size = Vector2(panel_w - 60.0, 205)
	heroes_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heroes_container.add_theme_constant_override("separation", 12)
	main_panel.add_child(heroes_container)

	# Ficha técnica del héroe seleccionado
	var detail_panel := Panel.new()
	detail_panel.position = Vector2(30, 305)
	detail_panel.size = Vector2(panel_w - 60.0, 72)
	var detail_style := StyleBoxFlat.new()
	detail_style.bg_color = Color(0.06, 0.08, 0.12, 0.95)
	detail_style.border_width_left = 1
	detail_style.border_width_top = 1
	detail_style.border_width_right = 1
	detail_style.border_width_bottom = 1
	detail_style.border_color = Color(0.25, 0.35, 0.52)
	detail_style.corner_radius_top_left = 8
	detail_style.corner_radius_top_right = 8
	detail_style.corner_radius_bottom_left = 8
	detail_style.corner_radius_bottom_right = 8
	detail_panel.add_theme_stylebox_override("panel", detail_style)
	main_panel.add_child(detail_panel)

	hero_detail_label = Label.new()
	hero_detail_label.position = Vector2(16, 8)
	hero_detail_label.size = Vector2(panel_w - 92.0, 56)
	hero_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero_detail_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hero_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hero_detail_label.add_theme_font_size_override("font_size", 13)
	hero_detail_label.add_theme_color_override("font_color", Color(0.90, 0.94, 1.0))
	detail_panel.add_child(hero_detail_label)

	var random_btn := Button.new()
	random_btn.text = "COMENZAR EXPEDICIÓN (SEMILLA ALEATORIA)"
	random_btn.position = Vector2((panel_w - 460.0) * 0.5, 388)
	random_btn.size = Vector2(460, 44)
	random_btn.add_theme_font_size_override("font_size", 16)
	random_btn.pressed.connect(_on_random_pressed)
	main_panel.add_child(random_btn)

	var sep_label := Label.new()
	sep_label.text = "— O INGRESA UNA SEMILLA ESPECÍFICA (SEED) —"
	sep_label.position = Vector2(30, 440)
	sep_label.size = Vector2(panel_w - 60.0, 20)
	sep_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sep_label.add_theme_font_size_override("font_size", 11)
	sep_label.add_theme_color_override("font_color", Color(0.6, 0.68, 0.78))
	main_panel.add_child(sep_label)

	var seed_row := HBoxContainer.new()
	seed_row.position = Vector2((panel_w - 620.0) * 0.5, 464)
	seed_row.size = Vector2(620, 38)
	seed_row.add_theme_constant_override("separation", 12)
	main_panel.add_child(seed_row)

	seed_input = LineEdit.new()
	seed_input.placeholder_text = "Número o código de semilla (ej. TUP2026)"
	seed_input.custom_minimum_size = Vector2(340, 38)
	seed_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	seed_input.add_theme_font_size_override("font_size", 13)
	seed_row.add_child(seed_input)

	var seeded_btn := Button.new()
	seeded_btn.text = "JUGAR CON SEMILLA"
	seeded_btn.custom_minimum_size = Vector2(268, 38)
	seeded_btn.add_theme_font_size_override("font_size", 13)
	seeded_btn.pressed.connect(_on_seeded_pressed)
	seed_row.add_child(seeded_btn)

	error_label = Label.new()
	error_label.text = ""
	error_label.position = Vector2(30, 508)
	error_label.size = Vector2(panel_w - 60.0, 22)
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	error_label.add_theme_font_size_override("font_size", 13)
	error_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	main_panel.add_child(error_label)

	var back_btn := Button.new()
	back_btn.text = "VOLVER AL MENÚ PRINCIPAL"
	back_btn.position = Vector2((panel_w - 260.0) * 0.5, 540)
	back_btn.size = Vector2(260, 38)
	back_btn.add_theme_font_size_override("font_size", 13)
	back_btn.pressed.connect(_on_back_pressed)
	main_panel.add_child(back_btn)

## Centra el panel principal usando el tamaño real del viewport y se suscribe a cambios de resolución.
func _ready() -> void:
	_layout_for_viewport()
	get_viewport().size_changed.connect(_layout_for_viewport)

## Recalcula la posición del panel principal para mantenerlo centrado respecto al tamaño actual del viewport.
func _layout_for_viewport() -> void:
	if not is_instance_valid(main_panel):
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	main_panel.position = (viewport_size - main_panel.size) * 0.5

## Configura la lista de héroes disponibles instanciando un `HeroCardView` por cada elemento del catálogo.
## Calcula automáticamente el ancho proporcional y selecciona al primer héroe por defecto.
func setup_heroes(heroes: Array[HeroData]) -> void:
	available_heroes = heroes
	selected_hero = null
	for child in heroes_container.get_children():
		heroes_container.remove_child(child)
		child.queue_free()
	hero_buttons.clear()

	if available_heroes.is_empty():
		status_label.text = "No se encontraron héroes disponibles en res://entities/hero/data."
		hero_detail_label.text = ""
		return

	var count: int = available_heroes.size()
	var sep: float = 12.0
	heroes_container.add_theme_constant_override("separation", int(sep))

	var total_w: float = 920.0
	var btn_width: float = 175.0
	if count > 0:
		btn_width = (total_w - (sep * float(count - 1))) / float(count)

	for hero in available_heroes:
		var card := HeroCardView.new()
		card.setup(hero, btn_width)
		card.hero_clicked.connect(_select_hero)
		heroes_container.add_child(card)
		hero_buttons.append(card)

	if not available_heroes.is_empty():
		_select_hero(available_heroes[0])

## Marca como activo al héroe seleccionado, actualiza el brillo de todas las tarjetas `HeroCardView`
## y refresca el panel inferior de ficha técnica con su habilidad y descripción.
func _select_hero(hero: HeroData) -> void:
	selected_hero = hero
	for card in hero_buttons:
		card.set_selected(card.hero_data == selected_hero)
	_update_hero_detail(hero)

## Construye el resumen detallado del héroe seleccionado (descripción de clase, arma inicial y habilidad activa).
func _update_hero_detail(hero: HeroData) -> void:
	if hero == null:
		hero_detail_label.text = ""
		return
	var desc_txt: String = hero.description if hero.description.strip_edges() != "" else "Combatiente listo para adentrarse en la mazmorra."
	var ability_txt: String = "Sin habilidad activa"
	if hero.ability != null:
		ability_txt = "%s (%d uso/combate): %s" % [hero.ability.ability_name, hero.ability.uses_per_combat, hero.ability.description]
	hero_detail_label.text = "[%s] %s\nHabilidad Activa — %s" % [hero.hero_name.to_upper(), desc_txt, ability_txt]

## Abre la pantalla de selección de héroe limpiando el campo de semilla y actualizando el encabezado del perfil activo.
func show_view() -> void:
	visible = true
	seed_input.text = ""
	error_label.text = ""
	error_label.visible = false

	if PersistenceManager.current_slot > 0:
		var p_name: String = PersistenceManager.profile_data.get("player_name", "Aventurero")
		var stats: Dictionary = PersistenceManager.profile_data.get("stats", {})
		var best_floor: int = stats.get("highest_floor", 1)
		var wins: int = stats.get("runs_won", 0)
		profile_info_label.text = "Perfil activo: %s (Ranura %d) | Mejor Piso: %d | Victorias: %d" % [p_name, PersistenceManager.current_slot, best_floor, wins]
	else:
		profile_info_label.text = ""

	if selected_hero == null and not available_heroes.is_empty():
		_select_hero(available_heroes[0])

## Callback del botón de expedición aleatoria. Valida que exista un héroe elegido y emite `start_random_run_requested`.
func _on_random_pressed() -> void:
	if not selected_hero:
		error_label.text = "Selecciona un héroe antes de comenzar."
		error_label.visible = true
		return
	visible = false
	start_random_run_requested.emit(selected_hero)

## Callback del botón de expedición con semilla. Parsea o hashea la entrada alfanumérica y emite `start_seeded_run_requested`.
func _on_seeded_pressed() -> void:
	if not selected_hero:
		error_label.text = "Selecciona un héroe antes de comenzar."
		error_label.visible = true
		return

	var raw: String = seed_input.text.strip_edges()
	if raw == "":
		error_label.text = "Escribe una semilla antes de iniciar con semilla fija."
		error_label.visible = true
		return

	var parsed_seed: int = 0
	if raw.is_valid_int():
		parsed_seed = abs(raw.to_int())
	else:
		parsed_seed = abs(hash(raw))
	if parsed_seed == 0:
		parsed_seed = 1

	visible = false
	start_seeded_run_requested.emit(selected_hero, parsed_seed)

## Oculta la pantalla de selección de héroe y emite `cancelled` para volver al menú principal.
func _on_back_pressed() -> void:
	visible = false
	cancelled.emit()
