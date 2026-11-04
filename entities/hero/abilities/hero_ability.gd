## Clase base abstracta para habilidades activables del héroe.
## Es un Resource para permitir su configuración directa desde el Inspector en HeroData.
class_name HeroAbility
extends Resource

## Nombre identificatorio de la habilidad visible en la interfaz.
@export var ability_name: String = "Habilidad"

## Descripción de los efectos de la habilidad para tooltips y menús.
@export_multiline var description: String = ""

## Cantidad máxima de activaciones permitidas por encuentro.
@export_range(1, 10, 1, "or_greater") var uses_per_combat: int = 1

## Cantidad de usos disponibles durante el combate en curso.
var uses_remaining: int = 1


## Evalúa si la habilidad cuenta con usos suficientes para ejecutarse.
func can_activate() -> bool:
	return uses_remaining > 0


## Ejecuta el efecto principal de la habilidad.
## Debe ser obligatoriamente implementado por las clases derivadas.
func activate(context: Dictionary) -> void:
	push_error("HeroAbility.activate() must be overridden in subclass")


## Restaura los usos de la habilidad al valor inicial configurado para el combate.
func reset_for_combat() -> void:
	uses_remaining = uses_per_combat


## Genera el texto formateado para la visualización del estado en el HUD.
func get_hud_text() -> String:
	return "%s (%d/%d)" % [ability_name, uses_remaining, uses_per_combat]
