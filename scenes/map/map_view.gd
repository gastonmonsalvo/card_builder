## Renderiza en pantalla completa la matriz `8x8` del piso actual, 
## los paneles informativos de Reliquias y Mazo a los costados,
## el modal interactivo del Santuario Ancestral y gestiona el clic sobre las salas vecinas para avanzar.
class_name MapView
extends Control

## Emitida cuando el jugador hace clic sobre un nodo de mapa válido (accesible).
## Pasa como parámetro la estructura de datos (`RoomData`) de la sala destino.
signal room_selected(room: RoomData)

## Referencia en memoria al grafo de salas actuales indexado por coordenada `Vector2i`.
var rooms: Dictionary = {}
## Coordenada `(x, y)` de la sala donde se encuentra el jugador actualmente.
var current_pos: Vector2i = Vector2i(3, 3)
## Nivel de profundidad actual de la expedición.
var floor_number: int = 1
## Semilla global que rige la partida entera.
var master_seed: int = 0
## Sub-semilla generada específicamente para este piso.
var floor_seed: int = 0
## Variable de depuración. Si es `true`, permite saltar a cualquier sala ignorando 
## las reglas de conexión por vecinos.
var free_travel_enabled: bool = false

var title_label: Label
var stats_label: Label
var seed_label: Label

var legend_label: Label
var deck_btn: Button
var grid_container: Control
var room_buttons: Dictionary = {}

## Componente hijo inyectado proceduralmente. Pantalla de decisión de bendiciones.
var sanctuary_modal: SanctuaryModalView
## Componente hijo inyectado proceduralmente. Pantalla de lectura de cartas o reliquias.
var inspector_modal: InspectorModalView
## Componente hijo inyectado proceduralmente. Pantalla de inventario
var inventory_modal: InventoryModalView 
var inventory_btn: Button 
## Referencia local al estado de la run actual para consultas de inventario y equipo.
var _current_run_ref: RunState = null 
## Memoria caché en formato texto (BBCode) con las descripciones de las reliquias 
## equipadas para inyectar en el Inspector.
var _cached_relics_detail: String = ""
## Memoria caché en formato texto (BBCode) con el listado del mazo actual para inyectar en el Inspector.
var _cached_deck_detail: String = ""
## Memoria caché con las instancias `CardData` de todas las cartas que posee el jugador para la vista visual del mazo.
var _cached_deck_cards: Array[CardData] = []

const CELL_SIZE := Vector2(96, 46)
const CELL_GAP := Vector2(20, 14)

## Constructor de la interfaz gráfica del mapa.
## Ensambla proceduralmente las etiquetas de cabecera, paneles laterales (Reliquias y Mazo), 
## leyenda inferior, el botón de copiar semilla al portapapeles y los paneles 
## modales ocultos (`SanctuaryModalView`, `InspectorModalView`, `InventoryModalView`).
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

	deck_btn = Button.new()
	deck_btn.text = "MI MAZO (0)"
	deck_btn.position = Vector2(765, 20)
	deck_btn.size = Vector2(145, 36)
	deck_btn.pressed.connect(func(): inspector_modal.open_deck_cards("CARTAS EN TU MAZO (%d)" % _cached_deck_cards.size(), _cached_deck_cards))
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
	
	inventory_btn = Button.new()
	inventory_btn.text = "🎒 INVENTARIO"
	inventory_btn.position = Vector2(610, 20)
	inventory_btn.size = Vector2(145, 36)
	inventory_btn.pressed.connect(func():
		if _current_run_ref:
			inventory_modal.open_inventory(_current_run_ref)
	)
	add_child(inventory_btn)

	inventory_modal = InventoryModalView.new()
	add_child(inventory_modal)
	
	inventory_modal.weapon_selected_to_equip.connect(
	_on_inventory_weapon_selected
	)
## Inyecta el estado completo de la partida proveniente de `RunDirector.open_map()`.
## Actualiza los textos (Salud, Energía, Suerte, Oro, Probabilidades de drop por rareza)
## reconstruye la grilla de nodos visuales y solicita el repintado de las conexiones en hardware (`queue_redraw()`).
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
	p_player_gold:int,
	p_run_ref: RunState = null,
	p_deck_cards: Array[CardData] = []
) -> void:
	visible = true
	floor_number = p_floor
	master_seed = p_master_seed
	floor_seed = p_floor_seed
	rooms = p_rooms
	current_pos = p_current_pos
	_cached_relics_detail = p_relics_detail
	_cached_deck_detail = p_deck_detail
	_cached_deck_cards = p_deck_cards
	_current_run_ref = p_run_ref
	var odds_txt: String = RaritySystem.get_probabilities_summary(floor_number, p_player_luck)
	
	title_label.text = "PLANTA %d - MAPA DE EXPLORACION (Matriz 8x8 | %d Salas)" % [floor_number, rooms.size()]
	stats_label.text = "VIDA: %d / %d HP   |   ENERGIA MAX: %d   |   SUERTE: %d | ORO: %d" % [
		p_player_hp, p_max_hp, p_max_energy, p_player_luck, p_player_gold
	]
	seed_label.text = "Master Seed: %d   |   Sub-Seed P%d: %d   |   Drop -> [ %s ]" % [
		master_seed, floor_number, floor_seed, odds_txt
	]
	legend_label.text = "Selecciona una sala conectada (borde brillante) para avanzar por la planta."

	inventory_btn.text = "🎒 INVENTARIO (%d)" % p_relics_count
	deck_btn.text = "MI MAZO (%d)" % p_deck_count

	_rebuild_grid_buttons()
	queue_redraw()
	
## Purga los botones visuales del tablero e instancia dinámicamente un `MapNodeView`
## por cada sala que haya sido descubierta. Conecta el clic de cada botón a `_on_room_clicked`.
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
		
## Valida si topológicamente es legal viajar a una celda destino.
## Reglas:
## 1. Si es la misma celda, falla (salvo que sea la TIENDA, permitiendo reingresar).
## 2. Si el modo de depuración (`free_travel_enabled`) está activo, pasa automático.
## 3. Si no ha sido descubierta, falla.
## 4. Debe ser vecina (arriba, abajo, izq, der) de la sala actual, o de alguna sala ya limpiada (`cleared`).
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
	
## Callback al presionar una celda válida del mapa.
## Redirige la petición al `RunDirector` mediante la señal `room_selected`.
func _on_room_clicked(room: RoomData) -> void:
	room_selected.emit(room)


## Función de bajo nivel de la API gráfica de Godot.
## Dibuja el rectángulo de fondo oscuro y traza líneas procedurales (`draw_line`)
## conectando matemáticamente los centros geométricos de las celdas vecinas descubiertas (pasillos).
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
				
	
## Expone (Facade) la apertura del modal de bendición del santuario hacia
## el orquestador externo (`RunDirector`), ocultando su implementación interna.
func show_sanctuary_modal(opt1_cb: Callable, opt2_cb: Callable) -> void:
	sanctuary_modal.show_sanctuary_modal(opt1_cb, opt2_cb)
	
## Equipa el arma seleccionada desde el inventario del mapa.
func _on_inventory_weapon_selected(weapon: WeaponData) -> void:
	if _current_run_ref == null:
		push_error("MapView: No hay una partida activa.")
		return

	if weapon == null:
		return

	# Intentamos equipar el arma seleccionada de la mochila.
	var success: bool = _current_run_ref.equip_weapon(weapon)

	if not success:
		push_warning(
			"MapView: No se pudo equipar %s." % weapon.weapon_name
		)
		inventory_modal.open_inventory(_current_run_ref)
		return

	print("MapView: Arma equipada: %s" % weapon.weapon_name)

	# Actualizamos el modal para mostrar el nuevo equipo
	# y devolver el arma anterior a la mochila.
	inventory_modal.open_inventory(_current_run_ref)
