## Nodo visual interactivo que representa una carta en la mesa.
## Gestiona sus propios estados (IDLE, HOVERED, DRAGGING), animaciones procedurales (lerp) y eventos de input.

extends Control
class_name CardUI

signal card_clicked(card: CardUI)
signal card_drag_moved(card: CardUI)
signal card_released(card: CardUI)

enum State { IDLE, HOVERED, DRAGGING }
var current_state: State = State.IDLE

const DRAG_THRESHOLD: float = 8.0

@export var card_data: CardData

@onready var panel: Panel = $Panel
@onready var title_label: Label = $TitleLabel
@onready var stats_label: Label = $StatsLabel

var home_position: Vector2
var drag_offset: Vector2
var press_start_pos: Vector2
var is_pointer_down: bool = false
var base_z_index: int = 0

## Configura el pivote central, guarda su posición inicial y conecta las señales de input del ratón.
## Si ya tiene `card_data` asignada al instanciarse, dispara su configuración visual.
func _ready() -> void:
	pivot_offset = size / 2.0
	home_position = global_position
	
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)
	
	if card_data:
		setup_card(card_data)
		
## Puebla la interfaz usando los datos de la carta (`CardData`).
## Tiñe el texto del título según la rareza de la carta y el fondo del panel según el color de su efecto.
func setup_card(data: CardData) -> void:
	card_data = data
	if not is_node_ready():
		await ready
	
	title_label.text = data.title
	title_label.add_theme_color_override("font_color", RaritySystem.get_tier_color(data.rarity))
	panel.self_modulate = data.get_color()
	stats_label.text = data.get_stats_text()
	

## Ejecuta un resorte exponencial continuo para interpolar suavemente la posición, rotación y escala.
## Durante el arrastre (`DRAGGING`), aplica una inclinación dinámica (tilt) basada en la velocidad horizontal.
func _process(delta: float) -> void:
	if is_pointer_down and current_state != State.DRAGGING:
		if get_global_mouse_position().distance_to(press_start_pos) > DRAG_THRESHOLD:
			_start_dragging()
	
	if current_state == State.DRAGGING:
		var target_pos: Vector2 = get_global_mouse_position() - drag_offset
		var weight: float = 1.0 - exp(-28.0 * delta)
		var velocity_x: float = target_pos.x - global_position.x
		var target_tilt: float = clamp(velocity_x * 0.35, -22.0, 22.0)
		
		global_position = global_position.lerp(target_pos, weight)
		rotation_degrees = lerp(rotation_degrees, target_tilt, weight)
		scale = scale.lerp(Vector2(1.2, 1.2), weight)
		card_drag_moved.emit(self)
	else:
		var weight: float = 1.0 - exp(-18.0 * delta)
		global_position = global_position.lerp(home_position, weight)
		
		var target_rot: float = -4.0 if current_state == State.HOVERED else 0.0
		rotation_degrees = lerp(rotation_degrees, target_rot, weight)
		
		var target_scale: Vector2 = Vector2(1.15, 1.15) if current_state == State.HOVERED else Vector2.ONE
		scale = scale.lerp(target_scale, weight)
		
## Expande la escala y rota la carta abruptamente al ser activada.
## Depende de la interpolación en `_process` para retornar suavemente a su tamaño y rotación original.
func pulse() -> void:
	scale = Vector2(1.42, 1.42)
	rotation_degrees = 7.0
	
## Actualiza forzosamente el orden de profundidad visual (Z-Index) de la carta a su valor correspondiente, 
## asumiendo que no esté siendo arrastrada.
func update_z_index() -> void:
	if current_state != State.DRAGGING:
		z_index = 50 if current_state == State.HOVERED else base_z_index
		
## Evalúa el clic izquierdo para distinguir entre un toque rápido (emite `card_clicked` al soltar) 
## y un arrastre continuo (superado el umbral `DRAG_THRESHOLD`, delega a `_start_dragging`).
func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_pointer_down = true
			press_start_pos = get_global_mouse_position()
			drag_offset = get_global_mouse_position() - global_position
		else:
			var was_dragging: bool = (current_state == State.DRAGGING)
			is_pointer_down = false
			if was_dragging:
				_stop_dragging()
			else:
				card_clicked.emit(self)
				
## Cambia el estado a DRAGGING y eleva el Z-Index al máximo (100) para renderizar la carta por encima de toda la mesa.
func _start_dragging() -> void:
	current_state = State.DRAGGING
	z_index = 100
	
## Restaura el estado a IDLE, devuelve el Z-Index a su valor base y emite la señal `card_released` 
## para que el tablero evalúe dónde cayó.
func _stop_dragging() -> void:
	current_state = State.IDLE
	z_index = base_z_index
	card_released.emit(self)
	
## Transiciona la carta al estado HOVERED y eleva ligeramente su Z-Index (50),
## ignorando el evento si está en pleno arrastre.
func _on_mouse_entered() -> void:
	if current_state == State.DRAGGING:
		return
	current_state = State.HOVERED
	z_index = 50
	
## Devuelve la carta al estado IDLE y restaura su Z-Index base, siempre y cuando no esté siendo arrastrada.
func _on_mouse_exited() -> void:
	if current_state == State.DRAGGING:
		return
	current_state = State.IDLE
	z_index = base_z_index
