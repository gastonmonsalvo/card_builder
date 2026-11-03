## Vista de pantalla completa (UI) para el menú de selección de personaje al iniciar una nueva partida.
## Construye proceduralmente su interfaz (fondo, contenedores, título) e instancia dinámicamente
##  un botón descriptivo por cada héroe disponible en la base de datos.
extends Control
class_name HeroSelectView

## Emitida cuando el jugador hace clic sobre la tarjeta de un héroe para iniciar la partida.
## Pasa como parámetro la estructura de datos estática (`HeroData`) del héroe elegido.
signal hero_selected(hero: HeroData)
## Emitida si el jugador decide abortar la selección (ej. presionando un botón de volver o la tecla ESC).
signal cancelled()
## Referencia al contenedor horizontal donde se inyectarán dinámicamente las tarjetas de los héroes.
var heroes_container: HBoxContainer
## Referencia a la etiqueta principal del título de la pantalla.
var title_label: Label

## Constructor de la interfaz visual. Ensambla proceduralmente el fondo oscuro semitransparente,
## los contenedores de alineación (VBox y HBox) y los textos principales, anclando todo a los márgenes totales de la pantalla.
func _init() -> void:
	name = "HeroSelectView"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Fondo oscuro semitransparente
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.05, 0.08, 0.95)
	add_child(bg)

	var v_box := VBoxContainer.new()
	v_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	v_box.alignment = BoxContainer.ALIGNMENT_CENTER
	v_box.add_theme_constant_override("separation", 32)
	add_child(v_box)

	title_label = Label.new()
	title_label.text = "ELIGE A TU PERSONAJE"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 28)
	v_box.add_child(title_label)

	heroes_container = HBoxContainer.new()
	heroes_container.alignment = BoxContainer.ALIGNMENT_CENTER
	heroes_container.add_theme_constant_override("separation", 24)
	v_box.add_child(heroes_container)

## Recibe la lista completa de héroes cargados desde la base de datos (`GameDatabase`),
## purga cualquier tarjeta existente en el contenedor horizontal y 
## genera una nueva tarjeta interactiva para cada uno.
func populate(heroes: Array[HeroData]) -> void:
	for child in heroes_container.get_children():
		child.queue_free()

	for hero in heroes:
		var card_btn := _create_hero_card(hero)
		heroes_container.add_child(card_btn)

## Instancia y formatea un botón genérico gigante por código inyectando las estadísticas base 
## (Vida, Energía, Descartes, Tamaño del Mazo) y la descripción del `HeroData`.
## Aplica el color de acento propio del héroe al texto y conecta su clic a la señal de selección.
func _create_hero_card(hero: HeroData) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(220, 320)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.text = "%s\n\nHP: %d\nEnergía: %d\nDescartes: %d\nCartas: %d\n\n%s" % [
		hero.hero_name.to_upper(),
		hero.max_hp_base,
		hero.energy_base,
		hero.discards_base,
		hero.starting_deck.size(),
		hero.description
	]
	btn.add_theme_color_override("font_color", hero.accent_color)
	
	# Clic con el mouse: emite la selección y arranca
	btn.pressed.connect(func():
		hero_selected.emit(hero)
	)
	return btn
