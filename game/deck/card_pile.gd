## Contenedor genérico para gestionar colecciones de recursos `CardData`.
## Actúa como estructura base para el mazo de robo, la pila de descartes y el cementerio,
##  emitiendo señales al cambiar su tamaño.
extends RefCounted
class_name CardPile

signal pile_changed(new_count: int)

var pile_name: String = "Pila"
var cards: Array[CardData] = []

func _init(p_name: String = "Pila") -> void:
	pile_name = p_name
	
## Agrega una carta al final del arreglo (la cima de la pila) y emite la señal de cambio de tamaño.
func add_card(card: CardData) -> void:
	if card:
		cards.append(card)
		pile_changed.emit(cards.size())

## Extrae y devuelve la carta ubicada en la cima de la pila (último elemento del arreglo).
## Retorna `null` si la pila está vacía.
func draw_top() -> CardData:
	if cards.is_empty():
		return null
	var top_card: CardData = cards.pop_back()
	pile_changed.emit(cards.size())
	return top_card
	
## Aleatoriza el orden interno de las cartas en el arreglo.
func shuffle() -> void:
	cards.shuffle()

## Vacía por completo la pila y emite la señal indicando que su tamaño es 0.
func clear() -> void:
	cards.clear()
	pile_changed.emit(0)

## Devuelve la cantidad actual de cartas contenidas en la pila.
func size() -> int:
	return cards.size()

## Evalúa si la pila no contiene ninguna carta. Retorna `true` si está vacía.
func is_empty() -> bool:
	return cards.is_empty()

## Transfiere todas las cartas de esta instancia hacia la `target_pile` especificada.
## Vacía la pila de origen y emite las señales de actualización de tamaño para ambas pilas.
func move_all_to(target_pile: CardPile) -> void:
	for card in cards:
		target_pile.cards.append(card)
	cards.clear()
	pile_changed.emit(0)
	target_pile.pile_changed.emit(target_pile.cards.size())
	
## Genera un texto formateado agrupando cartas idénticas por título (ej. "Ataque x3, Escudo x2").
## Útil para renderizar el contenido en modales de inspección de la interfaz durante el combate.
func get_contents_summary() -> String:
	if cards.is_empty():
		return "%s: (Vacia)" % pile_name
	
	var counts: Dictionary = {}
	for card in cards:
		var t: String = card.title
		counts[t] = counts.get(t, 0) + 1
	
	var parts: Array[String] = []
	for title in counts.keys():
		parts.append("%s x%d" % [title, counts[title]])
	return "%s (%d): %s" % [pile_name, cards.size(), ", ".join(parts)]
