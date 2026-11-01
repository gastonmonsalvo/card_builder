#Contiene las constantes de espaciado visual y tiempos de espera de resolución.
extends RefCounted
class_name CombatConstants

const DEFAULT_HERO_PATH: String = "res://entities/hero/data/warrior_hero.tres"
const HERO_PATH: String = "res://entities/hero/data/"
const ENEMY_PATH : String =  "res://entities/enemies/data"
const RELIC_PATH :String = "res://relics/data"
const CARD_PATH : String = "res://cards/data"
const WEAPON_PATH: String = "res://weapons/data"
const BASIC_WEAPON : WeaponData = preload("res://weapons/data/arma_basica.tres")
# --- UMBRALES Y BALANCE DE ESTADOS (STATUS EFFECTS) ---

## Cargas de hielo necesarias para congelar por completo al enemigo (0 daño en su turno).
const FREEZE_STUN_THRESHOLD: int = 5
## Cargas de hemorragia necesarias para desangrar 
const HEMORRHAGE_BURST_THRESHOLD: int = 10
const HEMORRHAGE_THRESHOLD_SCALING : int = 5
## Decaimiento estándar de cargas por turno (Quemadura, Veneno, Hielo sin stun).
const STATUS_DECAY_PER_TURN: int = 1

# --- REGLAS BASE DEL JUGADOR Y COMBATE ---
const BASE_HAND_SIZE: int = 5
const BASE_MAX_ENERGY: int = 3
const BASE_DISCARDS_PER_COMBAT: int = 2
const BASE_LUCKY : int = 1
const BASE_HEALTH : int = 50
const BASE_GOLD: int = 100
const BASE_STR : int = 1
const BASE_DEX: int = 1
const BASE_INT : int = 1
## BONUS DE COMBOS 
const BASE_MIN_CARDS_REQUIERED : int = 3
const BASE_BONUS_DMG : int =  6 
const BASE_BONUS_SHIELD : int = 5 

## Probabilidad base de aturdir por cada carga de Electrocutado (12% por carga).
const SHOCK_STUN_CHANCE_PER_STACK: float = 0.12

## Bonus de probabilidad de aturdimiento por cada punto de Suerte del jugador (+3% por punto).
const SHOCK_LUCK_BONUS_PER_POINT: float = 0.03

## Tope máximo de probabilidad de aturdimiento por electricidad (80% máx).
const SHOCK_MAX_STUN_CHANCE: float = 0.80

const MAX_INVENTORY_SIZE: int = 4
