## Clase base abstracta para los efectos modulares de las reliquias.
## Define los ganchos (hooks) virtuales que las subclases concretas deben sobrescribir
## para reaccionar a los eventos del juego.
extends Resource
class_name RelicEffect

## Método "abstracto". Se ejecuta una única vez al momento de adquirir y equipar la reliquia en el `RunState`.
## Ideal para aplicar modificaciones permanentes a las estadísticas del jugador.
func on_equipped(_run) -> void:
	pass

## Método "abstracto". Se dispara en el turno 0 de cada encuentro (tanto enemigos normales como jefes).
## Útil para inyectar estados alterados iniciales al enemigo.
func on_combat_start(_enemy: Enemy) -> void:
	pass

## Método "abstracto". Se dispara al cerrar la evaluación de la fila de combo en la mesa.
## Recibe el diccionario `combo_state` y la cantidad de cartas jugadas (`_card_count`) para inyectar bonificaciones reactivas.
func on_combo_evaluated(_combo_state: Dictionary, _card_count: int) -> void:
	pass

## Método "abstracto". Devuelve el texto descriptivo del efecto para renderizarse en los tooltips
## o paneles de inspección de la interfaz.
func get_description() -> String:
	return ""

## Método "abstracto". Intercepta el momento exacto en que el HP del jugador llega a 0.
## Debe retornar `true` si el efecto evita la muerte (lo que consumirá la reliquia), o `false` en caso contrario.
func on_player_lethal_damage(_run) -> bool:
	return false
