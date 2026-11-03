extends Control
class_name EnemyHUD

@onready var name_label: Label = $NameLabel
@onready var hp_bar: ProgressBar = $HPBar
@onready var hp_label: Label = $HPBar/HPLabel
@onready var block_label: Label = $BlockLabel
@onready var intent_label: Label = $IntentLabel
@onready var statuses_container: HBoxContainer = $StatusesContainer

func update_from_data(enemy_data: Dictionary) -> void:
	name_label.text = str(enemy_data["name"])
	var current_hp: int = int(enemy_data["current_hp"])
	var max_hp: int = int(enemy_data["max_hp"])
	hp_bar.max_value = max_hp
	hp_bar.value = current_hp
	hp_label.text = "%d / %d" % [current_hp, max_hp]
	block_label.text = "🛡 %d" % int(enemy_data["block"])
	block_label.visible = int(enemy_data["block"]) > 0
	intent_label.text = str(enemy_data["intent_text"])
	
	# Renderizar statuses (limpiar y re-crear)
	for child in statuses_container.get_children():
		child.queue_free()
	var statuses: Array = enemy_data["statuses"]
	for status in statuses:
		var label := Label.new()
		label.text = "%s: %d" % [status["label"], status["stacks"]]
		statuses_container.add_child(label)
