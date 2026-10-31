## Estructura de datos lógica que representa una celda individual dentro del grafo del piso (mapa).
## Gestiona el tipo de sala, su estado de descubrimiento/resolución y sus conexiones de navegación (pasillos).
extends RefCounted
class_name RoomData

enum Type { START, COMBAT, TREASURE, REST, SANCTUARY, BOSS , SHOP}

## Coordenada `(x, y)` en la matriz del mapa.
var grid_pos: Vector2i = Vector2i.ZERO

## Tipo de evento que alberga la sala (Combate, Tienda, Jefe, etc).
var room_type: Type = Type.COMBAT

## Indica si el evento de la sala ya fue resuelto (enemigo vencido, tesoro abierto).
var cleared: bool = false

## Indica si la sala es visible en el mapa (ya no la oculta la niebla de guerra).
var discovered: bool = false

## Arreglo de coordenadas ortogonales contiguas con las que existe conexión directa (pasillo).
var neighbors: Array[Vector2i] = []

## Inventario persistente de cartas en venta (solo utilizado si la sala es `Type.SHOP`).
var shop_cards: Array[CardData] = []
## Inventario persistente de reliquias en venta (solo utilizado si la sala es `Type.SHOP`).
var shop_relics: Array[RelicData] = []
## Bandera que indica si los inventarios de la tienda ya fueron generados
## proceduralmente al entrar por primera vez.
var shop_initialized: bool = false

## Constructor. Inicializa la sala en la coordenada indicada.
## Si la sala se crea como tipo `START`, se auto-marca como resuelta y descubierta de inmediato.
func _init(pos: Vector2i, type: Type = Type.COMBAT) -> void:
	grid_pos = pos
	room_type = type
	if type == Type.START:
		cleared = true
		discovered = true

## Vincula bidireccionalmente esta sala con una coordenada adyacente, 
## creando un "pasillo" en el grafo y evitando duplicados.
func add_neighbor(other_pos: Vector2i) -> void:
	if not neighbors.has(other_pos):
		neighbors.append(other_pos)
		
## Evalúa topológicamente si la sala es una hoja del grafo (callejón sin salida). 
## Retorna `true` si la sala tiene una sola conexión posible
func is_dead_end() -> bool:
	return neighbors.size() == 1

## Genera el texto identificatorio de la sala para la interfaz del mapa.
## Retorna `"???"` si está bajo niebla de guerra, o un texto contextual al tipo de sala
## y su estado actual (ej: "COMBATE" si está activa, "LIMPIA" si está resuelta).
func get_display_name() -> String:
	if not discovered:
		return "???"
		
	match room_type:
		Type.START:
			return "INICIO"
		Type.COMBAT:
			return "LIMPIA" if cleared else "COMBATE"
		Type.TREASURE:
			return "SAQUEADO" if cleared else "RELIQUIA"
		Type.REST:
			return "USADO" if cleared else "HOGUERA"
		Type.SANCTUARY:
			return "BENDECIDO" if cleared else "SANTUARIO"
		Type.BOSS:
			return "DERROTADO" if cleared else "JEFE"
		Type.SHOP:
			return "TIENDA"
	
	return ""

## Calcula y devuelve el color de renderizado representativo para la celda en la interfaz.
## Prioriza la niebla de guerra (gris opaco),
##  seguido de la posición actual del jugador (verde brillante) 
## y el estado de limpieza (verde apagado). Si está activa, devuelve su color temático distintivo.
func get_room_color(is_current: bool) -> Color:
	if not discovered:
		return Color(0.12, 0.12, 0.15, 0.4)
	if is_current:
		return Color(0.206, 0.585, 0.186, 1.0)
	if cleared:
		return Color(0.25, 0.32, 0.28)

	match room_type:
		Type.COMBAT:
			return Color(0.65, 0.25, 0.25)
		Type.TREASURE:
			return Color(0.85, 0.65, 0.12)
		Type.REST:
			return Color(0.20, 0.65, 0.45)
		Type.SANCTUARY:
			return Color(0.58, 0.22, 0.88)
		Type.BOSS:
			return Color(0.407, 0.0, 0.077, 1.0)
		Type.SHOP:
			return Color(0.913, 0.771, 0.0, 1.0)
	
	return Color(0.3, 0.3, 0.3)
