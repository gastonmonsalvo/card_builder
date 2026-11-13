# 🧠 CONTEXT.md — Master AI & Developer Context (`card-prototype`)

> **Propósito de este documento:** Este archivo es la **fuente única de verdad condensada (Single-File Knowledge Base)** diseñada específicamente para modelos de IA (LLMs / Agentes de Código) y desarrolladores. Contiene **toda la arquitectura, patrones de diseño, contratos de funciones, estructuras de datos (diccionarios/señales), fórmulas matemáticas exactas, catálogos y reglas de extensibilidad** necesarias para modificar, depurar o ampliar el proyecto sin adivinar ni romper invariantes.

---

## 1. Snapshot Técnico del Proyecto

- **Género:** 2D Tactical Roguelike Deckbuilder por Combos, Equipamiento RPG y Reacciones Elementales.
- **Motor:** Godot Engine `4.3+` / `4.7` (GDScript 2.0 con tipado estático estricto).
- **Resolución Base / Viewport:** `1152x648` (`canvas_items`, aspect `expand`) con centrado dinámico ante `size_changed` en `battle_table.tscn` (`PRESET_CENTER` incluyendo `InventoryBtn`) y en todas las vistas/modales en código, renderizador `mobile` (`d3d12`).
- **Escena Principal (`main_scene`):** `res://scenes/battle/battle_table.tscn` (`BattleTable`).
- **Filosofía de UI:** Sólo existen **4 escenas `.tscn`** en todo el proyecto (`battle_table.tscn`, `card_ui.tscn`, `relic_ui.tscn`, `weapon_ui.tscn`). Todas las demás pantallas (`MapView`, `ShopView`, `RewardView`, `MainMenuView`, `HeroSelectView`, `SlotSelectView`) y modales (`InventoryModalView`, `SanctuaryModalView`, `InspectorModalView`, `PauseMenuView`, `DebugOverlay`) se construyen **100% por código en GDScript**, montadas sobre `BattleTable` mediante `z_index` por el mediador `RunDirector`.
- **Autoloads Registrados (`project.godot`):**
  1. `SignalBus` → `res://autoload/signal_bus.gd`
  2. `PersistenceManager` → `res://autoload/persistence_manager.gd`
  3. `GameDatabase` → `res://autoload/game_database.gd`
  4. `WindowController` → `res://autoload/window_controller.gd` *(atajo global `F` para alternar `MODE_WINDOWED` ↔ `MODE_MAXIMIZED`)*

---

## 2. Las 8 Reglas Inquebrantables (Invariantes para la IA)

Cualquier código nuevo o modificación **DEBE** respetar estas reglas:

1. **Separación Estricta de Capas (`core/` vs `scenes/` & `ui/`):**
   - `core/` contiene lógica de dominio pura (`RefCounted`). **Nunca** instancia nodos visuales, no usa `await`, ni crea `Tween` (con la única excepción de `RunDirector`, cuyo rol explícito es ser el **Mediator** entre las vistas y `RunState`).
2. **`CombatResolver` es 100% Stateless y la Única Fuente de Verdad Matemática:**
   - Tanto el preview en vivo (`calculate_sequential_preview`) como la ejecución real (`process_card_in_combo` + `finalize_combo`) pasan por `CombatResolver`.
   - El diccionario `combo_state` **siempre** se instancia mediante el Factory Method `CombatResolver.create_empty_combo_state(run, initial_block)`.
3. **Polimorfismo OCP en Efectos de Cartas (Cero Type-Switching):**
   - Está **prohibido** escribir cadenas `if effect is BurnEffect or effect is ...` en `CardData` o `CombatResolver`.
   - Todo nuevo `CardEffect` debe sobrescribir los hooks virtuales de `CardEffect`: `apply_to_combo()`, `apply_instant()`, `get_description()`, `is_status_effect()`, `is_offensive()`, `get_status_icon()` y `get_emblem_icon()`.
4. **Punto Único de Entrada para Estados Alterados en el Enemigo:**
   - Siempre usar `enemy.apply_statuses(incoming: Dictionary)` (ej. `{"burn": 3, "hemorrhage": 5}`). Esto garantiza que siempre se evalúen las reacciones elementales en `StatusReactions.check()`. Nunca modificar `enemy.burn` o `enemy.poison` directamente desde afuera.
5. **Protección de Recursos en Runtime (`Prototype + Route Sealing`):**
   - En Godot 4, `load()` devuelve referencias compartidas en caché. Al otorgar cartas, armas o reliquias a la partida, **siempre** clonar con `var copy := res.duplicate()` y sellar la ruta original en `copy.resource_name = res.resource_path` para que `RunSerializer` y `DeckManager` puedan serializar la ruta en JSON.
6. **Determinismo Absoluto por Semillas (`master_seed` y `combat_rng`):**
   - Prohibido usar `randi()`, `randf()` o `randomize()` globales en lógica de dominio.
   - Usar `FloorGenerator.get_floor_subseed(master_seed, salt)` o `run.combat_rng`.
   - En `CombatResolver.calculate_sequential_preview()`, el estado `var rng_state := run.combat_rng.state` se guarda antes de simular y se restaura al salir para evitar *RNG manipulation*.
7. **Escritura Atómica de Guardado:**
   - Toda persistencia en disco pasa por `PersistenceManager._write_atomic(path, content)` (escribe en `.tmp` y renombra).
8. **Estándar de Documentación (`##`) y Metadatos de UI:**
   - Toda clase y función lleva docstring `##` inmediatamente encima de su declaración.
   - En botones dinámicos (como `ShopView`), guardar datos de negocio con `btn.set_meta("price", price)` y `btn.set_meta("sold", true)` en lugar de parsear `btn.text`.

---

## 3. Mapa de Arquitectura y Patrones de Diseño (13 Patrones)

```text
card-prototype/
├── autoload/
│   ├── signal_bus.gd              # [Observer / Event Bus] Señales globales desacopladas
│   ├── game_database.gd           # [Registry / Asset Repository] Carga catálogos .tres
│   ├── persistence_manager.gd     # [Repository + Atomic Write] 3 slots (profile.json + run.json)
│   └── window_controller.gd       # [Global Input Controller] Toggle maximizado con tecla F
├── core/
│   ├── constants/
│   │   └── combat_constants.gd    # [Constants Catalog] Umbrales, rutas y constantes de balance
│   ├── combat/
│   │   ├── combat_resolver.gd     # [Stateless Functional Core + Factory Method] Motor de combate
│   │   ├── status_reactions.gd    # [Data-Driven Rule Engine] Vaporización, Superconductor, Combustión
│   │   └── temp_stat_manager.gd   # [Temporal Modifier Aggregator] Buffs/debuffs de STR/INT/DEX por turno
│   ├── deck/
│   │   ├── card_pile.gd           # [Observable Collection] Array[CardData] + señal pile_changed
│   │   └── deck_manager.gd        # [Facade + Prototype Route Sealing + Memento] Draw, Discard, Graveyard
│   ├── enemies/
│   │   ├── enemy.gd               # [Domain Entity] Escalado normal/élite/boss, estados y reacciones
│   │   ├── enemy_ai.gd            # [Chain of Responsibility] Decide intención iterando behaviors
│   │   └── behaviors/             # [Strategy + Context/Value DTOs] EnemyBehavior, EnemyContext, EnemyIntent
│   ├── map/
│   │   ├── room_data.gd           # [State Node] Celda 8x8 (START, COMBAT, ELITE, TREASURE, REST, SANCTUARY, SHOP, BOSS)
│   │   └── floor_generator.gd     # [Procedural Builder] Generador ortogonal 8x8 sin bloques 2x2
│   └── run/
│       ├── run_state.gd           # [Facade + Domain State Container + Factory Method] Estado vivo de la run
│       ├── level_progression.gd   # [Stateless Domain Service (SRP)] Curva XP, niveles, crítico asintótico y daño %
│       ├── loot_generator.gd      # [Stateless Domain Service (SRP)] Recompensas deterministas y stock de tienda
│       ├── run_serializer.gd      # [Externalized Serializer / Memento (SRP)] to_dict() / from_dict() de RunState
│       ├── run_director.gd        # [Mediator] Orquestador de vistas, guardado y jerarquía de tecla ESC
│       ├── run_state_machine.gd   # [Finite State Machine (FSM)] 8 estados con validación de transiciones
│       └── rarity_system.gd       # [Stateless Probability Engine] 5 Tiers ponderados por Fortuna y Suerte
├── entities/
│   ├── hero/                      # HeroData (.tres) + abilities/ (HeroAbility Strategy: WarCry, ArcaneFlow, BloodySlash, DemonThrust)
│   └── enemies/                   # EnemyData (.tres: esqueleto.tres, jefe_basico.tres)
├── cards/                         # CardData + effects/ (11 subclases de CardEffect con polimorfismo OCP)
├── relics/                        # RelicData + effects/ (4 subclases de RelicEffect con hooks de ciclo de vida)
├── weapons/                       # WeaponData (Clases de arma, requisitos STR/INT/DEX, escalado y estados on-hit)
├── scenes/                        # Pantallas principales: BattleTable, CardBoardController, MapView, RewardView, ShopView, Menus
└── ui/                            # Widgets y Modales: CardUI, RelicUI, WeaponUI, BattleHUD, CritDiceWidget, InventoryModalView, DebugOverlay, etc.
```

---

## 4. Contratos de Clases, Funciones Clave y Estructuras de Datos

### 4.1 `autoload/`

#### `SignalBus` (`autoload/signal_bus.gd`)
- `signal card_played(card_data: CardData)`
- `signal relic_acquired(relic: RelicData)`
- `signal room_entered(room: RoomData)`
- `signal floor_started(floor_number: int)`
- `signal player_leveled_up(new_level: int)`

#### `GameDatabase` (`autoload/game_database.gd`)
- `load_all_heroes() -> Array[HeroData]` *(ordenados por `sort_order`)*
- `load_all_cards() -> Array[CardData]` *(recursivo en `res://cards/`, ignora `effects/`)*
- `load_all_relics() -> Array[RelicData]`
- `load_all_enemies() -> Array[EnemyData]`
- `load_all_weapons() -> Array[WeaponData]`

#### `PersistenceManager` (`autoload/persistence_manager.gd`)
- Ranuras: `1..3` en `user://saves/slot_<id>/profile.json` y `run.json`. Puntero de auto-login en `user://last_slot.cfg`.
- `save_active_run(slot_id: int, run_state: RunState, deck_manager: DeckManager) -> bool`
- `load_active_run(slot_id: int) -> Dictionary` *(retorna `{"version": 1, "timestamp": ..., "run_state": {...}, "deck": {...}}`)*
- `delete_active_run(slot_id: int) -> void` *(permadeath al morir o abandonar)*
- `record_run_end(slot_id: int, won: bool, floor_reached: int) -> void`

---

### 4.2 `core/combat/` — Motor Matemático y Reacciones

#### Estructura Estándar de `combo_state` (`CombatResolver.create_empty_combo_state(run, initial_block)`)
```gdscript
{
	"dmg": 0,                      # Daño base acumulado en la cadena de combo
	"block": initial_block,        # Escudo acumulado en el turno
	"burn": 0,                     # Cargas de Quemadura a aplicar
	"poison": 0,                   # Cargas de Veneno a aplicar
	"freeze": 0,                   # Cargas de Congelamiento a aplicar
	"shock": 0,                    # Cargas de Electrocutado a aplicar
	"hemorrhage": 0,               # Cargas de Hemorragia a aplicar
	"heal": 0,                     # Curación acumulada para el jugador
	"draw": 0,                     # Cartas extra a robar
	"mult": 1.0,                   # Multiplicador visual acumulado (ej. MultiplyEffect)
	"crit_chance": run.get_crit_chance() if run else 0.0,
	"crit_rolled": false,          # true si finalize_combo() tiró el dado D100 (cuando dmg > 0)
	"base_dmg_before_crit": 0,     # Daño tras reliquias y nivel, antes del multiplicador x1.5
	"crit_chance_pct": 0.0,        # Porcentaje visual de crítico (ej. 14.7)
	"crit_threshold_d100": 100,    # Umbral entero requerido en el D100 (ej. 85+)
	"crit_roll_d100": 1,           # Resultado entero obtenido en el D100 (1..100)
	"is_crit": false,              # Se activa en finalize_combo() si sale crítico
	"final_dmg_applied": 0,        # Daño final real aplicado al enemigo
	"level_dmg_pct": run.get_level_damage_bonus_pct() if run else 0,
	"run": run                     # Referencia a RunState (para combat_rng, armas y stats)
}
```

#### Funciones Estáticas de `CombatResolver` (`core/combat/combat_resolver.gd`)
- `create_empty_combo_state(run: RunState, initial_block: float = 0.0) -> Dictionary`
- `calculate_final_card_damage(card: CardData, current_weapon: WeaponData, h_str: int, h_int: int, h_dex: int) -> Dictionary`:
  - Retorna `{"damage": int, "used_weapon": bool, "is_clumsy": bool, "stat_Penalty": bool, "deficit_points": int, "msg": String}`.
- `calculate_sequential_preview(combo_cards: Array[CardUI], run: RunState, current_block: int = 0) -> Dictionary`:
  - Guarda y restaura `run.combat_rng.state`.
  - Aplica efectos secuencialmente, suma reliquias (`apply_relics_to_combo`), aplica el multiplicador determinista por nivel (`run.get_level_damage_multiplier()`) e inyecta `"crit_chance": run.get_crit_chance()` para que `ComboBanner` muestre `🎲 X.X% CRIT (x1.5)` sin spoilear el resultado de la tirada antes de ejecutar.
- `process_card_in_combo(card_data: CardData, run: RunState, combo_state: Dictionary) -> Dictionary`
- `finalize_combo(run: RunState, combo_state: Dictionary, enemy: Enemy, combo_size: int) -> int`:
  - Aplica reliquias de cierre de combo (`Catalizador de Combo`), multiplica `"dmg"` por `run.get_level_damage_multiplier()`, realiza la tirada determinista del Dado D100 de Golpe Crítico (`run.combat_rng.randf() < crit_chance` → `dmg *= 1.5`), inyecta todos los metadatos del D100 en `combo_state` y aplica `enemy.take_damage(final_dmg)`.
- `tick_enemy_statuses(enemy: Enemy, run: RunState) -> Array[Dictionary]`:
  - Procesa fin de turno del jugador sobre el enemigo: tick de `burn`, tick de `poison` y tick/estallido de `hemorrhage`. Retorna lista de eventos `[{"type": "burn"|"poison"|"hemorrhage_burst"|"hemorrhage_tick", "damage": int, "remaining": int}]`.
- `resolve_enemy_turn(enemy: Enemy, run: RunState, current_player_block: int) -> Dictionary`:
  - Evalúa primero `enemy.apply_freeze_tick()` (si `freeze >= 5` pierde el turno), luego `enemy.try_trigger_shock_stun(run.player_luck, run.combat_rng)`. Si no está aturdido, ejecuta `enemy.current_intent` (`DEFEND`, `CHARGE` o `ATTACK` reduciendo el daño en `enemy.freeze`). Si el daño mata al jugador, invoca `run.try_consume_revive_relic()`.
- `calculate_instant_card(card_data: CardData, run: RunState, current_block: int) -> Dictionary`

#### `StatusReactions` (`core/combat/status_reactions.gd`)
- `check(enemy: Enemy, incoming: Dictionary) -> Dictionary`:
  - Evalúa `future = current_enemy_status + incoming`. Retorna `{}` o la primera reacción que cumpla `requires`:
	1. `"vaporize"` (**¡VAPORIZACIÓN!**): `burn >= 1` y `freeze >= 1` → consume hasta `3 burn` y `3 freeze`, inflige **15 daño fijo**.
	2. `"superconductor"` (**¡SUPERCONDUCTOR!**): `freeze >= 1` y `shock >= 1` → consume `99 freeze` y `99 shock`, inflige **20 daño fijo**.
	3. `"combustion"` (**¡COMBUSTIÓN TÓXICA!**): `burn >= 1` y `poison >= 1` → consume `99 poison`, inflige **10 daño fijo**.
- `apply(enemy: Enemy, reaction: Dictionary) -> int`: Resta las cargas consumidas en `enemy` e invoca `enemy.take_damage(reaction.bonus_damage)`.

#### `TempStatManager` (`core/combat/temp_stat_manager.gd`)
- Gestiona modificadores temporales de `"str"`, `"int"`, `"dex"` en combate: `add_mod(stat, amount, turns)`, `get_total_mod(stat) -> int`, `tick_turn()`, `clear()`.

---

### 4.3 `core/run/` — Estado de Partida y Servicios de Dominio (SRP)

`RunState` (`core/run/run_state.gd`) actúa como **Facade** sobre tres servicios estáticos sin estado:

1. **`LevelProgression` (`core/run/level_progression.gd`)**:
   - `get_xp_required_for_next_level(level: int) -> int`
   - `get_combat_xp_reward(floor_num: int, is_boss: bool = false, is_elite: bool = false) -> int`
   - `apply_xp_gain(run: RunState, amount: int) -> Dictionary` *(retorna `{"xp_gained", "levels_gained", "old_level", "new_level", "hp_gained", "healed"}` y emite `SignalBus.player_leveled_up`)*
   - `get_crit_rating(level: int) -> int`
   - `get_crit_chance(level: int) -> float`
   - `get_level_damage_bonus_pct(level: int) -> int`
   - `get_level_damage_multiplier(level: int) -> float`
2. **`LootGenerator` (`core/run/loot_generator.gd`)**:
   - `grant_random_relic(run: RunState, bonus_fortune: float = 0.0) -> RelicData`
   - `generate_shop_cards(run: RunState, count: int, room_pos: Vector2i) -> Array[CardData]`
   - `generate_shop_relics(run: RunState, count: int, room_pos: Vector2i) -> Array[RelicData]`
   - `generate_combat_rewards(run: RunState, is_boss: bool, is_elite: bool = false) -> Dictionary`:
	 - Retorna `{"gold": int, "cards": Array[CardData], "relic": RelicData, "xp": int, "is_elite": bool, "is_boss": bool}`.
3. **`RunSerializer` (`core/run/run_serializer.gd`)**:
   - `to_dict(run: RunState) -> Dictionary` y `from_dict(run: RunState, data: Dictionary) -> void`.
   - Serializa armas guardando su ruta `.tres` sellada en `resource_name` o su `weapon_id`.

#### Propiedades y Métodos Principales de `RunState`:
- **Atributos y Progresión:** `selected_hero_path`, `player_hp`, `max_player_hp`, `max_energy`, `target_hand_size`, `discards_per_combat`, `player_gold`, `player_luck`, `player_str`, `player_int`, `player_dex`, `player_level` (inicia en 1), `player_xp`, `total_xp_earned`, `temp_stats: TempStatManager`.
- **Getters Efectivos (Base + Temporal):** `get_effective_str() -> int`, `get_effective_int() -> int`, `get_effective_dex() -> int`.
- **Equipo y Reliquias:** `current_weapon: WeaponData`, `inventory_weapons: Array[WeaponData]` (máx. `4` en `CombatConstants.MAX_INVENTORY_SIZE`), `current_ability: HeroAbility`, `active_relics: Array[RelicData]`.
- **Mapa y Semillas:** `master_seed: int`, `current_floor: int`, `combat_index: int`, `combat_rng: RandomNumberGenerator`, `floor_data: Dictionary`, `player_grid_pos: Vector2i`, `god_mode: bool`, `free_travel_enabled: bool`.
- **Fábrica de Enemigos:** `create_enemy_for_room(is_boss: bool, is_elite: bool = false) -> Enemy` *(usa sub-semilla determinista `master_seed + current_floor * 100 + combat_index`)*.

---

## 5. Modelo Matemático Completo y Fórmulas Exactas

### 5.1 Pipeline de Daño de Carta y Arma (`CombatResolver`)

1. **Verificación de Clase de Arma (`required_weapon_class`):**
   - Cada `CardData` define `required_weapon_class: Array[WeaponData.Class]`.
   - Si el array contiene `WeaponData.Class.ANY` (`0`) o incluye `run.current_weapon.weapon_class`, el arma es **compatible**.
   - Si **NO es compatible** → **"Golpe torpe" (`is_clumsy = true`)**:
	 $$\text{Daño Carta} = \text{card.fallback\_damage} \quad (\text{por defecto } 2)$$
	 Además, **se anulan todos los efectos de estado (`effect.is_status_effect() == true`)** de la carta y del arma.

2. **Verificación de Requisitos RPG del Arma (`req_str`, `req_int`, `req_dex`):**
   - Si el arma es compatible y `card.uses_weapon_damage == true`, se compara `get_effective_str/int/dex()` contra `weapon.req_str/int/dex`:
	 $$\text{deficit} = \max(0, \text{req\_str} - \text{STR}) + \max(0, \text{req\_int} - \text{INT}) + \max(0, \text{req\_dex} - \text{DEX})$$
   - **Si $\text{deficit} > 0$ (`stat_Penalty = true`):**
	 - No se suma el bono de escalado positivo del arma.
	 - Se aplica una penalización de **$-25\%$ por cada punto de déficit** al daño combinado (`daño_carta + weapon.base_damage`):
	   $$\text{Daño Penalizado} = \max\left(1, \lfloor (\text{Daño Base Carta} + \text{Weapon Base}) \cdot (1.0 - \min(1.0, \text{deficit} \cdot 0.25)) \rfloor\right)$$
	 - **Se anulan todos los efectos de estado** tanto de la carta como del arma.
   - **Si $\text{deficit} == 0$ (Cumple requisitos):**
	 $$\text{Bono Arma} = \text{weapon.base\_damage} + \lfloor \text{STR} \cdot \text{scale\_str} + \text{INT} \cdot \text{scale\_int} + \text{DEX} \cdot \text{scale\_dex} \rfloor$$
	 $$\text{Daño Final Carta} = \text{Daño Base Carta} + \text{Bono Arma}$$
	 Además, si la carta es ofensiva (`card.is_offensive()`), el arma inyecta sus estados pasivos On-Hit (`inflict_poison`, `inflict_burn`, `inflict_hemorrhage`, `inflict_shock`) al `combo_state`.

3. **Multiplicadores Secuenciales en la Zona de Combo (`MultiplyEffect`):**
   - Se evalúan en el orden exacto de izquierda a derecha en que el jugador colocó las cartas:
	 $$\text{combo\_state["dmg"]} = \lfloor \text{combo\_state["dmg"]} \cdot \text{multiplier} \rfloor$$

4. **Cierre del Combo (`finalize_combo`): Reliquias + Nivel + Dado D100 de Golpe Crítico:**
   - Primero se suman bonos planos de reliquias (ej. *Catalizador de Combo*: si `card_count >= 3`, `+6 dmg` y `+5 block`).
   - Luego se aplica el **Multiplicador de Daño Global por Nivel**:
	 $$\text{Daño Escala Nivel} = \text{roundi}\left(\text{dmg} \cdot \left(1.0 + \frac{(\text{Nivel} - 1) \cdot 2}{100.0}\right)\right)$$
   - Finalmente, si `Daño Escala Nivel > 0`, se realiza la tirada determinista de **Golpe Crítico en un Dado D100 (`1..100`)** contra `run.get_crit_chance()`:
	 - Umbral en el D100: $\text{crit\_threshold\_d100} = \text{clampi}(101 - \max(1, \text{roundi}(\text{CritChance} \cdot 100)),\; 2,\; 100)$.
	 - Si `run.combat_rng.randf() < CritChance` (`is_crit = true`): el dado D100 aterriza proporcionalmente en $[\text{crit\_threshold\_d100} \dots 100]$ y el daño se multiplica por `1.50`:
	   $$\text{Daño Final} = \text{roundi}(\text{Daño Escala Nivel} \cdot 1.50)$$
	 - Si no alcanza el umbral (`is_crit = false`): el dado D100 aterriza en $[1 \dots \text{crit\_threshold\_d100} - 1]$ y el daño queda en `Daño Escala Nivel`.
	 - **Feedback Visual (`CritDiceWidget` vía `BattleHUD.play_crit_dice_roll(combo_state, on_landed)`):** Al ejecutar el combo en `BattleTable.execute_combo_turn()`, antes de bajar la barra de vida en el HUD aparece en el centro de la mesa el componente autónomo **`CritDiceWidget`** (`ui/battle/crit_dice_widget.gd`, `460x224`) dividido en 3 etapas claras de lectura: (1) muestra el objetivo (`🎯 NECESITÁS SACAR: X o más`) y el daño base (`0.55s`), (2) gira el D100 (`~0.65s`), y (3) clava el número final (`🎯 NECESITABAS: X+ | 🎲 SALIÓ: Y` + `⚔️ DAÑO TOTAL APLICADO`) sincronizando la bajada de HP (`on_landed.call()`) y permaneciendo en pantalla `3.20s` en `💥 ¡CRÍTICO (x1.5)!` o `2.70s` en `⚔️ GOLPE NORMAL (x1.0)`. Hacer **clic izquierdo sobre el panel en cualquier etapa** interrumpe los timers (`_wait_or_skip`), aplica `on_landed` y cierra el dado en el acto.

---

### 5.2 Sistema de Curva de Nivel y Progresión de Atributos (`LevelProgression`)

1. **Curva Polinómica de XP Requerida para pasar de Nivel $L$ a $L+1$:**
   $$\text{XP Requerida}(L) = \lfloor 55 \cdot L^{1.45} + 20 \cdot L \rfloor$$
   - Nivel $1 \to 2$: `75 XP` | Nivel $2 \to 3$: `190 XP` (acum. `265`) | Nivel $3 \to 4$: `330 XP` (acum. `595`) | Nivel $4 \to 5$: `490 XP` (acum. `1085`).

2. **Recompensa de XP por Encuentro según Piso ($P \ge 1$):**
   - **Combate Común (`COMBAT`):** $\text{XP}_{\text{Común}}(P) = \lfloor 60 \cdot (1 + 0.35 \cdot P) \rfloor$ (`81 XP` en P1, `102 XP` en P2, `123 XP` en P3).
   - **Combate Élite (`ELITE`):** $\text{XP}_{\text{Élite}}(P) = \lfloor \text{XP}_{\text{Común}}(P) \cdot 2.5 \rfloor$ (`202 XP` en P1, `255 XP` en P2, `307 XP` en P3).
   - **Jefe de Piso (`BOSS`):** $\text{XP}_{\text{Jefe}}(P) = \lfloor \text{XP}_{\text{Común}}(P) \cdot 5.0 \rfloor$ (`405 XP` en P1, `510 XP` en P2, `615 XP` en P3).

3. **Beneficios Automáticos por Nivel (`L >= 1`):**
   - **Vida Máxima + Sustain (al subir de nivel):** $+5\text{ Max HP}$ permanentes y curación inmediata de $\max(1, \lfloor \text{Nuevo Max HP} \cdot 0.15 \rfloor)$.
   - **Probabilidad de Crítico Asintótica (Activa desde Nivel 1, Techo del $50\%$):**
	 $$\text{RatingCrit}(L) = \max(1, L) \cdot 10$$
	 $$\text{CritChance}(L) = \left(\frac{\text{RatingCrit}}{\text{RatingCrit} + 120.0}\right) \cdot 0.50$$
	 *(Ej.: Nivel 1 = `3.8%` [Umbral D100: `97+`], Nivel 2 = `7.1%` [Umbral: `94+`], Nivel 5 = `14.7%` [Umbral: `86+`], Nivel 15 = `27.8%`, asíntota en `50.0%`).*
   - **Daño Global Porcentual:** $+(L - 1) \cdot 2\%$ multiplicativo al daño saliente del combo.

---

### 5.3 Fórmulas de Estados Alterados (`Enemy`)

- **Quemadura (`burn`):** Al final del turno del jugador inflige `burn` de daño directo y decae a la mitad: $\text{burn} = \lfloor \text{burn} \cdot 0.5 \rfloor$.
- **Veneno (`poison`):** Al final del turno del jugador inflige `poison` de daño directo y decae en 1: $\text{poison} = \max(0, \text{poison} - 1)$.
- **Congelamiento (`freeze`):**
  - Reduce el daño de ataque del enemigo en `freeze` puntos: $\text{Daño Efectivo} = \max(0, \text{Daño Intención} - \text{freeze})$.
  - Si al inicio del turno enemigo $\text{freeze} \ge 5$ (`FREEZE_STUN_THRESHOLD`), el enemigo **pierde su turno** y `freeze` pasa a `0`. Si era $< 5$, decae en $1$ al terminar su turno.
- **Electrocutado (`shock`):**
  - Al inicio del turno enemigo, probabilidad de **Parálisis**:
	$$P(\text{Stun}) = \text{clamp}(0.12 \cdot \text{shock} + 0.03 \cdot \text{player\_luck},\; 0.05,\; 0.80)$$
  - Si acierta (usando `run.combat_rng.randf()`), el enemigo pierde el turno y `shock` pasa a `0`. Si falla, reduce `1` carga.
- **Hemorragia (`hemorrhage`):**
  - Umbral dinámico de estallido: empieza en `10` (`HEMORRHAGE_BURST_THRESHOLD`) y aumenta en `+5` (`HEMORRHAGE_THRESHOLD_SCALING`) cada vez que estalla en ese combate.
  - **Si $\text{hemorrhage} \ge \text{umbral}$:** Detona un **Estallido de Sangre** que inflige entre el **10% y el 25% del HP actual del enemigo** (interpolado por `player_luck` entre `0` y `12`), resetea `hemorrhage = 0` e incrementa el umbral en `+5`.
  - **Si $\text{hemorrhage} < \text{umbral}$:** Inflige daño igual a `hemorrhage` y decae en `4` cargas ($\max(0, \text{hemorrhage} - 4)$).

---

### 5.4 Escalado de Enemigos por Piso (`Enemy._init`)

Sea $F = \text{floor\_number} - 1$:
- **Enemigo Común (`COMBAT`):**
  $$\text{Max HP} = \text{base\_hp} + 25 \cdot F, \qquad \text{Damage} = \text{base\_damage} + 3 \cdot F$$
- **Enemigo Élite (`ELITE`, `is_elite = true`):**
  $$\text{Max HP} = \text{roundi}((\text{base\_hp} + 25 \cdot F) \cdot 1.45), \qquad \text{Damage} = (\text{base\_damage} + 3 \cdot F) + 2 + \text{floor\_number}$$
- **Jefe de Piso (`BOSS`, `is_boss = true`):**
  $$\text{Max HP} = \text{base\_hp} + 45 \cdot F, \qquad \text{Damage} = \text{base\_damage} + 4 \cdot F$$

---

### 5.5 Sistema de Rarezas, Fortuna y Suerte (`RaritySystem`)

$$\text{Fortuna} = \max\left(0.0,\; (\text{floor\_number} - 1) \cdot 1.5 + \text{player\_luck} \cdot 2.5 + \text{bonus\_fortune}\right)$$

Pesos dinámicos por Tier (`get_tier_weights`):
- `COMMON (0)`: $\max(10.0,\; 52.0 - 3.8 \cdot \text{Fortuna})$
- `UNCOMMON (1)`: $28.0 + 1.0 \cdot \text{Fortuna}$
- `RARE (2)`: $15.0 + 1.8 \cdot \text{Fortuna}$
- `EPIC (3)`: $4.5 + 1.2 \cdot \text{Fortuna}$
- `LEGENDARY (4)`: $\max(0.5,\; 0.5 + 0.8 \cdot \text{Fortuna})$

**Interpolación Suavizada por Suerte (`get_scaled_value_smooth(base_val, max_val, luck, max_luck_threshold = 12)`):**
- Calcula $t = \text{clamp}(\text{luck} / 12.0, 0.0, 1.0)$ con jitter determinista $\pm 15\%$ y retorna `roundi(lerp(base_val, max_val, final_t))`.

---

### 5.6 Generador Procedural de Pisos 8x8 (`FloorGenerator`)

- **Cantidad de salas por piso (`get_target_rooms_for_floor`):** Empieza en `BASE_START_ROOMS = 8` en Piso 1 y suma incrementos crecientes (`+2, +3, +4, +5, +6...`) hasta un tope de `MAX_ROOMS_CAP = 28` salas.
- **Topología:** Parte del centro `(3..4, 3..4)` y expande ortogonalmente rechazando celdas con $\ge 2$ vecinos ya ocupados (evita bloques 2x2 y garantiza pasillos serpenteantes).
- **Asignación en Callejones sin Salida (`dead_ends` ordenados de mayor a menor distancia Manhattan al `START`):**
  1. Más lejano → `BOSS`
  2. 2.º más lejano → `TREASURE`
  3. 3.º más lejano → `REST` (Hoguera: cura `25..50` HP según Suerte)
  4. 4.º más lejano (o fallback a distancia $>1$) → `SHOP` (1 garantizada por piso)
  5. Piso $\ge 3$ → `REST` extra; Piso $\ge 4$ → probabilidad de `SANCTUARY` o `TREASURE` extra.
- **Salas `ELITE` (`ÉLITE ⚔️`):** Convierte `1` sala `COMBAT` (o `2` en pisos $\ge 2$ con suficientes salas) ubicada a distancia Manhattan $\ge 2$ del inicio en `RoomData.Type.ELITE`.

---

## 6. Catálogos Actuales en Producción (`.tres` y Clases)

### 6.1 Héroes (`entities/hero/data/`) y Habilidades (`entities/hero/abilities/`)
| Héroe | HP | Energía | Descartes | STR/INT/DEX | Suerte | Arma Inicial | Habilidad Activa (`1 uso/combate`) |
|---|---|---|---|---|---|---|---|
| **Guerrero** (`warrior_hero.tres`) | 50 | 4 | 2 | 1 / 1 / 1 | 1 | `espadon.tres` | `WarCryAbility` (+3 STR por 2 turnos) |
| **Mago** (`magic_hero.tres`) | 45 | 5 | 3 | 3 / 6 / 2 | 1 | `baculo.tres` | `ArcaneFlowAbility` (Roba 3 cartas gratis) |
| **Samurai** (`samurai_hero.tres`) | 60 | 3 | 2 | 5 / 1 / 1 | 4 | `katana_basica.tres` | `BloodySlashAbility` (7 daño + 10 Hemorragia) |
| **Asesino** (`assasin_hero.tres`) | 50 | 3 | 4 | 4 / 2 / 4 | 1 | `dagger.tres` | `BloodySlashAbility` (7 daño + 10 Hemorragia) |
| **DEMO** (`demo_hero.tres`) | 200 | 8 | 4 | 1 / 5 / 1 | 1 | `baculo.tres` | Ninguna *(incluye `DemonThrustAbility`: `20 + luck*0.5` dmg en código)* |

### 6.2 Armas (`weapons/data/`)
| Archivo | Nombre | Clase (`WeaponData.Class`) | Daño Base | Requisitos (`STR/INT/DEX`) | Escalado (`STR/INT/DEX`) | On-Hit |
|---|---|---|---|---|---|---|
| `arma_basica.tres` | Palito | `ANY (0)` | 3 | 0 / 0 / 0 | 0 / 0 / 0 | — |
| `baculo.tres` | Báculo Básico | `STAFF (3)` | 3 | 3 / 0 / 0 | 0 / 1.0 / 0 | — |
| `dagger.tres` | Daga | `DAGGER (4)` | 2 | 1 / 0 / 3 | 0 / 0 / 0.4 | +2 Hemorragia |
| `espadon.tres` | Espadón | `HEAVY (2)` | 5 | 0 / 0 / 0 | 0 / 0 / 0 | +2 Hemorragia |
| `katana_basica.tres` | Katana Básica | `KATANA (5)` | 5 | 4 / 0 / 0 | 0 / 0 / 0 | — |

*(Nota: También existe `WeaponData.Class.SWORD (1)` para espadas de una mano).*

### 6.3 Efectos de Cartas (`cards/effects/`) — Polimorfismo OCP
Todos heredan de `CardEffect`:
- `DamageEffect(amount)` | `DefenseEffect(amount)` | `HealEffect(amount)` | `MultiplyEffect(multiplier)`
- `BurnEffect(amount)` | `PoisonEffect(amount)` | `FreezeEffect(amount)` | `ShockEffect(amount)` | `HemorrhageEffect(amount)`
- `ApplyStatusEffect(status_type, amount)` *(soporta `StatusType.RANDOM` usando `run.combat_rng`)*
- `StealEffect(cards_to_draw)` *(tiene `is_instant() -> true`: se consume al clickear sin entrar al combo)*

### 6.4 Efectos de Reliquias (`relics/effects/`)
Todos heredan de `RelicEffect`:
- `RelicStatBonusEffect`: Modifica stats permanentes en `on_equipped(run)` (`max_energy`, `target_hand_size`, `player_luck`, etc.).
- `RelicStartStatusEffect`: Aplica estados iniciales al enemigo en `on_combat_start(run, enemy)`.
- `RelicComboSynergyEffect`: Bonifica `combo_state` en `on_combo_evaluated(combo_state, card_count, run)` (ej. `card_count >= 3` → `+6 dmg`, `+5 block`).
- `RelicReviveEffect`: En `on_player_lethal_damage(run)` revive al jugador con `50% Max HP` y consume la reliquia (`return true`).

---

## 7. Flujo de Interacción, Vistas y Manejo de `ESC` (`RunDirector`)

1. **Jerarquía de `KEY_ESCAPE` (`RunDirector.handle_unhandled_key`):**
   - Cuando el jugador presiona `ESC`, `BattleTable._unhandled_key_input` delega en `RunDirector.handle_unhandled_key()`:
	 1. Si `PauseMenuView` ya está abierto → lo cierra y despausa.
	 2. Si en `MapView` están abiertos `InventoryModalView`, `InspectorModalView` o `SanctuaryModalView` → cierra primero ese modal hijo y **NO abre pausa**.
	 3. Si en `BattleTable` están abiertos `BattleHUD.inventory_modal` o `BattleHUD.pile_inspector` → cierra primero ese modal y **NO abre pausa**.
	 4. Recién si no hay ningún modal superpuesto abierto y el estado es `MAP`, `BATTLE` o `SHOP`, abre `PauseMenuView`.
2. **Matriz de Estados (`RunStateMachine.State`):**
   - Estados: `MENU`, `MAP`, `BATTLE`, `REWARD`, `EVENT`, `SHOP`, `DEAD`, `VICTORY`.
   - `MapView.setup_floor(run: RunState, owned_cards: Array[CardData])` recibe directamente la referencia a `RunState` y el arreglo de cartas del `DeckManager`.

---

## 8. Recetas Rápidas para Ampliar o Modificar el Proyecto

### A. Cómo crear un nuevo Efecto de Carta (`CardEffect`)
1. Crear `cards/effects/mi_nuevo_effect.gd` heredando de `CardEffect` con `class_name MiNuevoEffect`.
2. Sobrescribir:
   - `apply_to_combo(combo_state: Dictionary, _card_damage: int, _used_weapon: bool) -> void`
   - `get_description() -> String`
   - Si aplica un estado alterado al enemigo: sobrescribir `is_status_effect() -> bool: return true` y `get_status_icon() -> String`.
   - Si daña o debuffea al enemigo: sobrescribir `is_offensive() -> bool: return true`.
   - Opcional: `get_emblem_icon() -> String` para el arte procedural de `CardUI`.
3. **No necesitas tocar `CardData` ni `CombatResolver._is_status_effect()`** gracias al contrato polimórfico OCP.

### B. Cómo agregar un nuevo Atributo o Propiedad a `RunState`
1. Declarar la variable tipada en `core/run/run_state.gd` y su valor inicial en `reset_to_defaults()` / `start_new_run()`.
2. Si proviene de una fórmula o subsistema (como niveles o botín), agregar la lógica pura en `LevelProgression` o `LootGenerator` y exponer un método fachada en `RunState`.
3. Agregar su serialización en `core/run/run_serializer.gd` (`to_dict()` y `from_dict()` con `.get("prop", default_val)` para no romper guardados viejos).
4. Si debe mostrarse en UI, agregarla en `InventoryModalView._build_stats_block()`, `MapView` y/o `PlayerHUD`.

### C. Cómo agregar un nuevo Tipo de Sala al Mapa (`RoomData.Type`)
1. Añadir el valor al `enum Type` en `core/map/room_data.gd` y definir su nombre y color en `get_display_name()` y `get_room_color()`.
2. Asignar su generación en `core/map/floor_generator.gd` (`_assign_special_rooms`).
3. Manejar la entrada a la sala en `core/run/run_director.gd` (`_on_map_room_selected(room: RoomData)`).
4. Si requiere leyenda en el mapa, añadirlo en `scenes/map/map_view.gd` (`_create_legend_panel()`).
