## Tarjeta visual e interactiva que representa a un héroe seleccionable en el menú principal.
## Extiende de `Button` para capturar clics y utiliza un `RichTextLabel` con BBCode para formatear 
## y renderizar de manera eficiente las estadísticas (HP, Oro, Suerte, Energía) y reliquias iniciales.
extends Button
class_name HeroCardView

## Emitida cuando el jugador hace clic en esta tarjeta para elegir al personaje. 
## Pasa como parámetro la estructura de datos estática (`HeroData`) del héroe seleccionado.
signal hero_clicked(hero: HeroData)

## Referencia en memoria a la estructura de datos que define a este héroe
## (stats base, deck inicial, color de acento).
var hero_data: HeroData

## Ensambla proceduralmente la tarjeta inyectando los datos del héroe. 
## Construye el bloque de texto enriquecido (BBCode) 
## leyendo los atributos base (Vida, Oro, Suerte, Energía, Descartes, Tamaño del Mazo)
##  y lista las reliquias iniciales con sus colores de rareza correspondientes.
func setup(hero: HeroData, target_width: float) -> void:
	hero_data = hero
	custom_minimum_size = Vector2(target_width, 140)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	text = ""

	var rtl := RichTextLabel.new()
	rtl.set_anchors_preset(Control.PRESET_FULL_RECT)
	rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rtl.bbcode_enabled = true
	rtl.scroll_active = false
	rtl.fit_content = false
	rtl.add_theme_font_size_override("normal_font_size", 10)
	
	# Lógica de compatibilidad para extraer las reliquias iniciales
	var relics: Array = []
	if "starting_relics" in hero and not hero.starting_relics.is_empty():
		relics = hero.starting_relics
	elif "starting_relic" in hero and not hero.starting_relic.is_empty():
		relics = hero.starting_relic

	var relics_text: String = ""
	if relics.is_empty():
		relics_text = "[color=#7f8c8d]Sin Reliquias[/color]"
	else:
		var lines: Array[String] = []
		for relic in relics:
			if relic == null:
				continue
			var r_name: String = relic.title
			var hex_color: String = _get_rarity_color_hex(relic.rarity)
			lines.append("[color=%s]%s[/color]" % [hex_color, r_name])
		
		relics_text = "\n".join(lines)
	# Inyección del BBCode con íconos, colores y saltos de línea
	rtl.text = "[center][color=#ffcc00]%s[/color]\n[color=#ffffff]❤️: %d | 🪙: %d | 🍀: %d |⚡: %d\nDesc: %d | Deck: %d[/color]\n\nReliquias:\n%s[/center]" % [
		hero.hero_name.to_upper(),
		hero.max_hp_base,
		hero.gold,
		hero.lucky,
		hero.energy_base,
		hero.discards_base,
		hero.starting_deck.size(),
		relics_text
	]
	add_child(rtl)

	pressed.connect(func(): hero_clicked.emit(hero_data))
	
	# Estado base inicial (apagado hasta que se lo seleccione)
	set_selected(false)

## Modifica el brillo de la tarjeta multiplicando su color de acento base (`self_modulate`).
## Se llama desde el orquestador del menú para iluminar al héroe seleccionado (1.5x) 
## y oscurecer al resto (0.72x).
func set_selected(is_selected: bool) -> void:
	if is_selected:
		self_modulate = hero_data.accent_color * 1.5
	else:
		self_modulate = hero_data.accent_color * 0.72
		
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
