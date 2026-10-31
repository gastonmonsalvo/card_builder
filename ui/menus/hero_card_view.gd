extends Button
class_name HeroCardView

signal hero_clicked(hero: HeroData)

var hero_data: HeroData

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
	
	# Estado base inicial
	set_selected(false)

## Cambia el brillo de la tarjeta si es el héroe actualmente seleccionado
func set_selected(is_selected: bool) -> void:
	if is_selected:
		self_modulate = hero_data.accent_color * 1.5
	else:
		self_modulate = hero_data.accent_color * 0.72

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
