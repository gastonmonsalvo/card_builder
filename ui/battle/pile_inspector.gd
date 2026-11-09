## Panel emergente que renderiza visualmente el contenido de una pila (`CardPile`: Mazo, Descarte o Cementerio)
## durante el combate utilizando instancias `CardUI` agrupadas con su contador superior `"x1"` / `"xN"`.
extends Panel
class_name PileInspector

const CARD_SCENE: PackedScene = preload("res://ui/cards/card_ui.tscn")

@onready var popup_label: Label = $PilePopupLabel
@onready var close_btn: Button = $ClosePopupBtn

var title_label: Label
var scroll_container: ScrollContainer
var cards_grid: GridContainer

## Conecta el botón de cierre del popup, adapta el layout visual con grilla de cartas y oculta el inspector al iniciar la escena.
func _ready() -> void:
	position = Vector2((1152.0 - 920.0) * 0.5, (648.0 - 520.0) * 0.5)
	size = Vector2(920, 520)

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

	title_label = Label.new()
	title_label.position = Vector2(20, 14)
	title_label.size = Vector2(880, 30)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	add_child(title_label)

	scroll_container = ScrollContainer.new()
	scroll_container.position = Vector2(28, 52)
	scroll_container.size = Vector2(864, 398)
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll_container)

	var holder := VBoxContainer.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.add_child(holder)

	cards_grid = GridContainer.new()
	cards_grid.columns = 5
	cards_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cards_grid.add_theme_constant_override("h_separation", 24)
	cards_grid.add_theme_constant_override("v_separation", 18)
	holder.add_child(cards_grid)

	close_btn.position = Vector2((920.0 - 160.0) * 0.5, 464)
	close_btn.size = Vector2(160, 40)
	close_btn.pressed.connect(func(): visible = false)
	visible = false

## Muestra visualmente las cartas de una `CardPile` agrupadas por nombre con su contador `"x1"` / `"xN"` arriba.
func show_pile(pile: CardPile) -> void:
	if not pile:
		return

	title_label.text = "%s (%d)" % [pile.pile_name.to_upper(), pile.size()]
	for child in cards_grid.get_children():
		child.queue_free()

	if pile.is_empty():
		popup_label.text = "%s: (Vacía)" % pile.pile_name
		popup_label.visible = true
		scroll_container.visible = false
		visible = true
		return

	popup_label.visible = false
	scroll_container.visible = true
	scroll_container.scroll_vertical = 0

	var counts: Dictionary = {}
	var sample_cards: Dictionary = {}
	var ordered_titles: Array[String] = []

	for card in pile.cards:
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

## Construye una celda vertical que agrupa la insignia superior de cantidad (`"x1"` / `"xN"`)
## y la instancia visual de `CardUI` en modo estático.
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
