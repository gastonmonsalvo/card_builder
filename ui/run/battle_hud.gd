## Controlador de interfaz de usuario (Vista) durante el combate.
## Se encarga exclusivamente de renderizar en pantalla las estadísticas del jugador y del enemigo,
## previsualizar el daño del combo activo y mostrar modales para inspeccionar las pilas de cartas.
extends Control
class_name BattleHUD

@onready var player_stats_label: Label = $PlayerPanel/PlayerStatsLabel
@onready var enemy_stats_label: Label = $EnemyPanel/EnemyStatsLabel
@onready var combo_banner_label: Label = $ComboBannerLabel

@onready var draw_pile_btn: Button = $DrawPileBtn
@onready var discard_pile_btn: Button = $DiscardPileBtn
@onready var graveyard_pile_btn: Button = $GraveyardPileBtn

@onready var pile_popup: Panel = $PilePopup
@onready var pile_popup_label: Label = $PilePopup/PilePopupLabel
@onready var close_popup_btn: Button = $PilePopup/ClosePopupBtn

## Referencia en memoria a la pila de robo (Mazo) administrada por el `DeckManager`.
var _draw_pile: CardPile
## Referencia en memoria a la pila de descarte temporal del combate.
var _discard_pile: CardPile
## Referencia en memoria a la pila de cartas agotadas (Cementerio) del combate.
var _graveyard_pile: CardPile

## Inicializa la vista ocultando el modal de inspección y conectando los clics de los botones de las pilas (Mazo, Descarte, Cementerio)
## a la función de apertura del pop-up.
func _ready() -> void:
	pile_popup.visible = false
	draw_pile_btn.pressed.connect(func(): _show_pile(_draw_pile))
	discard_pile_btn.pressed.connect(func(): _show_pile(_discard_pile))
	graveyard_pile_btn.pressed.connect(func(): _show_pile(_graveyard_pile))
	close_popup_btn.pressed.connect(func(): pile_popup.visible = false)

## Inyecta las dependencias lógicas (pilas de cartas) desde el `DeckManager`.
## Permite que el HUD lea la cantidad y el contenido de las cartas sin manipularlas.
func bind_piles(draw_p: CardPile, discard_p: CardPile, graveyard_p: CardPile) -> void:
	_draw_pile = draw_p
	_discard_pile = discard_p
	_graveyard_pile = graveyard_p
	
## Función principal de renderizado. Reconstruye todos los textos de la pantalla:
## 1. Panel del Jugador (HP, Energía, Suerte y Escudo).
## 2. Panel del Enemigo (HP, Intención y Estados alterados).
## 3. Banner superior (Previsualización del combo).
## 4. Botones de las esquinas (Contadores actualizados de cada pila).
func refresh_all(
	player_hp: int,
	player_block: int,
	energy: int,
	max_energy: int,
	enemy: Enemy,
	preview: Dictionary,
	max_player_hp: int = 50,
	player_luck: int = 0
) -> void:
	# 1. Panel del Jugador 
	var player_lines: Array[String] = [
		"JUGADOR",
		"HP: %d / %d" % [player_hp, max_player_hp],
		"ENERGIA: %d / %d" % [energy, max_energy],
		"SUERTE: %d" % player_luck
	]
	
	if player_block > 0:
		player_lines.insert(2, "ESCUDO: +%d" % player_block)
	player_stats_label.text = "\n".join(player_lines)
	
	# 2. Panel del Enemigo 
	enemy_stats_label.text = enemy.get_status_text(player_luck)

	# 3. Banner del Combo
	combo_banner_label.text = _format_combo_preview(preview)

	# 4. Botones de Pilas en las esquinas
	if _draw_pile:
		draw_pile_btn.text = "Mazo (%d)" % _draw_pile.size()
	if _discard_pile:
		discard_pile_btn.text = "Descarte (%d)" % _discard_pile.size()
	if _graveyard_pile:
		graveyard_pile_btn.text = "Cementerio (%d)" % _graveyard_pile.size()

## Sobrescribe temporalmente el texto del banner superior para mostrar eventos fugaces,
## alertas o notificaciones del sistema (Ej: "¡SIN ENERGIA!", "DESCARTASTE 2 CARTAS").
func set_banner_message(msg: String) -> void:
	combo_banner_label.text = msg
	
## Función de utilidad interna que parsea el diccionario matemático del `CombatResolver`
## y lo traduce a una cadena de texto legible separada por tuberías (|)
## para mostrar todo lo que hará el combo.
func _format_combo_preview(p: Dictionary) -> String:
	var parts: Array[String] = []
	if p.get("dmg", 0) > 0:
		parts.append("%d DAÑO" % p["dmg"])
	if p.get("block", 0) > 0:
		parts.append("+%d ESCUDO" % p["block"])
	if p.get("burn", 0) > 0:
		parts.append("+%d QUEMADURA" % p["burn"])
	if p.get("poison", 0) > 0:
		parts.append("+%d VENENO" % p["poison"])
	if p.get("draw", 0) > 0:
		parts.append("+%d ROBO" % p["draw"])
	if p.get("freeze", 0) > 0:
		parts.append("+%d CONGELAMIENTO" % p["freeze"])
	if p.get("shock", 0) > 0:
		parts.append("+%d SHOCK" % p["shock"])
	if p.get("hemorrhage",0)>0:
		parts.append("+%d HEMORRAGIA" % p["hemorrhage"])
	if parts.is_empty():
		return "Selecciona o arrastra cartas a la Zona de Combo"
	return "COMBO ACTIVO:   " + "   |   ".join(parts)
	
## Abre el modal oscuro superpuesto (`PilePopup`) e inyecta en su etiqueta de texto
## la lista completa de todas las cartas contenidas en la pila solicitada.
func _show_pile(pile: CardPile) -> void:
	if not pile:
		return
	pile_popup_label.text = pile.get_contents_summary()
	pile_popup.visible = true
