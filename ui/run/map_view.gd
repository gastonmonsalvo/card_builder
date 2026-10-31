## Renderiza en pantalla completa la matriz `8x8` del piso actual, 
## los paneles informativos de Reliquias y Mazo a los costados,
## el modal interactivo del Santuario Ancestral y gestiona el clic sobre las salas vecinas.
class_name MapView
extends Control

signal room_selected(room: RoomData)

var rooms: Dictionary = {}
var current_pos: Vector2i = Vector2i(3, 3)
var floor_number: int = 1
var master_seed: int = 0
var floor_seed: int = 0
var free_travel_enabled: bool = false

var title_label: Label
var stats_label: Label
var seed_label: Label

var legend_label: Label
var relics_btn: Button
var deck_btn: Button
var grid_container: Control
var room_buttons: Dictionary = {}

var sanctuary_modal: SanctuaryModalView
var inspector_modal: InspectorModalView


var _cached_relics_detail: String = ""
var _cached_deck_detail: String = ""

const CELL_SIZE := Vector2(96, 46)
const CELL_GAP := Vector2(20, 14)

## Construye las etiquetas de cabecera, paneles laterales de reliquias y mazo completo, 
## leyenda inferior y el panel modal oculto del Santuario Ancestral.
func _init() -> void:
	name = "MapView"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 90

	title_label = Label.new()
	title_label.position = Vector2(40, 14)
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	add_child(title_label)

	stats_label = Label.new()
	stats_label.position = Vector2(40, 42)
	stats_label.add_theme_font_size_override("font_size", 15)
	stats_label.add_theme_color_override("font_color", Color(0.35, 0.95, 0.55))
	add_child(stats_label)
	
	seed_label = Label.new()
	seed_label.position = Vector2(40, 66)
	seed_label.add_theme_font_size_override("font_size", 13)
	seed_label.add_theme_color_override("font_color", Color(0.65, 0.75, 0.85))
	add_child(seed_label)

	legend_label = Label.new()
	legend_label.position = Vector2(40, 88)
	legend_label.add_theme_font_size_override("font_size", 14)
	legend_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	legend_label.text = "Selecciona una sala conectada (borde brillante) para avanzar por la planta."
	add_child(legend_label)

	relics_btn = Button.new()
	relics_btn.text = "RELIQUIAS (0)"
	relics_btn.position = Vector2(610, 20)
	relics_btn.size = Vector2(145, 36)
	relics_btn.pressed.connect(func(): inspector_modal.open_inspector("RELIQUIAS EQUIPADAS", _cached_relics_detail))
	add_child(relics_btn)

	deck_btn = Button.new()
	deck_btn.text = "MI MAZO (0)"
	deck_btn.position = Vector2(765, 20)
	deck_btn.size = Vector2(145, 36)
	deck_btn.pressed.connect(func(): inspector_modal.open_inspector("CARTAS EN TU MAZO", _cached_deck_detail))
	add_child(deck_btn)
	
	#CONFIGURACION DE LUGAR LABEL DE SEED
	seed_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	seed_label.offset_top = -32
	seed_label.offset_bottom = -8
	
	
	var copy_seed_btn := Button.new()
	copy_seed_btn.text = "COPIAR SEED"
	copy_seed_btn.position = Vector2(920, 20)
	copy_seed_btn.size = Vector2(150, 36)
	copy_seed_btn.pressed.connect(func():
		DisplayServer.clipboard_set(str(master_seed))
		legend_label.text = "Master Seed (%d) copiada al portapapeles!" % master_seed
	)
	add_child(copy_seed_btn)

	grid_container = Control.new()
	grid_container.position = Vector2(122, 114)
	add_child(grid_container)

	sanctuary_modal = SanctuaryModalView.new()
	add_child(sanctuary_modal)
	
	inspector_modal = InspectorModalView.new()
	add_child(inspector_modal)

##  Recibe todos los datos de `RunDirector.open_map()`, actualiza los textos de estado, oro,
##  semilla, mazo y reliquias, y solicita `_draw()` mediante `queue_redraw()`.
func setup_floor(
	p_floor: int,
	p_master_seed: int,
	p_floor_seed: int,
	p_rooms: Dictionary,
	p_current_pos: Vector2i,
	p_player_hp: int,
	p_max_hp: int,
	p_max_energy: int,
	p_player_luck: int,
	p_relics_count: int,
	p_relics_detail: String,
	p_deck_count: int,
	p_deck_detail: String,
	p_player_gold:int
) -> void:
	visible = true
	floor_number = p_floor
	master_seed = p_master_seed
	floor_seed = p_floor_seed
	rooms = p_rooms
	current_pos = p_current_pos
	_cached_relics_detail = p_relics_detail
	_cached_deck_detail = p_deck_detail

	var odds_txt: String = RaritySystem.get_probabilities_summary(floor_number, p_player_luck)
	
	title_label.text = "PLANTA %d - MAPA DE EXPLORACION (Matriz 8x8 | %d Salas)" % [floor_number, rooms.size()]
	stats_label.text = "VIDA: %d / %d HP   |   ENERGIA MAX: %d   |   SUERTE: %d | ORO: %d" % [
		p_player_hp, p_max_hp, p_max_energy, p_player_luck, p_player_gold
	]
	seed_label.text = "Master Seed: %d   |   Sub-Seed P%d: %d   |   Drop -> [ %s ]" % [
		master_seed, floor_number, floor_seed, odds_txt
	]
	legend_label.text = "Selecciona una sala conectada (borde brillante) para avanzar por la planta."

	relics_btn.text = "RELIQUIAS (%d)" % p_relics_count
	deck_btn.text = "MI MAZO (%d)" % p_deck_count

	_rebuild_grid_buttons()
	queue_redraw()
	
func _rebuild_grid_buttons() -> void:
	for child in grid_container.get_children():
		child.queue_free()
	room_buttons.clear()

	for pos: Vector2i in rooms.keys():
		var room: RoomData = rooms[pos]
		if not room.discovered:
			continue

		var is_current := (pos == current_pos)
		var can_travel := _can_travel_to(room)

		# Instanciamos nuestra nueva clase en lugar de un Button crudo
		var node_btn := MapNodeView.new()
		node_btn.position = Vector2(
			pos.x * (CELL_SIZE.x + CELL_GAP.x),
			pos.y * (CELL_SIZE.y + CELL_GAP.y)
		)
		
		# Le delegamos toda la lógica visual
		node_btn.setup(room, is_current, can_travel, CELL_SIZE)
		
		# Conectamos su señal personalizada al map_view
		node_btn.node_clicked.connect(_on_room_clicked)
		
		grid_container.add_child(node_btn)
		room_buttons[pos] = node_btn

func _can_travel_to(target_room: RoomData) -> bool:
	
	# Si estamos parados en una TIENDA, permitimos reabrirla al hacerle clic
	if target_room.room_type == RoomData.Type.SHOP:
		return true
	if target_room.grid_pos == current_pos:
		return false
	if free_travel_enabled:
		return true
	if not target_room.discovered:
		return false

	for n_pos: Vector2i in target_room.neighbors:
		if rooms.has(n_pos):
			var neighbor: RoomData = rooms[n_pos]
			if neighbor.cleared or n_pos == current_pos:
				return true
	return false

func _on_room_clicked(room: RoomData) -> void:
	room_selected.emit(room)


## Dibuja el tablero de fondo y los pasillos conectores (`draw_line`) 
## entre las salas descubiertas.

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.07, 0.1, 0.96), true)
	var offset := grid_container.position + (CELL_SIZE * 0.5)
	for pos: Vector2i in rooms.keys():
		var room: RoomData = rooms[pos]
		if not room.discovered:
			continue

		var from_px := offset + Vector2(
			pos.x * (CELL_SIZE.x + CELL_GAP.x),
			pos.y * (CELL_SIZE.y + CELL_GAP.y)
		)

		for n_pos: Vector2i in room.neighbors:
			if rooms.has(n_pos) and rooms[n_pos].discovered:
				var to_px := offset + Vector2(
					n_pos.x * (CELL_SIZE.x + CELL_GAP.x),
					n_pos.y * (CELL_SIZE.y + CELL_GAP.y)
				)
				draw_line(from_px, to_px, Color(0.45, 0.55, 0.7, 0.8), 5.0)
				
	
## Expone la apertura del modal del santuario hacia el exterior (ej. RunDirector)
func show_sanctuary_modal(opt1_cb: Callable, opt2_cb: Callable) -> void:
	sanctuary_modal.show_sanctuary_modal(opt1_cb, opt2_cb)
