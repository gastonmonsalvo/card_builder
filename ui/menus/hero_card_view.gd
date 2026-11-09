## Tarjeta visual e interactiva que representa a un héroe seleccionable dentro de `HeroSelectView`.
## Extiende de `Button` para capturar clics, utiliza un `RichTextLabel` con BBCode para renderizar atributos
## e implementa interpolación elástica de escala (`_process`) al estilo de `CardUI` para destacar el hover y la selección.
extends Button
class_name HeroCardView

## Emitida cuando el jugador hace clic en esta tarjeta para elegir al personaje.
## Pasa como parámetro la estructura de datos estática (`HeroData`) del héroe seleccionado.
signal hero_clicked(hero: HeroData)

## Velocidad del resorte exponencial para animar la escala de la tarjeta.
const SCALE_SPEED: float = 22.0
## Escala en reposo para las tarjetas no seleccionadas (ligeramente retraídas para dar contraste).
const IDLE_SCALE := Vector2(0.95, 0.95)
## Escala al pasar el mouse por encima de una tarjeta no seleccionada.
const HOVER_SCALE := Vector2(1.04, 1.04)
## Escala fija destacada cuando el héroe está seleccionado.
const SELECTED_SCALE := Vector2(1.08, 1.08)

## Referencia en memoria a la estructura de datos que define a este héroe
## (stats base, atributos RPG, arma, habilidad, deck inicial, color de acento).
var hero_data: HeroData
## Indica si esta tarjeta corresponde al héroe actualmente seleccionado.
var _is_selected: bool = false
## Indica si el cursor del mouse se encuentra actualmente posado sobre la tarjeta.
var _is_hovered: bool = false
## Escala objetivo hacia la que interpola suavemente la tarjeta en cada frame.
var _target_scale: Vector2 = IDLE_SCALE

## Ensambla proceduralmente la tarjeta inyectando los datos del héroe.
## Construye el bloque de texto enriquecido (BBCode) leyendo los atributos base
## (Vida, Oro, Suerte, Energía, Descartes, Stats RPG, Arma, Habilidad y Tamaño del Mazo)
## y lista las reliquias iniciales con sus colores de rareza correspondientes.
func setup(hero: HeroData, target_width: float) -> void:
	hero_data = hero
	custom_minimum_size = Vector2(target_width, 192)
	size = custom_minimum_size
	pivot_offset = size * 0.5
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_NONE
	text = ""

	var rtl := RichTextLabel.new()
	rtl.set_anchors_preset(Control.PRESET_FULL_RECT)
	rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rtl.bbcode_enabled = true
	rtl.scroll_active = false
	rtl.fit_content = false
	rtl.add_theme_font_size_override("normal_font_size", 11)
	
	var relics: Array[RelicData] = hero.starting_relic
	var relics_text: String = ""
	if relics.is_empty():
		relics_text = "[color=#7f8c8d]Ninguna[/color]"
	else:
		var lines: Array[String] = []
		for relic in relics:
			if relic == null:
				continue
			var r_name: String = relic.title
			var hex_color: String = _get_rarity_color_hex(relic.rarity)
			lines.append("[color=%s]%s[/color]" % [hex_color, r_name])
		relics_text = ", ".join(lines)

	var ability_title: String = hero.ability.ability_name if hero.ability != null else "Sin habilidad"

	rtl.text = (
		"[center][color=#ffcc00]%s[/color]\n"
		+ "[color=#ffffff]❤️ %d | ⚡ %d | 🪙 %d | 🍀 %d\n"
		+ "STR %d | INT %d | DEX %d\n"
		+ "Descartes: %d | Cartas: %d[/color]\n"
		+ "[color=#82ccdd]Arma: %s[/color]\n"
		+ "[color=#f8c291]Hab.: %s[/color]\n\n"
		+ "[color=#bdc3c7]Reliquias:[/color]\n%s[/center]"
	) % [
		hero.hero_name.to_upper(),
		hero.max_hp_base,
		hero.energy_base,
		hero.gold,
		hero.lucky,
		hero.base_str,
		hero.base_int,
		hero.base_dex,
		hero.discards_base,
		hero.starting_deck.size(),
		hero.get_starting_weapon_name(),
		ability_title,
		relics_text
	]
	add_child(rtl)

	pressed.connect(_on_card_pressed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	# Estado base inicial
	set_selected(false)
	scale = _target_scale

## Interpola suavemente la escala en cada frame usando un resorte exponencial (mismo feeling que `CardUI`).
func _process(delta: float) -> void:
	pivot_offset = size * 0.5
	var weight: float = 1.0 - exp(-SCALE_SPEED * delta)
	scale = scale.lerp(_target_scale, weight)

## Dispara un pulso elástico al hacer clic en la tarjeta y emite `hero_clicked`.
func _on_card_pressed() -> void:
	scale = Vector2(1.13, 1.13)
	hero_clicked.emit(hero_data)

## Actualiza el estado de selección de la tarjeta y refresca su apariencia visual y escala objetivo.
func set_selected(is_selected: bool) -> void:
	_is_selected = is_selected
	_refresh_visual_state()

## Activa el estado de previsualización (hover) cuando el cursor entra en la tarjeta.
func _on_mouse_entered() -> void:
	_is_hovered = true
	_refresh_visual_state()

## Desactiva el estado de previsualización (hover) cuando el cursor sale de la tarjeta.
func _on_mouse_exited() -> void:
	_is_hovered = false
	_refresh_visual_state()

## Sincroniza el color, `z_index`, escala objetivo y `StyleBox` de la tarjeta según su estado.
## - Seleccionada: escala `1.08x`, `z_index` al frente y color de acento encendido con `StyleBox` `"hover"`.
## - Hover (no seleccionada): escala `1.04x` y color de acento encendido.
## - Inactiva (no seleccionada): escala `0.95x` y color de acento mezclado suavemente hacia gris acero (sin parecer bloqueada).
func _refresh_visual_state() -> void:
	if hero_data == null:
		return
	var hover_style: StyleBox = get_theme_stylebox("hover", "Button")
	if _is_selected:
		_target_scale = SELECTED_SCALE
		z_index = 20
		self_modulate = hero_data.accent_color * 0.78
		modulate = Color(1.0, 1.0, 1.0, 1.0)
		if hover_style:
			add_theme_stylebox_override("normal", hover_style)
			add_theme_stylebox_override("pressed", hover_style)
	elif _is_hovered:
		_target_scale = HOVER_SCALE
		z_index = 10
		self_modulate = hero_data.accent_color * 0.78
		modulate = Color(1.0, 1.0, 1.0, 1.0)
		remove_theme_stylebox_override("normal")
		remove_theme_stylebox_override("pressed")
	else:
		_target_scale = IDLE_SCALE
		z_index = 1
		remove_theme_stylebox_override("normal")
		remove_theme_stylebox_override("pressed")
		# Conserva el matiz del héroe pero desaturado hacia gris acero para que quede en segundo plano sin parecer bloqueado
		var muted_tint: Color = hero_data.accent_color.lerp(Color(0.55, 0.58, 0.65, 1.0), 0.52)
		self_modulate = muted_tint * 0.62
		modulate = Color(0.86, 0.88, 0.92, 0.96)

## Función de utilidad interna. Traduce el enumerador de rareza de la reliquia (`RaritySystem.Tier`)
## a un código de color Hexadecimal compatible con las etiquetas BBCode del `RichTextLabel`.
func _get_rarity_color_hex(rarity: int) -> String:
	match rarity:
		RaritySystem.Tier.COMMON:
			return "#dcdde1"
		RaritySystem.Tier.UNCOMMON:
			return "#2ecc71"
		RaritySystem.Tier.RARE:
			return "#3498db"
		RaritySystem.Tier.EPIC:
			return "#9b59b6"
		RaritySystem.Tier.LEGENDARY:
			return "#f1c40f"
		_:
			return "#dcdde1"
