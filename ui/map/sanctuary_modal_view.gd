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
	size = Vector2(600, 320)
	position = Vector2((1152.0 - size.x) * 0.5, (648.0 - size.y) * 0.5)
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

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "SANTUARIO ANCESTRAL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.88, 0.65, 1.0))
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = "Has hallado una cámara sagrada en las profundidades.\nElige una bendición para continuar tu ascenso:"
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 14)
	vbox.add_child(desc)

	var btn1 := Button.new()
	btn1.text = "1. DON DEL ARTEFACTO: +1 Reliquia y Sanación Bendita (50%-100% HP)"
	btn1.custom_minimum_size = Vector2(0, 62)
	btn1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn1.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn1.add_theme_font_size_override("font_size", 15)
	btn1.pressed.connect(func():
		visible = false 
		if _sanctuary_opt1_cb.is_valid():
			_sanctuary_opt1_cb.call()
	)
	vbox.add_child(btn1)

	var btn2 := Button.new()
	btn2.text = "2. VITALIDAD INMORTAL: Aumenta tus HP Máximos Permanentemente y Cúrate"
	btn2.custom_minimum_size = Vector2(0, 62)
	btn2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn2.add_theme_font_size_override("font_size", 15)
	btn2.pressed.connect(func():
		visible = false 
		if _sanctuary_opt2_cb.is_valid():
			_sanctuary_opt2_cb.call()
	)
	vbox.add_child(btn2)

## Centra el modal respecto al viewport actual y se suscribe a cambios de tamaño.
func _ready() -> void:
	_layout_for_viewport()
	get_viewport().size_changed.connect(_layout_for_viewport)

## Recalcula la posición del modal del santuario para mantenerlo centrado en el viewport.
func _layout_for_viewport() -> void:
	position = (get_viewport_rect().size - size) * 0.5
## Despliega el modal sobre la capa del mapa (haciéndolo visible) y enlaza las lógicas de resolución.
## Los `Callables` recibidos se ejecutarán de forma aislada cuando el jugador pulse el botón correspondiente,
## delegando la lógica matemática de curación/reliquias al `RunDirector` y al `RunState`.
func show_sanctuary_modal(opt1_cb: Callable, opt2_cb: Callable) -> void:
	_sanctuary_opt1_cb = opt1_cb
	_sanctuary_opt2_cb = opt2_cb
	visible = true 
