## Representación visual e interactiva de una celda individual dentro del grafo del mapa de expedición.
## Extiende de `Button` para recibir los clics del jugador y ensambla proceduralmente
##  su aspecto gráfico (StyleBox) según el estado topológico de la sala.
extends Button
class_name MapNodeView

## Emitida cuando el jugador hace clic válido en este botón con la intención de viajar.
## Pasa como parámetro la estructura de datos lógica de la sala destino.
signal node_clicked(room: RoomData)
## Referencia en memoria a la estructura lógica (datos, vecinos, inventario) que este nodo visual representa.
var room_data: RoomData

## Configura el tamaño absoluto del botón y renderiza su aspecto gráfico dinámico (`StyleBoxFlat`).
## Inyecta el texto contextual (ej. "[AQUI]"), bloquea el clic si `can_travel` es falso, 
## y traza bordes de estado: blancos (posición actual), dorados (accesible) o grises (inaccesible).
func setup(room: RoomData, is_current: bool, can_travel: bool, cell_size: Vector2) -> void:
	room_data = room
	custom_minimum_size = cell_size
	size = cell_size
	
	var title_txt := room.get_display_name()
	if is_current:
		title_txt = "[AQUI]\n" + title_txt
	
	text = title_txt
	disabled = not can_travel

	var style := StyleBoxFlat.new()
	var base_col: Color = room.get_room_color(is_current)
	
	# Oscurece dramáticamente el color base si el evento de la sala ya fue resuelto
	if room.cleared:
		style.bg_color = base_col.darkened(0.55)
	else:
		style.bg_color = base_col.darkened(0.25)
	# Asignación de jerarquía visual mediante los bordes del botón
	if is_current:
		style.border_width_left = 4
		style.border_width_top = 4
		style.border_width_right = 4
		style.border_width_bottom = 4
		style.border_color = Color(1.0, 1.0, 1.0)
	elif can_travel:
		style.border_width_left = 3
		style.border_width_top = 3
		style.border_width_right = 3
		style.border_width_bottom = 3
		style.border_color = Color(1.0, 0.9, 0.3)
	else:
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.border_color = Color(0.3, 0.3, 0.35)
		
	# Aplica el mismo estilo para todos los estados visuales del botón (Flat Design)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8

	add_theme_stylebox_override("normal", style)
	add_theme_stylebox_override("hover", style)
	add_theme_stylebox_override("pressed", style)
	add_theme_stylebox_override("disabled", style)
	add_theme_font_size_override("font_size", 13)

	pressed.connect(func(): node_clicked.emit(room_data))
