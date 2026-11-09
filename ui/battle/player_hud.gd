extends Panel
class_name PlayerHUD

@onready var stats_label: Label = $PlayerStatsLabel

## Renderiza los datos del jugador recibidos desde BattleHUD (incluyendo Nivel, bono de daño global y probabilidad de crítico).
func update_data(player_hp: int, max_player_hp: int, player_block: int, 
				 energy: int, max_energy: int, player_luck: int, 
				 hero_name: String, weapon_name: String,
				 player_level: int = 1, level_dmg_pct: int = 0, crit_pct: float = 0.0) -> void:
	var lines: Array[String] = [
		"%s (Nvl %d)" % [hero_name, player_level],
		"❤️: %d / %d" % [player_hp, max_player_hp],
		"🗡️: %s" % weapon_name,
		"⚡: %d / %d" % [energy, max_energy],
		"🍀: %d   
		💥: +%d%% / %.1f%% Crit" % [player_luck, level_dmg_pct, crit_pct]
	]

	if player_block > 0:
		lines.insert(3, "🛡️: +%d" % player_block)

	stats_label.text = "\n".join(lines)
