## Controlador global de ventana de la aplicación.
## Gestiona el atajo de teclado (`F`) para alternar entre modo ventana normal y ventana maximizada
## sin interferir cuando el jugador está escribiendo en campos de texto.
extends Node

## Alterna el modo de ventana al presionar la tecla `F` cuando ningún control de entrada de texto tiene el foco.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

## Intercepta teclas no consumidas por la UI para alternar el maximizado de la ventana con `F`.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode != KEY_F:
		return
	if key_event.ctrl_pressed or key_event.alt_pressed or key_event.meta_pressed:
		return

	var viewport := get_viewport()
	if viewport == null:
		return
	var focus_owner: Control = viewport.gui_get_focus_owner()
	if focus_owner is LineEdit or focus_owner is TextEdit:
		return

	toggle_maximized()
	viewport.set_input_as_handled()

## Alterna entre ventana normal (`Window.MODE_WINDOWED`) y ventana completa maximizada (`Window.MODE_MAXIMIZED`).
func toggle_maximized() -> void:
	if Engine.is_embedded_in_editor():
		push_warning("[WindowController] El juego está corriendo embebido dentro del editor de Godot (Embedded Game). Desactivá 'Embed Game on Next Play' en la pestaña Game para probar el redimensionado y maximizado de ventana.")
		return
	var win: Window = get_window()
	if win == null:
		return
	if win.mode == Window.MODE_MAXIMIZED:
		win.mode = Window.MODE_WINDOWED
	else:
		win.mode = Window.MODE_MAXIMIZED
