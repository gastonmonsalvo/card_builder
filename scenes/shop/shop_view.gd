## Interfaz modal interactiva para la "Tienda del Bazar".
## Construye proceduralmente el mostrador donde el jugador puede 
## gastar su oro para adquirir nuevas cartas para el mazo o reliquias permanentes.

extends Control
class_name ShopView

## Emitida cuando el jugador hace clic en el botón de compra de una carta.
## Pasa como parámetros la estructura estática de la carta (`CardData`) y el costo final debitado.
signal card_bought(card: CardData, cost: int)

## Emitida cuando el jugador hace clic en el botón de compra de una reliquia.
## Pasa como parámetros la estructura estática de la reliquia (`RelicData`) y el costo final debitado.
signal relic_bought(relic: RelicData, cost: int)
## Emitida cuando el jugador presiona el botón "VOLVER AL MAPA", solicitando cerrar la tienda.
signal closed()

## Referencia a la etiqueta visual que muestra el saldo actual de oro del jugador.
var gold_label: Label
## Contenedor horizontal dinámico que aloja los botones de compra de las cartas.
var cards_container: HBoxContainer
## Contenedor horizontal dinámico que aloja los botones de compra de las reliquias.
var relics_container: HBoxContainer

## Constructor de la interfaz visual.
## Ensambla por código el panel central opaco (`860x520`),
## el título de la tienda, el indicador de oro disponible,
## los dos contenedores horizontales separados para el stock (Cartas y Reliquias)
## y el botón inferior para cerrar el modal y volver al mapa.
func _init() -> void:
	name = "ShopView"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 110

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.05, 0.07, 0.96)
	add_child(bg)

	var panel := Panel.new()
	panel.size = Vector2(860, 520)
	panel.position = Vector2((1152.0 - 860.0) * 0.5, (648.0 - 520.0) * 0.5)
	add_child(panel)

	var title := Label.new()
	title.text = "TIENDA DEL BAZAR"
	title.position = Vector2(30, 20)
	title.size = Vector2(800, 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	panel.add_child(title)

	gold_label = Label.new()
	gold_label.position = Vector2(30, 56)
	gold_label.size = Vector2(800, 24)
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gold_label.add_theme_font_size_override("font_size", 16)
	gold_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	panel.add_child(gold_label)

	# Sección Cartas
	var cards_lbl := Label.new()
	cards_lbl.text = "--- CARTAS EN VENTA ---"
	cards_lbl.position = Vector2(30, 90)
	cards_lbl.size = Vector2(800, 20)
	cards_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(cards_lbl)

	cards_container = HBoxContainer.new()
	cards_container.position = Vector2(40, 115)
	cards_container.size = Vector2(780, 140)
	cards_container.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_container.add_theme_constant_override("separation", 20)
	panel.add_child(cards_container)

	# Sección Reliquias
	var relics_lbl := Label.new()
	relics_lbl.text = "--- RELIQUIAS EN VENTA ---"
	relics_lbl.position = Vector2(30, 270)
	relics_lbl.size = Vector2(800, 20)
	relics_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(relics_lbl)

	relics_container = HBoxContainer.new()
	relics_container.position = Vector2(40, 295)
	relics_container.size = Vector2(780, 130)
	relics_container.alignment = BoxContainer.ALIGNMENT_CENTER
	relics_container.add_theme_constant_override("separation", 24)
	panel.add_child(relics_container)

	# Botón Salir
	var close_btn := Button.new()
	close_btn.text = "VOLVER AL MAPA"
	close_btn.position = Vector2(330, 455)
	close_btn.size = Vector2(200, 42)
	close_btn.pressed.connect(func():
		visible = false
		closed.emit()
	)
	panel.add_child(close_btn)

## Inyecta el inventario de la tienda generado por el `RunState`. 
## Limpia instancias previas y genera un botón interactivo por cada ítem listado. 
## Si el objeto es nulo (fue comprado en una visita previa a esta misma tienda), 
## renderiza un botón "VENDIDO" inactivo.
## Bloquea (deshabilita) el botón de compra si el `current_gold` del jugador es inferior al precio calculado.
func open_shop(current_gold: int, available_cards: Array[CardData], available_relics: Array[RelicData]) -> void:
	visible = true
	_refresh_gold(current_gold)

	for c in cards_container.get_children():
		c.queue_free()
	for r in relics_container.get_children():
		r.queue_free()

	# Generar botones de cartas
	for card in available_cards:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(170, 120)
		
		if card == null:
			# Si el slot es null significa que ya fue comprado en una visita previa
			btn.text = "VENDIDO"
			btn.disabled = true
			btn.set_meta("sold", true)
		else:
			var price: int = _calculate_card_price(card)
			btn.text = "%s\nCosto: %d Maná\n\nPrecio: %d Oro" % [card.title, card.cost, price]
			btn.disabled = current_gold < price
			btn.set_meta("price", price)
			btn.set_meta("sold", false)
			btn.pressed.connect(func():
				btn.disabled = true
				btn.text = "COMPRADO"
				btn.set_meta("sold", true)
				# Avisamos al director que se compró esta carta específica
				card_bought.emit(card, price)
			)
		cards_container.add_child(btn)

	for relic in available_relics:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(200, 110)
		
		if relic == null:
			btn.text = "VENDIDO"
			btn.disabled = true
			btn.set_meta("sold", true)
		else:
			# 1. Declaramos price aquí adentro para este scope
			var price: int = _calculate_relic_price(relic)
			
			# 2. Obtenemos el tier, el título, la descripción manual y los efectos técnicos
			var tier_str: String = RaritySystem.get_tier_name(relic.rarity)
			var eff_desc: String = relic.get_effects_description() if relic.has_method("get_effects_description") else ""
			
			var display_text: String = "[%s] %s\n%s" % [tier_str, relic.title, relic.description]
			if eff_desc != "":
				display_text += "\n(%s)" % eff_desc
				
			display_text += "\n\nPrecio: %d Oro" % price
			btn.text = display_text
			
			btn.disabled = current_gold < price
			btn.set_meta("price", price)
			btn.set_meta("sold", false)
			btn.pressed.connect(func():
				btn.disabled = true
				btn.text = "COMPRADO"
				btn.set_meta("sold", true)
				relic_bought.emit(relic, price)
			)
			
		relics_container.add_child(btn)
		
## Re-evalúa el poder adquisitivo del jugador inmediatamente después de una compra.
## Actualiza la etiqueta del oro y desactiva dinámicamente cualquier botón de ítem sobrante cuyo `meta("price")`
## supere al `new_gold` restante (sin acoplarse al formato de texto del botón).
func update_after_purchase(new_gold: int) -> void:
	_refresh_gold(new_gold)
	for btn in cards_container.get_children():
		if btn is Button and not bool(btn.get_meta("sold", true)):
			var cost: int = int(btn.get_meta("price", 0))
			btn.disabled = new_gold < cost
	for btn in relics_container.get_children():
		if btn is Button and not bool(btn.get_meta("sold", true)):
			var cost: int = int(btn.get_meta("price", 0))
			btn.disabled = new_gold < cost

## Actualiza puramente el texto de la etiqueta visual de la billetera del jugador.
func _refresh_gold(amount: int) -> void:
	gold_label.text = "Oro Disponible: %d" % amount
	
## Función de tasación interna para cartas. 
## Calcula el costo base en oro leyendo el enumerador `RaritySystem.Tier` de la carta:
## `45` (Común), `60` (Poco Común), `75` (Rara), `120` (Épica), `180` (Legendaria).
func _calculate_card_price(card: CardData) -> int:
	if not card:
		return 50
	match card.rarity:
		RaritySystem.Tier.COMMON:
			return 45
		RaritySystem.Tier.UNCOMMON:
			return 60
		RaritySystem.Tier.RARE:
			return 75
		RaritySystem.Tier.EPIC:
			return 120
		RaritySystem.Tier.LEGENDARY:
			return 180
		_:
			return 50
			
## Función de tasación interna para reliquias. 
## Aplica una inflación general sobre el costo de rareza (`RaritySystem.Tier`) al tratarse de bonificadores pasivos permanentes:
## `120` (Común), `140` (Poco Común), `160` (Rara), `220` (Épica), `300` (Legendaria).
func _calculate_relic_price(relic: RelicData) -> int:
	if not relic:
		return 150
	match relic.rarity:
		RaritySystem.Tier.COMMON:
			return 120
		RaritySystem.Tier.UNCOMMON:
			return 140
		RaritySystem.Tier.RARE:
			return 160
		RaritySystem.Tier.EPIC:
			return 220
		RaritySystem.Tier.LEGENDARY:
			return 300
		_:
			return 150
