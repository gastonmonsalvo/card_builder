## Vista modal (pop-up) superpuesta que actúa como un panel genérico de inspección de detalles.
## Provee un contenedor con scroll automático para leer descripciones largas (cartas, reliquias, estados) 
## bloqueando visualmente el fondo.
extends Panel
class_name InspectorModalView

## Referencia a la etiqueta visual que renderiza el título principal superior del modal.
var inspector_title_label: Label
## Referencia a la etiqueta de texto multilínea con ajuste automático (Word Wrap).
## Está inyectada dentro de un `ScrollContainer` para acomodar textos extensos sin desbordar la ventana.
var inspector_body_label: Label

## Constructor de la interfaz visual. Ensambla proceduralmente (vía código puro) 
## el panel contenedor estilizado (`StyleBoxFlat`), tipografías, el sistema de scroll vertical 
## y el botón de cierre.
## Calcula matemáticamente su anclaje para centrarse de forma absoluta 
## en una resolución de diseño de 1152x648 en la capa superior (`z_index = 30`).
func _init() -> void:
	name = "InspectorModalView"
	visible = false
	position = Vector2((1152.0 - 660.0) * 0.5, (648.0 - 420.0) * 0.5)
	size = Vector2(660, 420)
	z_index = 30

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.15, 0.98)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.4, 0.7, 1.0)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	add_theme_stylebox_override("panel", style)

	inspector_title_label = Label.new()
	inspector_title_label.position = Vector2(20, 18)
	inspector_title_label.size = Vector2(620, 32)
	inspector_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inspector_title_label.add_theme_font_size_override("font_size", 20)
	inspector_title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	add_child(inspector_title_label)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(30, 62)
	scroll.size = Vector2(600, 285)
	add_child(scroll)

	inspector_body_label = Label.new()
	inspector_body_label.custom_minimum_size = Vector2(580, 0)
	inspector_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspector_body_label.add_theme_font_size_override("font_size", 15)
	scroll.add_child(inspector_body_label)

	var close_btn := Button.new()
	close_btn.text = "Cerrar"
	close_btn.position = Vector2(250, 362)
	close_btn.size = Vector2(160, 40)
	close_btn.pressed.connect(func(): visible = false)
	add_child(close_btn)
## Inyecta el texto del título y la descripción detallada en las etiquetas correspondientes de la interfaz,
## y hace visible el modal pasándolo al primer plano de la pantalla.
func open_inspector(title_txt: String, body_txt: String) -> void:
	inspector_title_label.text = title_txt
	inspector_body_label.text = body_txt
	visible = true
