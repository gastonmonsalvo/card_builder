## Clase base abstracta para todos los efectos de las cartas.
## Define la interfaz virtual que las subclases concretas deben implementar 
##para inyectar lógica en el combate y definir su estética.
extends Resource
class_name CardEffect

## Flag que identifica si el efecto es de naturaleza mágica/arcana (ej. hechizos elementales o sobrecarga).
@export var is_magical: bool = false

## Método "abstracto" (a sobrescribir). Recibe y muta el diccionario `combo_state`, aplicando el daño,
## escudo o estado correspondiente durante la resolución del combate.
func apply(_combo_state: Dictionary) -> void:
	pass
	
## Método "abstracto" (a sobrescribir). Devuelve el texto descriptivo del efecto para renderizarse en la interfaz de la carta.
func get_description() -> String:
	return ""
	
## Método "abstracto" (a sobrescribir). Devuelve el color representativo del efecto
## (ej. rojo para daño, azul para escudo) para colorear la tipografía o el fondo en la UI.
func get_color() -> Color:
	return Color.WHITE
	
## Método virtual (a sobrescribir). Retorna `true` si el efecto debe ejecutarse y descartarse
##  inmediatamente al jugar la carta, o `false` si debe encolarse en la mesa para la evaluación final del combo.
func is_instant() -> bool:
	return false
