## Efecto de reliquia que previene la muerte del jugador (ej. Cenizas del Fénix).
## Restaura un porcentaje de la vida máxima al recibir daño letal.
## Nota: La reliquia se consume y elimina desde el `RunState` al retornar `true`.

extends RelicEffect
class_name RelicReviveEffect

## Porcentaje de vida máxima que se restaura al revivir (rango 0.1 a 1.0).
@export_range(0.1, 1.0, 0.05) var revive_hp_ratio: float = 0.5

## Intercepta el daño letal, restaura el HP del jugador en base a su vida máxima y el `revive_hp_ratio`,
## y retorna `true` para confirmar la salvación (lo que desencadena la destrucción de la reliquia).
func on_player_lethal_damage(run) -> bool:
	run.player_hp = max(1, int(round(float(run.max_player_hp) * revive_hp_ratio)))                                  
	return true         
																								
## Genera el texto dinámico para la interfaz, formateando el porcentaje de curación.
func get_description() -> String:
	return "Al morir, revives con %d%% HP (Se rompe al usarse)" % int(revive_hp_ratio * 100.0)
