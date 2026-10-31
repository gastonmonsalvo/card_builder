## Efecto de reliquia que otorga bonificaciones permanentes a las estadísticas base del jugador.
## Se aplica una única vez al momento de equiparse mediante `on_equipped(run)`.

extends RelicEffect
class_name RelicStatBonusEffect

## Valor de incremento para la estadística correspondiente.
@export var max_energy_bonus: int = 0
@export var hand_size_bonus: int = 0
@export var max_hp_bonus: int = 0
@export var discards_bonus: int = 0
@export var luck_bonus: int = 0

## Suma directamente los modificadores a las estadísticas del `RunState`.
## Si se incrementa la vida máxima, también se suma el mismo valor a la vida actual.
func on_equipped(run) -> void:
	run.max_energy += max_energy_bonus
	run.target_hand_size += hand_size_bonus
	if max_hp_bonus > 0:
		run.max_player_hp += max_hp_bonus
		run.player_hp += max_hp_bonus
	run.discards_per_combat += discards_bonus
	run.player_luck += luck_bonus
	
## Construye un texto dinámico para la interfaz, listando únicamente las estadísticas que fueron modificadas.
func get_description() -> String:
	var parts: Array[String] = []
	if max_energy_bonus > 0:
		parts.append("+%d Energia Max" % max_energy_bonus)
	if hand_size_bonus > 0:
		parts.append("+%d Mano Base" % hand_size_bonus)
	if max_hp_bonus > 0:
		parts.append("+%d HP Max" % max_hp_bonus)
	if discards_bonus > 0:
		parts.append("+%d Descarte por pelea" % discards_bonus)
	if luck_bonus != 0:
		parts.append("%+d Suerte" % luck_bonus)
	return ", ".join(parts)
