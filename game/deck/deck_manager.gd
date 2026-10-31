## Gestor centralizado del mazo de cartas durante la partida.
## Administra las 3 pilas de combate (`draw_pile`, `discard_pile`, `graveyard_pile`)
## y expone la lógica de guardado/carga del mazo del jugador.
extends RefCounted
class_name DeckManager

## Instancias de las 3 pilas operativas de `CardPile` que componen el mazo.
var draw_pile: CardPile = CardPile.new("Mazo")
var discard_pile: CardPile = CardPile.new("Descarte")
var graveyard_pile: CardPile = CardPile.new("Cementerio")


## Reinicia por completo el gestor y construye el mazo inicial instanciando las cartas definidas en el héroe.
## Clona cada recurso asignándole su `resource_name` como sello para asegurar la persistencia al guardar.
func build_initial_deck_for_hero(run: RunState) -> void:
	# 1. Limpieza absoluta de estados previos (evita cartas fantasmas de runs anteriores)
	if draw_pile:
		draw_pile.clear()
	if discard_pile:
		discard_pile.clear()
	if graveyard_pile:
		graveyard_pile.clear()

	# 2. Comprobación defensiva del héroe y su mazo
	if not run or not run.selected_hero:
		push_error("[DeckManager] Error: No hay un héroe seleccionado en RunState.")
		return

	if run.selected_hero.starting_deck.is_empty():
		push_warning("[DeckManager] Advertencia: El héroe '%s' no tiene cartas en starting_deck." % run.selected_hero.hero_name)
		return

	# 3. Clonamos cada carta para evitar mutaciones directas sobre el .tres en disco
	var cards_to_insert: Array[CardData] = []
	for card_res in run.selected_hero.starting_deck:
		if card_res != null:
			# duplicate() asegura una copia fresca e independiente de la definición base
			var card_instance: CardData = card_res.duplicate() as CardData
			
			# SELLADO DE RUTA: Guardamos el path original para que el sistema de guardado lo encuentre
			card_instance.resource_name = card_res.resource_path if card_res.resource_path != "" else card_res.resource_name
			
			cards_to_insert.append(card_instance)

	# 4. Barajamos antes de ingresarlas al mazo de robo
	cards_to_insert.shuffle()

	# 5. Poblamos el draw_pile
	for card in cards_to_insert:
		draw_pile.add_card(card)
		
## Extrae hasta `amount` cartas de la cima del `draw_pile`.
## Si se agota el mazo principal, recicla automáticamente la pila de descarte, la baraja, y continúa robando.
func draw_cards_data(amount: int) -> Array[CardData]:
	var drawn: Array[CardData] = []
	for i in range(amount):
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				break
			discard_pile.move_all_to(draw_pile)
			draw_pile.shuffle()

		var data: CardData = draw_pile.draw_top()
		if not data:
			break
		drawn.append(data)
	return drawn
	
## Evalúa el destino de una carta una vez resuelto su efecto.
## Si la carta es `single_use` la envía al cementerio; de lo contrario, va a la pila de descarte.
func route_played_card(data: CardData) -> void:
	if not data:
		return
	if data.single_use:
		graveyard_pile.add_card(data)
	else:
		discard_pile.add_card(data)

## Envía forzosamente una carta a la pila de descarte sin ejecutarla.
## Ignora la bandera `single_use` ya que la carta no llegó a jugarse.
func discard_card(data: CardData) -> void:
	if data:
		discard_pile.add_card(data)

## Recupera todas las cartas del descarte, del cementerio y de la mesa,
## agrupándolas de vuelta en el mazo de robo y barajándolas para preparar un nuevo encuentro.
func reset_for_new_combat(board_cards_data: Array[CardData]) -> void:
	for data in board_cards_data:
		if data:
			draw_pile.add_card(data)
	discard_pile.move_all_to(draw_pile)
	graveyard_pile.move_all_to(draw_pile)
	draw_pile.shuffle()
	
## Recopila y cuenta todas las copias de cartas que posee el jugador actualmente en todas las pilas.
## Genera un informe en texto plano con rarezas, cantidades, costos y efectos detallados para la interfaz del mapa.
func get_full_deck_detailed_text(board_cards: Array[CardData] = []) -> String:
	var all_cards: Array[CardData] = []
	all_cards.append_array(draw_pile.cards)
	all_cards.append_array(discard_pile.cards)
	all_cards.append_array(graveyard_pile.cards)
	all_cards.append_array(board_cards)

	if all_cards.is_empty():
		return "El mazo esta vacio."

	var counts: Dictionary = {}
	var sample_card: Dictionary = {}
	for c in all_cards:
		if not c:
			continue
		counts[c.title] = counts.get(c.title, 0) + 1
		sample_card[c.title] = c

	var lines: Array[String] = []
	for title in counts.keys():
		var c: CardData = sample_card[title]
		var fx_parts: Array[String] = []
		for eff in c.effects:
			if eff:
				fx_parts.append(eff.get_description())
		var single_txt: String = " [UNICO USO]" if c.single_use else ""
		lines.append("x%d  [%s] %s (Costo %d)%s  ->  %s" % [
			counts[title],
			RaritySystem.get_tier_name(c.rarity),
			c.title,
			c.cost,
			single_txt,
			", ".join(fx_parts)
		])
	return "\n\n".join(lines)

## Suma y retorna la cantidad total de cartas físicas que posee el jugador, sumando opcionalmente las que estén en la mesa.
func get_total_cards_count(board_cards_count: int = 0) -> int:
	return draw_pile.size() + discard_pile.size() + graveyard_pile.size() + board_cards_count

	
## Serializa el mazo completo del jugador en un arreglo de rutas de disco.
## Incluye todas las pilas y la mesa, usando el `resource_name` como respaldo (fallback) para las cartas duplicadas en memoria.
func to_dict(active_board_cards: Array[CardData] = []) -> Array:
	var deck_paths: Array[String] = []
	var all_cards: Array = []
	
	all_cards.append_array(draw_pile.cards)
	all_cards.append_array(discard_pile.cards)
	all_cards.append_array(graveyard_pile.cards)
	all_cards.append_array(active_board_cards)
	
	for card in all_cards:
		if card != null:
			# Si el path está vacío (porque se duplicó), usamos el resource_name como salvavidas
			var path: String = card.resource_path
			if path == "" and card.resource_name != "":
				path = card.resource_name
			
			if path != "":
				deck_paths.append(path)
				
	return deck_paths

## Reconstruye el mazo del jugador desde cero leyendo un arreglo de rutas de disco.
## Carga, instancia y sella cada carta, depositándolas en la pila de robo listas para la partida.
func from_dict(deck_paths: Array) -> void:
	draw_pile.clear()
	discard_pile.clear()
	graveyard_pile.clear()
	
	for c_path in deck_paths:
		if ResourceLoader.exists(c_path):
			var card_res := load(c_path) as CardData
			if card_res:
				var copy := card_res.duplicate()
				copy.resource_name = c_path # <- Sellar la ruta en la copia
				draw_pile.add_card(copy)
				
	draw_pile.shuffle()
