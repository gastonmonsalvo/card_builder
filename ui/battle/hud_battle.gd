## Controlador de interfaz de usuario (Vista) durante el combate.
## Actúa como orquestador: recibe datos y los deriva a los sub-componentes de UI.
extends Control
class_name BattleHUD

signal equipment_changed

@onready var player_hud: PlayerHUD = $PlayerPanel
@onready var enemy_hud: EnemyHUD = $EnemyPanel
@onready var combo_banner: ComboBanner = $ComboBannerLabel
@onready var pile_inspector: PileInspector = $PilePopup

@onready var draw_pile_btn: Button = $DrawPileBtn
@onready var discard_pile_btn: Button = $DiscardPileBtn
@onready var graveyard_pile_btn: Button = $GraveyardPileBtn

var inventory_btn: Button
var relics_btn: Button

## Referencias a las pilas inyectadas por DeckManager
var _draw_pile: CardPile
var _discard_pile: CardPile
var _graveyard_pile: CardPile

## Modal de inventario y modal de inspección de reliquias en combate
var inventory_modal: InventoryModalView
var relics_inspector_modal: InspectorModalView
var _run_ref: RunState

## Conecta los botones de inspección de pilas e instancia los botones y modales de inventario y reliquias en el HUD de combate.
func _ready() -> void:
	draw_pile_btn.pressed.connect(func(): pile_inspector.show_pile(_draw_pile))
	discard_pile_btn.pressed.connect(func(): pile_inspector.show_pile(_discard_pile))
	graveyard_pile_btn.pressed.connect(func(): pile_inspector.show_pile(_graveyard_pile))

	# Instanciar modal de inventario
	inventory_modal = InventoryModalView.new()
	add_child(inventory_modal)
	inventory_modal.weapon_selected_to_equip.connect(_on_inventory_weapon_selected)

	# Instanciar modal visual de reliquias (con z_index alto sobre la mesa de combate)
	relics_inspector_modal = InspectorModalView.new()
	relics_inspector_modal.z_index = 200
	add_child(relics_inspector_modal)

	# Botón de inventario en el HUD (izquierda)
	inventory_btn = Button.new()
	inventory_btn.text = "INVENTARIO"
	inventory_btn.position = Vector2(20, 400)
	inventory_btn.size = Vector2(175, 50)
	inventory_btn.pressed.connect(func():
		if _run_ref:
			inventory_modal.open_inventory(_run_ref)
	)
	add_child(inventory_btn)

	# Botón de reliquias justo debajo de Inventario (izquierda)
	relics_btn = Button.new()
	relics_btn.text = "RELIQUIAS (0)"
	relics_btn.position = Vector2(20, 460)
	relics_btn.size = Vector2(175, 50)
	relics_btn.pressed.connect(func():
		if _run_ref:
			relics_inspector_modal.open_relic_cards(
				"RELIQUIAS EQUIPADAS (%d)" % _run_ref.active_relics.size(),
				_run_ref.active_relics
			)
	)
	add_child(relics_btn)

## Enlaza las referencias de las tres pilas del `DeckManager` (mazo, descarte y cementerio) con el HUD.
func bind_piles(draw_p: CardPile, discard_p: CardPile, graveyard_p: CardPile) -> void:
	_draw_pile = draw_p
	_discard_pile = discard_p
	_graveyard_pile = graveyard_p

## Inyecta la referencia al `RunState` activo para consultar el héroe, el arma equipada y abrir el inventario.
func bind_run_reference(run: RunState) -> void:
	_run_ref = run

## Equipa el arma seleccionada desde el modal de inventario durante el combate y notifica el cambio mediante `equipment_changed`.
func _on_inventory_weapon_selected(weapon: WeaponData) -> void:
	if not _run_ref:
		return
	if _run_ref.equip_weapon(weapon):
		inventory_modal.open_inventory(_run_ref)
		equipment_changed.emit()

## Actualiza y sincroniza todos los subcomponentes del HUD con el estado actual del combate.
## Refresca la información del jugador, enemigo, pilas de cartas y el banner de previsualización.
## Preserva el contenido actual del banner si el diccionario de preview recibido está vacío.
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
	# 1. Player HUD
	var hero_name: String = "HÉROE"
	if _run_ref != null and _run_ref.selected_hero != null:
		hero_name = _run_ref.selected_hero.hero_name.to_upper()
	
	var weapon_name: String = "Sin arma"
	if _run_ref != null and _run_ref.current_weapon != null:
		weapon_name = _run_ref.current_weapon.weapon_name
		
	player_hud.update_data(player_hp, max_player_hp, player_block, energy, max_energy, player_luck, hero_name, weapon_name)
	
	# 2. Enemy HUD
	var enemy_data: Dictionary = enemy.get_hud_data(player_luck) if enemy != null else {}
	enemy_hud.update_data(enemy_data)
	
	# 3. Combo Banner (solo actualiza si hay datos nuevos de preview)
	if not preview.is_empty():
		combo_banner.update_data(preview)
	
	# 4. Piles
	if _draw_pile:
		draw_pile_btn.text = "Mazo (%d)" % _draw_pile.size()
	if _discard_pile:
		discard_pile_btn.text = "Descarte (%d)" % _discard_pile.size()
	if _graveyard_pile:
		graveyard_pile_btn.text = "Cementerio (%d)" % _graveyard_pile.size()
	if relics_btn:
		var relics_count: int = _run_ref.active_relics.size() if _run_ref != null else 0
		relics_btn.text = "RELIQUIAS (%d)" % relics_count
## Sobrescribe el banner con un mensaje efímero
func set_banner_message(msg: String) -> void:
	combo_banner.show_message(msg)
