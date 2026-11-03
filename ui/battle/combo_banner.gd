extends Label
class_name ComboBanner

## Renderiza la previsualización del combo desde el diccionario del CombatResolver
func update_data(p: Dictionary) -> void:
	text = _format_combo_preview(p)

## Sobrescribe el banner con un mensaje personalizado (ej: "¡SIN ENERGIA!")
func show_message(msg: String) -> void:
	text = msg

func _format_combo_preview(p: Dictionary) -> String:
	var parts: Array[String] = []
	if p.get("dmg", 0) > 0:
		parts.append("%d DAÑO" % p["dmg"])
	if p.get("block", 0) > 0:
		parts.append("+%d ESCUDO" % p["block"])
	if p.get("burn", 0) > 0:
		parts.append("+%d QUEMADURA" % p["burn"])
	if p.get("poison", 0) > 0:
		parts.append("+%d VENENO" % p["poison"])
	if p.get("draw", 0) > 0:
		parts.append("+%d ROBO" % p["draw"])
	if p.get("freeze", 0) > 0:
		parts.append("+%d CONGELAMIENTO" % p["freeze"])
	if p.get("shock", 0) > 0:
		parts.append("+%d SHOCK" % p["shock"])
	if p.get("hemorrhage", 0) > 0:
		parts.append("+%d HEMORRAGIA" % p["hemorrhage"])
	if parts.is_empty():
		return "Selecciona o arrastra cartas a la Zona de Combo"
	return "COMBO ACTIVO:    " + "   |   ".join(parts)
