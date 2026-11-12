extends Panel
class_name PlayerHUD

# Rutas a los íconos
const ICON_HEART := "res://assets/textures/ui/heart.png"
const ICON_WEAPON := "res://assets/textures/ui/weapon.png"
const ICON_ENERGY := "res://assets/textures/ui/energy.png"
const ICON_LUCK := "res://assets/textures/ui/luck.png"
const ICON_BLOCK := "res://assets/textures/ui/block.png"
const ICON_DMG := "res://assets/textures/ui/damage.png"
const ICON_CRIT := "res://assets/textures/ui/crit.png"

var _container: VBoxContainer
var _name_label: Label

# Referencias a las filas
var _row_hp: StatRow
var _row_block: StatRow
var _row_weapon: StatRow
var _row_energy: StatRow
var _row_luck: StatRow
var _row_dmg: StatRow
var _row_crit: StatRow

func _ready() -> void:
	# Contenedor principal vertical
	_container = VBoxContainer.new()
	_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_container.add_theme_constant_override("separation", 4)
	add_child(_container)
	
	# Nombre (sin ícono)
	_name_label = Label.new()
	_container.add_child(_name_label)
	
	# Crear las filas con tamaños personalizados
	_row_hp = _create_row(Vector2(32, 32))      # Corazón grande
	_row_hp.set_icon(ICON_HEART)
	
	_row_block = _create_row(Vector2(32, 32))   # Escudo mediano
	_row_block.set_icon(ICON_BLOCK)
	
	_row_weapon = _create_row(Vector2(24, 24))   # Arma normal
	_row_weapon.set_icon(ICON_WEAPON)
	
	_row_energy = _create_row(Vector2(24, 24))   # Energía normal
	_row_energy.set_icon(ICON_ENERGY)
	
	_row_luck = _create_row(Vector2(20, 20))     # Trébol chico
	_row_luck.set_icon(ICON_LUCK)
	
	_row_dmg = _create_row(Vector2(24, 24))      # Daño normal
	_row_dmg.set_icon(ICON_DMG)
	
	_row_crit = _create_row(Vector2(24, 24))     # Crítico normal
	_row_crit.set_icon(ICON_CRIT)

## Helper para crear una fila con tamaño de ícono personalizado
func _create_row(icon_size: Vector2 = Vector2(24, 24)) -> StatRow:
	var row := StatRow.new()
	row.icon_size = icon_size  # Setear ANTES de add_child para que _ready() lo use
	_container.add_child(row)
	return row

## Renderiza los datos del jugador
func update_data(player_hp: int, max_player_hp: int, player_block: int, 
				 energy: int, max_energy: int, player_luck: int, 
				 hero_name: String, weapon_name: String,
				 player_level: int = 1, level_dmg_pct: int = 0, crit_pct: float = 0.0) -> void:
	
	_name_label.text = "%s (Nivel %d)" % [hero_name, player_level]
	
	_row_hp.set_text("%d / %d" % [player_hp, max_player_hp])
	
	"""
	if player_block > 0:
		_row_block.set_text("+%d" % player_block)
		_row_block.set_visible(true)
	else:
		_row_block.set_visible(false)
	"""
	_row_block.set_text("+%d" % player_block)
	_row_block.set_visible(true)
	_row_weapon.set_text(weapon_name)
	_row_energy.set_text("%d / %d" % [energy, max_energy])
	_row_luck.set_text("%d" % player_luck)
	_row_dmg.set_text("+%d%%" % level_dmg_pct)
	_row_crit.set_text("%.1f%%" % crit_pct)
