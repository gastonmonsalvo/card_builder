extends Panel
class_name PlayerHUD

@onready var stats_label: Label = $PlayerStatsLabel

## Renderiza los datos del jugador recibidos desde BattleHUD
func update_data(player_hp: int, max_player_hp: int, player_block: int, 
				 energy: int, max_energy: int, player_luck: int, 
				 hero_name: String, weapon_name: String) -> void:
	var lines: Array[String] = [
		hero_name,
		"❤️: %d / %d" % [player_hp, max_player_hp],
		"🗡️: %s" % weapon_name,
		"⚡: %d / %d" % [energy, max_energy],
		"🍀: %d" % player_luck
	]

	if player_block > 0:
		lines.insert(3, "🛡️: +%d" % player_block)

	stats_label.text = "\n".join(lines)
