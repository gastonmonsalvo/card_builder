# 🃏 Card Prototype — Roguelike Deckbuilder (Godot 4)

Prototipo de juego **2D Roguelike Deckbuilder** desarrollado en **Godot Engine 4.x (GDScript)**. El proyecto implementa una arquitectura desacoplada basada en recursos personalizados (`Resource`), un bus de eventos global (`SignalBus`), resolución de combate por **cadena de combos** y **reacciones elementales** (`CombatResolver` + `StatusReactions`), estadísticas RPG (`STR`, `INT`, `DEX`, `LUCK`) con requisitos y escalado de armas (`WeaponData`), habilidades activas por héroe (`HeroAbility`), generación procedural de mapas ortogonales 8x8 por semillas (`FloorGenerator`), sistema de rarezas ponderadas de 5 Tiers (`RaritySystem`), sinergias de reliquias y persistencia atómica en múltiples ranuras de guardado (`PersistenceManager`).

> **Convención de estado en la documentación:**
> - Todo componente o mecánica sin etiqueta está **100% implementado y operativo en código**.
> - Todo elemento marcado con **`🚧 [FUTURO / PENDIENTE]`** indica arquitectura planificada, carpetas vacías o mecánicas aún no conectadas en runtime.

---

## 📑 Tabla de contenidos

1. [Requisitos y ejecución](#-requisitos-y-ejecución)
2. [Cómo correr los tests](#-cómo-correr-los-tests)
3. [Arquitectura general y principios de diseño](#-arquitectura-general-y-principios-de-diseño)
4. [Estructura de directorios](#-estructura-de-directorios)
5. [Flujo de ejecución](#-flujo-de-ejecución-execution-flow)
6. [Relación entre componentes principales](#-relación-entre-componentes-principales)
7. [Guía de edición y extensibilidad](#-guía-de-edición-y-extensibilidad)
8. [Herramientas de desarrollo y debugging](#-herramientas-de-desarrollo-y-debugging)
9. [Reglas de oro](#-reglas-de-oro)
10. [Convenciones](#-convenciones)
11. [Git](#-git)
12. [Documentación adicional](#-documentación-adicional)
13. [Roadmap](#-roadmap)

---

## 🚀 Requisitos y ejecución

### Requisitos

- **Godot Engine 4.3+** (configurado actualmente en `project.godot` con features **4.7**, renderer `mobile` sobre `d3d12`).
- **GUT (Godot Unit Test)** incluido en `addons/gut/`.
- Opcional: **GDScript LSP** para tu editor (VSCode, Neovim).

### Setup

```bash
# 1. Clonar
git clone <repo-url> card-prototype
cd card-prototype

# 2. Abrir el proyecto en Godot
# Godot Launcher → Import → seleccionar project.godot

# 3. GUT ya viene commiteado en addons/gut/, no hace falta instalar nada.
```

### Cómo correr el juego

```bash
# Desde Godot Editor
F5  → corre la escena principal (res://scenes/battle/battle_table.tscn)
F6  → corre la escena actual

# Desde CLI
godot --path .                          # abre el editor
godot --path . --main-scene res://scenes/battle/battle_table.tscn
```

> **Nota de arquitectura de arranque:** `battle_table.tscn` actúa como contenedor raíz del `SceneTree`. Al inicializarse, instancia `RunDirector`, el cual monta proceduralmente por código (`SlotSelectView`, `MainMenuView`, `HeroSelectView`, `MapView`, `ShopView`, `PauseMenuView`) como capas superpuestas por `z_index`.

---

## 🧪 Cómo correr los tests

```bash
# CLI (para CI / pre-commit) — 🚧 [FUTURO / PENDIENTE: crear run_tests.cfg y suites en test/]
godot --path . -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit

# Desde el editor
# Panel inferior → GUT → Run All
```

- **Estado actual de `test/`:** La estructura de directorios (`test/combat/`, `test/deck/`, `test/run/`) está creada con `.gitkeep`.
- **Tests prioritarios a implementar (`🚧 [FUTURO / PENDIENTE]`):** `combat_resolver`, `status_reactions`, `temp_stat_manager`, `deck_manager`, `run_state_machine`, `rarity_system`, `floor_generator`.

---

## 📐 Arquitectura general y principios de diseño

El proyecto está diseñado bajo tres pilares técnicos para evitar el acoplamiento rígido entre la interfaz (UI) y la lógica de negocio:

### 1. Diseño Orientado a Datos (Data-Driven Design con `Resource`)

Toda entidad estática o configurable (Cartas, Efectos de Cartas, Héroes, Habilidades de Héroe, Enemigos, Behaviors de IA, Reliquias, Efectos de Reliquias y Armas) hereda de `Resource`. La lógica de ejecución se inyecta mediante composición de recursos (patrón *Strategy*), permitiendo crear nuevas cartas, enemigos o reliquias desde el Inspector de Godot combinando scripts sin modificar el motor de combate.

**Protección de Recursos en Runtime (Clonación + Sellado vs Instance Wrapper):**
- Actualmente, para evitar el bug clásico de mutar el `.tres` en disco, `DeckManager` y `RunState` clonan cada recurso al instanciarlo (`card_res.duplicate()`) y sellan su ruta original en `resource_name = card_res.resource_path` para que `PersistenceManager` pueda serializarlo sin perder la referencia.
- La migración completa a wrappers `CardInstance` (`cards/card_instance.gd`, hoy stub) y `RelicInstance` está marcada como **`🚧 [FUTURO / PENDIENTE]`** (ver [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md#decisión-data-vs-instance)).

### 2. Arquitectura Dirigida por Eventos (`SignalBus`) y Orquestador (`RunDirector`)

Los componentes de UI y los controladores de lógica se comunican mediante señales locales hacia su mediador (`RunDirector` o `BattleTable`) y a través de un *Autoload* centralizado (`SignalBus`) para eventos transversales (`card_played`, `relic_acquired`, `room_entered`, `floor_started`), evitando referencias cruzadas frágiles (`get_node("../../..")`).

### 3. Estado Centralizado de Partida (`RunState`, `RunDirector` & `RunStateMachine`)

El estado mutable de una *run* (HP actual/máximo, estadísticas RPG `STR`/`INT`/`DEX`/`LUCK`, modificadores temporales `TempStatManager`, oro, piso, semilla maestra, `combat_rng`, reliquias activas, arma equipada, mochila de armas `inventory_weapons`, habilidad activa `current_ability` y grafo del mapa) vive en `RunState`.

`RunDirector` orquesta las transiciones entre vistas validándolas contra la máquina de estados finita `RunStateMachine` (`MENU`, `MAP`, `BATTLE`, `REWARD`, `EVENT`, `SHOP`, `DEAD`, `VICTORY`) y gestiona el guardado atómico mediante `PersistenceManager`.

---

## 📂 Estructura de directorios

```text
card-prototype/
├── README.md
├── CONTEXT.md                              # Base de conocimiento maestra condensada para IAs y devs
├── .gitignore
├── project.godot
│
├── docs/                                   # Documentación viva del proyecto
│   ├── CONTEXT.md                          # Espejo de CONTEXT.md en docs/
│   ├── GDD.md                              # Game Design Document
│   └── ARCHITECTURE.md                     # Detalle técnico archivo por archivo y patrones de diseño
│
├── autoload/                               # Singletons globales (Autoloads)
│   ├── game_database.gd                    # Escaneo y carga de catálogos (.tres) por directorio
│   ├── persistence_manager.gd              # Guardado/Carga atómica en JSON (3 slots + perfil + last_slot.cfg)
│   └── signal_bus.gd                       # Bus de señales globales desacopladas
│
├── core/                                   # LÓGICA PURA (RefCounted, sin .tscn, sin nodos visuales)
│   ├── combat/                             # Resolución matemática del combate
│   │   ├── combat_resolver.gd              # Motor estático stateless de combos, daño, armas y turnos
│   │   ├── status_reactions.gd             # Reacciones elementales (Vaporización, Superconductor, Combustión)
│   │   └── temp_stat_manager.gd            # Buffs/debuffs temporales de STR/INT/DEX por turnos
│   ├── deck/                               # Gestión de pilas de cartas
│   │   ├── card_pile.gd                    # Pila genérica (Mazo, Descarte, Cementerio)
│   │   └── deck_manager.gd                 # Ciclo de vida del mazo, ruteo single_use y serialización
│   ├── enemies/                            # Modelo runtime de enemigo e IA
│   │   ├── enemy.gd                        # Estado vivo del enemigo, escalado por piso y ticks de statuses
│   │   ├── enemy_ai.gd                     # Orquestador estático de intenciones enemigas
│   │   └── behaviors/                      # Estrategias componibles (Resource)
│   │       ├── enemy_behavior.gd           # Clase base abstracta
│   │       ├── enemy_context.gd            # Contexto (enemy, run, turn_count)
│   │       ├── enemy_intent.gd             # Datos de intención (ATTACK, DEFEND, CHARGE, APPLY_STATUS, NOTHING)
│   │       ├── attack_behavior.gd          # Ataque periódico
│   │       ├── defend_behavior.gd          # Escudo periódico
│   │       └── charge_behavior.gd          # Turno de carga + golpe multiplicado
│   ├── run/                                # Estado de run, servicios de dominio (SRP), FSM y director
│   │   ├── run_director.gd                 # Mediador entre vistas UI, RunState y PersistenceManager
│   │   ├── run_state.gd                    # Fachada y contenedor de estado vivo de la run + RNG determinista
│   │   ├── level_progression.gd            # Servicio estático SRP: curva XP, niveles, crítico asintótico y daño %
│   │   ├── loot_generator.gd               # Servicio estático SRP: sorteo determinista de recompensas y tienda
│   │   ├── run_serializer.gd               # Servicio estático SRP: serialización to_dict / from_dict
│   │   ├── run_state_machine.gd            # FSM explícita de estados de partida
│   │   └── rarity_system.gd                # Sorteo ponderado de 5 Tiers escalado por piso y suerte
│   ├── map/                                # Generación procedural de plantas
│   │   ├── floor_generator.gd              # Grafo ortogonal 8x8 (Spanning Tree + Dead Ends + Élites + Niebla)
│   │   └── room_data.gd                    # Datos de celda (START, COMBAT, ELITE, TREASURE, REST, SANCTUARY, BOSS, SHOP)
│   └── constants/
│       └── combat_constants.gd             # Umbrales de estados, stats base y rutas de catálogos
│
├── systems/                                # 🚧 [FUTURO / PENDIENTE] Subsistemas transversales independientes
│   ├── statuses/                           # 🚧 [FUTURO / PENDIENTE] Migración de statuses hardcodeados a StatusData
│   ├── modifiers/                          # 🚧 [FUTURO / PENDIENTE] Modificadores permanentes/condicionales
│   └── events/                             # 🚧 [FUTURO / PENDIENTE] Eventos narrativos genéricos (EventData)
│
├── entities/                               # Definición de actores (Resources + Habilidades)
│   ├── hero/
│   │   ├── hero_data.gd                    # Plantilla de héroe (stats base, RPG stats, arma, mazo, habilidad)
│   │   ├── abilities/                      # Habilidades activables por combate (HeroAbility)
│   │   │   ├── hero_ability.gd             # Clase base
│   │   │   ├── war_cry_ability.gd          # Grito de Guerra (+STR temporal)
│   │   │   ├── arcane_flow_ability.gd      # Flujo Arcano (roba 3 cartas gratis)
│   │   │   ├── demon_thrust_ability.gd     # Estocada Demoníaca (daño directo escalado con suerte)
│   │   │   └── bloody_slash_ability.gd     # Corte Sangrante / BloodySlashAbility (daño + hemorragia)
│   │   └── data/                           # warrior_hero, magic_hero, samurai_hero, assasin_hero, demo_hero (.tres)
│   └── enemies/
│       ├── enemy_data.gd                   # Plantilla de enemigo (HP, daño, is_boss, intent_pattern)
│       └── data/                           # esqueleto.tres, jefe_basico.tres
│
├── cards/                                  # Datos y efectos modulares de cartas
│   ├── card_data.gd                        # Resource de carta (cost, rarity, single_use, required_weapon_class, effects)
│   ├── card_instance.gd                    # 🚧 [FUTURO / PENDIENTE] Stub actual; runtime usa CardData.duplicate()
│   ├── data/                               # 12 cartas .tres (tajo, estocada, escudo_basico, lanza_rayo, etc.)
│   └── effects/                            # 12 scripts de efectos (CardEffect + subclases)
│
├── relics/                                 # Sistema de Reliquias
│   ├── relic_data.gd                       # Resource base con hooks (on_equipped, on_combat_start, on_combo, on_lethal)
│   ├── relic_instance.gd                   # 🚧 [FUTURO / PENDIENTE] Estado runtime por reliquia
│   ├── data/                               # 8 reliquias .tres (anillo_brasas, cenizas_fenix, pata_conejo, etc.)
│   └── effects/                            # 5 scripts (RelicEffect, StatBonus, StartStatus, ComboSynergy, Revive)
│
├── weapons/                                # Armas equipables y escalado RPG
│   ├── weapon_data.gd                      # Clases de arma, requisitos STR/INT/DEX, escalado y estados on-hit
│   └── data/                               # 5 armas .tres (arma_basica, baculo, dagger, espadon, katana_basica)
│
├── scenes/                                 # Escenas y vistas de pantalla completa
│   ├── battle/
│   │   ├── battle_table.tscn               # Escena principal del proyecto
│   │   ├── battle_table.gd                 # Fachada de combate y orquestador de turnos/animaciones
│   │   └── card_board_controller.gd        # Layout espacial de Mano y Zona de Combo (drag & drop)
│   ├── map/
│   │   └── map_view.gd                     # Vista de matriz 8x8 construida 100% en código
│   ├── event/                              # 🚧 [FUTURO / PENDIENTE] event_view.gd para eventos narrativos
│   ├── reward/
│   │   └── reward_view.gd                  # Vista post-combate en código con animaciones estilo Balatro
│   ├── shop/
│   │   └── shop_view.gd                    # Tienda del Bazar construida en código
│   └── menus/
│       ├── main_menu_view.gd               # Menú principal con resumen del perfil activo ya cargado
│       ├── slot_select_view.gd             # Selector/creador de 3 perfiles de guardado en código
│       └── hero_select_view.gd             # Pantalla dedicada de selección de héroe, ficha técnica e input de semilla
│
├── ui/                                     # Componentes UI atómicos y modales reutilizables
│   ├── cards/
│   │   ├── card_ui.tscn                    # Escena visual de carta individual
│   │   └── card_ui.gd                      # Física de resorte (hover/drag) y animación de quemado/disolución
│   ├── battle/
│   │   ├── hud_battle.gd                   # BattleHUD (fachada orquestadora de paneles de combate)
│   │   ├── crit_dice_widget.gd             # CritDiceWidget (Dado D100 animado en 3 etapas con clic para saltar)
│   │   ├── player_hud.gd                   # Panel de stats del héroe, nivel, XP y arma activa
│   │   ├── enemy_hud.gd                    # Panel de HP, bloqueo, intent y estados del enemigo
│   │   ├── combo_banner.gd                 # Previsualización matemática en vivo del combo activo + % Crit
│   │   └── pile_inspector.gd               # Popup para inspeccionar Mazo, Descarte y Cementerio
│   ├── inventory/
│   │   └── inventory_modal_view.gd         # Modal de atributos RPG (STR/INT/DEX/LUCK) y mochila de armas
│   ├── map/
│   │   ├── map_node_view.gd                # Botón de celda individual de la grilla 8x8
│   │   ├── sanctuary_modal_view.gd         # Modal interactivo del Santuario Ancestral
│   │   └── inspector_modal_view.gd         # Modal con scroll para inspeccionar mazo y reliquias
│   ├── menus/
│   │   └── hero_card_view.gd               # Tarjeta BBCode de héroe para HeroSelectView
│   └── system/
│       ├── pause_menu_view.gd              # Menú de pausa con confirmación de abandono y guardado al salir
│       └── debug_overlay.gd                # Panel QA/Debug (F3/F4): God Mode, stats, armas, reliquias, pisos
│
├── assets/                                 # Recursos binarios (actualmente directorios con .gitkeep)
│   ├── audio/                              # music/, sfx/, ui/
│   ├── fonts/
│   └── textures/                           # cards/, heroes/, map/, relics/, ui/
│
├── addons/
│   └── gut/                                # Godot Unit Test (commiteado)
│
└── test/                                   # 🚧 [FUTURO / PENDIENTE] Suites de tests unitarios con GUT
	├── combat/
	├── deck/
	└── run/
```

---

## 🔄 Flujo de ejecución (Execution Flow)

### 1. Inicialización, Perfiles y Menú Principal (`scenes/menus/` & `autoload/`)

1. Al iniciar el ejecutable, Godot carga los Autoloads (`SignalBus`, `PersistenceManager`, `GameDatabase`) e instancia la escena principal `res://scenes/battle/battle_table.tscn`.
2. `BattleTable._ready()` inicializa `RunState`, `DeckManager`, `CardBoardController` y crea el `RunDirector`.
3. **`RunDirector._init()`** verifica en `PersistenceManager` si existe un `last_slot.cfg` válido:
   - **Auto-login:** Si el último slot jugado tiene una partida activa (`run.json`), la deserializa en `RunState` y `DeckManager`, y reanuda directamente en la sala correspondiente (Mapa, Combate o Tienda). Si no tiene partida activa, abre `MainMenuView` con el perfil cargado.
   - **Selección de Perfil (`SlotSelectView`):** Si no hay slot previo, muestra las **3 ranuras de guardado**. El jugador puede crear un perfil nuevo (ingresando su nombre), continuar/seleccionar uno existente o borrarlo.
4. En **`MainMenuView`** (con el perfil ya cargado), el jugador visualiza su récord (Mejor Piso y Victorias) y puede cambiar de ranura o pulsar **"NUEVA EXPEDICIÓN"**, lo que abre **`HeroSelectView`**, donde inspecciona la ficha técnica de cada héroe (`HeroCardView` poblado desde `entities/hero/data/`) e inicia una partida aleatoria o con **semilla personalizada (numérica o alfanumérica)**.

### 2. Creación de la Run y Generación Procedural (`core/run/` & `core/map/`)

1. Al confirmar el inicio, **`RunDirector`** limpia residuos visuales y llama a **`RunState.start_new_run(seed, hero)`**:
   - Asigna estadísticas base del `HeroData`: `max_hp_base`, `energy_base`, `lucky`, `gold`, `discards_base`, `hand_size` y atributos RPG (`base_str`, `base_int`, `base_dex`).
   - Equipa el arma inicial (`starting_weapon` o `arma_basica.tres` como fallback), clona la habilidad activa (`hero.ability.duplicate()`) y equipa clones de las reliquias iniciales (`starting_relic`).
   - Si no se proveyó semilla, `FloorGenerator.generate_master_seed()` genera una semilla de alta entropía combinando reloj del sistema y ticks de CPU.
2. **`FloorGenerator.generate_floor()`** construye una **matriz ortogonal de 8x8**:
   - Coloca la sala `START` en el centro y expande la frontera evitando bloques 2x2 para formar pasillos serpenteantes (escalando de 7 salas en Planta 1 hasta un tope de 28 salas en Planta 7+).
   - Detecta los **callejones sin salida (`dead_ends`)**, los ordena por distancia Manhattan al centro y asigna determinísticamente: el más lejano como `BOSS`, seguido de `TREASURE`, `REST`, `SHOP` (garantizando 1 tienda por piso) y, según piso y suerte, salas extra de `REST`, `SANCTUARY` o `TREASURE`.
   - Revela únicamente las salas vecinas al `START` (niebla de guerra).
3. `DeckManager.build_initial_deck_for_hero()` clona y sella las cartas del `starting_deck` y las baraja en `draw_pile`.
4. `RunStateMachine` transiciona a `MAP`, `PersistenceManager` guarda atómicamente `run.json` y se despliega **`MapView`**.

### 3. Navegación en el Mapa (`scenes/map/` & `ui/map/`)

- En **`MapView`**, el jugador ve la grilla 8x8 con las conexiones dibujadas proceduralmente (`_draw()`). Desde la barra superior puede abrir:
  - **`InventoryModalView`**: Muestra sus stats (`STR`, `INT`, `DEX`, `LUCK`), el arma equipada y la **Mochila (`inventory_weapons`)**, permitiendo cambiar de arma activa en cualquier momento (lo que dispara autoguardado).
  - **`InspectorModalView`**: Permite leer el detalle completo de sus Reliquias activas o la composición exacta de su Mazo.
  - **Copiar Seed**: Copia la `master_seed` al portapapeles.
- Al hacer clic en un `MapNodeView` adyacente a una sala despejada (o cualquier sala si `god_mode` / `free_travel_enabled` está activo), `RunDirector._on_map_room_selected()` evalúa el `RoomData.Type`:
  - **`TREASURE`:** Otorga inmediatamente una reliquia ponderada por `RaritySystem`, despeja la sala y descubre sus vecinas.
  - **`REST` (Hoguera):** Cura entre 25 y 50 HP (interpolado suavemente según `player_luck`), despeja la sala y actualiza el mapa.
  - **`SANCTUARY` (`SanctuaryModalView`):** Presenta dos bendiciones: *Don del Artefacto* (+1 reliquia con bonus de fortuna por piso y curación de 25% a 50% del HP máx) o *Vitalidad Inmortal* (+5 a +25 HP máximo permanente según suerte y curación equivalente).
  - **`SHOP` (`ShopView`):** Transiciona la FSM a `SHOP`. Genera por única vez 3 cartas y 2 reliquias con `_get_shop_rng(room_pos)` (persistidas en `RoomData` para no regenerarse al salir y volver a entrar).
  - **`COMBAT` / `BOSS`:** Transiciona la FSM a `BATTLE` e invoca `BattleTable.start_combat_encounter(is_boss)`.

### 4. Ciclo de Combate por Combos (`scenes/battle/battle_table.gd` & `core/combat/combat_resolver.gd`)

A diferencia de un deckbuilder tradicional donde cada carta se resuelve aisladamente al soltarla, el combate implementa un **sistema de encadenamiento en Zona de Combo con previsualización matemática en tiempo real**:

1. **Inicio del Encuentro (`start_combat_encounter`):**
   - Se limpian los modificadores temporales (`temp_stats.clear()`), se resetea el RNG determinista de combate (`reset_combat_rng()`), se restauran los usos de la `HeroAbility` y los descartes tácticos (`discards_remaining`), y se reciclan todas las pilas en `draw_pile`.
   - `RunState.create_enemy_for_room(is_boss)` instancia el `Enemy` escalando su HP y daño según `current_floor`, y dispara los hooks `trigger_on_combat_start(enemy)` de las reliquias activas.
2. **Inicio del Turno del Jugador (`_start_new_turn`):**
   - Se restaura `current_energy = run.max_energy` y se resetea `player_block = 0`.
   - El enemigo calcula y muestra su intención (`enemy.update_intent(run)` vía `EnemyAI`).
   - Se roban cartas hasta completar `target_hand_size` (5 base). Si `draw_pile` se vacía, recicla y baraja `discard_pile` (las cartas en `graveyard_pile` no se reciclan durante el combate).
3. **Fase de Armado de Combo, Cartas Instantáneas, Habilidad y Descarte Táctico:**
   - **Cartas Instantáneas (`is_instant_card() == true`, ej. `StealEffect`):** Al clickearlas o arrastrarlas a la mesa, se consumen en el acto con una animación de levitación y quemado (`play_consume_animation()`), debitan energía y ejecutan su efecto (ej. robar cartas) sin ocupar lugar en el combo.
   - **Armado del Combo:** Al clickear o arrastrar cartas no instantáneas a la `ComboZone`, se reserva su costo de energía. El jugador puede **reordenar libremente las cartas arrastrándolas horizontalmente** dentro de la `ComboZone` (crítico para posicionar multiplicadores como `MultiplyEffect` al final de la cadena) o devolverlas a la mano recuperando la energía.
   - **Previsualización en Vivo (`ComboBanner`):** Cada cambio en la `ComboZone` ejecuta `CombatResolver.calculate_sequential_preview()` (guardando y restaurando el estado de `combat_rng` para que los efectos aleatorios como `Efecto Caótico` sean 100% deterministas entre preview y ejecución). Verifica compatibilidad del arma equipada (`required_weapon_class`), requisitos de stats RPG (`req_str`, `req_int`, `req_dex` — aplicando penalización de -25% de daño por punto faltante y anulando estados si hay déficit) y escalado (`scale_str`, `scale_int`, `scale_dex`).
   - **Habilidad Activa (`AbilityButton`):** El jugador puede activar la habilidad de su héroe (ej. *Grito de Guerra*, *Flujo Arcano*, *Corte Sangrante*, *Estocada Demoníaca*) una vez por combate.
   - **Descarte Táctico (`DiscardButton`):** Permite descartar todas las cartas colocadas en la `ComboZone`, reembolsando su energía, gastando 1 ficha de descarte y robando inmediatamente la misma cantidad de cartas nuevas.
4. **Ejecución del Combo, Dado D100 de Crítico y Reacciones Elementales (`execute_combo_turn`):**
   - Al pulsar `EJECUTAR COMBO` (o `PASAR TURNO`), `BattleTable` itera secuencialmente cada carta en `combo_cards` llamando a `CombatResolver.process_card_in_combo()`, animando cada pulso (`card.pulse()`), robando cartas adicionales si corresponde y actualizando el escudo.
   - `CombatResolver.finalize_combo()` inyecta las sinergias de reliquias (`apply_relics_to_combo`, ej. *Catalizador de Combo*), aplica el multiplicador global de daño por nivel (`get_level_damage_multiplier()`) y realiza la tirada determinista del **Dado D100 de Golpe Crítico (`x1.5`)** contra la probabilidad asintótica (`get_crit_chance()`).
   - **Animación Secuencial del Dado D100 (`CritDiceWidget.play_roll`):** Si el combo inflige daño, aparece en el centro de la mesa el widget autónomo `CritDiceWidget` mostrando en 3 etapas claras: (1) el umbral requerido en el D100 y el daño base (`0.55s`), (2) el giro del D100 (`~0.65s`), y (3) el resultado comparativo (`🎯 NECESITABAS: X+ | 🎲 SALIÓ: Y` + daño final aplicado) sincronizado con la bajada de HP del enemigo (`2.70s` en Normal / `3.20s` en Crítico). Hacer **clic sobre el dado en cualquier etapa salta la animación inmediatamente**.
   - Las cartas jugadas se rutean vía `DeckManager.route_played_card()`: si tienen `single_use = true` van al **Cementerio (`graveyard_pile`)**; si no, van a **Descarte (`discard_pile`)**.
   - **Estados y Reacciones Elementales (`enemy.apply_statuses`):** Antes de acumular estados, `StatusReactions.check()` evalúa si la combinación de estados actuales + entrantes detona una reacción:
	 - **¡Vaporización!** (`burn >= 1` + `freeze >= 1`): Consume hasta 3 de cada uno e inflige **15 de daño fijo**.
	 - **¡Superconductor!** (`freeze >= 1` + `shock >= 1`): Consume todas las cargas de ambos e inflige **20 de daño fijo**.
	 - **¡Combustión Tóxica!** (`burn >= 1` + `poison >= 1`): Consume todo el veneno e inflige **10 de daño fijo**.
   - **Ticks de Fin de Turno (`CombatResolver.tick_enemy_statuses`):** Los estados no consumidos en reacciones hacen tick:
	 - `burn`: Daño igual a las cargas, luego decae a la mitad (`int(burn * 0.5)`).
	 - `poison`: Daño igual a las cargas, luego decae en 1 (`STATUS_DECAY_PER_TURN`).
	 - `hemorrhage`: Si alcanza el umbral dinámico (`10 + 5 * procs_previos`), detona un **Estallido de Sangre** que inflige entre **10% y 25% del HP actual del enemigo** (escalado por `player_luck`) y se resetea a 0; si no alcanza el umbral, hace daño igual a las cargas y decae en 4.
   - Se aplica la curación acumulada (`heal`) al jugador y se descuentan 1 turno a los modificadores temporales (`temp_stats.tick_turn()`).
5. **Turno del Enemigo (`execute_enemy_turn` & `CombatResolver.resolve_enemy_turn`):**
   - Al inicio de su turno, el enemigo resetea su propio bloqueo (`reset_block_for_new_turn()`).
   - **Control de Masas (Stuns):**
	 - Si `enemy.freeze >= 5` (`FREEZE_STUN_THRESHOLD`), el enemigo queda **congelado por completo**, pierde su turno y el hielo se rompe (`freeze = 0`).
	 - Si no está congelado pero tiene `shock > 0`, tira probabilidad de **parálisis eléctrica** (`12% por carga + 3% por punto de Suerte`, tope 80%). Si acierta, pierde el turno y descarga `shock = 0`; si falla, `shock` decae en 1.
   - Si actúa normalmente, ejecuta su `current_intent`:
	 - `ATTACK`: Su daño se reduce en `enemy.freeze` cargas (`max(0, damage - freeze)`), luego es absorbido por `player_block` y el excedente resta `player_hp` (0 si `god_mode`).
	 - `DEFEND`: Suma bloqueo (`enemy.add_block`) que persistirá durante el próximo turno del jugador.
	 - `CHARGE`: No hace daño este turno y prepara el golpe cargado para el siguiente.
   - Luego `freeze` decae en 1 y `enemy.advance_turn()` incrementa `turn_count`.
6. **Resolución del Combate (`Victory / Defeat`):**
   - **Muerte o Resurrección:** Si `player_hp <= 0`, `RunState.try_consume_revive_relic()` verifica si hay una reliquia con `RelicReviveEffect` (ej. *Cenizas de Fénix*). Si existe, restaura 50% HP y destruye la reliquia. Si no, transiciona a `DEAD`, borra `run.json` (Permadeath), registra la derrota en `profile.json` y vuelve a `MainMenuView`.
   - **Victoria y Recompensas (`RewardView`):** Si el enemigo muere, `RunDirector` transiciona la FSM a `REWARD`, genera recompensas deterministas (`RunState.generate_combat_rewards()`) e instancia `RewardView` con animaciones estilo Balatro. Tras elegir carta o saltar, aplica oro + carta + reliquia, vuelve a `MAP` y, si era el `BOSS`, avanza a `current_floor + 1` regenerando el mapa con nueva sub-semilla.

---

## 🧩 Relación entre componentes principales

| Componente | Responsabilidad Principal | Se comunica con... |
| :--- | :--- | :--- |
| **`SignalBus`** *(Autoload)* | Canal global de notificaciones (`card_played`, `relic_acquired`, `room_entered`, `floor_started`). | `RunDirector`, `RunState`, `BattleTable`. |
| **`GameDatabase`** *(Autoload)* | Escanea directorios con `ResourceLoader.list_directory` e instancia los catálogos de `.tres` (héroes, cartas, reliquias, enemigos, armas). | `RunState`, `RunDirector`, `CombatConstants`. |
| **`PersistenceManager`** *(Autoload)* | Escritura atómica (`.tmp` + rename) de `profile.json`, `run.json` y `last_slot.cfg` para 3 ranuras de guardado. | `RunDirector`, `SlotSelectView`, `MainMenuView`, `RunState`, `DeckManager`. |
| **`RunDirector` & `RunState`** | `RunState` mantiene los datos vivos de la partida y sorteos RNG deterministas; `RunDirector` media entre todas las vistas y el estado. | `RunStateMachine`, `FloorGenerator`, `BattleTable`, `MapView`, `ShopView`, `RewardView`, `SlotSelectView`, `MainMenuView`, `PauseMenuView`. |
| **`RunStateMachine`** | FSM explícita: `MENU → MAP → BATTLE → REWARD → EVENT → SHOP → DEAD → VICTORY`. Valida transiciones legales. | `RunDirector`. |
| **`CombatResolver`** | Motor estático stateless. Calcula previews secuenciales, penalizaciones/escalados de armas RPG, ejecución de combos y turnos enemigos. | `BattleTable`, `Enemy`, `CardData`, `CardEffect`, `WeaponData`, `RunState`. |
| **`StatusReactions`** | Motor estático que detecta y detona combinaciones elementales (`Vaporización`, `Superconductor`, `Combustión Tóxica`). | `Enemy`, `BattleTable`. |
| **`TempStatManager`** | Administra modificadores temporales de `str`, `int`, `dex` durante el combate y los expira por turno. | `RunState`, `WarCryAbility`, `BattleTable`. |
| **`DeckManager` & `CardPile`** | Administra las 3 pilas lógicas (`draw_pile`, `discard_pile`, `graveyard_pile`), clona `.tres` y sella rutas para guardado. | `BattleTable`, `RunState`, `PersistenceManager`, `PileInspector`. |
| **`CardBoardController`** | Controla el layout físico en pantalla de `hand_cards` y `combo_cards` (`CardUI`), drag & drop y reordenamiento en vivo. | `BattleTable`, `CardUI`. |
| **`Enemy` & `EnemyAI`** | `Enemy` gestiona HP, bloqueo, escalado por piso y los 5 statuses; `EnemyAI` evalúa el `intent_pattern` de `EnemyBehavior`. | `CombatResolver`, `BattleTable`, `StatusReactions`, `EnemyHUD`. |
| **`RewardView`** | Vista pura construida 100% en código con animaciones estilo Balatro (pop-in, idle senoidal, hover magnético). Emite `card_chosen` o `skipped`. | `RunDirector`, `CardUI`. |
| **`DebugOverlay`** | Panel QA in-game (`F3`/`F4`) para activar God Mode, inyectar stats RPG, oro, estados al enemigo, equipar armas o reliquias y saltar pisos. | `BattleTable`, `RunState`, `RunDirector`, `RaritySystem`. |

---

## 🛠️ Guía de edición y extensibilidad

Gracias a la arquitectura basada en `Resource` y al escaneo automático de `GameDatabase`, **no necesitás tocar el motor de combate ni registrar rutas a mano para agregar contenido**. Todo archivo `.tres` guardado en su carpeta correspondiente es detectado automáticamente al iniciar el juego.

### 1. Cómo crear o editar una Carta (`CardData`)

1. En el panel *FileSystem* de Godot, navegá a `res://cards/data/`.
2. Hacé clic derecho → **Create New → Resource...** y seleccioná **`CardData`** (`cards/card_data.gd`). Guardala como `mi_nueva_carta.tres`.
3. En el **Inspector**, configurá sus propiedades `@export`:
   - **Identity:** `title` (nombre visible), `rarity` (`RaritySystem.Tier`: Common, Uncommon, Rare, Epic, Legendary), `single_use` (`true` si va al Cementerio tras usarse).
   - **Effects and Cost:** `cost` (energía), `description` y el array `effects: Array[CardEffect]` instanciando subclases de `res://cards/effects/`:
	 - `damage_effect.gd` (`DamageEffect`): Daño base directo.
	 - `defense_effect.gd` (`DefenseEffect`): Otorga escudo (`block`).
	 - `burn_effect.gd` (`BurnEffect`): Aplica cargas de Quemadura.
	 - `poison_effect.gd` (`PoisonEffect`): Aplica cargas de Veneno.
	 - `freeze_effect.gd` (`FreezeEffect`): Aplica cargas de Congelamiento.
	 - `hemorrhage_effect.gd` (`HemorrhageEffect`): Aplica cargas de Hemorragia.
	 - `shock_effect.gd` (`ShockEffect`): Aplica cargas de Electrocutado.
	 - `apply_status_effect.gd` (`ApplyStatusEffect`): Aplica un estado específico o **`RANDOM`** (sorteado con pesos vía `RaritySystem.roll_weighted` y `combat_rng`).
	 - `heal_effect.gd` (`HealEffect`): Restaura HP al héroe al resolver el combo.
	 - `multiply_effect.gd` (`MultiplyEffect`): Multiplica el daño acumulado hasta ese punto del combo por `factor` (ej. `x2.0`).
	 - `steal_effect.gd` (`StealEffect`): Roba cartas adicionales (`is_instant() == true`, se consume al instante sin entrar a la fila de combo).
   - **Synergy (Armas):**
	 - `required_weapon_class`: Array de `WeaponData.Class` (`ANY`, `SWORD`, `HEAVY`, `STAFF`, `DAGGER`, `KATANA`). Si el jugador no tiene equipada un arma compatible, la carta hace `fallback_damage` ("Golpe torpe") y anula sus efectos de estado.
	 - `uses_weapon_damage`: Si es `true`, suma el daño base y escalado RPG del arma equipada.

### 2. Cómo crear un Nuevo Efecto de Carta (`CardEffect`)

1. Creá un script en `res://cards/effects/mi_efecto.gd` que extienda `CardEffect` y declare `class_name MiEfecto`.
2. Definí tus variables `@export` y sobrescribí:
   - `apply(combo_state: Dictionary) -> void`: Muta el diccionario de estado del combo.
   - `get_description() -> String`: Texto automático para la carta y el inspector.
   - `get_color() -> Color`: Color representativo para teñir el panel de `CardUI`.
   - `is_instant() -> bool`: Retorná `true` solo si debe consumirse inmediatamente al hacerle clic en la mano.

### 3. Cómo crear o editar un Héroe (`HeroData`) y su Habilidad (`HeroAbility`)

1. Andá a `res://entities/hero/data/` y editá cualquiera de los existentes (`warrior_hero.tres`, `magic_hero.tres`, `samurai_hero.tres`, `assasin_hero.tres`, `demo_hero.tres`) o creá un nuevo `HeroData`.
2. Configurá en el Inspector:
   - **Identity:** `hero_name`, `description`, `accent_color`.
   - **Stats:** `max_hp_base`, `energy_base`, `lucky`, `gold`, `hand_size`, `discards_base`, `sort_order`.
   - **RPG Stats:** `base_str`, `base_int`, `base_dex`.
   - **Cards and Relics:** `starting_deck` (`Array[CardData]`) y `starting_relic` (`Array[RelicData]`).
   - **Equipment & Ability:** Arrastrá un `WeaponData` a `starting_weapon` y asigná una subclase de `HeroAbility` (`entities/hero/abilities/`) en `ability`.

### 4. Cómo crear o editar un Arma (`WeaponData`)

1. Navegá a `res://weapons/data/` (`arma_basica.tres`, `baculo.tres`, `dagger.tres`, `espadon.tres`, `katana_basica.tres`).
2. Creá o editá un recurso **`WeaponData`** (`weapons/weapon_data.gd`):
   - **Identity & Dmg:** `weapon_id`, `weapon_name`, `weapon_class` (`ANY`, `SWORD`, `HEAVY`, `STAFF`, `DAGGER`, `KATANA`) y `base_damage`.
   - **Effects (On-Hit):** `inflict_poison`, `inflict_burn`, `inflict_hemorrhage`, `inflict_shock` (se suman automáticamente a cada carta compatible).
   - **Requirements:** `req_str`, `req_int`, `req_dex`. Cada punto de déficit reduce el daño final un 25% y desactiva los estados alterados de la carta y del arma.
   - **Scale:** `scale_str`, `scale_int`, `scale_dex` (multiplicadores que suman daño adicional según los stats efectivos del héroe).

### 5. Cómo crear o editar una Reliquia (`RelicData`)

1. En `res://relics/data/`, creá un recurso **`RelicData`** (`relics/relic_data.gd`).
2. Configurá `title`, `rarity`, `description` y agregá elementos a `effects: Array[RelicEffect]` (`res://relics/effects/`):
   - `relic_stat_bonus_effect.gd` (`RelicStatBonusEffect`): Modifica permanentemente `max_energy`, `target_hand_size`, `max_player_hp`, `discards_per_combat` o `player_luck` al equiparse (`on_equipped`).
   - `relic_start_status_effect.gd` (`RelicStartStatusEffect`): Aplica Quemadura, Veneno, Congelamiento, Shock o Hemorragia al enemigo en el turno 0 (`on_combat_start`).
   - `relic_combo_synergy_effect.gd` (`RelicComboSynergyEffect`): Otorga `+bonus_damage` y `+bonus_block` si el combo tiene al menos `min_cards_required` cartas (`on_combo_evaluated`).
   - `relic_revive_effect.gd` (`RelicReviveEffect`): Impide la muerte del jugador restaurando `revive_hp_ratio` de su vida máxima y consumiendo la reliquia (`on_player_lethal_damage`).

### 6. Cómo crear o editar un Enemigo (`EnemyData`)

1. En `res://entities/enemies/data/`, creá un recurso **`EnemyData`** (`entities/enemies/enemy_data.gd`).
2. Configurá `enemy_name`, `base_hp`, `base_damage`, `is_boss`, `artwork`.
3. **Patrón de IA (`intent_pattern: Array[EnemyBehavior]`):** Agregá recursos `EnemyBehavior` (`res://core/enemies/behaviors/`). `EnemyAI` los evalúa en orden y selecciona el primero que no devuelva `null`:
   - `AttackBehavior(damage, every_n_turns)` — Ataca cada $N$ turnos escalando con la planta.
   - `DefendBehavior(block, every_n_turns)` — Gana escudo cada $N$ turnos (persiste durante el siguiente turno del jugador y se resetea al inicio del próximo turno enemigo).
   - `ChargeBehavior(bonus_multiplier, every_n_turns)` — Carga un turno (`0` daño) y golpea con multiplicador al turno siguiente.

### 7. Cómo editar Recompensas de combate

Las recompensas se calculan en `RunState.generate_combat_rewards()` (`core/run/run_state.gd`):
1. **Oro base:** `10 + (current_floor * 2) + randi() % 5`.
2. **Semilla determinista:** `FloorGenerator.get_floor_subseed(master_seed, current_floor * 1000 + combat_index)`.
3. **Oferta de cartas:** 3 cartas sin repetir sorteadas con `RaritySystem.roll_tier(rng, current_floor, player_luck)`.
4. **Chance de reliquia:** 30% (`rng.randf() < 0.3`).

---

## 🔧 Herramientas de desarrollo y debugging

El proyecto incluye un **`DebugOverlay`** (`res://ui/system/debug_overlay.gd`) que se inyecta automáticamente en `BattleTable._ready()` cuando `OS.is_debug_build()` es `true`:

- **Atajos:** `F3` abre/cierra el panel de 3 columnas; `F4` oculta/muestra toda la interfaz de debug (incluido el badge `[F3] DEBUG`).
- **Columna 1 (God Mode & Stats RPG):** Activar/desactivar **God Mode** (invulnerabilidad, 99 energía, 99 descartes, mapa revelado y viaje libre), sumar `+1 STR`, `+1 INT`, `+1 DEX`, `+2 LUCK`, `+5 Energía`, `+100 Oro`, curar Full HP o dejar en 1 HP.
- **Columna 2 (Combate, Mapa y Armas):** `INSTA-KILL Enemigo`, revelar mapa, alternar vista de mapa, robar +1 carta, +3 descartes, inyectar cargas de cualquiera de los 5 estados al enemigo, forzar pelea con el Jefe, saltar a la siguiente planta y **agregar/equipar cualquier arma del catálogo**.
- **Columna 3 (Inyectar Reliquias):** Botones generados dinámicamente para equipar al instante cualquier `.tres` de `res://relics/data/` o limpiar todas las reliquias restaurando los stats base del héroe.

---

## 🥇 Reglas de oro

1. **`core/` no conoce `scenes/` ni `ui/`.** Toda la lógica de dominio extiende `RefCounted` y es testeable sin levantar escenas.
2. **Inmutabilidad de `.tres` en disco:** ningún `.tres` se modifica directamente en runtime; las cartas y reliquias se clonan (`duplicate()`) sellando su `resource_name` (con transición prevista a `*_instance.gd`).
3. **UI desacoplada del Resolver:** `CombatResolver` es 100% `static` y stateless. Cualquier `await`, animación, `card.pulse()` o `card.queue_free()` vive en `scenes/battle/battle_table.gd`.
4. **Catálogos centralizados:** todo escaneo masivo de recursos pasa por `GameDatabase` usando las rutas de `CombatConstants`.
5. **`*.tres` solo data, nunca lógica acoplada a UI:** el comportamiento se delega a scripts modulares en `effects/`, `behaviors/` o `abilities/`.
6. **Las vistas no mutan dominio directamente:** vistas como `RewardView`, `ShopView` o `InventoryModalView` solo renderizan datos y emiten señales (`card_chosen`, `card_bought`, `weapon_selected_to_equip`); `RunDirector` o `BattleTable` coordinan la mutación en `RunState`.

---

## 📐 Convenciones

- **Nombres de archivos**: `snake_case.gd`, `snake_case.tscn`, `snake_case.tres`.
- **Nombres de clases**: `PascalCase` con `class_name` explícito.
- **Recursos `.tres`**: nombres descriptivos (`tajo.tres`, `cenizas_fenix.tres`, `katana_basica.tres`).
- **Señales**: pasado simple descriptivo (`card_played`, `relic_acquired`, `room_entered`, `floor_started`, `card_chosen`).
- **`scenes/` vs `ui/`**: pantallas completas / vistas de estado en `scenes/`, componentes atómicos y modales reutilizables en `ui/`.

---

## 🔧 Git

- Commitear `addons/gut/` completo.
- **No commitear** `.godot/`, `*.import` ni archivos temporales `*.tmp` (limpiar cualquier `.tscn*.tmp` residual antes de commitear).

---

## 📚 Documentación adicional

- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — Reglas de capas, árbol real de archivos vs `🚧 [FUTURO / PENDIENTE]`, decisiones técnicas (Combo Resolver stateless, UI 100% en código, grafo 8x8, sellado de recursos) y checklists.
- [`docs/GDD.md`](docs/GDD.md) — Game Design Document actualizado al código real: mecánicas de combo, reacciones elementales, stats RPG y armas, 5 héroes, catálogo real de cartas/reliquias/armas/enemigos, mapa 8x8, economía y matriz FSM.

---

## 🗺️ Roadmap

1. **MVP (Completado ✅):** Combate por combos 1v1, mazo con 3 pilas (Robo, Descarte, Cementerio), previsualización en vivo, cartas instantáneas.
2. **Run Loop & Persistencia (Completado ✅):** Mapa procedural 8x8 con niebla de guerra, tiendas, hogueras, santuarios, recompensas estilo Balatro, 3 slots de guardado atómico JSON y menú de pausa.
3. **Sistemas RPG & Elementales (Completado ✅):** Stats `STR`/`INT`/`DEX`/`LUCK`, armas con requisitos/escalado y mochila, 5 estados alterados, 3 reacciones elementales (`StatusReactions`), 5 perfiles de héroe con habilidades activas (`HeroAbility`), IA enemiga modular (`EnemyBehavior`).
4. **Testing & Refactor de Subsistemas (`🚧 [FUTURO / PENDIENTE]`):** Suites unitarias en `test/` con GUT, wrappers `CardInstance`/`RelicInstance`, carpeta `systems/` (eventos narrativos `EventData` y `StatusData` desacoplado).
5. **Expansión de Contenido & Polish (`🚧 [FUTURO / PENDIENTE]`):** Nuevos enemigos y bosses por planta, más cartas/reliquias/armas, arte final, SFX/música y sistema de desbloqueos meta-progreso.

---

## 📄 Licencia

Por definir. Sugerido: MIT para código, CC-BY 4.0 para assets.
