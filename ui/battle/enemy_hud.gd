extends Panel
class_name EnemyHUD

@onready var stats_label: Label = $EnemyStatsLabel

## Renderiza los datos del enemigo desde un diccionario provisto por Enemy.get_hud_data()
func update_data(enemy_data: Dictionary) -> void:
	if enemy_data.is_empty():
		stats_label.text = "ENEMIGO\nSin objetivo"
		return
		
	var text: String = "%s   |   HP: %d / %d" % [
		str(enemy_data.get("name", "?")),
		int(enemy_data.get("current_hp", 0)),
		int(enemy_data.get("max_hp", 0))
	]
	
	var block: int = int(enemy_data.get("block", 0))
	if block > 0:
		text += "   |   🛡 %d" % block
		
	text += "   |   %s" % str(enemy_data.get("intent_text", ""))
	
	var statuses: Array = enemy_data.get("statuses", [])
	if not statuses.is_empty():
		var parts: Array[String] = []
		for s in statuses:
			var label: String = str(s.get("label", ""))
			var stacks: int = int(s.get("stacks", 0))
			if s.get("id") == "shock" and s.has("stun_chance_pct"):
				parts.append("%s: %d (%d%% Stun)" % [label, stacks, int(s["stun_chance_pct"])])
			elif s.get("id") == "freeze":
				var threshold: int = CombatConstants.FREEZE_STUN_THRESHOLD
				parts.append("%s: %d/%d" % [label, stacks, threshold])
			else:
				parts.append("%s: %d" % [label, stacks])
		text += "\nEstados:  %s" % "  |  ".join(parts)
		
	stats_label.text = text
