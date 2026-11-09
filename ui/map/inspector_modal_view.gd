## Vista modal (pop-up) superpuesta que actúa como panel de inspección de detalles.
## Soporta modo texto (reliquias) y modo grilla visual de cartas (`CardUI`) agrupadas con su contador superior `"x1"` / `"xN"`.
extends Panel
class_name InspectorModalView

const CARD_SCENE: PackedScene = preload("res://ui/cards/card_ui.tscn")
const RELIC_SCENE: PackedScene = preload("res://ui/relics/relic_ui.tscn")

## Referencia a la etiqueta visual que renderiza el título principal superior del modal.
var inspector_title_label: Label
## Referencia a la etiqueta de texto multilínea con ajuste automático (Word Wrap).
var inspector_body_label: Label
## Contenedor de desplazamiento vertical para el texto o la grilla de cartas.
var scroll_container: ScrollContainer
## Grilla visual donde se instancian las cartas agrupadas con su contador `"xN"`.
var cards_grid: GridContainer

## Constructor de la interfaz visual. Ensambla proceduralmente (vía código puro)
## el panel contenedor estilizado (`StyleBoxFlat`), tipografías, el sistema de scroll vertical,
## la grilla visual de cartas y el botón de cierre.
func _init() -> void:
	name = "InspectorModalView"
	visible = false
	position = Vector2((1152.0 - 920.0) * 0.5, (648.0 - 540.0) * 0.5)
	size = Vector2(920, 540)
	z_index = 30

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.09, 0.14, 0.98)
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
	inspector_title_label.position = Vector2(20, 16)
	inspector_title_label.size = Vector2(880, 32)
	inspector_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inspector_title_label.add_theme_font_size_override("font_size", 20)
	inspector_title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	add_child(inspector_title_label)

	scroll_container = ScrollContainer.new()
	scroll_container.position = Vector2(28, 58)
	scroll_container.size = Vector2(864, 414)
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll_container)

	var content_holder := VBoxContainer.new()
	content_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.add_child(content_holder)

	inspector_body_label = Label.new()
	inspector_body_label.custom_minimum_size = Vector2(840, 0)
	inspector_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspector_body_label.add_theme_font_size_override("font_size", 15)
	content_holder.add_child(inspector_body_label)

	cards_grid = GridContainer.new()
	cards_grid.columns = 5
	cards_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cards_grid.add_theme_constant_override("h_separation", 24)
	cards_grid.add_theme_constant_override("v_separation", 18)
	cards_grid.visible = false
	content_holder.add_child(cards_grid)

	var close_btn := Button.new()
	close_btn.text = "Cerrar"
	close_btn.position = Vector2((920.0 - 160.0) * 0.5, 484)
	close_btn.size = Vector2(160, 40)
	close_btn.pressed.connect(func(): visible = false)
	add_child(close_btn)

## Inyecta el texto del título y la descripción detallada en las etiquetas correspondientes de la interfaz,
## ocultando la grilla de cartas y haciendo visible el modal en modo texto (usado para Reliquias).
func open_inspector(title_txt: String, body_txt: String) -> void:
	inspector_title_label.text = title_txt
	inspector_body_label.text = body_txt
	inspector_body_label.visible = true
	cards_grid.visible = false
	scroll_container.scroll_vertical = 0
	visible = true

## Abre el modal en modo visual renderizando cada carta única de `cards` mediante `CardUI`
## con una insignia superior `"x1"` o `"xN"` que indica cuántas copias posee el jugador.
func open_deck_cards(title_txt: String, cards: Array[CardData]) -> void:
	inspector_title_label.text = title_txt
	for child in cards_grid.get_children():
		child.queue_free()

	if cards.is_empty():
		inspector_body_label.text = "El mazo está vacío."
		inspector_body_label.visible = true
		cards_grid.visible = false
		visible = true
		return

	inspector_body_label.visible = false
	cards_grid.visible = true
	cards_grid.columns = 5
	scroll_container.scroll_vertical = 0

	var counts: Dictionary = {}
	var sample_cards: Dictionary = {}
	var ordered_titles: Array[String] = []

	for card in cards:
		if card == null:
			continue
		if not counts.has(card.title):
			counts[card.title] = 0
			sample_cards[card.title] = card
			ordered_titles.append(card.title)
		counts[card.title] += 1

	for title_key in ordered_titles:
		var count: int = counts[title_key]
		var sample: CardData = sample_cards[title_key]
		cards_grid.add_child(_create_card_slot(sample, count))

	visible = true

## Abre el modal en modo visual renderizando cada reliquia equipada de `relics` mediante `RelicUI`
## con su insignia superior `"x1"` o `"xN"` indicando la cantidad de copias.
func open_relic_cards(title_txt: String, relics: Array[RelicData]) -> void:
	inspector_title_label.text = title_txt
	for child in cards_grid.get_children():
		child.queue_free()

	if relics.is_empty():
		inspector_body_label.text = "No tienes reliquias equipadas."
		inspector_body_label.visible = true
		cards_grid.visible = false
		visible = true
		return

	inspector_body_label.visible = false
	cards_grid.visible = true
	cards_grid.columns = 3
	scroll_container.scroll_vertical = 0

	var counts: Dictionary = {}
	var sample_relics: Dictionary = {}
	var ordered_titles: Array[String] = []

	for relic in relics:
		if relic == null:
			continue
		if not counts.has(relic.title):
			counts[relic.title] = 0
			sample_relics[relic.title] = relic
			ordered_titles.append(relic.title)
		counts[relic.title] += 1

	for title_key in ordered_titles:
		var count: int = counts[title_key]
		var sample: RelicData = sample_relics[title_key]
		cards_grid.add_child(_create_relic_slot(sample, count))

	visible = true

## Construye una celda vertical que agrupa la insignia superior de cantidad (`"x1"` / `"xN"`)
## y la instancia visual interactiva de `CardUI` en modo estático.
func _create_card_slot(card_data: CardData, count: int) -> Control:
	var slot := VBoxContainer.new()
	slot.custom_minimum_size = Vector2(148, 234)
	slot.alignment = BoxContainer.ALIGNMENT_CENTER
	slot.add_theme_constant_override("separation", 6)

	var badge_row := HBoxContainer.new()
	badge_row.alignment = BoxContainer.ALIGNMENT_CENTER
	slot.add_child(badge_row)

	var badge_panel := PanelContainer.new()
	badge_panel.custom_minimum_size = Vector2(46, 22)
	var badge_style := StyleBoxFlat.new()
	if count > 1:
		badge_style.bg_color = Color(0.22, 0.17, 0.05, 0.96)
		badge_style.border_color = Color(1.0, 0.82, 0.25, 0.95)
	else:
		badge_style.bg_color = Color(0.10, 0.14, 0.22, 0.94)
		badge_style.border_color = Color(0.50, 0.68, 0.90, 0.65)
	badge_style.border_width_left = 1
	badge_style.border_width_top = 1
	badge_style.border_width_right = 1
	badge_style.border_width_bottom = 1
	badge_style.corner_radius_top_left = 6
	badge_style.corner_radius_top_right = 6
	badge_style.corner_radius_bottom_left = 6
	badge_style.corner_radius_bottom_right = 6
	badge_style.content_margin_left = 8
	badge_style.content_margin_right = 8
	badge_style.content_margin_top = 2
	badge_style.content_margin_bottom = 2
	badge_panel.add_theme_stylebox_override("panel", badge_style)
	badge_row.add_child(badge_panel)

	var count_label := Label.new()
	count_label.text = "x%d" % count
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count_label.add_theme_font_size_override("font_size", 13)
	if count > 1:
		count_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.32))
	else:
		count_label.add_theme_color_override("font_color", Color(0.88, 0.94, 1.0))
	badge_panel.add_child(count_label)

	var card_holder := Control.new()
	card_holder.custom_minimum_size = Vector2(140, 200)
	card_holder.mouse_filter = Control.MOUSE_FILTER_PASS
	slot.add_child(card_holder)

	var card_ui := CARD_SCENE.instantiate() as CardUI
	card_ui.set_static_display_mode(true)
	card_holder.add_child(card_ui)
	card_ui.setup_card(card_data)

	return slot

## Construye una celda vertical que agrupa la insignia superior de cantidad (`"x1"` / `"xN"`)
## y la instancia visual de `RelicUI`.
func _create_relic_slot(relic_data: RelicData, count: int) -> Control:
	var slot := VBoxContainer.new()
	slot.custom_minimum_size = Vector2(248, 304)
	slot.alignment = BoxContainer.ALIGNMENT_CENTER
	slot.add_theme_constant_override("separation", 6)

	var badge_row := HBoxContainer.new()
	badge_row.alignment = BoxContainer.ALIGNMENT_CENTER
	slot.add_child(badge_row)

	var badge_panel := PanelContainer.new()
	badge_panel.custom_minimum_size = Vector2(46, 22)
	var badge_style := StyleBoxFlat.new()
	if count > 1:
		badge_style.bg_color = Color(0.22, 0.17, 0.05, 0.96)
		badge_style.border_color = Color(1.0, 0.82, 0.25, 0.95)
	else:
		badge_style.bg_color = Color(0.10, 0.14, 0.22, 0.94)
		badge_style.border_color = Color(0.50, 0.68, 0.90, 0.65)
	badge_style.border_width_left = 1
	badge_style.border_width_top = 1
	badge_style.border_width_right = 1
	badge_style.border_width_bottom = 1
	badge_style.corner_radius_top_left = 6
	badge_style.corner_radius_top_right = 6
	badge_style.corner_radius_bottom_left = 6
	badge_style.corner_radius_bottom_right = 6
	badge_style.content_margin_left = 8
	badge_style.content_margin_right = 8
	badge_style.content_margin_top = 2
	badge_style.content_margin_bottom = 2
	badge_panel.add_theme_stylebox_override("panel", badge_style)
	badge_row.add_child(badge_panel)

	var count_label := Label.new()
	count_label.text = "x%d" % count
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count_label.add_theme_font_size_override("font_size", 13)
	if count > 1:
		count_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.32))
	else:
		count_label.add_theme_color_override("font_color", Color(0.88, 0.94, 1.0))
	badge_panel.add_child(count_label)

	var relic_holder := Control.new()
	relic_holder.custom_minimum_size = Vector2(240, 270)
	relic_holder.mouse_filter = Control.MOUSE_FILTER_PASS
	slot.add_child(relic_holder)

	var relic_ui := RELIC_SCENE.instantiate() as RelicUI
	relic_holder.add_child(relic_ui)
	relic_ui.setup_relic(relic_data)

	return slot
