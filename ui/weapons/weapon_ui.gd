## Nodo visual interactivo que representa un Arma (`weapon_ui.tscn`).
## Renderiza una estructura de 5 bloques (Cabecera con Nombre sobrio + [Rareza],
## Marco/Pedestal central con Sprite 2D del arma o glifo, Píldora de Tipo de Arma idéntica a `CardUI`,
## bloque de ESTADÍSTICAS / ESCALADO con daño base y efecto pasivo On-Hit,
## y bloque inferior de LORE / DESCRIPCIÓN en cursiva atenuada).
## Emite `weapon_clicked(weapon_data)` cuando está en la mochila y el jugador hace clic para equiparla.
extends Control
class_name WeaponUI

signal weapon_clicked(weapon: WeaponData)

@export var weapon_data: WeaponData

@onready var panel: Panel = $Panel
@onready var title_label: Label = $TitleLabel
@onready var rarity_label: Label = $RarityLabel
@onready var pedestal_panel: Panel = $PedestalPanel
@onready var art_texture: TextureRect = $PedestalPanel/ArtTexture
@onready var art_placeholder_label: Label = $PedestalPanel/ArtPlaceholderLabel
@onready var weapon_tag_panel: Panel = $WeaponTagPanel
@onready var weapon_tag_label: Label = $WeaponTagPanel/WeaponTagLabel
@onready var stats_header_label: Label = $StatsHeaderLabel
@onready var stats_body_label: Label = $StatsBodyLabel
@onready var lore_header_label: Label = $LoreHeaderLabel
@onready var lore_body_label: RichTextLabel = $LoreBodyLabel

var is_hovered: bool = false
var is_equipped: bool = false

## Inicializa el pivote central, conecta las señales de ratón e input y configura el arma si ya tiene datos.
func _ready() -> void:
	pivot_offset = size * 0.5
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)
	if weapon_data:
		setup_weapon(weapon_data, is_equipped)

## Puebla los 5 bloques visuales del arma a partir de `WeaponData`:
## 1. Cabecera sobria con `weapon_name` a la izquierda y `[Rareza]` a la derecha.
## 2. Pedestal central enmarcado con el Sprite 2D (`artwork`) o el emblema del arma.
## 3. Píldora central `🏷️ Tipo de Arma: ...` con la misma estética que `CardUI`.
## 4. Bloque de ESTADÍSTICAS / ESCALADO con daño base, requisitos/escalado y efecto pasivo On-Hit.
## 5. Bloque de LORE / DESCRIPCIÓN en cursiva (`[i]`) y tono gris atenuado.
func setup_weapon(data: WeaponData, equipped: bool = false) -> void:
	weapon_data = data
	is_equipped = equipped
	if panel == null:
		await ready

	var rarity_color: Color = RaritySystem.get_tier_color(data.rarity)
	var rarity_name: String = RaritySystem.get_tier_name(data.rarity)
	mouse_default_cursor_shape = Control.CURSOR_ARROW if is_equipped else Control.CURSOR_POINTING_HAND

	# 1. Cuerpo del arma teñido según su Rareza, con realce dorado adicional si está equipada
	var body_style := StyleBoxFlat.new()
	body_style.bg_color = Color(0.07, 0.09, 0.14, 0.98).lerp(rarity_color, 0.22)
	var border_w: int = 3 if is_equipped else 2
	body_style.border_width_left = border_w
	body_style.border_width_top = border_w
	body_style.border_width_right = border_w
	body_style.border_width_bottom = border_w
	body_style.border_color = Color(1.0, 0.84, 0.28) if is_equipped else rarity_color
	body_style.corner_radius_top_left = 8
	body_style.corner_radius_top_right = 8
	body_style.corner_radius_bottom_left = 8
	body_style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", body_style)

	# 2. Cabecera: Nombre del Arma + [Rareza]
	title_label.text = data.weapon_name
	title_label.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))

	rarity_label.text = "[%s]" % rarity_name
	rarity_label.add_theme_color_override("font_color", rarity_color)

	# 3. Marco / Pedestal central para el Sprite del Arma
	var ped_style := StyleBoxFlat.new()
	ped_style.bg_color = Color(0.04, 0.05, 0.08, 0.92).lerp(rarity_color, 0.14)
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

	# 4. Píldora de Tipo de Arma (misma estética que CardUI)
	var tag_style := StyleBoxFlat.new()
	tag_style.bg_color = Color(0.05, 0.06, 0.09, 0.82)
	tag_style.border_width_left = 1
	tag_style.border_width_top = 1
	tag_style.border_width_right = 1
	tag_style.border_width_bottom = 1
	tag_style.border_color = Color(1.0, 1.0, 1.0, 0.18)
	tag_style.corner_radius_top_left = 4
	tag_style.corner_radius_top_right = 4
	tag_style.corner_radius_bottom_left = 4
	tag_style.corner_radius_bottom_right = 4
	weapon_tag_panel.add_theme_stylebox_override("panel", tag_style)
	weapon_tag_label.text = data.get_weapon_tag_text()
	weapon_tag_label.add_theme_color_override("font_color", Color(0.86, 0.92, 1.0))

	# 5. Bloque de ESTADÍSTICAS / ESCALADO
	stats_header_label.text = "ESTADÍSTICAS / ESCALADO"
	stats_header_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.38))

	stats_body_label.text = data.get_stats_and_scaling_text()
	stats_body_label.add_theme_color_override("font_color", Color(0.94, 0.97, 1.0))

	# 6. Bloque de LORE / DESCRIPCIÓN DEL OBJETO
	lore_header_label.text = "LORE / DESCRIPCIÓN"
	lore_header_label.add_theme_color_override("font_color", Color(0.54, 0.60, 0.70))

	lore_body_label.bbcode_enabled = true
	lore_body_label.text = "[i]%s[/i]" % data.get_lore_text()
	lore_body_label.add_theme_color_override("default_color", Color(0.66, 0.71, 0.78))

## Interpola suavemente la escala y la inclinación en hover, destacando las armas de la mochila listas para equipar.
func _process(delta: float) -> void:
	pivot_offset = size * 0.5
	var weight: float = 1.0 - exp(-18.0 * delta)
	var target_scale: Vector2 = Vector2(1.04, 1.04) if is_hovered else Vector2.ONE
	var target_rot: float = -1.5 if (is_hovered and not is_equipped) else 0.0
	scale = scale.lerp(target_scale, weight)
	rotation_degrees = lerp(rotation_degrees, target_rot, weight)

## Emite `weapon_clicked` al hacer clic izquierdo sobre una tarjeta de arma en la mochila.
func _on_gui_input(event: InputEvent) -> void:
	if is_equipped or weapon_data == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		scale = Vector2(1.09, 1.09)
		weapon_clicked.emit(weapon_data)

## Activa el estado de hover al entrar el puntero del ratón.
func _on_mouse_entered() -> void:
	is_hovered = true
	z_index = 20

## Desactiva el estado de hover al salir el puntero del ratón.
func _on_mouse_exited() -> void:
	is_hovered = false
	z_index = 0
