extends Panel
class_name PileInspector

@onready var popup_label: Label = $PilePopupLabel
@onready var close_btn: Button = $ClosePopupBtn

## Conecta el botón de cierre del popup y oculta el inspector al iniciar la escena.
func _ready() -> void:
	close_btn.pressed.connect(func(): visible = false)
	visible = false

## Muestra el contenido de una pila en el popup
func show_pile(pile: CardPile) -> void:
	if not pile:
		return
	popup_label.text = pile.get_contents_summary()
	visible = true
