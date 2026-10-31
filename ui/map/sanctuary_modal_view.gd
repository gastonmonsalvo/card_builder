## Vista modal (pop-up) interactiva que representa el evento de "Santuario Ancestral" en el mapa.
## Presenta al jugador una decisión binaria (Bendiciones) bloqueando el flujo del juego hasta
## que seleccione una opción.
extends Panel
class_name SanctuaryModalView

## Referencia a la función de retorno (callback) inyectada para la Opción 1 (Reliquia + Curación).
var _sanctuary_opt1_cb: Callable
## Referencia a la función de retorno (callback) inyectada para la Opción 2 (Aumento de Vida Máxima).
var _sanctuary_opt2_cb: Callable

## Constructor de la interfaz visual. Ensambla proceduralmente el panel contenedor 
## con un estilo temático (tonos púrpuras/místicos),
## instancia los textos descriptivos y los dos botones de decisión. 
## Vincula los clics de los botones a sus respectivos callbacks.
func _init() -> void:
	name = "SanctuaryModalView"
	visible = false
	position = Vector2((1152.0 - 540.0) * 0.5, (648.0 - 300.0) * 0.5)
	size = Vector2(540, 300)
	z_index = 20

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.06, 0.18, 0.98)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.75, 0.38, 1.0)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	
	add_theme_stylebox_override("panel", style)

	var title := Label.new()
	title.text = "SANTUARIO ANCESTRAL"
	title.position = Vector2(20, 22)
	title.size = Vector2(500, 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.88, 0.65, 1.0))
	add_child(title) 

	var desc := Label.new()
	desc.text = "Has hallado una camara sagrada en las profundidades.\nElige una bendicion para continuar tu ascenso:"
	desc.position = Vector2(30, 65)
	desc.size = Vector2(480, 50)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 14)
	add_child(desc)

	var btn1 := Button.new()
	btn1.text = "1. DON DEL ARTEFACTO: +1 Reliquia y Sanación Bendita (50%-100% HP)"
	btn1.position = Vector2(45, 135)
	btn1.size = Vector2(450, 54)
	btn1.add_theme_font_size_override("font_size", 15)
	btn1.pressed.connect(func():
		visible = false 
		if _sanctuary_opt1_cb.is_valid():
			_sanctuary_opt1_cb.call()
	)
	add_child(btn1)

	var btn2 := Button.new()
	btn2.text = "2. VITALIDAD INMORTAL: Aumenta tus HP Maximos Permanentemente y Curarate"
	btn2.position = Vector2(45, 205)
	btn2.size = Vector2(450, 54)
	btn2.add_theme_font_size_override("font_size", 15)
	btn2.pressed.connect(func():
		visible = false 
		if _sanctuary_opt2_cb.is_valid():
			_sanctuary_opt2_cb.call()
	)
	add_child(btn2)
## Despliega el modal sobre la capa del mapa (haciéndolo visible) y enlaza las lógicas de resolución.
## Los `Callables` recibidos se ejecutarán de forma aislada cuando el jugador pulse el botón correspondiente,
## delegando la lógica matemática de curación/reliquias al `RunDirector` y al `RunState`.
func show_sanctuary_modal(opt1_cb: Callable, opt2_cb: Callable) -> void:
	_sanctuary_opt1_cb = opt1_cb
	_sanctuary_opt2_cb = opt2_cb
	visible = true 
