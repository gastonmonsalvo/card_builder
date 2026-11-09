extends Label
class_name ComboBanner

## Renderiza la previsualización del combo desde el diccionario del CombatResolver
func update_data(p: Dictionary) -> void:
	text = _format_combo_preview(p)

## Sobrescribe el banner con un mensaje personalizado (ej: "¡SIN ENERGIA!")
func show_message(msg: String) -> void:
	text = msg

## Formatea el diccionario de previsualización del combo en una cadena legible con daño, estados, curación y multiplicadores.
func _format_combo_preview(p: Dictionary) -> String:
	var parts: Array[String] = []
	
	# 1. Daño (si MultiplyEffect lo modificó, esto ya muestra el valor final)
	if p.get("dmg", 0) > 0:
		parts.append("%d DAÑO" % int(p["dmg"]))
	
	# 2. Resto de efectos
	if p.get("block", 0) > 0:
		parts.append("+%d ESCUDO" % int(p["block"]))
	if p.get("burn", 0) > 0:
		parts.append("+%d QUEMADURA" % int(p["burn"]))
	if p.get("poison", 0) > 0:
		parts.append("+%d VENENO" % int(p["poison"]))
	if p.get("draw", 0) > 0:
		parts.append("+%d ROBO" % int(p["draw"]))
	if p.get("freeze", 0) > 0:
		parts.append("+%d CONGELAMIENTO" % int(p["freeze"]))
	if p.get("shock", 0) > 0:
		parts.append("+%d SHOCK" % int(p["shock"]))
	if p.get("hemorrhage", 0) > 0:
		parts.append("+%d HEMORRAGIA" % int(p["hemorrhage"]))
	
	# 3. Multiplicadores aplicados (solo informativo, ej: x2.0)
	var multipliers: Array = p.get("multipliers", [])
	for mult in multipliers:
		var formatted: String
		if float(mult) == int(mult):
			formatted = "x%d" % int(mult)
		else:
			formatted = "x%.1f" % float(mult)
		parts.append(formatted)
	
	# 4. Si no hay nada, mostrar hint
	if parts.is_empty():
		return "Selecciona o arrastra cartas a la Zona de Combo"
		
	if p.get("heal", 0) > 0:
		parts.append("+%d HP" % int(p["heal"]))

	if p.get("dmg", 0) > 0 and float(p.get("crit_chance", 0.0)) > 0.0:
		parts.append("🎲 %.1f%% CRIT (x1.5)" % (float(p["crit_chance"]) * 100.0))
	
	return "COMBO ACTIVO:    " + "   |   ".join(parts)
