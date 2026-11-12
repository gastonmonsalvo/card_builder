extends HBoxContainer
class_name StatRow

@export var icon_size: Vector2 = Vector2(24, 24)  # NUEVO: configurable

var _icon: TextureRect
var _label: Label

func _ready() -> void:
	add_theme_constant_override("separation", 8)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Crear el ícono usando el tamaño configurado
	_icon = TextureRect.new()
	_icon.custom_minimum_size = icon_size  # <--- USA EL PARÁMETRO
	_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(_icon)
	
	# Crear el texto
	_label = Label.new()
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_label)

## Setear la imagen del ícono
func set_icon(texture_path: String) -> void:
	if ResourceLoader.exists(texture_path):
		_icon.texture = load(texture_path)
		_icon.visible = true
	else:
		_icon.visible = false

## Setear el texto
func set_text(text: String) -> void:
	_label.text = text
