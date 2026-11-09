## Nodo visual interactivo que representa una Reliquia (`relic_ui.tscn`).
## Renderiza una estructura de 4 bloques (Cabecera con Nombre sobrio + [Rareza],
## Marco/Pedestal central con Sprite 2D o glifo, bloque de EFECTO claro y resaltado,
## y bloque inferior de LORE / HISTORIA en cursiva y tono gris atenuado).
extends Control
class_name RelicUI

@export var relic_data: RelicData

@onready var panel: Panel = $Panel
@onready var title_label: Label = $TitleLabel
@onready var rarity_label: Label = $RarityLabel
@onready var pedestal_panel: Panel = $PedestalPanel
@onready var art_texture: TextureRect = $PedestalPanel/ArtTexture
@onready var art_placeholder_label: Label = $PedestalPanel/ArtPlaceholderLabel
@onready var effect_header_label: Label = $EffectHeaderLabel
@onready var effect_body_label: Label = $EffectBodyLabel
@onready var lore_header_label: Label = $LoreHeaderLabel
@onready var lore_body_label: RichTextLabel = $LoreBodyLabel

var is_hovered: bool = false

## Inicializa el pivote central, conecta las señales de hover del ratón y configura la reliquia si ya tiene datos.
func _ready() -> void:
	pivot_offset = size * 0.5
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	if relic_data:
		setup_relic(relic_data)

## Puebla los 4 bloques visuales de la reliquia a partir de `RelicData`:
## 1. Cabecera sobria con `title` a la izquierda y `[Rareza]` a la derecha.
## 2. Pedestal central enmarcado con el Sprite 2D (`artwork`) o el emblema del objeto.
## 3. Bloque de EFECTO resaltado con la mecánica de juego.
## 4. Bloque de LORE / HISTORIA en cursiva (`[i]`) y tono gris atenuado.
func setup_relic(data: RelicData) -> void:
	relic_data = data
	if panel == null:
		await ready

	var rarity_color: Color = RaritySystem.get_tier_color(data.rarity)
	var rarity_name: String = RaritySystem.get_tier_name(data.rarity)

	# 1. Cuerpo sobrio de reliquia con reborde fino (2px) según su Rareza
	var body_style := StyleBoxFlat.new()
	body_style.bg_color = Color(0.07, 0.08, 0.12, 0.98).lerp(rarity_color, 0.18)
	body_style.border_width_left = 2
	body_style.border_width_top = 2
	body_style.border_width_right = 2
	body_style.border_width_bottom = 2
	body_style.border_color = rarity_color
	body_style.corner_radius_top_left = 8
	body_style.corner_radius_top_right = 8
	body_style.corner_radius_bottom_left = 8
	body_style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", body_style)

	# 2. Cabecera: Nombre de la Reliquia + [Rareza]
	title_label.text = data.title
	title_label.add_theme_color_override("font_color", Color(0.94, 0.96, 1.0))

	rarity_label.text = "[%s]" % rarity_name
	rarity_label.add_theme_color_override("font_color", rarity_color)

	# 3. Marco / Pedestal central para el Sprite 2D
	var ped_style := StyleBoxFlat.new()
	ped_style.bg_color = Color(0.04, 0.05, 0.08, 0.92).lerp(rarity_color, 0.12)
	ped_style.border_width_left = 1
	ped_style.border_width_top = 1
	ped_style.border_width_right = 1
	ped_style.border_width_bottom = 2
	ped_style.border_color = Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.55)
	ped_style.corner_radius_top_left = 6
	ped_style.corner_radius_top_right = 6
	ped_style.corner_radius_bottom_left = 6
	ped_style.corner_radius_bottom_right = 6
	pedestal_panel.add_theme_stylebox_override("panel", ped_style)

	if data.artwork != null:
		art_texture.texture = data.artwork
		art_texture.visible = true
		art_placeholder_label.visible = false
	else:
		art_texture.texture = null
		art_texture.visible = false
		art_placeholder_label.visible = true
		art_placeholder_label.text = data.get_placeholder_emblem()

	# 4. Bloque de EFECTO (Mecánica de juego clara y resaltada)
	effect_header_label.text = "EFECTO"
	effect_header_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.38))

	effect_body_label.text = "\"%s\"" % data.get_effect_summary_text()
	effect_body_label.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))

	# 5. Bloque de LORE / HISTORIA DEL OBJETO (Cursiva y tono gris atenuado)
	lore_header_label.text = "LORE / HISTORIA"
	lore_header_label.add_theme_color_override("font_color", Color(0.54, 0.60, 0.70))

	lore_body_label.bbcode_enabled = true
	lore_body_label.text = "[i]%s[/i]" % data.get_lore_text()
	lore_body_label.add_theme_color_override("default_color", Color(0.66, 0.71, 0.78))

## Interpola suavemente la escala y una leve inclinación cuando el cursor pasa sobre la reliquia.
func _process(delta: float) -> void:
	pivot_offset = size * 0.5
	var weight: float = 1.0 - exp(-18.0 * delta)
	var target_scale: Vector2 = Vector2(1.04, 1.04) if is_hovered else Vector2.ONE
	var target_rot: float = -1.5 if is_hovered else 0.0
	scale = scale.lerp(target_scale, weight)
	rotation_degrees = lerp(rotation_degrees, target_rot, weight)

## Activa el estado de hover al entrar el puntero del ratón.
func _on_mouse_entered() -> void:
	is_hovered = true
	z_index = 20

## Desactiva el estado de hover al salir el puntero del ratón.
func _on_mouse_exited() -> void:
	is_hovered = false
	z_index = 0
