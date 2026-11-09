## Menú de inicio de partida
## Vista principal del menú de inicio (Main Menu) construida proceduralmente.
## Orquesta la selección de héroe, el ingreso opcional de semillas (seeds) para replicar mundos,
## la visualización de estadísticas del perfil activo y el inicio de la aventura.
extends Control
class_name MainMenuView

## Emitida al solicitar una nueva partida con generación procedural 100% aleatoria.
signal start_random_run_requested(hero: HeroData)
## Emitida al solicitar una partida usando una semilla específica para replicar un mapa determinista.
signal start_seeded_run_requested(hero: HeroData, custom_seed: int)
## Emitida cuando el jugador desea regresar a la pantalla de selección de ranura (Slot/Perfil).
signal change_slot_requested()
## Emitida al presionar el botón de salir, solicitando cerrar el juego por completo.
signal quit_requested()

## Referencia a la etiqueta que brinda instrucciones de uso al jugador.
var status_label: Label
## Campo de entrada de texto (alfanumérico) para inyectar una semilla personalizada.
var seed_input: LineEdit
## Etiqueta roja multipropósito: muestra validaciones fallidas ("Elige un héroe")
##  o las causas de muerte del Game Over.
var error_label: Label
## Contenedor horizontal dinámico que aloja las tarjetas visuales de los héroes disponibles.
var heroes_container: HBoxContainer
## Etiqueta que lee y renderiza los datos en memoria del perfil actual (Slot, Nombre, Victorias, etc.).
var profile_info_label: Label
## Panel central que se reposiciona cuando cambia el tamaño de la ventana.
var main_panel: Panel

## Catálogo en memoria de los héroes inyectados en la vista.
var available_heroes: Array[HeroData] = []
## Referencia al objeto de datos del héroe actualmente resaltado por el jugador.
var selected_hero: HeroData = null
## Lista interna de las instancias visuales (`HeroCardView`) generadas proceduralmente.
var hero_buttons: Array[HeroCardView] = []

## Constructor de la interfaz visual. Ensambla proceduralmente (sin escenas `.tscn`) el panel central,
## el formulario para el ingreso de semilla, el layout horizontal para los héroes, y la botonera inferior.
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
	var card_w: float = 760.0
	var card_h: float = 580.0
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
	title.position = Vector2(30, 14)
	title.size = Vector2(700, 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	main_panel.add_child(title)
	
	# Info del perfil activo (Slot, nombre y estadísticas)
	profile_info_label = Label.new()
	profile_info_label.position = Vector2(30, 46)
	profile_info_label.size = Vector2(700, 22)
	profile_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	profile_info_label.add_theme_font_size_override("font_size", 13)
	profile_info_label.modulate = Color(0.7, 0.85, 1.0)
	main_panel.add_child(profile_info_label)

	status_label = Label.new()
	status_label.text = "Selecciona tu Héroe para comenzar la aventura."
	status_label.position = Vector2(30, 68)
	status_label.size = Vector2(700, 24)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 13)
	status_label.add_theme_color_override("font_color", Color(0.75, 0.82, 0.9))
	main_panel.add_child(status_label)

	# Fila interactiva para seleccionar héroes con el mouse
	heroes_container = HBoxContainer.new()
	heroes_container.position = Vector2(30, 95)
	heroes_container.size = Vector2(700, 150)
	heroes_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heroes_container.add_theme_constant_override("separation", 16)
	main_panel.add_child(heroes_container)

	var random_btn := Button.new()
	random_btn.text = "JUGAR PARTIDA NUEVA"
	random_btn.position = Vector2(160, 260)
	random_btn.size = Vector2(440, 46)
	random_btn.add_theme_font_size_override("font_size", 16)
	random_btn.pressed.connect(_on_random_pressed)
	main_panel.add_child(random_btn)

	var sep_label := Label.new()
	sep_label.text = "--- O CARGAR UNA SEMILLA ESPECIFICA (SEED) ---"
	sep_label.position = Vector2(30, 318)
	sep_label.size = Vector2(700, 22)
	sep_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sep_label.add_theme_font_size_override("font_size", 12)
	sep_label.add_theme_color_override("font_color", Color(0.6, 0.68, 0.78))
	main_panel.add_child(sep_label)

	seed_input = LineEdit.new()
	seed_input.placeholder_text = "Ingresa numero o codigo de semilla"
	seed_input.position = Vector2(160, 346)
	seed_input.size = Vector2(440, 40)
	seed_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	seed_input.add_theme_font_size_override("font_size", 14)
	main_panel.add_child(seed_input)

	var seeded_btn := Button.new()
	seeded_btn.text = "JUGAR CON ESTA SEMILLA"
	seeded_btn.position = Vector2(160, 396)
	seeded_btn.size = Vector2(440, 42)
	seeded_btn.add_theme_font_size_override("font_size", 14)
	seeded_btn.pressed.connect(_on_seeded_pressed)
	main_panel.add_child(seeded_btn)

	error_label = Label.new()
	error_label.text = ""
	error_label.position = Vector2(30, 448)
	error_label.size = Vector2(700, 24)
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	error_label.add_theme_font_size_override("font_size", 13)
	error_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	main_panel.add_child(error_label)

	# Fila de botones inferiores: Cambiar Slot y Salir
	var bottom_row := HBoxContainer.new()
	var row_w: float = 460.0
	bottom_row.size = Vector2(row_w, 38)
	bottom_row.position = Vector2((card_w - row_w) * 0.5, 498)
	bottom_row.add_theme_constant_override("separation", 20)
	bottom_row.alignment = BoxContainer.ALIGNMENT_CENTER
	main_panel.add_child(bottom_row)

	var btn_change_slot := Button.new()
	btn_change_slot.text = "CAMBIAR DE PERFIL"
	btn_change_slot.custom_minimum_size = Vector2(220, 38)
	btn_change_slot.add_theme_font_size_override("font_size", 14)
	btn_change_slot.pressed.connect(func(): change_slot_requested.emit())
	bottom_row.add_child(btn_change_slot)

	var btn_quit := Button.new()
	btn_quit.text = "SALIR DEL JUEGO"
	btn_quit.custom_minimum_size = Vector2(220, 38)
	btn_quit.add_theme_font_size_override("font_size", 14)
	btn_quit.modulate = Color(1.0, 0.45, 0.45)
	btn_quit.pressed.connect(func(): quit_requested.emit())
	bottom_row.add_child(btn_quit)
	

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

## Configura la lista de héroes disponibles inyectando un `HeroCardView` por cada uno.
## Ajusta matemáticamente el ancho de las tarjetas según la cantidad de héroes para que encajen perfecto,
## y selecciona al primero por defecto.
func setup_heroes(heroes: Array[HeroData]) -> void:
	available_heroes = heroes
	selected_hero = null
	for child in heroes_container.get_children():
		heroes_container.remove_child(child)
		child.queue_free()
	hero_buttons.clear()

	if available_heroes.is_empty():
		status_label.text = "No se encontraron héroes disponibles. Revisá game/entities/hero/data."
		return

	var count: int = available_heroes.size()
	var sep: float = 12.0
	heroes_container.add_theme_constant_override("separation", int(sep))
	
	var total_w: float = 700.0
	var btn_width: float = 160.0
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
		
## Guarda la referencia al héroe activo y notifica a todas las tarjetas visuales
## para que actualicen su iluminación (destacando al elegido y apagando al resto).
func _select_hero(hero: HeroData) -> void:
	selected_hero = hero
	for card in hero_buttons:
		card.set_selected(card.hero_data == selected_hero)

## Despliega el menú principal restableciendo el formulario de semillas (para forzar la regla de Permadeath).
## Extrae la metadata del jugador desde el `PersistenceManager` (Nombre, Slot, Mejor Piso, Victorias)
##  para mostrarla en pantalla, y expone en rojo la causa de muerte si recibe un mensaje de Game Over.
func show_menu(game_over_msg: String = "") -> void:
	visible = true
	seed_input.text = ""
	
	# Mostrar los datos del perfil cargado en el Autoload
	if PersistenceManager.current_slot > 0:
		var p_name: String = PersistenceManager.profile_data.get("player_name", "Aventurero")
		var stats: Dictionary = PersistenceManager.profile_data.get("stats", {})
		var best_floor: int = stats.get("highest_floor", 1)
		var wins: int = stats.get("runs_won", 0)
		profile_info_label.text = "Perfil: %s (Ranura %d) | Mejor Piso: %d | Victorias: %d" % [p_name, PersistenceManager.current_slot, best_floor, wins]
	else:
		profile_info_label.text = ""

	# Reutilizamos error_label que ya está en rojo en tu card
	if game_over_msg != "":
		error_label.text = game_over_msg
		error_label.visible = true
	else:
		error_label.text = ""
		error_label.visible = false
		
## Callback del botón "JUGAR PARTIDA NUEVA".
## Valida que haya un héroe seleccionado y emite la señal para arrancar el juego procedural estándar.
func _on_random_pressed() -> void:
	if not selected_hero:
		error_label.text = "Selecciona un héroe antes de jugar."
		return
	visible = false
	start_random_run_requested.emit(selected_hero)

## Callback del botón "JUGAR CON ESTA SEMILLA".
## Parsea de forma segura el texto de entrada. Si es numérico puro, lo convierte a entero. 
## Si es un texto alfanumérico (ej. "TUP2026"), le aplica un hash matemático para generar una semilla válida,
##  y emite la solicitud.
func _on_seeded_pressed() -> void:
	if not selected_hero:
		error_label.text = "Selecciona un héroe antes de jugar."
		return

	var raw: String = seed_input.text.strip_edges()
	if raw == "":
		error_label.text = "Escribe una semilla arriba antes de iniciar."
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
