## Componente visual autónomo del Dado de Crítico (D100) en la mesa de combate.
## Encapsula la construcción de su propio `PanelContainer`, etiquetas, estilos dinámicos (`StyleBoxFlat`)
## y las corrutinas de animación secuencial por etapas (Lectura de Objetivo -> Giro D100 -> Desglose de Resultado y Daño),
## permitiendo saltar/cerrar la animación en cualquier instante haciendo clic sobre el panel.
extends PanelContainer
class_name CritDiceWidget

## Señal interna emitida cuando el jugador hace clic sobre el panel para saltar la animación.
signal skip_pressed

var _dice_style: StyleBoxFlat
var _header_lbl: Label
var _target_lbl: Label
var _number_lbl: Label
var _outcome_lbl: Label
var _damage_lbl: Label
var _skip_hint_lbl: Label
var _skip_requested: bool = false

## Construye e inicializa el panel flotante del dado D100 con jerarquía tipográfica clara y soporte de clic para saltar.
func _init() -> void:
	name = "CritDiceWidget"
	position = Vector2(346, 140)
	custom_minimum_size = Vector2(460, 224)
	size = Vector2(460, 224)
	pivot_offset = Vector2(230, 112)
	z_index = 95
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	visible = false

	_dice_style = StyleBoxFlat.new()
	_dice_style.bg_color = Color(0.05, 0.07, 0.12, 0.98)
	_dice_style.border_width_left = 3
	_dice_style.border_width_top = 3
	_dice_style.border_width_right = 3
	_dice_style.border_width_bottom = 3
	_dice_style.border_color = Color(0.42, 0.68, 1.0)
	_dice_style.corner_radius_top_left = 14
	_dice_style.corner_radius_top_right = 14
	_dice_style.corner_radius_bottom_left = 14
	_dice_style.corner_radius_bottom_right = 14
	_dice_style.content_margin_left = 18
	_dice_style.content_margin_right = 18
	_dice_style.content_margin_top = 12
	_dice_style.content_margin_bottom = 10
	add_theme_stylebox_override("panel", _dice_style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 5)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vbox)

	_header_lbl = Label.new()
	_header_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header_lbl.add_theme_font_size_override("font_size", 14)
	_header_lbl.add_theme_color_override("font_color", Color(0.70, 0.84, 1.0))
	vbox.add_child(_header_lbl)

	_target_lbl = Label.new()
	_target_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_target_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_target_lbl.add_theme_font_size_override("font_size", 16)
	_target_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.50))
	vbox.add_child(_target_lbl)

	_number_lbl = Label.new()
	_number_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_number_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_number_lbl.add_theme_font_size_override("font_size", 36)
	_number_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	_number_lbl.add_theme_constant_override("outline_size", 4)
	_number_lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.92))
	vbox.add_child(_number_lbl)

	_outcome_lbl = Label.new()
	_outcome_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_outcome_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_outcome_lbl.add_theme_font_size_override("font_size", 17)
	_outcome_lbl.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98))
	vbox.add_child(_outcome_lbl)

	_damage_lbl = Label.new()
	_damage_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_damage_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_damage_lbl.add_theme_font_size_override("font_size", 20)
	_damage_lbl.add_theme_constant_override("outline_size", 3)
	_damage_lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	_damage_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.80))
	vbox.add_child(_damage_lbl)

	_skip_hint_lbl = Label.new()
	_skip_hint_lbl.text = "(Clic aquí para saltar)"
	_skip_hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skip_hint_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skip_hint_lbl.add_theme_font_size_override("font_size", 11)
	_skip_hint_lbl.add_theme_color_override("font_color", Color(0.58, 0.65, 0.76, 0.85))
	vbox.add_child(_skip_hint_lbl)

## Detecta el clic izquierdo sobre el panel del dado para interrumpir y saltar inmediatamente la animación en curso.
func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_skip_requested = true
		skip_pressed.emit()
		accept_event()

## Espera `duration` segundos o se despierta en el acto si el jugador hace clic en el panel (`skip_pressed`).
func _wait_or_skip(duration: float) -> void:
	if _skip_requested:
		return
	var timer := get_tree().create_timer(duration)
	var on_skip := func() -> void:
		if timer.time_left > 0.0:
			timer.timeout.emit()
	skip_pressed.connect(on_skip, CONNECT_ONE_SHOT)
	await timer.timeout
	if skip_pressed.is_connected(on_skip):
		skip_pressed.disconnect(on_skip)

## Ejecuta la animación por etapas del Dado D100 a partir de los metadatos de `combo_state`:
## 1) Muestra claramente cuánto necesitás sacar y el daño base (0.55s).
## 2) Gira el dado D100 (~0.65s).
## 3) Clava el número que salió junto al requerido y destaca el daño final durante ~2.7s - 3.2s para lectura cómoda.
## Si el jugador hace clic sobre el panel en cualquier etapa, salta la espera y cierra el widget inmediatamente.
func play_roll(combo_state: Dictionary, on_landed: Callable = Callable(), banner_callback: Callable = Callable()) -> void:
	if not bool(combo_state.get("crit_rolled", false)):
		if on_landed.is_valid():
			on_landed.call()
		return

	_skip_requested = false
	var crit_pct: float = float(combo_state.get("crit_chance_pct", 0.0))
	var threshold: int = int(combo_state.get("crit_threshold_d100", 100))
	var final_roll: int = int(combo_state.get("crit_roll_d100", 1))
	var is_crit: bool = bool(combo_state.get("is_crit", false))
	var base_dmg: int = int(combo_state.get("base_dmg_before_crit", 0))
	var final_dmg: int = int(combo_state.get("final_dmg_applied", 0))

	# --- ETAPA 1: PRESENTACIÓN CLARA DEL OBJETIVO ANTES DE TIRAR ---
	_dice_style.bg_color = Color(0.05, 0.07, 0.12, 0.98)
	_dice_style.border_color = Color(0.42, 0.68, 1.0)
	_header_lbl.text = "🎲 TIRADA DE GOLPE CRÍTICO (Probabilidad: %.1f%%)" % crit_pct
	_target_lbl.text = "🎯 NECESITÁS SACAR:  %d o más  (en D100)" % threshold
	_number_lbl.text = "🎲  [ -- ]"
	_number_lbl.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	_outcome_lbl.text = "Preparando tirada..."
	_outcome_lbl.add_theme_color_override("font_color", Color(0.78, 0.84, 0.95))
	_damage_lbl.text = "Daño del Combo: %d  (Crítico x1.5 = %d)" % [base_dmg, int(round(float(base_dmg) * 1.5))]
	_damage_lbl.add_theme_color_override("font_color", Color(0.85, 0.90, 1.0))

	visible = true
	modulate = Color(1, 1, 1, 1)
	scale = Vector2(0.80, 0.80)
	rotation_degrees = 0.0

	var pop_tween := create_tween()
	pop_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Pausa breve para leer el umbral antes de que empiece a girar el dado (saltable con clic)
	await _wait_or_skip(0.55)

	# --- ETAPA 2: GIRO DEL DADO (RÁPIDO Y FLUIDO ~0.65s, SALTABLE CON CLIC) ---
	if not _skip_requested:
		_outcome_lbl.text = "Tirando D100..."
		var step_delays: Array[float] = [0.045, 0.045, 0.05, 0.05, 0.06, 0.07, 0.08, 0.10, 0.13]
		for i in range(step_delays.size()):
			if _skip_requested:
				break
			var fake_num: int = ((final_roll + (i + 1) * 17 + i * 11) % 100) + 1
			_number_lbl.text = "🎲  [ %02d ]" % fake_num
			rotation_degrees = -3.0 if (i % 2 == 0) else 3.0
			await _wait_or_skip(step_delays[i])

	# --- ETAPA 3: RESULTADO EN PANTALLA (LECTURA PAUSADA Y CLARA, SALTABLE CON CLIC) ---
	rotation_degrees = 0.0
	scale = Vector2(1.0, 1.0)
	_target_lbl.text = "🎯 NECESITABAS: %d+    |    🎲 SALIÓ: %d" % [threshold, final_roll]
	_number_lbl.text = "🎲 SALIÓ:  %d" % final_roll
	if on_landed.is_valid():
		on_landed.call()

	if is_crit:
		_dice_style.bg_color = Color(0.20, 0.11, 0.03, 0.99)
		_dice_style.border_color = Color(1.0, 0.78, 0.15)
		_number_lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.22))
		_outcome_lbl.text = "💥 ¡GOLPE CRÍTICO ACTIVADO (x1.5)!"
		_outcome_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.30))
		_damage_lbl.text = "⚔️ DAÑO FINAL:  %d  ➔  %d DAÑO TOTAL" % [base_dmg, final_dmg]
		_damage_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.40))
		if banner_callback.is_valid():
			banner_callback.call("💥 ¡SALIÓ %d (NECESITABAS %d+)! ¡CRÍTICO x1.5: %d ➔ %d DE DAÑO!" % [final_roll, threshold, base_dmg, final_dmg])
		if not _skip_requested:
			var impact_tween := create_tween()
			impact_tween.tween_property(self, "scale", Vector2(1.16, 1.16), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			impact_tween.tween_property(self, "scale", Vector2(1.04, 1.04), 0.14)
			await _wait_or_skip(3.20)
	else:
		_dice_style.bg_color = Color(0.07, 0.09, 0.14, 0.98)
		_dice_style.border_color = Color(0.50, 0.58, 0.70)
		_number_lbl.add_theme_color_override("font_color", Color(0.90, 0.94, 1.0))
		_outcome_lbl.text = "⚔️ NO ALCANZÓ EL UMBRAL  •  GOLPE NORMAL (x1.0)"
		_outcome_lbl.add_theme_color_override("font_color", Color(0.78, 0.84, 0.92))
		_damage_lbl.text = "⚔️ DAÑO TOTAL APLICADO:  %d DAÑO" % final_dmg
		_damage_lbl.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
		if banner_callback.is_valid():
			banner_callback.call("🎲 Salió %d (Necesitabas %d+)  •  Golpe Normal: %d de Daño" % [final_roll, threshold, final_dmg])
		if not _skip_requested:
			var impact_tween := create_tween()
			impact_tween.tween_property(self, "scale", Vector2(1.06, 1.06), 0.10)
			impact_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.10)
			await _wait_or_skip(2.70)

	if not _skip_requested:
		var fade_tween := create_tween()
		fade_tween.tween_property(self, "modulate:a", 0.0, 0.32)
		await fade_tween.finished

	visible = false
