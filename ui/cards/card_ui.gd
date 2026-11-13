## Nodo visual interactivo que representa una carta en la mesa (`card_ui.tscn`).
## Renderiza una estructura de 4 bloques (Cabecera con Costo + Nombre + Ícono de Arma, Recuadro de Arte 2D,
## Tag de Familia de Arma, y Caja de Reglas/Efectos) enmarcada por el color de su Rareza (`RaritySystem.Tier`).
## Gestiona además sus estados de interacción (`IDLE`, `HOVERED`, `DRAGGING`) y animaciones procedurales.
extends Control
class_name CardUI

signal card_clicked(card: CardUI)
signal card_drag_moved(card: CardUI)
signal card_released(card: CardUI)

enum State { IDLE, HOVERED, DRAGGING, CONSUMING }
var current_state: State = State.IDLE

const DRAG_THRESHOLD: float = 8.0

@export var card_data: CardData

@onready var panel: Panel = $Panel
@onready var cost_badge: Panel = $CostBadge
@onready var cost_label: Label = $CostBadge/CostLabel
@onready var title_label: Label = $TitleLabel
@onready var weapon_icon_label: Label = $WeaponIconLabel
@onready var art_panel: Panel = $ArtPanel
@onready var art_texture: TextureRect = $ArtPanel/ArtTexture
@onready var art_placeholder_label: Label = $ArtPanel/ArtPlaceholderLabel
@onready var weapon_tag_panel: Panel = $WeaponTagPanel
@onready var weapon_tag_label: Label = $WeaponTagPanel/WeaponTagLabel
@onready var stats_label: Label = $StatsLabel
@onready var status_icon_label: Label = $StatusIconLabel

var home_position: Vector2
var drag_offset: Vector2
var press_start_pos: Vector2
var is_pointer_down: bool = false
var base_z_index: int = 0
## Cuando es `true`, desactiva el arrastre y el reposicionamiento global (`home_position`)
## para que la carta pueda alojarse dentro de contenedores (`GridContainer`/`ScrollContainer`) manteniendo su animación de hover.
var static_display_mode: bool = false

## Configura el pivote central, guarda su posición inicial y conecta las señales de input del ratón.
## Si ya tiene `card_data` asignada al instanciarse, dispara su configuración visual.
func _ready() -> void:
	pivot_offset = size / 2.0
	home_position = global_position
	
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)
	
	if card_data:
		setup_card(card_data)

## Puebla los bloques visuales de la carta a partir de `CardData`:
## 1. Cuerpo y borde uniforme (2px) teñidos según la Rareza (`RaritySystem.Tier`).
## 2. Cabecera: `[Costo]`, `TitleLabel` (coloreado según la función/efecto de la carta) y `[Icono Arma]`.
## 3. Recuadro central de Arte (`Texture2D` si existe en `data.artwork`, o emblema elemental de respaldo).
## 4. Tag compacto de familia de arma, descripción centrada (`StatsLabel`) e ícono de estado alterado al enemigo abajo a la izquierda (`StatusIconLabel`).
func setup_card(data: CardData) -> void:
	card_data = data
	if panel == null:
		await ready
	
	var rarity_color: Color = RaritySystem.get_tier_color(data.rarity)
	var category_color: Color = data.get_color()
	var art_accent: Color = data.get_art_accent_color()

	# 1. Todo el cuerpo y el reborde uniforme (2px) se colorean según la Rareza de la carta
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.08, 0.10, 0.14, 0.98).lerp(rarity_color, 0.38)
	card_style.border_width_left = 2
	card_style.border_width_top = 2
	card_style.border_width_right = 2
	card_style.border_width_bottom = 2
	card_style.border_color = rarity_color
	card_style.corner_radius_top_left = 7
	card_style.corner_radius_top_right = 7
	card_style.corner_radius_bottom_left = 7
	card_style.corner_radius_bottom_right = 7
	panel.self_modulate = Color.WHITE
	panel.add_theme_stylebox_override("panel", card_style)

	# 2. Cabecera: [Costo] + Nombre Carta (coloreado por tipo de efecto) + [Icono Arma]
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color(0.06, 0.09, 0.14, 0.85)
	badge_style.border_width_left = 1
	badge_style.border_width_top = 1
	badge_style.border_width_right = 1
	badge_style.border_width_bottom = 1
	badge_style.border_color = Color(1.0, 1.0, 1.0, 0.28)
	badge_style.corner_radius_top_left = 4
	badge_style.corner_radius_top_right = 4
	badge_style.corner_radius_bottom_left = 4
	badge_style.corner_radius_bottom_right = 4
	cost_badge.add_theme_stylebox_override("panel", badge_style)
	cost_label.text = str(data.cost)
	cost_label.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))

	title_label.text = data.title
	title_label.add_theme_color_override("font_color", category_color)
	title_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.92))
	title_label.add_theme_constant_override("outline_size", 2)

	weapon_icon_label.text = data.get_weapon_icon()
	weapon_icon_label.add_theme_color_override("font_color", Color(0.90, 0.94, 1.0))

	# 3. Recuadro de Sprite / Arte 2D (borde fino y delicado con el acento elemental del efecto)
	var art_style := StyleBoxFlat.new()
	art_style.bg_color = Color(0.04, 0.05, 0.08, 0.88).lerp(art_accent, 0.25)
	art_style.border_width_left = 1
	art_style.border_width_top = 1
	art_style.border_width_right = 1
	art_style.border_width_bottom = 1
	art_style.border_color = Color(art_accent.r, art_accent.g, art_accent.b, 0.42)
	art_style.corner_radius_top_left = 4
	art_style.corner_radius_top_right = 4
	art_style.corner_radius_bottom_left = 4
	art_style.corner_radius_bottom_right = 4
	art_panel.add_theme_stylebox_override("panel", art_style)
	
	art_panel.clip_contents = true
	art_texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	if data.artwork != null:
		art_texture.texture = data.artwork
		art_texture.visible = true
		art_placeholder_label.visible = false
	else:
		art_texture.texture = null
		art_texture.visible = false
		art_placeholder_label.visible = true
		art_placeholder_label.text = data.get_placeholder_emblem()

	# 4. Tag compacto de Familia de Arma
	var tag_style := StyleBoxFlat.new()
	tag_style.bg_color = Color(0.05, 0.06, 0.09, 0.78)
	tag_style.border_width_left = 1
	tag_style.border_width_top = 1
	tag_style.border_width_right = 1
	tag_style.border_width_bottom = 1
	tag_style.border_color = Color(1.0, 1.0, 1.0, 0.16)
	tag_style.corner_radius_top_left = 3
	tag_style.corner_radius_top_right = 3
	tag_style.corner_radius_bottom_left = 3
	tag_style.corner_radius_bottom_right = 3
	weapon_tag_panel.add_theme_stylebox_override("panel", tag_style)
	weapon_tag_label.text = data.get_weapon_tag_text()
	weapon_tag_label.add_theme_color_override("font_color", Color(0.84, 0.90, 0.98))

	# 5. Descripción centrada y emoji de estado alterado sobre el enemigo abajo a la izquierda
	stats_label.text = data.get_rules_text()
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stats_label.add_theme_color_override("font_color", Color(0.94, 0.96, 1.0))

	if status_icon_label:
		var status_icons: String = data.get_enemy_status_icons()
		status_icon_label.text = status_icons
		status_icon_label.visible = status_icons != ""

## Configura la carta en modo de exhibición estática (para inspectores de mazo o pilas con scroll),
## desactivando el drag & drop y permitiendo que la rueda del ratón desplace el contenedor padre.
func set_static_display_mode(enabled: bool = true) -> void:
	static_display_mode = enabled
	if enabled:
		mouse_filter = Control.MOUSE_FILTER_PASS

## Ejecuta un resorte exponencial continuo para interpolar suavemente la posición, rotación y escala.
## Durante el arrastre (`DRAGGING`), aplica una inclinación dinámica (tilt) basada en la velocidad horizontal.
func _process(delta: float) -> void:
	if static_display_mode:
		pivot_offset = size / 2.0
		var static_weight: float = 1.0 - exp(-18.0 * delta)
		var static_rot: float = -2.5 if current_state == State.HOVERED else 0.0
		var static_scale: Vector2 = Vector2(1.07, 1.07) if current_state == State.HOVERED else Vector2.ONE
		rotation_degrees = lerp(rotation_degrees, static_rot, static_weight)
		scale = scale.lerp(static_scale, static_weight)
		return

	if is_pointer_down and current_state != State.DRAGGING:
		if get_global_mouse_position().distance_to(press_start_pos) > DRAG_THRESHOLD:
			_start_dragging()
	
	if current_state == State.DRAGGING:
		var target_pos: Vector2 = get_global_mouse_position() - drag_offset
		var weight: float = 1.0 - exp(-28.0 * delta)
		var velocity_x: float = target_pos.x - global_position.x
		var target_tilt: float = clamp(velocity_x * 0.35, -22.0, -22.0 if velocity_x < -62.0 else 22.0)
		target_tilt = clamp(velocity_x * 0.35, -22.0, 22.0)
		
		global_position = global_position.lerp(target_pos, weight)
		rotation_degrees = lerp(rotation_degrees, target_tilt, weight)
		scale = scale.lerp(Vector2(1.2, 1.2), weight)
		card_drag_moved.emit(self)
	else:
		var weight: float = 1.0 - exp(-18.0 * delta)
		global_position = global_position.lerp(home_position, weight)
		
		var target_rot: float = -4.0 if current_state == State.HOVERED else 0.0
		rotation_degrees = lerp(rotation_degrees, target_rot, weight)
		
		var target_scale: Vector2 = Vector2(1.15, 1.15) if current_state == State.HOVERED else Vector2.ONE
		scale = scale.lerp(target_scale, weight)

## Expande la escala y rota la carta abruptamente al ser activada.
## Depende de la interpolación en `_process` para retornar suavemente a su tamaño y rotación original.
func pulse() -> void:
	scale = Vector2(1.42, 1.42)
	rotation_degrees = 7.0

## Actualiza forzosamente el orden de profundidad visual (Z-Index) de la carta a su valor correspondiente,
## asumiendo que no esté siendo arrastrada ni consumida.
func update_z_index() -> void:
	if current_state != State.DRAGGING and current_state != State.CONSUMING:
		z_index = 50 if current_state == State.HOVERED else base_z_index

## Evalúa el clic izquierdo para distinguir entre un toque rápido (emite `card_clicked` al soltar)
## y un arrastre continuo (superado el umbral `DRAG_THRESHOLD`, delega a `_start_dragging`).
func _on_gui_input(event: InputEvent) -> void:
	if static_display_mode:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_pointer_down = true
			press_start_pos = get_global_mouse_position()
			drag_offset = get_global_mouse_position() - global_position
		else:
			var was_dragging: bool = (current_state == State.DRAGGING)
			is_pointer_down = false
			if was_dragging:
				_stop_dragging()
			else:
				card_clicked.emit(self)

## Cambia el estado a DRAGGING y eleva el Z-Index al máximo (100) para renderizar la carta por encima de toda la mesa.
func _start_dragging() -> void:
	current_state = State.DRAGGING
	z_index = 100

## Restaura el estado a IDLE, devuelve el Z-Index a su valor base y emite la señal `card_released`
## para que el tablero evalúe dónde cayó.
func _stop_dragging() -> void:
	current_state = State.IDLE
	z_index = base_z_index
	card_released.emit(self)

## Transiciona la carta al estado HOVERED y eleva ligeramente su Z-Index (50),
## ignorando el evento si está en pleno arrastre o consumiéndose.
func _on_mouse_entered() -> void:
	if current_state == State.DRAGGING or current_state == State.CONSUMING:
		return
	current_state = State.HOVERED
	z_index = 50

## Devuelve la carta al estado IDLE y restaura su Z-Index base, siempre y cuando no esté siendo arrastrada ni consumida.
func _on_mouse_exited() -> void:
	if current_state == State.DRAGGING or current_state == State.CONSUMING:
		return
	current_state = State.IDLE
	z_index = base_z_index

## Ejecuta la animación de consumo estilo cartas de tarot (elevación, sacudida, quema y desintegración).
## No destruye el nodo; el orquestador (`BattleTable`) se encarga de liberarlo al finalizar.
func play_consume_animation() -> void:
	current_state = State.CONSUMING
	set_process(false)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	base_z_index = 140
	z_index = 140
	move_to_front()
	
	pivot_offset = size * 0.5
	var original_pos := position
	var original_rot := rotation
	
	# 1. FASE DE ELEVACIÓN Y ENFOQUE
	var lift_tween := create_tween().set_parallel(true)
	lift_tween.tween_property(self, "position:y", original_pos.y - 50.0, 0.35)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	lift_tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.35)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	await lift_tween.finished
	
	# 2. FASE DE VIBRACIÓN Y QUEMADO
	var mat: ShaderMaterial = panel.material as ShaderMaterial
	var burn_tween := create_tween().set_parallel(true)
	
	if mat:
		burn_tween.tween_property(mat, "shader_parameter/dissolve_amount", 1.0, 0.75)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	else:
		burn_tween.tween_property(self, "modulate:a", 0.0, 0.75)
	
	# Flash de brillo antes de desvanecerse
	burn_tween.tween_property(self, "modulate", Color(1.8, 1.3, 0.8, 1.0), 0.4)\
		.set_trans(Tween.TRANS_QUAD)
	
	# Micro-sacudidas aleatorias
	var shake_duration := 0.75
	var elapsed := 0.0
	var shake_intensity := 6.0
	
	while elapsed < shake_duration:
		var delta_shake := 0.05
		var offset := Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)
		var rot_offset := deg_to_rad(randf_range(-3.0, 3.0))
		
		var mini_tween := create_tween().set_parallel(true)
		mini_tween.tween_property(self, "position", Vector2(original_pos.x, original_pos.y - 60.0) + offset, delta_shake)
		mini_tween.tween_property(self, "rotation", original_rot + rot_offset, delta_shake)
		
		await mini_tween.finished
		elapsed += delta_shake
		shake_intensity += 0.8
	
	# 3. COLAPSO FINAL (Puff de ceniza)
	var end_tween := create_tween().set_parallel(true)
	end_tween.tween_property(self, "scale", Vector2(0.05, 0.05), 0.15)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	end_tween.tween_property(self, "modulate:a", 0.0, 0.15)
	
	await end_tween.finished
