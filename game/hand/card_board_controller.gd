## Controlador lógico del tablero de cartas en la mesa.
## Gestiona el posicionamiento espacial fluido (en abanico o fila) de los nodos `CardUI` 
## dentro de la Mano y la Zona de Combo,  así como su reordenamiento dinámico en vivo 
## durante las operaciones de arrastrar y soltar (drag and drop).
extends RefCounted
class_name CardBoardController

signal card_clicked(card: CardUI)
signal card_dropped(card: CardUI, dropped_in_combo: bool)
signal board_order_changed()

const CARD_SCENE: PackedScene = preload(CombatConstants.CARD_UI_SCN)
const CARD_WIDTH: float = 140.0

var hand_zone: Panel
var combo_zone: Panel
var hand_cards: Array[CardUI] = []
var combo_cards: Array[CardUI] = []
var is_locked: bool = false

## Constructor. Recibe las referencias de los Paneles de la UI (`hand_zone` y `combo_zone`)
## y purga cualquier nodo residual que pudiera haber quedado como hijo de la zona de la mano.
func _init(p_hand_zone: Panel, p_combo_zone: Panel) -> void:
	hand_zone = p_hand_zone
	combo_zone = p_combo_zone
	for child in hand_zone.get_children():
		child.queue_free()
		
## Instancia nuevos nodos `CardUI` a partir de un arreglo de datos.
## Los posiciona inicialmente fuera de cámara (sobre el mazo virtual) para que vuelen con 
## física elástica hacia su lugar en la mano, conectando además sus señales de interacción.
func spawn_cards_to_hand(cards_data: Array[CardData]) -> void:
	for data in cards_data:
		if not data:
			continue
		var new_card: CardUI = CARD_SCENE.instantiate()
		hand_zone.add_child(new_card)
		new_card.setup_card(data)
		new_card.global_position = hand_zone.global_position + Vector2(-150, 15)
		new_card.card_clicked.connect(_on_card_clicked)
		new_card.card_drag_moved.connect(_on_card_drag_moved)
		new_card.card_released.connect(_on_card_released)
		hand_cards.append(new_card)
	layout_cards()

## Verifica si la instancia de la carta especificada se encuentra actualmente registrada 
## en la mano del jugador.
func is_in_hand(card: CardUI) -> bool:
	return hand_cards.has(card)
	
## Verifica si la instancia de la carta especificada se encuentra actualmente registrada
## en la zona de resolución de combos.
func is_in_combo(card: CardUI) -> bool:
	return combo_cards.has(card)
	
## Transfiere una carta desde la mano hacia la zona de combo.
## Si se arrastró físicamente (`use_drop_position == true`), calcula su posición ideal intercalándola entre las demás. Luego recalcula la distribución visual general.
func move_to_combo(card: CardUI, use_drop_position: bool = false) -> void:
	hand_cards.erase(card)
	if not combo_cards.has(card):
		if use_drop_position:
			var center_x: float = card.global_position.x + (card.size.x * 0.5)
			var idx: int = _find_slot_index(combo_cards, card, center_x)
			combo_cards.insert(idx, card)
		else:
			combo_cards.append(card)
	layout_cards()
	
## Transfiere una carta desde la zona de combo de regreso a la mano.
## Si se arrastró físicamente, calcula su índice posicional relativo. Finaliza recalculando el layout espacial.
func move_to_hand(card: CardUI, use_drop_position: bool = false) -> void:
	combo_cards.erase(card)
	if not hand_cards.has(card):
		if use_drop_position:
			var center_x: float = card.global_position.x + (card.size.x * 0.5)
			var idx: int = _find_slot_index(hand_cards, card, center_x)
			hand_cards.insert(idx, card)
		else:
			hand_cards.append(card)
	layout_cards()
	
## Desvincula por completo a la carta de los registros lógicos, tanto de la mano como del combo.
func remove_card(card: CardUI) -> void:
	hand_cards.erase(card)
	combo_cards.erase(card)
	
## Libera de memoria (`queue_free`) todos los nodos `CardUI` de la mesa y extrae sus recursos `CardData` subyacentes.
## Retorna un arreglo plano con todos los recursos extraídos 
## (útil para devolver las cartas al mazo al finalizar el turno o guardar la partida).
func clear_all_and_extract_data() -> Array[CardData]:
	var extracted: Array[CardData] = []
	for c in hand_cards:
		if c.card_data:
			extracted.append(c.card_data)
		c.queue_free()
	hand_cards.clear()

	for c in combo_cards:
		if c.card_data:
			extracted.append(c.card_data)
		c.queue_free()
	combo_cards.clear()
	return extracted
	
## Ordena la actualización del posicionamiento espacial para ambas zonas (Mano y Combo) simultáneamente.
func layout_cards() -> void:
	_layout_zone(hand_cards, hand_zone)
	_layout_zone(combo_cards, combo_zone)
	
## Calcula el espaciado dinámico (aplicando solapamiento si la zona está muy llena) 
## y asigna la `home_position` y el `z_index` de cada `CardUI` dentro del Panel correspondiente.
func _layout_zone(cards: Array[CardUI], zone: Panel) -> void:
	var count: int = cards.size()
	if count == 0:
		return

	var padding: float = 20.0
	var available_width: float = zone.size.x - (padding * 2.0) - CARD_WIDTH
	var ideal_step: float = 152.0

	var step: float = ideal_step
	if count > 1:
		step = min(ideal_step, available_width / float(count - 1))

	var total_span: float = CARD_WIDTH + step * float(count - 1)
	var start_x: float = (zone.size.x - total_span) * 0.5

	for i in range(count):
		var c: CardUI = cards[i]
		c.base_z_index = i
		c.home_position = zone.global_position + Vector2(start_x + i * step, 15.0)
		c.update_z_index()
		
## Calcula el índice de arreglo donde debería insertarse una carta basándose en su coordenada horizontal (X),
## permitiendo intercalar cartas visualmente durante el arrastre.
func _find_slot_index(list: Array[CardUI], dragged: CardUI, center_x: float) -> int:
	var idx: int = 0
	for other in list:
		if other == dragged:
			continue
		var other_center: float = other.home_position.x + (other.size.x * 0.5)
		if center_x > other_center:
			idx += 1
	return idx
	
## Intercepta el clic izquierdo sobre una carta. Si el tablero no está bloqueado por una animación, 
## retransmite la señal hacia el coordinador principal.
func _on_card_clicked(card: CardUI) -> void:
	if is_locked:
		return
	card_clicked.emit(card)

## Reacciona al movimiento de arrastre. Si la carta se movió lo suficiente horizontalmente para cruzar a otra,
## reordena dinámicamente el arreglo y emite `board_order_changed` para actualizar el preview numérico en vivo.
func _on_card_drag_moved(card: CardUI) -> void:
	if is_locked:
		return
	var center_x: float = card.global_position.x + (card.size.x * 0.5)

	if combo_cards.has(card):
		var old_idx: int = combo_cards.find(card)
		var new_idx: int = _find_slot_index(combo_cards, card, center_x)
		if new_idx != old_idx:
			combo_cards.remove_at(old_idx)
			combo_cards.insert(new_idx, card)
			layout_cards()
			board_order_changed.emit()
	elif hand_cards.has(card):
		var old_idx: int = hand_cards.find(card)
		var new_idx: int = _find_slot_index(hand_cards, card, center_x)
		if new_idx != old_idx:
			hand_cards.remove_at(old_idx)
			hand_cards.insert(new_idx, card)
			layout_cards()

## Determina físicamente dónde fue soltada la carta
## (mediante colisión de su centro con el rectángulo del `combo_zone`)
## y notifica al tablero superior para que valide su jugabilidad y aplique los costos.
func _on_card_released(card: CardUI) -> void:
	if is_locked:
		card.update_z_index()
		return
	var card_center: Vector2 = card.global_position + (card.size * 0.5)
	var in_combo: bool = combo_zone.get_global_rect().has_point(card_center)
	card_dropped.emit(card, in_combo)
	
## Iteración defensiva de limpieza total. Libera (hace `queue_free`)
## de forma segura a cualquier `CardUI` vivo en la mesa y vacía los registros.
func clear_all_nodes() -> void:
	# Limpieza de las cartas en mano
	if "hand_cards" in self:
		for card in hand_cards:
			if is_instance_valid(card):
				card.queue_free()
		hand_cards.clear()

	# Limpieza de las cartas jugadas en la zona de combo
	if "combo_cards" in self:
		for card in combo_cards:
			if is_instance_valid(card):
				card.queue_free()
		combo_cards.clear()
