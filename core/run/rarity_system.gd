## Motor matemático estático que gestiona el sistema de rarezas (Tiers) y el cálculo de probabilidades.
## Maneja la asignación de pesos ponderados dinámicos (que escalan según el avance de la partida y la Suerte del héroe)
##  y el sorteo determinista (RNG) de recompensas.
extends RefCounted
class_name RaritySystem

## Clasificación estándar de rarezas para cartas y reliquias en orden de jerarquía ascendente.
enum Tier { COMMON, UNCOMMON , RARE, EPIC, LEGENDARY }

## Traduce el identificador del enum al nombre localizado en texto plano para la interfaz de usuario
## (`"Comun"`, `"Poco Comun"`, `"Rara"`, `"Epica"` o `"Legendaria"`).
static func get_tier_name(tier: Tier) -> String:
	match tier:
		Tier.COMMON:
			return "Comun"
		Tier.UNCOMMON:
			return "Poco Comun"
		Tier.RARE:
			return "Rara"
		Tier.EPIC:
			return "Epica"
		Tier.LEGENDARY:
			return "Legendaria"
	return "Comun"
## Devuelve el color de acento estándar asociado a cada rareza para teñir bordes, textos o paneles en la UI
## (Gris, Verde, Azul, Violeta y Dorado, respectivamente).
static func get_tier_color(tier: Tier) -> Color:
	match tier:
		Tier.COMMON:
			return Color(0.72, 0.76, 0.82)
		Tier.UNCOMMON:
			return Color(0.18, 0.80, 0.44)
		Tier.RARE:
			return Color(0.25, 0.62, 1.0)
		Tier.EPIC:
			return Color(0.72, 0.30, 1.0)
		Tier.LEGENDARY:
			return Color(1.0, 0.75, 0.15)
	return Color.WHITE

## Calcula y devuelve un diccionario con los pesos probabilísticos para cada rareza.
## Escala dinámicamente el factor de "fortuna" combinando la planta actual (`floor_number`), 
## la estadística base de `player_luck` y cualquier bonificador eventual.
static func get_tier_weights(floor_number: int, player_luck: int, bonus_fortune: float = 0.0) -> Dictionary:
	var fortune: float = max(0.0, float(floor_number - 1) * 1.5 + float(player_luck) * 2.5 + bonus_fortune)
	
	# Common cae progresivamente conforme aumenta la fortuna, con un piso de 10.0
	var w_common: float = max(10.0, 52.0 - fortune * 3.8)
	
	# Uncommon tiene una base sólida y escala con la fortuna moderadamente
	var w_uncommon: float = 28.0 + fortune * 1.0
	
	# Rare, Epic y Legendary absorben más peso a mayor piso y suerte
	var w_rare: float = 15.0 + fortune * 1.8
	var w_epic: float = 4.5 + fortune * 1.2
	var w_legendary: float = max(0.5, 0.5 + fortune * 0.8)
	return {
		Tier.COMMON: w_common,
		Tier.UNCOMMON: w_uncommon,
		Tier.RARE: w_rare,
		Tier.EPIC: w_epic,
		Tier.LEGENDARY: w_legendary
	}

## Genera un bloque de texto plano resumiendo porcentualmente las probabilidades exactas de aparición 
## (ej. `"Comun: 63% | Poco Comun: 20% ..."`).
static func get_probabilities_summary(floor_number: int, player_luck: int) -> String:
	var weights: Dictionary = get_tier_weights(floor_number, player_luck)
	var total: float = 0.0
	for w in weights.values():
		total += float(w)
	return "Comun: %.0f%% | Poco Comun %.0f%% |Rara: %.0f%% | Epica: %.0f%% | Legendaria: %.1f%%" % [
		(weights[Tier.COMMON] / total) * 100.0,
		(weights[Tier.UNCOMMON] / total)  *100,
		(weights[Tier.RARE] / total) * 100.0,
		(weights[Tier.EPIC] / total) * 100.0,
		(weights[Tier.LEGENDARY] / total) * 100.0
	]
	
## Ejecuta un sorteo ponderado determinista (basado en la semilla del `rng` inyectado)
##  para elegir y devolver una rareza al azar.
## Respeta estrictamente los pesos generados por la fortuna actual de la run.
static func roll_tier(rng: RandomNumberGenerator, floor_number: int, player_luck: int, bonus_fortune: float = 0.0) -> Tier:
	var weights: Dictionary = get_tier_weights(floor_number, player_luck, bonus_fortune)
	var total_weight: float = 0.0
	for t in weights.keys():
		total_weight += weights[t]

	var roll: float = rng.randf_range(0.0, total_weight)
	var cumulative: float = 0.0
	for t in [Tier.COMMON,Tier.UNCOMMON, Tier.RARE, Tier.EPIC, Tier.LEGENDARY]:
		cumulative += weights[t]
		if roll <= cumulative:
			return t
	return Tier.COMMON

## Ejecuta una interpolación lineal (Lerp) para transicionar suavemente un número entre `base_min` y `base_max`
## utilizando la suerte como motor de progresión. `luck_for_max` define el "techo" matemático 
## (ej. si se requieren 12 de suerte para alcanzar el valor máximo de 25).
static func get_scaled_value_smooth(player_luck: int, base_min: float, base_max: float, luck_for_max: int) -> float:

	if player_luck <= 0:
		return base_min
		
	# Normalizamos la suerte de 0.0 a 1.0 en base a cuánta suerte se requiere para el máximo
	var luck_factor: float = clamp(float(player_luck) / float(luck_for_max), 0.0, 1.0)
	
	# Interpola de forma lineal entre 5 y 25
	return lerp(base_min, base_max, luck_factor)
	
## Sortea un elemento de una lista usando pesos ponderados.
## Recibe un diccionario de {elemento: peso} y un RNG.
## Retorna el elemento elegido.
static func roll_weighted(elements: Dictionary, rng: RandomNumberGenerator) -> Variant:
	var total_weight: float = 0.0
	for w in elements.values():
		total_weight += float(w)
	
	var roll: float = rng.randf_range(0.0, total_weight)
	var cumulative: float = 0.0
	for el in elements.keys():
		cumulative += float(elements[el])
		if roll <= cumulative:
			return el
	return elements.keys()[0]  # fallback
