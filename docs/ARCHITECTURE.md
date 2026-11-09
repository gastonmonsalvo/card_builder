# Architecture

Documento de referencia arquitectónica para todo desarrollo en `card-prototype`. Define qué va en cada carpeta, el grafo real de dependencias entre clases, el detalle archivo por archivo de lo que está hoy en producción y las decisiones técnicas del motor.

**Lectura obligatoria** antes de agregar o refactorizar un archivo en el proyecto.

> **Leyenda de estado:**
> - Sin etiqueta: **Implementado y activo en el código actual.**
> - **`🚧 [FUTURO / PENDIENTE]`**: Planificado en diseño o en transición; aún no implementado o con archivo stub vacío.

---

## Tabla de contenidos

1. [Árbol de directorios](#árbol-de-directorios)
2. [Capas y responsabilidades](#capas-y-responsabilidades)
3. [Grafo de dependencias reales](#grafo-de-dependencias-reales)
4. [Detalle archivo por archivo](#detalle-archivo-por-archivo)
5. [Reglas de oro](#reglas-de-oro)
6. [Patrones de diseño aplicados](#patrones-de-diseño-aplicados)
7. [Decisiones Técnicas](#decisiones-técnicas)
   - 7.1 [¿Por qué CombatResolver es Stateless y no usa Command pattern?](#71-por-qué-combatresolver-es-stateless-y-no-usa-command-pattern)
   - 7.2 [Decisión: Protección de Recursos (Duplicate + Sellado vs Data/Instance)](#72-decisión-protección-de-recursos-duplicate--sellado-vs-datainstance)
   - 7.3 [Decisión: `scenes/` vs `ui/` y Vistas 100% en Código](#73-decisión-scenes-vs-ui-y-vistas-100-en-código)
   - 7.4 [¿Por qué RewardView no genera sus propias recompensas?](#74-por-qué-rewardview-no-genera-sus-propias-recompensas)
   - 7.5 [Decisión: Simulación Predictiva Determinista en `calculate_sequential_preview`](#75-decisión-simulación-predictiva-determinista-en-calculate_sequential_preview)
8. [Checklist: agregar X al proyecto](#checklist-agregar-x-al-proyecto)
9. [FAQ](#faq)

---

## Árbol de directorios

```text
card-prototype/
├── README.md
├── .gitignore
├── project.godot
│
├── docs/
│   ├── GDD.md
│   └── ARCHITECTURE.md
│
├── autoload/
│   ├── game_database.gd
│   ├── persistence_manager.gd
│   └── signal_bus.gd
│
├── core/
│   ├── combat/
│   │   ├── combat_resolver.gd
│   │   ├── status_reactions.gd
│   │   ├── temp_stat_manager.gd
│   │   ├── combat_action.gd                    # 🚧 [FUTURO / PENDIENTE - Solo si se agrega Replay/Undo]
│   │   └── actions/                            # 🚧 [FUTURO / PENDIENTE]
│   │
│   ├── deck/
│   │   ├── deck_manager.gd
│   │   └── card_pile.gd
│   │
│   ├── enemies/
│   │   ├── enemy.gd
│   │   ├── enemy_ai.gd
│   │   └── behaviors/
│   │       ├── enemy_behavior.gd
│   │       ├── enemy_context.gd
│   │       ├── enemy_intent.gd
│   │       ├── attack_behavior.gd
│   │       ├── defend_behavior.gd
│   │       └── charge_behavior.gd
│   │
│   ├── run/
│   │   ├── run_director.gd
│   │   ├── run_state.gd
│   │   ├── run_state_machine.gd
│   │   └── rarity_system.gd
│   │
│   ├── map/
│   │   ├── floor_generator.gd
│   │   └── room_data.gd
│   │
│   └── constants/
│       └── combat_constants.gd
│
├── systems/                                    # 🚧 [FUTURO / PENDIENTE - Hoy resuelto en core/combat y RunState]
│   ├── statuses/                               # 🚧 [FUTURO / PENDIENTE - Hoy en Enemy + StatusReactions]
│   ├── modifiers/                              # 🚧 [FUTURO / PENDIENTE - Hoy en TempStatManager]
│   └── events/                                 # 🚧 [FUTURO / PENDIENTE - Hoy en SanctuaryModalView + RunState]
│
├── entities/
│   ├── hero/
│   │   ├── hero_data.gd
│   │   ├── abilities/
│   │   │   ├── hero_ability.gd
│   │   │   ├── war_cry_ability.gd
│   │   │   ├── arcane_flow_ability.gd
│   │   │   ├── demon_thrust_ability.gd
│   │   │   └── bloody_slash_ability.gd         # (Define class_name BloodySlashAbility)
│   │   └── data/
│   │       ├── warrior_hero.tres
│   │       ├── magic_hero.tres
│   │       ├── samurai_hero.tres
│   │       ├── assasin_hero.tres
│   │       └── demo_hero.tres
│   │
│   └── enemies/
│       ├── enemy_data.gd
│       └── data/
│           ├── esqueleto.tres
│           └── jefe_basico.tres
│
├── cards/
│   ├── card_data.gd
│   ├── card_instance.gd                        # 🚧 [FUTURO / PENDIENTE - Archivo stub vacío]
│   ├── data/
│   │   ├── corte_rapido.tres
│   │   ├── curacion_basica.tres
│   │   ├── efecto_caotico.tres
│   │   ├── escudo_basico.tres
│   │   ├── estocada.tres
│   │   ├── frasco_veneno_basico.tres
│   │   ├── golpe_congelante.tres
│   │   ├── golpe_fuego.tres
│   │   ├── lanza_rayo.tres
│   │   ├── robo_basico.tres
│   │   ├── sobre_carga.tres
│   │   └── tajo.tres
│   └── effects/
│       ├── card_effect.gd
│       ├── damage_effect.gd
│       ├── defense_effect.gd
│       ├── burn_effect.gd
│       ├── poison_effect.gd
│       ├── freeze_effect.gd
│       ├── shock_effect.gd
│       ├── hemorrhage_effect.gd
│       ├── heal_effect.gd
│       ├── multiply_effect.gd
│       ├── steal_effect.gd
│       └── apply_status_effect.gd
│
├── relics/
│   ├── relic_data.gd
│   ├── relic_instance.gd                       # 🚧 [FUTURO / PENDIENTE]
│   ├── data/
│   │   ├── anillo_brasas.tres
│   │   ├── bolsillo_dimensional.tres
│   │   ├── catalizador_combo.tres
│   │   ├── cenizas_fenix.tres
│   │   ├── colmillo_vibora.tres
│   │   ├── nucleo_sobrecargado.tres
│   │   ├── pata_conejo.tres
│   │   └── trebol_abismo.tres
│   └── effects/
│       ├── relic_effect.gd
│       ├── relic_combo_synergy_effect.gd
│       ├── relic_revive_effect.gd
│       ├── relic_start_status_effect.gd
│       └── relic_stat_bonus_effect.gd
│
├── weapons/
│   ├── weapon_data.gd
│   └── data/
│       ├── arma_basica.tres
│       ├── baculo.tres
│       ├── dagger.tres
│       ├── espadon.tres
│       └── katana_basica.tres
│
├── scenes/
│   ├── battle/
│   │   ├── battle_table.tscn
│   │   ├── battle_table.gd
│   │   └── card_board_controller.gd
│   ├── map/
│   │   └── map_view.gd
│   ├── event/                                  # 🚧 [FUTURO / PENDIENTE]
│   ├── reward/
│   │   └── reward_view.gd
│   ├── shop/
│   │   └── shop_view.gd
│   └── menus/
│       ├── main_menu_view.gd
│       ├── slot_select_view.gd
│       └── hero_select_view.gd
│
├── ui/
│   ├── cards/
│   │   ├── card_ui.tscn
│   │   └── card_ui.gd
│   ├── battle/
│   │   ├── hud_battle.gd                       # (class_name BattleHUD)
│   │   ├── player_hud.gd
│   │   ├── enemy_hud.gd
│   │   ├── combo_banner.gd
│   │   └── pile_inspector.gd
│   ├── inventory/
│   │   └── inventory_modal_view.gd
│   ├── map/
│   │   ├── map_node_view.gd
│   │   ├── sanctuary_modal_view.gd
│   │   └── inspector_modal_view.gd
│   ├── menus/
│   │   └── hero_card_view.gd
│   └── system/
│       ├── pause_menu_view.gd
│       └── debug_overlay.gd
│
├── assets/
│   ├── audio/                                  # music/, sfx/, ui/ (.gitkeep)
│   ├── fonts/                                  # (.gitkeep)
│   └── textures/                               # cards/, heroes/, map/, relics/, ui/ (.gitkeep)
│
├── addons/
│   └── gut/
│
└── test/                                       # 🚧 [FUTURO / PENDIENTE - Carpetas con .gitkeep]
	├── combat/
	├── deck/
	└── run/
```

---

## Capas y responsabilidades

| Capa | Carpeta | Conoce / Depende de | No conoce |
|---|---|---|---|
| **Servicios globales** | `autoload/` | `CombatConstants`, `RunState`, `DeckManager`, `Resource` types | `scenes/`, `ui/` |
| **Lógica de dominio** | `core/` | `entities/`, `cards/`, `relics/`, `weapons/`, `autoload/` | `scenes/`, `ui/` *(excepto `RunDirector`, que actúa como Mediador de vistas)* |
| **Definición de actores** | `entities/` | `cards/`, `relics/`, `weapons/`, `core/enemies/behaviors/`, `CombatConstants` | `scenes/`, `ui/` *(nota: `ArcaneFlowAbility` y `BloodySlashAbility` reciben `table` vía diccionario `context`)* |
| **Datos de cartas** | `cards/` | `RaritySystem`, `WeaponData`, `RunState` (para `combat_rng` en `ApplyStatusEffect`) | `scenes/`, `ui/` |
| **Datos de reliquias** | `relics/` | `RaritySystem`, `CombatConstants`, `Enemy`, `RunState` | `scenes/`, `ui/` |
| **Datos de armas** | `weapons/` | — (100% autónomo) | Todo lo demás |
| **Escenas / Pantallas** | `scenes/` | `core/`, `ui/`, `autoload/`, `entities/`, `cards/`, `relics/`, `weapons/` | — |
| **UI atómica y modales** | `ui/` | Datos inyectados (`CardData`, `RoomData`, `CardPile`, `RunState`, `RaritySystem`) | `scenes/` *(salvo `DebugOverlay`, que es herramienta de QA transversal)* |

---

## Grafo de dependencias reales

```mermaid
flowchart TD
	subgraph Autoloads["autoload/ (Singletons)"]
		SB["SignalBus"]
		GDB["GameDatabase"]
		PM["PersistenceManager"]
	end

	subgraph Scenes["scenes/ (Pantallas y Controladores)"]
		BT["BattleTable (battle_table.tscn + .gd)"]
		CBC["CardBoardController"]
		MV["MapView (100% código)"]
		SV["ShopView (100% código)"]
		RV["RewardView (100% código)"]
		MMV["MainMenuView (100% código)"]
		HSV["HeroSelectView (100% código)"]
		SSV["SlotSelectView (100% código)"]
	end

	subgraph UI["ui/ (Componentes Atómicos y Modales)"]
		BHUD["BattleHUD (PlayerHUD, EnemyHUD, ComboBanner, PileInspector)"]
		CUI["CardUI (card_ui.tscn + .gd)"]
		IMV["InventoryModalView"]
		SMV["SanctuaryModalView"]
		INSP["InspectorModalView"]
		MNV["MapNodeView"]
		HCV["HeroCardView"]
		PMV["PauseMenuView"]
		DBG["DebugOverlay"]
	end

	subgraph Core["core/ (Lógica de Dominio - RefCounted)"]
		RD["RunDirector (Mediator)"]
		RS["RunState"]
		RSM["RunStateMachine (FSM)"]
		CR["CombatResolver (Static)"]
		SR["StatusReactions (Static)"]
		TSM["TempStatManager"]
		DM["DeckManager & CardPile"]
		EN["Enemy & EnemyAI"]
		FG["FloorGenerator & RoomData"]
		RAR["RaritySystem (Static)"]
	end

	subgraph Data["entities/ + cards/ + relics/ + weapons/ (Resources)"]
		RES["HeroData, HeroAbility, EnemyData, EnemyBehavior,\nCardData, CardEffect, RelicData, RelicEffect, WeaponData"]
	end

	BT --> CBC
	BT --> BHUD
	BT --> RD
	BT --> CR
	BT --> DM
	BT --> DBG
	CBC --> CUI
	BHUD --> IMV

	RD --> RSM
	RD --> RS
	RD --> PM
	RD --> MV
	RD --> SV
	RD --> RV
	RD --> MMV
	RD --> SSV
	RD --> PMV

	MV --> MNV
	MV --> SMV
	MV --> INSP
	MV --> IMV
	MMV --> HCV
	RV --> CUI

	RS --> GDB
	RS --> FG
	RS --> RAR
	RS --> TSM
	RS --> EN
	CR --> SR
	EN --> SR
	Core --> RES
	Core --> SB
```

---

## Detalle archivo por archivo

### `autoload/` — Singletons globales

| Archivo | Clase / Tipo | Responsabilidad real en código |
|---|---|---|
| `signal_bus.gd` | `SignalBus` (`Node`) | Declara 4 señales globales desacopladas: `card_played(card_data: CardData)`, `relic_acquired(relic: RelicData)`, `room_entered(room: RoomData)` y `floor_started(floor_number: int)`. |
| `game_database.gd` | `GameDatabase` (`Node`) | Escanea directorios con `ResourceLoader.list_directory()` usando las rutas de `CombatConstants`. Expone `load_all_heroes()` (ordenados por `sort_order`), `load_all_cards()` (recursivo, ignorando `effects/`), `load_all_relics()`, `load_all_enemies()` y `load_all_weapons()`. |
| `persistence_manager.gd` | `PersistenceManager` (`Node`) | Administra hasta 3 ranuras (`user://saves/slot_1..3/profile.json` y `run.json`) y el puntero de auto-arranque `user://last_slot.cfg`. Implementa escritura atómica (`_write_atomic`: escribe en `.tmp` y renombra) para evitar corrupción de JSON. |

---

### `core/combat/` — Resolución de combate, reacciones y stats temporales

| Archivo | Clase / Tipo | Responsabilidad real en código |
|---|---|---|
| `combat_resolver.gd` | `CombatResolver` (`RefCounted`) | **100% estático y stateless.** Métodos puros: `calculate_sequential_preview()` (simula el combo preservando el estado de `combat_rng`), `calculate_final_card_damage()` (verifica `required_weapon_class`, suma `base_damage` y `get_scaling_bonus()` del arma, o aplica penalización de -25% por cada punto de déficit en `STR`/`INT`/`DEX` anulando estados), `_apply_card_effects_to_combo()`, `process_card_in_combo()`, `finalize_combo()`, `tick_enemy_statuses()`, `resolve_enemy_turn()` y `calculate_instant_card()`. |
| `status_reactions.gd` | `StatusReactions` (`RefCounted`) | Motor estático data-driven (`const REACTIONS`). `check(enemy, incoming)` simula la suma de estados y detecta si se activa **Vaporización** (`burn + freeze` → consume hasta 3 de c/u, 15 daño fijo), **Superconductor** (`freeze + shock` → consume todo, 20 daño fijo) o **Combustión Tóxica** (`burn + poison` → consume todo el veneno, 10 daño fijo). `apply(enemy, reaction)` consume las cargas y aplica el daño. |
| `temp_stat_manager.gd` | `TempStatManager` (`RefCounted`) | Gestiona buffs/debuffs temporales de estadísticas RPG (`str`, `int`, `dex`) durante un combate. Métodos: `add_mod(stat, amount, turns)`, `tick_turn()`, `get_total_mod(stat)`, `has_mod(stat)`, `clear()`, `get_active_mods_summary()`. |

---

### `core/deck/` — Pilas de cartas y ciclo del mazo

| Archivo | Clase / Tipo | Responsabilidad real en código |
|---|---|---|
| `card_pile.gd` | `CardPile` (`RefCounted`) | Contenedor de `Array[CardData]` con señal `pile_changed(new_count: int)`. Métodos: `add_card()`, `draw_top()`, `shuffle()`, `clear()`, `move_all_to()`, `get_contents_summary()`. |
| `deck_manager.gd` | `DeckManager` (`RefCounted`) | Administra 3 instancias de `CardPile`: `draw_pile` ("Mazo"), `discard_pile` ("Descarte") y `graveyard_pile` ("Cementerio"). Clona las cartas iniciales (`duplicate()`) sellando la ruta en `resource_name` para serialización (`to_dict()` / `from_dict()`). `route_played_card()` envía cartas con `single_use == true` al Cementerio y el resto a Descarte. |

---

### `core/enemies/` — Lógica de enemigos e IA componible

| Archivo | Clase / Tipo | Responsabilidad real en código |
|---|---|---|
| `enemy.gd` | `Enemy` (`RefCounted`) | Entidad viva del enemigo. Escala `max_hp` (`+25/piso` normal, `+45/piso` jefe) e `intent_damage` (`+3/piso` normal, `+4/piso` jefe). Gestiona `block`, los 5 estados alterados (`burn`, `poison`, `freeze`, `shock`, `hemorrhage`), reacciones elementales (`apply_statuses()`), estallido dinámico de hemorragia (`apply_hemorrhage_tick()`), parálisis por shock (`try_trigger_shock_stun()`) y congelamiento (`apply_freeze_tick()`). |
| `enemy_ai.gd` | `EnemyAI` (`RefCounted`) | Orquestador estático `decide_intent(enemy, run, turn_count) -> EnemyIntent`. Itera `enemy.data.intent_pattern` y devuelve el primer `EnemyIntent` no nulo; si no hay ninguno o el array está vacío, hace fallback a un ataque básico con `get_effective_intent_damage()`. |
| `behaviors/enemy_behavior.gd` | `EnemyBehavior` (`Resource`) | Clase base abstracta para comportamientos de IA configurables desde el Inspector (`decide(context) -> EnemyIntent`). |
| `behaviors/enemy_context.gd` | `EnemyContext` (`RefCounted`) | DTO que encapsula `enemy: Enemy`, `run: RunState` y `turn_count: int`. |
| `behaviors/enemy_intent.gd` | `EnemyIntent` (`RefCounted`) | DTO con `enum Type { ATTACK, DEFEND, CHARGE, APPLY_STATUS, NOTHING }`, `damage`, `block`, `status_id`, `status_stacks` y `description`. |
| `behaviors/attack_behavior.gd` | `AttackBehavior` (`EnemyBehavior`) | Ataca cada `every_n_turns` turnos sumando el escalado de piso del enemigo. |
| `behaviors/defend_behavior.gd` | `DefendBehavior` (`EnemyBehavior`) | Otorga `block` al enemigo cada `every_n_turns` turnos. |
| `behaviors/charge_behavior.gd` | `ChargeBehavior` (`EnemyBehavior`) | Ciclo en fases (`turn_count % every_n_turns`): fase 0 retorna `CHARGE` (0 daño), fase 1 retorna `ATTACK` multiplicado por `bonus_multiplier`, resto retorna `null` para delegar al siguiente behavior. |

---

### `core/run/` — Estado de partida, FSM, Director y Rarezas

| Archivo | Clase / Tipo | Responsabilidad real en código |
|---|---|---|
| `run_state.gd` | `RunState` (`RefCounted`) | Contenedor de estado vivo y lógica de dominio de la run: stats del jugador (`player_hp`, `max_player_hp`, `max_energy`, `target_hand_size`, `discards_per_combat`, `player_gold`, `player_luck`, `player_str`, `player_int`, `player_dex`), `temp_stats`, `current_weapon`, `inventory_weapons` (mochila hasta 4 armas), `current_ability`, `active_relics`, `floor_data`, `combat_rng`. Genera y aplica recompensas de combate, stock de tienda, curación en hoguera, bendiciones de santuario y serialización completa (`to_dict` / `from_dict`). |
| `run_director.gd` | `RunDirector` (`RefCounted`) | Mediador central. Instancia en código `MapView`, `PauseMenuView`, `MainMenuView`, `HeroSelectView`, `ShopView`, `SlotSelectView` y `RewardView` como hijos de `BattleTable`. Maneja el auto-login con `last_slot.cfg` (dejando siempre al jugador con su perfil ya cargado o reanudando su run activa), la navegación hacia `HeroSelectView`, salas del mapa, compras en tienda, fin de combate y guardado al salir. |
| `run_state_machine.gd` | `RunStateMachine` (`RefCounted`) | FSM con `enum State { MENU, MAP, BATTLE, REWARD, EVENT, SHOP, DEAD, VICTORY }`. Valida transiciones en `_is_valid_transition(from, to)` y emite `state_changed(new_state)`. |
| `rarity_system.gd` | `RaritySystem` (`RefCounted`) | Motor estático de probabilidades con 5 Tiers (`COMMON`, `UNCOMMON`, `RARE`, `EPIC`, `LEGENDARY`). Calcula `fortune` según `floor_number` y `player_luck`, sortea rarezas (`roll_tier`), hace sorteos ponderados genéricos (`roll_weighted`) e interpolación lineal suavizada por suerte (`get_scaled_value_smooth`). |

---

### `core/map/` y `core/constants/`

| Archivo | Clase / Tipo | Responsabilidad real en código |
|---|---|---|
| `room_data.gd` | `RoomData` (`RefCounted`) | Representa una celda de la matriz `8x8` con `enum Type { START, COMBAT, TREASURE, REST, SANCTUARY, BOSS, SHOP }`, `grid_pos`, `cleared`, `discovered`, `neighbors: Array[Vector2i]` y caché de tienda (`shop_cards`, `shop_relics`, `shop_initialized`). Provee nombre y color temático según estado. |
| `floor_generator.gd` | `FloorGenerator` (`RefCounted`) | Generador procedural estático de grafo ortogonal en grilla `8x8`. Expande la frontera desde el centro evitando bloques 2x2, conecta vecinos ortogonales y asigna salas especiales en los `dead_ends` ordenados por distancia Manhattan (`BOSS` en el más lejano, `TREASURE`, `REST`, `SHOP`, `SANCTUARY`). |
| `combat_constants.gd` | `CombatConstants` (`RefCounted`) | Rutas de catálogos, umbrales (`FREEZE_STUN_THRESHOLD = 5`, `HEMORRHAGE_BURST_THRESHOLD = 10`, `SHOCK_STUN_CHANCE_PER_STACK = 0.12`, etc.) y estadísticas base del jugador (`BASE_HAND_SIZE = 5`, `BASE_MAX_ENERGY = 3`, `MAX_INVENTORY_SIZE = 4`). |

---

### `entities/`, `cards/`, `relics/`, `weapons/` — Recursos de Datos y Estrategias

| Carpeta / Archivo | Clase Base | Implementaciones Concretas Actuales |
|---|---|---|
| `entities/hero/hero_data.gd` | `HeroData` (`Resource`) | `warrior_hero.tres` (Guerrero), `magic_hero.tres` (Mago), `samurai_hero.tres` (Samurai), `assasin_hero.tres` (Asesino), `demo_hero.tres` (DEMO). |
| `entities/hero/abilities/` | `HeroAbility` (`Resource`) | `WarCryAbility` (`war_cry_ability.gd`), `ArcaneFlowAbility` (`arcane_flow_ability.gd`), `DemonThrustAbility` (`demon_thrust_ability.gd`), `BloodySlashAbility` (`bloody_slash_ability.gd`). |
| `entities/enemies/enemy_data.gd` | `EnemyData` (`Resource`) | `esqueleto.tres` (con `DefendBehavior`), `jefe_basico.tres` (`is_boss = true`). |
| `cards/card_data.gd` | `CardData` (`Resource`) | 12 cartas en `cards/data/`: `corte_rapido`, `curacion_basica`, `efecto_caotico`, `escudo_basico`, `estocada`, `frasco_veneno_basico`, `golpe_congelante`, `golpe_fuego`, `lanza_rayo`, `robo_basico`, `sobre_carga`, `tajo`. Incluye `@export var is_magical: bool`, `@export var artwork: Texture2D` y helpers de presentación (`is_magic_card()`, `get_color()`, `get_art_accent_color()`, `get_weapon_icon()`, `get_weapon_tag_text()`, `get_placeholder_emblem()`, `get_rules_text()`, `get_enemy_status_icons()`). |
| `cards/effects/` | `CardEffect` (`Resource`) | Clase base con `@export var is_magical: bool = false`. Subclases: `DamageEffect`, `DefenseEffect`, `BurnEffect` (`is_magical = true`), `PoisonEffect`, `FreezeEffect` (`is_magical = true`), `ShockEffect` (`is_magical = true`), `HemorrhageEffect`, `HealEffect`, `MultiplyEffect` (`is_magical = true`), `StealEffect` (instantánea), `ApplyStatusEffect` (`is_magical = true`, fijo o `RANDOM`). |
| `relics/relic_data.gd` | `RelicData` (`Resource`) | 8 reliquias en `relics/data/`: `anillo_brasas`, `bolsillo_dimensional`, `catalizador_combo`, `cenizas_fenix`, `colmillo_vibora`, `nucleo_sobrecargado`, `pata_conejo`, `trebol_abismo`. |
| `relics/effects/` | `RelicEffect` (`Resource`) | `RelicStatBonusEffect`, `RelicStartStatusEffect`, `RelicComboSynergyEffect`, `RelicReviveEffect`. |
| `weapons/weapon_data.gd` | `WeaponData` (`Resource`) | 5 armas en `weapons/data/`: `arma_basica.tres` (Palito), `baculo.tres` (Báculo Básico), `dagger.tres` (Daga), `espadon.tres` (Espadón), `katana_basica.tres` (Katana Básica). |

---

### `scenes/` y `ui/` — Capa de Presentación

| Archivo | Clase | Tipo de UI | Responsabilidad |
|---|---|---|---|
| `scenes/battle/battle_table.gd` | *(Control)* | `.tscn` + `.gd` | Nodo raíz de la escena principal y fachada de combate. Coordina `CardBoardController`, `BattleHUD`, `DeckManager`, `CombatResolver` y `RunDirector`. |
| `scenes/battle/card_board_controller.gd` | `CardBoardController` | `RefCounted` | Administra las listas `hand_cards` y `combo_cards` de nodos `CardUI`, calcula el layout dinámico horizontal, e intercala cartas en vivo durante el drag & drop. |
| `scenes/map/map_view.gd` | `MapView` | 100% código (`Control`) | Dibuja la grilla 8x8 y sus pasillos (`_draw()`), instancia `MapNodeView` por cada sala descubierta, y aloja `SanctuaryModalView`, `InspectorModalView` e `InventoryModalView`. |
| `scenes/reward/reward_view.gd` | `RewardView` | 100% código (`Control`) | Modal post-victoria adaptado al viewport `1152x648` con instancias `CardUI` (`180x240`), animaciones estilo Balatro (pop-in con `TRANS_BACK`, flotación senoidal desfasada y hover magnético con inclinación). |
| `scenes/shop/shop_view.gd` | `ShopView` | 100% código (`Control`) | Tienda del Bazar: renderiza 3 cartas y 2 reliquias tasadas por `RaritySystem.Tier`, validando oro y marcando slots como `"VENDIDO"` / `"COMPRADO"`. |
| `scenes/menus/main_menu_view.gd` | `MainMenuView` | 100% código (`Control`) | Menú principal enfocado en mostrar el estado del perfil activo ya cargado (nombre, ranura, mejor piso, victorias), mensajes de Game Over y navegación hacia `HeroSelectView` o `SlotSelectView`. |
| `scenes/menus/slot_select_view.gd` | `SlotSelectView` | 100% código (`Control`) | Gestión de las 3 ranuras de guardado con modal emergente para nombrar nuevo perfil. |
| `scenes/menus/hero_select_view.gd` | `HeroSelectView` | 100% código (`Control`) | Pantalla dedicada de preparación de expedición: instancia las tarjetas `HeroCardView`, muestra la ficha técnica del héroe elegido (descripción, arma y habilidad activa) y gestiona el ingreso opcional de semilla (`seed`). |
| `ui/cards/card_ui.gd` | `CardUI` | `.tscn` + `.gd` | Representación visual responsiva de una carta en 4 bloques (`[Costo] Nombre [Icono Arma]`, recuadro de Arte 2D / emblema, tag `[🏷️ Familia de Arma]`, y caja inferior con descripción centrada + ícono de estado alterado sobre el enemigo abajo a la izquierda). Cuerpo y reborde fijo (`2px`) coloreados por Rareza (`RaritySystem.Tier`); `TitleLabel` (con contorno negro de `2px`) coloreado según la función/naturaleza mágica de la carta (`CardData.get_color()`). Incluye física de resorte exponencial (`exp(-28 * delta)`), tilt por velocidad horizontal y animación de disolución (`play_consume_animation()`). |
| `ui/battle/hud_battle.gd` | `BattleHUD` | Nodos en `battle_table.tscn` + `.gd` | Orquesta `PlayerHUD`, `EnemyHUD`, `ComboBanner`, `PileInspector`, botones de pilas y botón de `InventoryModalView`. |
| `ui/battle/player_hud.gd` | `PlayerHUD` | `Panel` | Renderiza nombre del héroe, HP, escudo, arma equipada, energía y suerte. |
| `ui/battle/enemy_hud.gd` | `EnemyHUD` | `Panel` | Renderiza nombre, HP, bloqueo, intención declarada y cargas de estados alterados (incluyendo `% Stun` de Shock y progreso `X/5` de Freeze). |
| `ui/battle/combo_banner.gd` | `ComboBanner` | `Label` | Formatea el diccionario predictivo de `CombatResolver.calculate_sequential_preview()` o muestra alertas de combate. |
| `ui/battle/pile_inspector.gd` | `PileInspector` | `Panel` | Popup que muestra el resumen agrupado (`get_contents_summary()`) de Mazo, Descarte o Cementerio. |
| `ui/inventory/inventory_modal_view.gd` | `InventoryModalView` | 100% código (`Control`) | Muestra `STR`, `INT`, `DEX`, `LUCK`, tarjeta destacada del arma equipada y lista scrollable de la mochila (`inventory_weapons`) para intercambiar el arma activa. |
| `ui/map/map_node_view.gd` | `MapNodeView` | 100% código (`Button`) | Celda individual del mapa 8x8 coloreada según `RoomData.get_room_color()` con bordes jerárquicos (blanco = actual, dorado = viajable, gris = bloqueado). |
| `ui/map/sanctuary_modal_view.gd` | `SanctuaryModalView` | 100% código (`Panel`) | Modal de decisión binaria para las salas `SANCTUARY`. |
| `ui/map/inspector_modal_view.gd` | `InspectorModalView` | 100% código (`Panel`) | Modal con scroll vertical para inspeccionar el texto detallado de reliquias o cartas del mazo. |
| `ui/menus/hero_card_view.gd` | `HeroCardView` | 100% código (`Button`) | Tarjeta con `RichTextLabel` BBCode (stats base, atributos RPG, arma inicial, habilidad y reliquias) y resorte exponencial de escala (`0.95x` en reposo con tinte gris acero, `1.04x` en hover, `1.08x` fija seleccionada con pulso `1.13x` al clic y `StyleBox` `"hover"`). |
| `ui/system/pause_menu_view.gd` | `PauseMenuView` | 100% código (`Control`) | Congela el árbol (`get_tree().paused = true` con `PROCESS_MODE_ALWAYS`), ofrece Continuar, Abandonar Partida (con modal de confirmación) y Guardar y Salir. |
| `ui/system/debug_overlay.gd` | `DebugOverlay` | 100% código (`Control`) | Consola QA de 3 columnas (`F3`/`F4`) inyectada solo en builds debug. |

---

## Reglas de oro

1. **`core/` no conoce `scenes/` ni `ui/`** (con la única excepción de `RunDirector`, cuya responsabilidad explícita es ser el Mediador entre las vistas y `RunState`).
2. **Inmutabilidad de `.tres` en disco**: ningún archivo `.tres` se muta en runtime; se clona con `.duplicate()` sellando `resource_name = resource_path`.
3. **UI fuera del Resolver**: `CombatResolver` y `StatusReactions` son 100% estáticos y puros. Ningún `await`, `Tween` ni manipulación de nodos entra en `core/combat/`.
4. **No `load()` desparramado**: la carga de catálogos se centraliza en `GameDatabase` y las rutas constantes en `CombatConstants`.
5. **Las vistas no mutan dominio directamente**: las vistas (`RewardView`, `ShopView`, `InventoryModalView`, `MapView`) emiten señales; `RunDirector` o `BattleTable` invocan los métodos de negocio en `RunState`.
6. **Determinismo por semillas**: toda generación aleatoria de mapas, tiendas, recompensas y efectos de combate (`ApplyStatusEffect` con `RANDOM`) debe utilizar instancias de `RandomNumberGenerator` derivadas de `master_seed` (`FloorGenerator.get_floor_subseed` o `run.combat_rng`), nunca el `randi()` global sin semilla cuando afecte decisiones reproducibles.

---

## Patrones de diseño aplicados

| Patrón | Dónde se aplica | Propósito técnico |
|---|---|---|
| **Mediator** | `core/run/run_director.gd` | Coordina la navegación entre `SlotSelectView`, `MainMenuView`, `MapView`, `ShopView`, `RewardView`, `PauseMenuView` y `BattleTable` sin acoplar las vistas entre sí. |
| **Facade** | `scenes/battle/battle_table.gd` | Unifica la interacción entre el tablero visual (`CardBoardController`), el mazo (`DeckManager`), el motor matemático (`CombatResolver`) y el HUD (`BattleHUD`). |
| **Strategy (Data-Driven)** | `cards/effects/`, `relics/effects/`, `core/enemies/behaviors/`, `entities/hero/abilities/` | Inyecta comportamiento polimórfico desde archivos `.tres` editables en el Inspector. |
| **Stateless Functional Core** | `CombatResolver`, `StatusReactions`, `FloorGenerator`, `RaritySystem` | Clases con métodos 100% `static` sin efectos secundarios ocultos, facilitando la predicción en vivo (`calculate_sequential_preview`) y el testeo unitario. |
| **State Machine (FSM)** | `core/run/run_state_machine.gd` | Garantiza transiciones legales del ciclo de partida (`MENU`, `MAP`, `BATTLE`, `REWARD`, `EVENT`, `SHOP`, `DEAD`, `VICTORY`). |
| **Observer (Event Bus)** | `autoload/signal_bus.gd` + señales locales | Desacopla notificaciones globales y eventos de UI. |
| **Atomic Write Persistence** | `autoload/persistence_manager.gd` (`_write_atomic`) | Escribe primero en `.tmp` y reemplaza mediante `rename` para garantizar que un crash nunca corrompa `profile.json` ni `run.json`. |

---

## Decisiones Técnicas

### 7.1 ¿Por qué `CombatResolver` es Stateless y no usa Command pattern?

El `CombatResolver` es completamente **stateless**: todos sus métodos son `static`, no retiene estado mutable entre llamadas y opera transformando diccionarios de estado (`combo_state`).

La separación de responsabilidades se resuelve mediante el patrón **Pure Logic + UI Orchestrator**:
- `core/combat/combat_resolver.gd` → matemática pura y determinista, sin `await` ni referencias a nodos.
- `scenes/battle/battle_table.gd` → orquestación asíncrona de turnos, animaciones (`await`, `card.pulse()`, `hud.set_banner_message()`, `card.queue_free()`).

Esto permite usar exactamente la misma lógica (`calculate_final_card_damage` + `_apply_card_effects_to_combo`) tanto para **previsualizar el combo en tiempo real** mientras el jugador arrastra cartas como para **ejecutar el turno real**, sin necesidad de construir ni revertir objetos `CombatAction`.

### 7.2 Decisión: Protección de Recursos (Duplicate + Sellado vs Data/Instance)

Si se modifica un recurso `.tres` cargado en memoria, Godot altera la instancia compartida en caché y contamina todo el mazo.

- **Implementación actual en producción (Clonación + Sellado de Ruta):**
  Cuando `DeckManager.build_initial_deck_for_hero()` o `RunState` instancian cartas o reliquias para la partida, ejecutan `var copy := res.duplicate()` y sellan la ruta original en `copy.resource_name = res.resource_path`. Así cada copia en el mazo es independiente en memoria y, al guardar la partida en JSON (`PersistenceManager`), `DeckManager.to_dict()` recupera `resource_name` cuando `resource_path` está vacío por ser un duplicado.
- **Evolución planificada (`🚧 [FUTURO / PENDIENTE]` — `CardInstance` / `RelicInstance`):**
  Cuando se implementen mejoras permanentes por carta en partida (upgrades en hoguera, reducciones de costo por turno o contadores de cargas en reliquias), se migrará el stub `cards/card_instance.gd` y se creará `relics/relic_instance.gd` para envolver el `.tres` inmutable sin necesidad de duplicar el `Resource`.

### 7.3 Decisión: `scenes/` vs `ui/` y Vistas 100% en Código

- **`scenes/`**: Pantallas completas del flujo de la partida (`BattleTable`, `MapView`, `ShopView`, `RewardView`, `MainMenuView`, `SlotSelectView`).
- **`ui/`**: Componentes atómicos que se instancian múltiples veces (`CardUI`, `MapNodeView`, `HeroCardView`), subpaneles del HUD (`PlayerHUD`, `EnemyHUD`, `ComboBanner`, `PileInspector`) y modales reutilizables (`InventoryModalView`, `SanctuaryModalView`, `InspectorModalView`, `PauseMenuView`, `DebugOverlay`).

**¿Por qué la mayoría de las vistas (`MapView`, `ShopView`, `RewardView`, `MainMenuView`, `SlotSelectView`, modales) se construyen 100% en código sin `.tscn`?**
1. Evita conflictos de UIDs y corrupción de escenas `.tscn` en Git cuando se itera rápido sobre el layout.
2. Facilita el posicionamiento dinámico responsivo al viewport (`_layout_for_viewport()`, `top_level = true`) y animaciones procedurales complejas (como el efecto Balatro en `RewardView` o el trazado `_draw()` de pasillos en `MapView`).
3. Solo se mantienen `.tscn` donde el diseño visual estático en el editor aporta valor directo (`battle_table.tscn` y `card_ui.tscn`).

### 7.4 ¿Por qué `RewardView` no genera sus propias recompensas?

`RewardView` es una vista pura: recibe el diccionario `rewards` ya calculado en `setup()`, renderiza las cartas con animaciones y emite `card_chosen(card_data)` o `skipped()`.
Toda la generación vive en `RunState.generate_combat_rewards()`, que usa `FloorGenerator.get_floor_subseed(master_seed, current_floor * 1000 + combat_index)`. Esto garantiza que las recompensas sean **100% deterministas por semilla** y testeables sin instanciar nodos de UI.

### 7.5 Decisión: Simulación Predictiva Determinista en `calculate_sequential_preview`

Cartas como `Efecto Caótico` (`ApplyStatusEffect` con `StatusType.RANDOM`) consumen números aleatorios de `run.combat_rng` al evaluarse en el combo. Si el preview consumiera el RNG libremente cada vez que el jugador mueve una carta, el estado del RNG avanzaría y el resultado real al apretar "EJECUTAR COMBO" sería distinto al previsualizado (o permitiría hacer *scumming* moviendo cartas).

Para blindar esto, `CombatResolver.calculate_sequential_preview()` guarda `var rng_state = run.combat_rng.state` antes de simular la fila de combo y lo restaura (`run.combat_rng.state = rng_state`) al terminar el cálculo. Así, la simulación es **libre de side-effects** y la ejecución real reproduce exactamente la misma tirada.

### 7.6 Estándar de Documentación Interna (`##`) y Depuración de Código Obsoleto

Todo el código fuente GDScript del proyecto (excluyendo addons de terceros como `addons/gut/`) cumple con **100% de cobertura de docstrings `##`** de Godot 4 tanto a nivel de clase como en cada función (`func` / `static func`).

- **Convención de Docstrings (`##`):**
  - Se coloca inmediatamente encima de la declaración `func` (sin comentarios `#` simples intercalados que corten la asociación del parser de Godot).
  - Describe el **propósito, efectos secundarios y valor de retorno** de la función en lenguaje directo, sin requerir etiquetas `@param` redundantes cuando el tipado estático de GDScript ya explicita la firma.
- **Unificación y Limpieza de Código Obsoleto (Refactor Consolidado):**
  - **`Enemy.apply_statuses(incoming: Dictionary)` como único punto de entrada:** Se eliminó el wrapper deprecado `Enemy.add_statuses(...)` y se migraron todos los emisores de estados (`BloodySlashAbility`, `RelicStartStatusEffect`, `CombatResolver`) al contrato unificado por `Dictionary`, garantizando que cualquier aplicación de estados evalúe siempre las reacciones elementales (`StatusReactions`).
  - **Delegación estricta de IA en `EnemyAI`:** Se eliminó la función estática duplicada `Enemy.decide_intent()` de `core/enemies/enemy.gd`; toda resolución de intenciones pasa exclusivamente por `EnemyAI.decide_intent()`.
  - **Selección de cartas por rareza unificada en `RunState`:** Tanto la tienda (`generate_shop_cards`) como las recompensas post-combate (`generate_combat_rewards`) utilizan el mismo helper determinista `_pick_from_pool_by_tier_cards()` (eliminando el duplicado `_pick_card_by_tier()`).
  - **Separación entre `InspectorModalView` e `InventoryModalView`:** Se purgaron de `InspectorModalView` las señales y callbacks residuales de equipamiento de armas (`weapon_selected_to_equip`, `_on_weapon_button_pressed`), responsabilidad que pertenece exclusivamente a `InventoryModalView`.
  - **Separación de responsabilidades entre `MainMenuView` y `HeroSelectView`:** `MainMenuView` actúa como hub del perfil activo ya cargado (estadísticas del jugador, alertas de fin de run, cambio de perfil), delegando la selección de personaje (`HeroCardView`), inspección de habilidad/arma e ingreso de semilla (`seed`) a la pantalla dedicada `HeroSelectView`.

---

## Checklist: agregar X al proyecto

### Agregar una carta nueva
- [ ] Crear `cards/data/<nombre>.tres` de tipo `CardData`.
- [ ] Configurar `title`, `rarity`, `single_use`, `cost`, `description`.
- [ ] Configurar sinergia de arma: `required_weapon_class` y `uses_weapon_damage`.
- [ ] Asignar recursos `CardEffect` en el array `effects`. (Si requiere un efecto nuevo, crearlo en `cards/effects/<nombre>_effect.gd` heredando de `CardEffect`).
- [ ] Verificar en combate que `GameDatabase.load_all_cards()` la levanta automáticamente y que `ComboBanner` previsualiza bien su efecto.

### Agregar un arma nueva
- [ ] Crear `weapons/data/<nombre>.tres` de tipo `WeaponData`.
- [ ] Definir `weapon_id` único, `weapon_name`, `weapon_class` y `base_damage`.
- [ ] Configurar estados on-hit (`inflict_poison`, `inflict_burn`, `inflict_hemorrhage`, `inflict_shock`), requisitos (`req_str`, `req_int`, `req_dex`) y escalado (`scale_str`, `scale_int`, `scale_dex`).
- [ ] Probar equiparla desde `DebugOverlay` (`F3` → Columna 2) y verificar su visualización en `InventoryModalView`.

### Agregar una reliquia nueva
- [ ] Crear `relics/data/<nombre>.tres` de tipo `RelicData`.
- [ ] Si requiere un hook nuevo, crear `relics/effects/relic_<nombre>_effect.gd` heredando de `RelicEffect`.
- [ ] Probar inyectándola en vivo desde `DebugOverlay` (`F3` → Columna 3).

### Agregar un enemigo o behavior nuevo
- [ ] Si requiere nueva lógica de decisión, crear `core/enemies/behaviors/<nombre>_behavior.gd` heredando de `EnemyBehavior`.
- [ ] Crear `entities/enemies/data/<nombre>.tres` de tipo `EnemyData`, configurar `enemy_name`, `base_hp`, `base_damage`, `is_boss` y poblar `intent_pattern`.

### Agregar un héroe o habilidad activa nueva
- [ ] Si tiene habilidad nueva, crear `entities/hero/abilities/<nombre>_ability.gd` heredando de `HeroAbility` e implementar `activate(context: Dictionary)`.
- [ ] Crear `entities/hero/data/<nombre>_hero.tres` de tipo `HeroData` y configurar sus stats base, stats RPG (`base_str`, `base_int`, `base_dex`), `starting_weapon`, `starting_deck`, `starting_relic` y `ability`.

---

## FAQ

**¿Por qué `core/` y no `game/`?**
`core/` explicita que se trata del núcleo de dominio puro (`RefCounted`), libre de escenas `.tscn`.

**¿Por qué las cartas van al Cementerio (`graveyard_pile`)?**
Las cartas marcadas con `single_use = true` (como `Curacion`) se envían a `graveyard_pile` tras ejecutarse en un combo (`DeckManager.route_played_card()`), impidiendo que se vuelvan a barajar cuando se agota el `draw_pile` durante ese mismo combate. Al iniciar el próximo combate, `reset_for_new_combat()` reúne `discard_pile` y `graveyard_pile` de vuelta en el mazo.

**¿Qué pasa si uso una carta con un arma incompatible o sin los stats RPG requeridos?**
1. Si el arma equipada no coincide con `card.required_weapon_class`, la carta ejecuta un **"Golpe torpe"**: su daño cae a `card.fallback_damage` y no aplica estados alterados.
2. Si el arma es de la clase correcta pero los stats efectivos del héroe (`STR`, `INT`, `DEX`) no alcanzan los requisitos del arma (`req_str`, `req_int`, `req_dex`), cada punto de déficit aplica un **-25% de penalización al daño final** (mínimo 1 de daño) y **anula todos los efectos de estado** tanto de la carta como del arma.
