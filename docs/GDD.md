# Game Design Document (GDD)

**Card Prototype** — Roguelike deckbuilder táctico por combos en Godot 4.

Última actualización: 2026-11-09
Estado: Prototipo jugable (Core Loop, Combate por Combos, Reacciones Elementales, Armas RPG y Mapa 8x8 implementados).

> **Convención de estado en este documento:**
> - Todo elemento sin etiqueta corresponde a mecánicas y recursos **implementados y activos en el código actual**.
> - Todo elemento marcado con **`🚧 [FUTURO / PENDIENTE]`** corresponde a diseño planificado para próximas iteraciones.

---

## Tabla de contenidos

1. [Visión general](#visión-general)
2. [Público objetivo](#público-objetivo)
3. [Inspiraciones](#inspiraciones)
4. [Core loop](#core-loop)
5. [Mecánicas principales](#mecánicas-principales)
6. [Héroes y Habilidades Activas](#héroes-y-habilidades-activas)
7. [Cartas](#cartas)
8. [Reliquias](#reliquias)
9. [Armas y Estadísticas RPG](#armas-y-estadísticas-rpg)
10. [Estados Alterados y Reacciones Elementales](#estados-alterados-y-reacciones-elementales)
11. [Enemigos e IA](#enemigos-e-ia)
12. [Mapa procedural (Matriz 8x8)](#mapa-procedural-matriz-8x8)
13. [Salas Especiales y Eventos](#salas-especiales-y-eventos)
14. [Sistema de rarezas y Suerte](#sistema-de-rarezas-y-suerte)
15. [Economía y Tienda](#economía-y-tienda)
16. [Progresión meta y Guardado](#progresión-meta-y-guardado)
17. [Balance numérico](#balance-numérico)
18. [UI/UX](#uiux)
19. [Arte y audio](#arte-y-audio)
20. [Roadmap](#roadmap)
21. [Matriz de transiciones legales (FSM)](#matriz-de-transiciones-legales-fsm)
22. [Open questions](#open-questions)

---

## Visión general

**Card Prototype** es un roguelike deckbuilder de un solo jugador donde cada partida es una expedición procedural determinista por semillas. A diferencia de los deckbuilders clásicos de cartas sueltas, el jugador **arma y ordena secuencias en una Zona de Combo**, cruza los requisitos y escalados de su **Arma equipada** con sus atributos RPG (`STR`, `INT`, `DEX`, `LUCK`), y detona **Reacciones Elementales** sobre los enemigos mientras explora una **matriz ortogonal de 8x8** cubierta por niebla de guerra.

### Pilares de diseño

1. **Secuenciación sobre spam (Zona de Combo)**: El orden en que colocás y arrastrás las cartas dentro del combo altera radicalmente el resultado (ej. sumar daño base y estados antes de un multiplicador `Sobrecarga`).
2. **Identidad por Arma y Stats RPG**: Las cartas exigen clases de armas específicas (`SWORD`, `HEAVY`, `STAFF`, `DAGGER`, `KATANA`) y las armas exigen `STR`, `INT` o `DEX`. Usar un arma sin los stats necesarios aplica penalizaciones severas ("Golpe torpe" o déficit de stats).
3. **Alquimia Elemental**: Los 5 estados alterados interactúan entre sí mediante `StatusReactions` (*Vaporización*, *Superconductor*, *Combustión Tóxica*).
4. **Legibilidad Predictiva Absoluta**: Antes de apretar "EJECUTAR COMBO", el `ComboBanner` simula exactamente cuánto daño, escudo, robo, curación y estados va a producir la cadena actual.
5. **Exploración Espacial en Grilla**: Cada piso es un laberinto ortogonal 8x8 donde los callejones sin salida esconden al Jefe, Tesoros, Hogueras, Tiendas y Santuarios.

---

## Público objetivo

- Fans de *Slay the Spire*, *Balatro*, *Monster Train*, *Inscryption*.
- Jugadores que disfrutan armar cadenas de sinergias, optimizar el orden de ejecución y gestionar equipamiento RPG.
- Sesiones de 20-45 minutos por run.
- Plataforma inicial: PC (Windows/Linux/Mac) y soporte de renderizado `mobile`.

---

## Inspiraciones

| Juego | Qué tomamos | Qué NO tomamos |
|---|---|---|
| **Slay the Spire** | Intenciones enemigas visibles, economía de energía, reliquias pasivas/reactivas | Mapa lineal de columnas hacia arriba (usamos grilla 8x8) |
| **Balatro** | Importancia del orden de izquierda a derecha en la fila jugada (sumas antes de multiplicadores), descartes tácticos limitados y feedback visual magnético en recompensas | Reglas de póker |
| **Genshin Impact / Divinity** | Reacciones elementales al combinar estados alterados (`Quemadura` + `Congelamiento` = *Vaporización*, etc.) | Combate en tiempo real |
| **Dark Souls / RPGs clásicos** | Requisitos de `STR`/`INT`/`DEX` para empuñar armas sin penalización y escalado de daño por atributo | — |

---

## Core loop

```text
┌──────────────────────────────────────────────────────────┐
│  SELECTOR DE PERFIL (SlotSelectView - 3 Ranuras)         │
│  → Auto-login a la última ranura jugada (last_slot.cfg)  │
│  → Si hay run viva en run.json, reanuda directamente     │
└──────────────────────────────────────────────────────────┘
							│
							▼
┌──────────────────────────────────────────────────────────┐
│  MENÚ PRINCIPAL (MainMenuView)                           │
│  → Muestra el perfil activo ya cargado y sus récords     │
│  → Botones: Nueva Expedición / Cambiar Perfil / Salir    │
└──────────────────────────────────────────────────────────┘
							│
							▼
┌──────────────────────────────────────────────────────────┐
│  SELECCIÓN DE HÉROE (HeroSelectView)                     │
│  → Elegir Héroe (Guerrero, Mago, Samurai, Asesino, DEMO) │
│  → Inspeccionar Stats RPG, Arma, Habilidad y Reliquias   │
│  → Iniciar Partida Aleatoria o ingresar Semilla (Seed)   │
└──────────────────────────────────────────────────────────┘
							│
							▼
┌──────────────────────────────────────────────────────────┐
│  MAPA DE EXPLORACIÓN (MapView - Grilla Ortogonal 8x8)    │
│  → Gestionar Mochila de Armas e Inventario               │
│  → Avanzar a salas adyacentes descubiertas:              │
│    COMBAT / TREASURE / REST / SANCTUARY / SHOP / BOSS    │
└──────────────────────────────────────────────────────────┘
							│
							▼
┌──────────────────────────────────────────────────────────┐
│  COMBATE POR COMBOS (BattleTable)                        │
│  → Rellenar mano hasta target_hand_size (5 base)         │
│  → Usar Cartas Instantáneas o Habilidad Activa del Héroe │
│  → Arrastrar y ordenar cartas en la Zona de Combo        │
│  → Usar Descartes Tácticos o Ejecutar el Combo           │
│  → Detonar Reacciones Elementales y Ticks de Estado      │
│  → Turno Enemigo (con chequeo de Freeze/Shock Stun)      │
└──────────────────────────────────────────────────────────┘
							│
							▼
┌──────────────────────────────────────────────────────────┐
│  RECOMPENSA POST-COMBATE (RewardView - Estilo Balatro)   │
│  → Oro: 10 + (piso * 2) + random(0..4)                   │
│  → Elegir 1 de 3 cartas (sorteadas por RaritySystem)     │
│  → 30% de probabilidad de Reliquia adicional             │
└──────────────────────────────────────────────────────────┘
							│
							▼
	   (Si la sala era BOSS → Avanza a Planta N+1)
```

---

## Mecánicas principales

### 1. Energía y Mano
- **Energía por turno**: Definida por el héroe (`3` base en `CombatConstants.BASE_MAX_ENERGY`, `4` en Guerrero, `5` en Mago). Se restaura al máximo al inicio de cada turno.
- **Reserva en Zona de Combo**: Subir una carta de la mano a la Zona de Combo reserva su costo de energía. Si el jugador devuelve la carta a la mano antes de ejecutar el turno, **la energía se reembolsa íntegramente**.
- **Robo de mano (`target_hand_size`)**: Al inicio de cada turno, el jugador NO descarta las cartas que conservó en la mano; roba únicamente las cartas necesarias (`max(0, target_hand_size - hand_cards.size())`) para volver a completar su tamaño de mano objetivo (`5` base, ampliable con reliquias como *Bolsillo Dimensional*).

### 2. Zona de Combo y Orden de Ejecución
- Las cartas colocadas en la `ComboZone` se evalúan **secuencialmente de izquierda a derecha** cuando se presiona `EJECUTAR COMBO`.
- El jugador puede arrastrar cualquier carta dentro de la `ComboZone` para cambiar su posición en la fila en tiempo real.
- **Importancia del orden**: Efectos como `MultiplyEffect` (`Sobrecarga`) multiplican el daño acumulado *hasta ese instante* en `combo_state["dmg"]`. Colocar `Sobrecarga` al principio multiplica `0`; colocarla al final multiplica la suma de todos los ataques previos.
- Si la `ComboZone` está vacía, el botón cambia a `PASAR TURNO`.

### 3. Cartas Instantáneas (`is_instant_card()`)
- Cartas cuyos efectos tienen `is_instant() == true` (actualmente `StealEffect` en la carta **Robo**).
- Al hacerles clic o soltarlas en la mesa, **no entran a la fila de combo**: descuentan su energía, ejecutan una animación de levitación y disolución tipo tarot (`play_consume_animation()`), aplican su efecto en el acto (ej. robar cartas nuevas) y permiten seguir armando el turno.

### 4. Descartes Tácticos (`discards_remaining`)
- Cada héroe cuenta con un número limitado de **Descartes por combate** (`2` base, `3` en Mago, `4` en Asesino, ampliable por reliquias).
- Para descartar, el jugador sube a la `ComboZone` las cartas que no quiere y presiona `DESCARTAR (X)`:
  - Se reembolsa toda la energía de esas cartas.
  - Las cartas van a `discard_pile` (incluso si eran `single_use`, ya que no se ejecutaron).
  - Se consume 1 ficha de descarte y **se roba inmediatamente la misma cantidad de cartas**.

### 5. Las 3 Pilas del Mazo (`DeckManager`) y Vista Visual de Colección
1. **`draw_pile` (Mazo)**: Cartas listas para robar. Cuando se vacía, recicla y baraja automáticamente `discard_pile`.
2. **`discard_pile` (Descarte)**: Cartas normales jugadas o descartadas tácticamente.
3. **`graveyard_pile` (Cementerio)**: Las cartas con `single_use = true` (ej. **Curación**) van al Cementerio tras ejecutarse en un combo y **no vuelven a reciclarse durante ese combate**. Al finalizar un combate (`RunDirector._clear_room_after_combat()`) o iniciar el siguiente, todas las pilas y cartas de la mesa se consolidan de nuevo en el Mazo.
4. **Inspección Visual del Mazo y Pilas (`InspectorModalView.open_deck_cards()` y `PileInspector.show_pile()`)**:
   - Tanto al tocar **`MI MAZO`** en el Mapa como al tocar **`Mazo`**, **`Descarte`** o **`Cementerio`** durante el combate, el juego despliega una grilla visual de 5 columnas con scroll vertical que renderiza las cartas reales mediante `CardUI` en modo estático (`set_static_display_mode(true)`).
   - Las cartas idénticas se agrupan en una única ranura visual coronada arriba por una insignia de cantidad: **`x1`** (en tono plata/celeste) cuando se posee una sola copia, o **`xN`** (destacada en dorado) cuando se poseen múltiples copias. Al ganar una carta en `RewardView` o comprarla en `ShopView`, el contador se incrementa automáticamente.

### 6. Escudo (`block`) Jugador vs Enemigo
- **Escudo del Jugador (`player_block`)**: Se suma durante la ejecución del combo, absorbe el ataque enemigo de ese turno y se resetea a `0` al inicio del siguiente turno del jugador.
- **Escudo del Enemigo (`enemy.block`)**: Cuando el enemigo usa `DefendBehavior`, gana escudo en su turno. Ese escudo **persiste durante todo el siguiente turno del jugador** (absorbiendo el daño del combo) y recién se resetea al inicio del próximo turno del enemigo (`reset_block_for_new_turn()`).

---

## Héroes y Habilidades Activas

Cada héroe tiene estadísticas base, atributos RPG (`STR`, `INT`, `DEX`, `LUCK`), un arma inicial, un mazo inicial, reliquias de partida y una **Habilidad Activa (`HeroAbility`)** utilizable desde el botón de habilidad en combate (`1 uso por combate` por defecto).

### Catálogo de Héroes implementados (`entities/hero/data/`)

| Héroe (`archivo.tres`) | HP Máx | Energía | Descartes | Oro | Suerte | STR / INT / DEX | Arma Inicial | Habilidad Activa | Reliquias Iniciales | Mazo Inicial |
|---|---|---|---|---|---|---|---|---|---|---|
| **Guerrero** (`warrior_hero.tres`) | 50 | 4 | 2 | 100 | 1 | 1 / 1 / 1 | `Espadon` | **Grito de Guerra** (`+3 STR` por 2 turnos) | Ninguna | 3x *Estocada*, 3x *Escudo*, 1x *Robo* (7 cartas) |
| **Mago** (`magic_hero.tres`) | 45 | 5 | 3 | 120 | 1 | 3 / 6 / 2 | `Baculo Basico` | **Flujo Arcano** (Roba 3 cartas sin gastar energía) | Ninguna | 1x *Golpe Congelante*, 1x *Lanza Rayo*, 2x *Golpe Ígneo*, 1x *Escudo*, 1x *Sobrecarga* (6 cartas) |
| **Samurai** (`samurai_hero.tres`) | 60 | 3 | 2 | 200 | 4 | 5 / 1 / 1 | `Katana Basica` | **Corte Sangrante** (`7` daño directo + `10` Hemorragia) | Ninguna | 3x *Tajo*, 2x *Escudo*, 1x *Robo* (6 cartas) |
| **Asesino** (`assasin_hero.tres`) | 50 | 3 | 4 | 678 | 1 | 4 / 2 / 4 | `Daga` | **Corte Sangrante** (`7` daño directo + `10` Hemorragia) | *Cenizas de Fénix*, *Trébol del Abismo* | 1x *Sobrecarga*, 1x *Tajo*, 1x *Corte Rápido* (3 cartas) |
| **DEMO** (`demo_hero.tres`) | 200 | 8 | 4 | 100 | 1 | 1 / 5 / 1 | `Baculo Basico` | Sin habilidad | *Cenizas de Fénix*, *Núcleo Sobrecargado*, *Catalizador de Combo* | 1x *Escudo*, 1x *Lanza Rayo*, 1x *Curación*, 1x *Efecto Caótico* (4 cartas) |

### Habilidades Activas (`entities/hero/abilities/`)

| Clase (`script`) | Nombre en UI | Usos / Combate | Efecto exacto |
|---|---|---|---|
| `WarCryAbility` (`war_cry_ability.gd`) | **Grito de Guerra** | 1 | Registra en `TempStatManager` un modificador temporal de **`+3 STR` durante 2 turnos**. |
| `ArcaneFlowAbility` (`arcane_flow_ability.gd`) | **Flujo Arcano** | 1 | Invoca `table.draw_cards(3)` robando **3 cartas gratis** en el acto. |
| `BloodySlashAbility` (`bloody_slash_ability.gd`) | **Corte Sangrante** | 1 | Inflige **7 de daño directo** al enemigo y le aplica **+10 de Hemorragia** (disparando reacciones o estallido si corresponde). |
| `DemonThrustAbility` (`demon_thrust_ability.gd`) | **Estocada Demoníaca** | 1 | Inflige **`20 + int(player_luck * 0.5)` de daño directo** al enemigo ignorando armas *(disponible en código, pendiente de asignar a un `.tres` de héroe)*. |

---

## Cartas

### Anatomía Visual y Código de Colores (`CardUI` + `CardData`)

Cada carta renderizada por `ui/cards/card_ui.tscn` y `ui/cards/card_ui.gd` utiliza anclas proporcionales (escalando limpiamente tanto en mano a `140x200` como en `RewardView` a `180x240`) y se divide en 4 bloques funcionales:

```text
┌────────────────────────────────────────┐
│ [Costo]  Nombre Carta    [Icono Arma]  │  <- Cabecera: Costo + Nombre (color por efecto) + Sinergia
├────────────────────────────────────────┤
│                                        │
│          Sprite / Arte (2D)            │  <- Texture2D (`artwork`) o Emblema elemental de respaldo
│                                        │
├────────────────────────────────────────┤
│ [🏷️ Familia de Arma: Ej. Espada/Daga] │  <- Tag compacto de compatibilidad (`get_weapon_tag_text()`)
├────────────────────────────────────────┤
│                                        │
│           "+6 Daño Base                │  <- Descripción centrada (`StatsLabel`)
│            +5 Hemorragia"              │
│ 🩸                                     │  <- Abajo izq.: Emoji del estado al enemigo (`StatusIconLabel`)
└────────────────────────────────────────┘
  (Cuerpo y reborde fijo de 2px teñidos según la Rareza)
```

1. **Cuerpo y Borde según Rareza (`RaritySystem.get_tier_color`):**
   - El fondo del cuerpo de la carta y su reborde uniforme de **2px** reflejan la jerarquía de rareza (**Gris** Común, **Verde** Poco Común, **Azul** Rara, **Violeta** Épica, **Dorado** Legendaria).
2. **Color del Título según Función y Naturaleza Mágica (`CardData.get_color`):**
   - El nombre de la carta (`TitleLabel`, con contorno negro de `2px` para garantizar contraste sobre cualquier rareza) indica qué hace la carta:
	 - **Azul** (`Color(0.32, 0.72, 1.0)`): **Escudo** (`DefenseEffect`).
	 - **Verde** (`Color(0.28, 0.92, 0.48)`): **Sanación** (`HealEffect`).
	 - **Rojo** (`Color(1.0, 0.32, 0.34)`): **Daño Físico / Alquímico** (`not is_magic_card()`).
	 - **Violeta Mágico** (`Color(0.82, 0.36, 1.0)` / `Color(0.86, 0.36, 1.0)`): **Daño Mágico** (`is_magic_card()`) y **Sobrecarga / Multiplicador** (`MultiplyEffect`).
	 - **Violeta Índigo** (`Color(0.58, 0.50, 1.0)`): **Robo de cartas** (`StealEffect`).
3. **Flag Mágico (`is_magical` en `CardData` y `CardEffect`):**
   - Tanto `CardData` como `CardEffect` exportan `@export var is_magical: bool`. El helper `CardData.is_magic_card()` evalúa `true` si la carta tiene `is_magical = true`, si requiere `WeaponData.Class.STAFF`, o si cualquiera de sus efectos tiene `is_magical = true` (activo por defecto en `BurnEffect`, `FreezeEffect`, `ShockEffect`, `ApplyStatusEffect` y `MultiplyEffect`).
4. **Indicador Inferior Izquierdo de Estado al Enemigo (`CardData.get_enemy_status_icons`):**
   - En la esquina inferior izquierda (`StatusIconLabel`) se muestran únicamente los emojis de los estados alterados que la carta aplica sobre el enemigo: `🩸` (Hemorragia), `🔥` (Quemadura), `❄️` (Congelamiento), `🧪` (Veneno), `⚡` (Electrocución) o `🎲` (Estado Aleatorio).

### Catálogo de Cartas implementadas (`cards/data/`)

| Carta (`archivo.tres`) | Rareza (`Tier`) | Costo | Mágica (`is_magical`) | Arma Requerida (`Class`) | Usa Daño de Arma | Único Uso (`single_use`) | Efectos (`CardEffect`) |
|---|---|---|---|---|---|---|---|
| **Corte Rápido** (`corte_rapido.tres`) | Común (`0`) | 1 | No | `DAGGER` (`4`) | Sí (Fallback: 2) | No | `HemorrhageEffect(6)` (+ daño del arma equipada) |
| **Estocada** (`estocada.tres`) | Común (`0`) | 1 | No | `SWORD` (`1`), `KATANA` (`5`) | Sí (Fallback: 2) | No | `DamageEffect(10)` (+ daño base y escalado del arma equipada) |
| **Frasco De Veneno** (`frasco_veneno_basico.tres`) | Común (`0`) | 2 | No | `ANY` (`0`) | Sí (Fallback: 2) | No | `PoisonEffect(2)` |
| **Golpe Ígneo** (`golpe_fuego.tres`) | Común (`0`) | 1 | **Sí** | `STAFF` (`3`) | Sí (Fallback: 2) | No | `DamageEffect(4)` + `BurnEffect(2)` |
| **Escudo** (`escudo_basico.tres`) | Poco Común (`1`) | 1 | No | `ANY` (`0`) | Sí (Fallback: 2) | No | `DefenseEffect(8)` (+8 Escudo) |
| **Golpe Congelante** (`golpe_congelante.tres`) | Poco Común (`1`) | 1 | **Sí** | `STAFF` (`3`) | Sí (Fallback: 2) | No | `DamageEffect(4)` + `FreezeEffect(2)` |
| **Robo** (`robo_basico.tres`) | Poco Común (`1`) | 1 | No | `ANY` (`0`) | Sí | No | `StealEffect(1)` (**Instantánea**: roba +1 carta al clickearla) |
| **Sobrecarga** (`sobre_carga.tres`) | Poco Común (`1`) | 2 | **Sí** | `ANY` (`0`) | Sí | No | `MultiplyEffect(2.5)` (Multiplica `x2.5` el daño acumulado en el combo) |
| **Tajo** (`tajo.tres`) | Poco Común (`1`) | 2 | No | `KATANA` (`5`) | Sí (Fallback: 2) | No | `DamageEffect(6)` + `HemorrhageEffect(5)` |
| **Curación** (`curacion_basica.tres`) | Rara (`2`) | 1 | No | `ANY` (`0`) | No (Fallback: 0) | **Sí** (Cementerio) | `HealEffect(5)` (Restaura +5 HP al resolver el combo) |
| **Lanza Rayo** (`lanza_rayo.tres`) | Rara (`2`) | 1 | **Sí** | `STAFF` (`3`) | Sí (Fallback: 2) | No | `DamageEffect(5)` + `ShockEffect(3)` |
| **Efecto Caótico** (`efecto_caotico.tres`) | Épica (`3`) | 1 | **Sí** | `ANY` (`0`) | No (Fallback: 2) | No | `ApplyStatusEffect(RANDOM, 5)` (+5 de un estado sorteado con pesos: 30% Burn, 30% Poison, 20% Freeze, 15% Shock, 5% Hemorrhage) |

### Cartas adicionales en diseño (`🚧 [FUTURO / PENDIENTE]`)

- **Puñalada** (`🚧 [FUTURO / PENDIENTE]`): Costo 0, daño rápido para arquetipo Asesino/Daga.
- **Emboscada** (`🚧 [FUTURO / PENDIENTE]`): Daño condicional aumentado si el enemigo tiene $\le 50\%$ HP.
- **Ira / Fortaleza** (`🚧 [FUTURO / PENDIENTE]`): Cartas de tipo *Power* (`single_use = true`) que otorguen `STR` o `DEX` por todo el combate vía `TempStatManager`.
- **Renacer** (`🚧 [FUTURO / PENDIENTE]`): Rareza Legendaria, curación completa (`single_use = true`).

---

## Reliquias

Las reliquias persisten durante toda la run y disparan sus efectos en cuatro momentos posibles: al equiparse (`on_equipped`), al inicio de cada combate (`on_combat_start`), al evaluar el cierre de un combo (`on_combo_evaluated`) o al recibir daño letal (`on_player_lethal_damage`).

### Anatomía Visual de las Reliquias (`RelicUI` + `RelicData`)

Al inspeccionar las reliquias desde el botón **`RELIQUIAS (N)`** en el Mapa (`InspectorModalView.open_relic_cards()`), cada reliquia se presenta como una tarjeta visual (`ui/relics/relic_ui.tscn` + `ui/relics/relic_ui.gd`) con su insignia superior de copias (`x1` / `xN`) y una estructura de 4 bloques:

```text
┌──────────────────────────────────────────────┐
│  Nombre de la Reliquia           [Rareza]    │  <- Título sobrio + Rareza coloreada
├──────────────────────────────────────────────┤
│                                              │
│         [ Marco / Pedestal ]                 │
│              ( Sprite 2D )                   │  <- Objeto centrado (`artwork` o glifo)
│                                              │
├──────────────────────────────────────────────┤
│  EFECTO                                      │
│  "Aplica +3 de Quemadura al inicio."         │  <- Mecánica corta, clara y resaltada
├──────────────────────────────────────────────┤
│  LORE / HISTORIA                             │
│  "Forjado en el corazón de una fragua        │  <- Párrafo narrativo en cursiva (`[i]`),
│   enana hoy sepultada bajo cenizas..."       │     tono gris/azulado atenuado
└──────────────────────────────────────────────┘
```

### Catálogo de Reliquias implementadas (`relics/data/`)

| Reliquia (`archivo.tres`) | Rareza (`Tier`) | Hook / Efecto (`RelicEffect`) | Impacto en partida | Lore (`lore`) |
|---|---|---|---|---|
| **Anillo de Brasas** (`anillo_brasas.tres`) | Común (`0`) | `RelicStartStatusEffect` | Aplica **+3 Quemadura inicial** al enemigo al comenzar cada combate. | *"Forjado en el corazón de una fragua enana hoy sepultada bajo cenizas. Su metal jamás se enfría y murmura chispas al desenfundar."* |
| **Catalizador de Combo** (`catalizador_combo.tres`) | Común (`0`) | `RelicComboSynergyEffect` | Si el combo ejecutado tiene **3 o más cartas**, añade **+6 Daño y +5 Escudo**. | *"Un engranaje rúnico que acelera el pulso de su portador. Cuanto más frenética es la cadena de estocadas, más violento resuena su núcleo."* |
| **Bolsillo Dimensional** (`bolsillo_dimensional.tres`) | Poco Común (`1`) | `RelicStatBonusEffect` | Otorga **+1 Tamaño de Mano base** permanente (`target_hand_size`). | *"Cosido con hebras de vacío por un sastre exiliado de la Torre Arcana. Por dentro siempre cabe un truco más del que permite la tela."* |
| **Colmillo de Víbora** (`colmillo_vibora.tres`) | Poco Común (`1`) | `RelicStartStatusEffect` | Aplica **+3 Veneno inicial** al enemigo al comenzar cada combate. | *"Arrancado de una sierpe albina de las criptas profundas. Aunque lleva décadas seco, su canal interno sigue destilando una gota letal al primer roce."* |
| **Núcleo Sobrecargado** (`nucleo_sobrecargado.tres`) | Poco Común (`1`) | `RelicStatBonusEffect` | Otorga **+1 Energía Máxima** permanente (`max_energy`). | *"Una esfera de cuarzo agrietada que contiene una tormenta en miniatura. Los alquimistas que intentaron sellarla desaparecieron sin dejar sombra."* |
| **Pata De Conejo** (`pata_conejo.tres`) | Poco Común (`1`) | `RelicStatBonusEffect` | Otorga **+10 Suerte** permanente (`player_luck`). | *"Un amuleto gastado por generaciones de tahúres y saqueadores de tumbas. Dicen que la suerte que otorga fue robada a su antiguo dueño."* |
| **Trébol del Abismo** (`trebol_abismo.tres`) | Poco Común (`1`) | `RelicStatBonusEffect` | Otorga **+3 Suerte** permanente (`player_luck`). | *"Brotó en la oscuridad absoluta donde jamás llega el sol. Sus cuatro hojas negras inclinan los dados del destino a favor de quien no teme mirarlo."* |
| **Cenizas de Fénix** (`cenizas_fenix.tres`) | Épica (`3`) | `RelicReviveEffect` | Al recibir daño letal (`HP <= 0`), **revive al jugador con el 50% de su HP máximo** y la reliquia se consume (destruye). | *"El clan, que perdió todo en el gran incendio, recogió este puñado de pavesas doradas como objeto sagrado. Aún laten esperando una última agonía."* |

### Reliquias adicionales en diseño (`🚧 [FUTURO / PENDIENTE]`)

- **Bolsa del Aventurero** (`🚧 [FUTURO / PENDIENTE]`): Oro adicional al iniciar cada nueva planta (`SignalBus.floor_started`).
- **Garra del Demonio** (`🚧 [FUTURO / PENDIENTE]`): Reliquia de Jefe con downside (reducción de costo a cambio de HP).

---

## Armas y Estadísticas RPG

### Atributos RPG del Héroe
- **Fuerza (`STR`)**, **Inteligencia (`INT`)** y **Destreza (`DEX`)**: Determinan qué armas puede dominar el héroe y cuánto daño adicional ganan sus ataques. Pueden aumentarse temporalmente en combate mediante `TempStatManager` (ej. *Grito de Guerra*).
- **Suerte (`LUCK`)**: Afecta la probabilidad de obtener rarezas altas en `RaritySystem`, la probabilidad de aturdimiento por **Electrocutado (Shock)**, el porcentaje de daño del estallido de **Hemorragia**, la curación en **Hogueras / Santuarios** y la aparición de salas especiales en el `FloorGenerator`.

### Reglas de Armas y Penalizaciones (`CombatResolver.calculate_final_card_damage`)
1. **Compatibilidad de Clase (`required_weapon_class`)**: Si una carta exige un tipo de arma específico (ej. `STAFF` para *Lanza Rayo* o `KATANA` para *Tajo*) y el jugador tiene equipada un arma de otra clase, la carta ejecuta un **"Golpe torpe"**: solo inflige `fallback_damage` (2 de daño) y **anula todos sus efectos de estado**.
2. **Requisitos de Atributos (`req_str`, `req_int`, `req_dex`)**: Si el arma es de la clase correcta pero los atributos efectivos del héroe son menores a los requeridos por el arma, se calcula el `stat_deficit` (suma de puntos faltantes). Cada punto de déficit **reduce el daño final un 25%** (`min(1.0, deficit * 0.25)`) y **anula por completo los estados alterados** de la carta y del arma.
3. **Escalado (`scale_str`, `scale_int`, `scale_dex`) y Estados On-Hit**: Si la carta tiene `uses_weapon_damage = true` y se cumplen los requisitos, suma al daño de la carta:
   $$\text{Daño Arma} = \text{base\_damage} + \lfloor \text{STR}\cdot\text{scale\_str} + \text{INT}\cdot\text{scale\_int} + \text{DEX}\cdot\text{scale\_dex} \rfloor$$
   Además, inyecta automáticamente las cargas `inflict_poison`, `inflict_burn`, `inflict_hemorrhage` e `inflict_shock` del arma al combo.
4. **Mochila de Armas (`inventory_weapons`)**: El jugador puede guardar hasta **4 armas en su mochila** (`MAX_INVENTORY_SIZE = 4`) y cambiar su arma equipada desde `InventoryModalView` tanto en el mapa como en combate.

### Anatomía Visual de las Armas (`WeaponUI` + `WeaponData`)

En el modal de **Inventario** (`InventoryModalView`), tanto el arma equipada como las armas guardadas en la mochila se renderizan mediante `ui/weapons/weapon_ui.tscn` y `ui/weapons/weapon_ui.gd` con una estructura de 5 bloques:

```text
┌──────────────────────────────────────────────┐
│  Nombre del Arma                 [Rareza]    │  <- Título sobrio + Rareza coloreada
├──────────────────────────────────────────────┤
│                                              │
│         [ Marco / Pedestal ]                 │
│          ( Sprite del Arma )                 │  <- Visual claro del arma (`artwork` o glifo)
│                                              │
├──────────────────────────────────────────────┤
│  🏷️ Tipo de Arma: Daga / Espada / etc.       │  <- Misma píldora de compatibilidad que `CardUI`
├──────────────────────────────────────────────┤
│  ESTADÍSTICAS / ESCALADO                     │
│  • Daño Base: 2                              │  <- Números clave, escalado, requisitos
│  • Efecto Pasivo: "Las cartas de DAGA        │     y estado On-Hit
│    aplican +2 Hemorragia."                   │
├──────────────────────────────────────────────┤
│  LORE / DESCRIPCIÓN                          │
│  "Hoja corta utilizada por asesinos de la    │  <- Párrafo de historia en cursiva (`[i]`)
│   corte interior..."                         │     y tono gris atenuado
└──────────────────────────────────────────────┘
```

Hacer clic directamente sobre cualquier tarjeta `WeaponUI` de la mochila (o en su botón inferior `EQUIPAR ARMA`) intercambia en el acto el arma activa con la de la mochila.

### Catálogo de Armas implementadas (`weapons/data/`)

| Arma (`archivo.tres`) | Rareza (`Tier`) | Clase (`WeaponData.Class`) | Daño Base | Requisitos (`STR / INT / DEX`) | Escalado (`STR / INT / DEX`) | Efecto Pasivo On-Hit | Lore (`lore`) |
|---|---|---|---|---|---|---|---|
| **Palito** (`arma_basica.tres`) | Común (`0`) | `ANY` (`0`) | 3 | 0 / 0 / 0 | 0 / 0 / 0 | — | *"Una rama nudosa arrancada de un roble seco a la entrada de la cripta. No impone respeto, pero golpea mejor que un puño desnudo."* |
| **Báculo Básico** (`baculo.tres`) | Poco Común (`1`) | `STAFF` (`3`) | 3 | **3** / 0 / 0 | 0 / **1.0** / 0 | — | *"Tallado en madera de fresno ceniciento por aprendices del Círculo Interior. Canaliza el intelecto del portador en descargas elementales puras."* |
| **Daga** (`dagger.tres`) | Poco Común (`1`) | `DAGGER` (`4`) | 2 | **1** / 0 / **3** | 0 / 0 / **0.4** | **+2 Hemorragia** | *"Hoja corta utilizada por asesinos de la corte interior. El filo dentado conserva un leve brillo carmesí que abre heridas imposibles de cerrar."* |
| **Espadón** (`espadon.tres`) | Poco Común (`1`) | `HEAVY` (`2`) | 5 | 0 / 0 / 0 | 0 / 0 / 0 | **+2 Hemorragia** | *"Una mole de hierro negro concebida para partir escudos y armaduras de un solo tajo. Su propio peso desgarra la carne al impactar."* |
| **Katana Básica** (`katana_basica.tres`) | Rara (`2`) | `KATANA` (`5`) | 5 | **4** / 0 / 0 | 0 / 0 / 0 | — | *"Forjada mediante cien pliegues de acero templado en agua helada. Exige un brazo firme, pero su corte es tan limpio que la víctima tarda en notarlo."* |

---

## Estados Alterados y Reacciones Elementales

### Los 5 Estados Alterados (`Enemy`)

| Estado | ID | Mecánica de Resolución / Tick | Decaimiento por Turno |
|---|---|---|---|
| **Quemadura** | `"burn"` | Al final del turno del jugador, inflige daño fijo igual a las cargas actuales (`burn`). | Se reduce a la mitad (`int(burn * 0.5)`). |
| **Veneno** | `"poison"` | Al final del turno del jugador, inflige daño fijo igual a las cargas actuales (`poison`). | Reduce 1 carga por turno (`STATUS_DECAY_PER_TURN = 1`). |
| **Congelamiento** | `"freeze"` | Reduce el daño de ataque enemigo en `freeze` puntos. Si llega a **5 cargas (`FREEZE_STUN_THRESHOLD`)**, **congela por completo al enemigo** (pierde su turno). | Si congeló por completo ($\ge 5$), se rompe y pasa a `0`. Si era $< 5$, reduce 1 carga al final del turno enemigo. |
| **Electrocutado** | `"shock"` | Al inicio del turno enemigo, tira probabilidad de **Parálisis**: `12% por carga + 3% por punto de Suerte` (mín. 5%, máx. **80%**). Si acierta, el enemigo pierde su turno. | Si paraliza al enemigo, se descarga a `0`. Si falla, reduce 1 carga. |
| **Hemorragia** | `"hemorrhage"` | Posee un **umbral de estallido dinámico**: empieza en **10 cargas** (`HEMORRHAGE_BURST_THRESHOLD`) y sube **+5 por cada estallido previo** en ese combate. Si supera el umbral, detona un **Estallido de Sangre** que inflige entre **10% y 25% del HP actual del enemigo** (interpolado por Suerte hasta 12 LUCK) y se resetea a `0`. Si no alcanza el umbral, inflige daño igual a las cargas. | Tras hacer daño sin estallar, reduce **4 cargas** por turno. |

### Reacciones Elementales (`StatusReactions`)

Cuando un combo aplica estados sobre un enemigo (`enemy.apply_statuses()`), antes de sumarlos normalmente se verifica si el estado futuro (`actual + entrante`) activa alguna reacción elemental. Si se detona una reacción, se consumen las cargas indicadas, se inflige daño instantáneo y los estados consumidos no vuelven a hacer tick en ese mismo fin de turno:

| Reacción | ID | Condición (`requires`) | Cargas Consumidas (`consumes`) | Efecto Instantáneo |
|---|---|---|---|---|
| **¡VAPORIZACIÓN!** | `"vaporize"` | `burn >= 1` y `freeze >= 1` | Hasta `3 Burn` y `3 Freeze` | **15 de daño fijo** al enemigo |
| **¡SUPERCONDUCTOR!** | `"superconductor"` | `freeze >= 1` y `shock >= 1` | Todas (`99 Freeze`, `99 Shock`) | **20 de daño fijo** al enemigo |
| **¡COMBUSTIÓN TÓXICA!** | `"combustion"` | `burn >= 1` y `poison >= 1` | Todo el veneno (`99 Poison`) | **10 de daño fijo** al enemigo |

### Estados adicionales en diseño (`🚧 [FUTURO / PENDIENTE]`)
- **Vulnerable / Weak / Frágil** sobre el jugador o el enemigo mediante un sistema desacoplado en `systems/statuses/` (`🚧 [FUTURO / PENDIENTE]`).

---

## Enemigos e IA

### Escalado Matemático por Planta (`Enemy._init`)
Cuando `RunState.create_enemy_for_room()` instancia un enemigo en la planta `current_floor`, sus estadísticas escalan automáticamente:
- **Enemigo Normal (`is_boss == false`)**:
  - $\text{Max HP} = \text{base\_hp} + (\text{current\_floor} - 1) \times 25$
  - $\text{Intent Damage} = \text{base\_damage} + (\text{current\_floor} - 1) \times 3$
- **Jefe de Planta (`is_boss == true`)**:
  - $\text{Max HP} = \text{base\_hp} + (\text{current\_floor} - 1) \times 45$
  - $\text{Intent Damage} = \text{base\_damage} + (\text{current\_floor} - 1) \times 4$

### Composición de IA (`EnemyAI` + `EnemyBehavior`)
Cada `EnemyData` contiene un array `intent_pattern: Array[EnemyBehavior]`. En cada turno (`turn_count`), `EnemyAI.decide_intent()` consulta en orden los behaviors y ejecuta el primero que no retorne `null`. Si ninguno aplica (o si el array está vacío), ejecuta un ataque básico por `get_effective_intent_damage()`.

### Catálogo de Enemigos implementados (`entities/enemies/data/`)

| Enemigo (`archivo.tres`) | Tipo | HP Base (Planta 1) | Daño Base (Planta 1) | Patrón de IA (`intent_pattern`) |
|---|---|---|---|---|
| **Esqueleto** (`esqueleto.tres`) | Común | 50 | 10 | `[DefendBehavior(block=5, every_n_turns=2)]` → Gana +5 Escudo en turnos pares (`0, 2, 4...`) y ataca por 10 DMG (escalado) en turnos impares. |
| **JEFE** (`jefe_basico.tres`) | Boss (`is_boss = true`) | 76 | 14 | `[]` (Fallback: ataca todos los turnos por 14 DMG base + escalado de jefe). |

### Enemigos adicionales en diseño (`🚧 [FUTURO / PENDIENTE]`)
- **Goblin, Limo, Murciélago, Caballero Caído (Élite), Ogro del Bosque** (`🚧 [FUTURO / PENDIENTE]`).

---

## Mapa procedural (Matriz 8x8)

### Algoritmo de Generación (`FloorGenerator.generate_floor`)
En lugar de columnas lineales, cada planta se construye sobre una **grilla ortogonal de `8x8` celdas** usando una sub-semilla determinista (`get_floor_subseed(master_seed, floor_number)`):

1. **Escalado de tamaño por planta (`get_target_rooms_for_floor`)**:
   - Planta 1: **7 salas**
   - Planta 2: **9 salas** (+2)
   - Planta 3: **12 salas** (+3)
   - Planta 4: **16 salas** (+4)
   - Planta 5: **21 salas** (+5)
   - Planta 6: **27 salas** (+6)
   - Planta 7+: **28 salas** (`MAX_ROOMS_CAP`)
2. **Expansión de Frontera Anti-Apelotonamiento (`_expand_frontier`)**:
   - Coloca `START` en una de las 4 celdas centrales `(3,3), (4,3), (3,4), (4,4)`.
   - Expande ortogonalmente rechazando celdas que ya tengan 2 o más vecinos ocupados (evita bloques cuadrados 2x2 y fuerza corredores tipo laberinto).
3. **Asignación de Salas Especiales en Callejones sin Salida (`_assign_special_rooms`)**:
   - Identifica todas las hojas del grafo (`is_dead_end() == true`, salas con 1 sola conexión) y las ordena de **mayor a menor distancia Manhattan** respecto a `START`:
	 - **1.º más lejano:** `BOSS` (Jefe de la planta).
	 - **2.º más lejano:** `TREASURE` (Reliquia gratuita).
	 - **3.º más lejano:** `REST` (Hoguera).
	 - **4.º más lejano (o fallback en sala de combate a distancia > 1):** `SHOP` (1 Tienda garantizada por planta).
	 - **Planta $\ge 3$:** Callejón extra de `REST`.
	 - **Planta $\ge 4$:** Probabilidad dinámica (`45% base + 8%/piso + 7%/suerte`) de generar un **`SANCTUARY`** o un `TREASURE` adicional.
	 - **Planta 2-3 con `player_luck > 0`:** Probabilidad (`8% por punto de suerte`, máx. 65%) de un `TREASURE` extra.
4. **Niebla de Guerra (`discovered`)**:
   - Al iniciar la planta, solo `START` y sus vecinos ortogonales inmediatos están descubiertos. Despejar una sala revela a sus vecinos.
   - El jugador puede desplazarse a cualquier sala descubierta que sea vecina de su posición actual o de **cualquier sala ya despejada (`cleared`)**, permitiendo recorrer libremente los ramales del laberinto sin quedar atrapado en un callejón.

---

## Salas Especiales y Eventos

### Eventos implementados en el Mapa

| Tipo de Sala (`RoomData.Type`) | Nombre en Mapa | Mecánica implementada |
|---|---|---|
| **`START`** | `INICIO` | Punto de partida de la planta (aparece despejado). |
| **`COMBAT`** | `COMBATE` / `LIMPIA` | Encuentro contra enemigo común escalado al piso actual; al ganar abre `RewardView`. |
| **`BOSS`** | `JEFE` / `DERROTADO` | Encuentro contra Jefe escalado; al ganar abre `RewardView` y luego avanza a la siguiente planta (`current_floor + 1`). |
| **`TREASURE`** | `RELIQUIA` / `SAQUEADO` | Otorga inmediatamente 1 reliquia aleatoria ponderada por `RaritySystem` (evitando duplicadas). |
| **`REST`** | `HOGUERA` / `USADO` | Cura instantáneamente entre **25 y 50 HP**, interpolado suavemente según `player_luck` (alcanza 50 HP con 12 de Suerte). |
| **`SANCTUARY`** | `SANTUARIO` / `BENDECIDO` | Abre `SanctuaryModalView` con 2 opciones:<br>1. **Don del Artefacto**: Otorga +1 Reliquia (con bonus de fortuna $+1.0$ por piso hasta $+4.0$) y cura entre **25% y 50% del HP máximo** según Suerte.<br>2. **Vitalidad Inmortal**: Aumenta el **HP Máximo permanente entre +5 y +25** según Suerte y cura esa misma cantidad. |
| **`SHOP`** | `TIENDA` | Abre `ShopView` (permite salir y volver a entrar todas las veces que se quiera dentro de la misma planta conservando el stock). |

### Eventos narrativos adicionales (`🚧 [FUTURO / PENDIENTE]`)
- Sistema genérico `EventData` / `EventChoice` (`El Mercader Errante`, `El Espejo Roto`) en `systems/events/` y `scenes/event/` (`🚧 [FUTURO / PENDIENTE]`).

---

## Sistema de rarezas y Suerte

Implementado en `core/run/rarity_system.gd` con **5 Tiers** y escalado dinámico por **Fortuna**:

$$\text{Fortuna} = \max\left(0.0,\; (\text{floor\_number} - 1) \times 1.5 + \text{player\_luck} \times 2.5 + \text{bonus\_fortune}\right)$$

| Tier (`RaritySystem.Tier`) | Nombre UI | Color UI | Fórmula de Peso (`get_tier_weights`) | Peso Base (Piso 1, Luck 0) |
|---|---|---|---|---|
| `COMMON` (`0`) | `"Comun"` | Gris `(0.72, 0.76, 0.82)` | $\max(10.0,\; 52.0 - \text{fortuna} \times 3.8)$ | `52.0` (~52%) |
| `UNCOMMON` (`1`) | `"Poco Comun"` | Verde `(0.18, 0.80, 0.44)` | $28.0 + \text{fortuna} \times 1.0$ | `28.0` (~28%) |
| `RARE` (`2`) | `"Rara"` | Azul `(0.25, 0.62, 1.0)` | $15.0 + \text{fortuna} \times 1.8$ | `15.0` (~15%) |
| `EPIC` (`3`) | `"Epica"` | Violeta `(0.72, 0.30, 1.0)` | $4.5 + \text{fortuna} \times 1.2$ | `4.5` (~4.5%) |
| `LEGENDARY` (`4`) | `"Legendaria"` | Dorado `(1.0, 0.75, 0.15)` | $\max(0.5,\; 0.5 + \text{fortuna} \times 0.8)$ | `0.5` (~0.5%) |

---

## Economía y Tienda

### Obtención de Oro
- **Oro inicial**: Depende del héroe (`100` Guerrero/DEMO, `120` Mago, `200` Samurai, `678` Asesino).
- **Recompensa por combate (`generate_combat_rewards`)**: `10 + (current_floor * 2) + randi() % 5` de oro garantizado (se cobra tanto al elegir carta como al saltar la selección).

### Tienda del Bazar (`ShopView`)
Cada tienda ofrece **3 cartas** y **2 reliquias** sin repetir (generadas de forma determinista con la semilla de las coordenadas de la sala). Los precios son fijos según el `RaritySystem.Tier`:

| Rareza (`Tier`) | Precio de Carta en Tienda | Precio de Reliquia en Tienda |
|---|---|---|
| **Común (`COMMON`)** | 45 Oro | 120 Oro |
| **Poco Común (`UNCOMMON`)** | 60 Oro | 140 Oro |
| **Rara (`RARE`)** | 75 Oro | 160 Oro |
| **Épica (`EPIC`)** | 120 Oro | 220 Oro |
| **Legendaria (`LEGENDARY`)** | 180 Oro | 300 Oro |

- **Servicio de remover carta en tienda**: `🚧 [FUTURO / PENDIENTE]`.

---

## Progresión meta y Guardado

Implementado en `autoload/persistence_manager.gd`:
- **3 Ranuras de Guardado (`user://saves/slot_1..3/`)**:
  - `profile.json`: Nombre del jugador, fecha de creación, `unlocked_heroes` y estadísticas históricas (`runs_started`, `runs_won`, `highest_floor`, `total_enemies_killed`).
  - `run.json`: Snapshot completo de la partida en curso (`master_seed`, `current_floor`, héroe, arma equipada, mochila de armas, posición en la grilla 8x8, salas despejadas y descubiertas, stats actuales, mazo completo y reliquias).
- **Auto-login (`user://last_slot.cfg`)**: Recuerda la última ranura activa para reanudar sin fricción al abrir el juego.
- **Permadeath estricto**: Cuando el jugador muere en combate o abandona la partida desde el menú de pausa, `delete_active_run()` elimina físicamente `run.json` y registra la derrota y el piso alcanzado en `profile.json`.

---

## Balance numérico

Constantes actuales en `core/constants/combat_constants.gd`:

```gdscript
# --- UMBRALES Y BALANCE DE ESTADOS (STATUS EFFECTS) ---
const FREEZE_STUN_THRESHOLD: int = 5
const HEMORRHAGE_BURST_THRESHOLD: int = 10
const HEMORRHAGE_THRESHOLD_SCALING: int = 5
const STATUS_DECAY_PER_TURN: int = 1

const SHOCK_STUN_CHANCE_PER_STACK: float = 0.12
const SHOCK_LUCK_BONUS_PER_POINT: float = 0.03
const SHOCK_MAX_STUN_CHANCE: float = 0.80

# --- REGLAS BASE DEL JUGADOR Y COMBATE ---
const BASE_HAND_SIZE: int = 5
const BASE_MAX_ENERGY: int = 3
const BASE_DISCARDS_PER_COMBAT: int = 2
const BASE_LUCKY: int = 1
const BASE_HEALTH: int = 50
const BASE_GOLD: int = 100
const BASE_STR: int = 1
const BASE_DEX: int = 1
const BASE_INT: int = 1

# --- BONUS DE COMBOS (Catalizador de Combo) ---
const BASE_MIN_CARDS_REQUIERED: int = 3
const BASE_BONUS_DMG: int = 6
const BASE_BONUS_SHIELD: int = 5

const MAX_INVENTORY_SIZE: int = 4
```

---

## UI/UX

### Layout de Batalla (`battle_table.tscn` + `BattleHUD`)

```text
┌─────────────────────────────────────────────────────────────────────────────────┐
│ [F3] DEBUG                                                                      │
│   ┌─────────────────────────────────────────────────────────────────────────┐   │
│   │ Esqueleto  |  HP: 50 / 50  |  🛡 5  |  Defensa: +5 Bloqueo              │   │
│   │ Estados: Quemadura: 2  |  Congelamiento: 2/5  |  Electrocutado: 3 (39%) │   │
│   └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                 │
│   ┌─────────────────────────────────────────────────────────────────────────┐   │
│   │                              ZONA DE COMBO                              │   │
│   │        [ Golpe Ígneo ]     [ Golpe Congelante ]     [ Sobrecarga ]      │   │
│   └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                 │
│       COMBO ACTIVO:   16 DAÑO   |   +2 QUEMADURA   |   +2 CONGELAMIENTO   | x2  │
│                                                                                 │
│   ┌──────────────┐  ┌───────────────────────────────────────────────────────┐   │
│   │ GUERRERO     │  │                        MANO                           │   │
│   │ ❤️: 50 / 50  │  │   [ Escudo ]        [ Estocada ]        [ Robo ]      │   │
│   │ 🛡️: +8       │  │    +8 Escudo         Costo: 1            Roba +1      │   │
│   │ 🗡️: Espadon  │  │    Costo: 1          [Comun]          [INSTANTANEO]   │   │
│   │ ⚡: 4 / 4    │  └───────────────────────────────────────────────────────┘   │
│   │ 🍀: 1        │                                      [Grito de Guerra (1/1)] │
│   └──────────────┘                                      [EJECUTAR COMBO]        │
│   [INVENTARIO]                                          [DESCARTAR (2)]         │
│   [Mazo (4)]                                            [Descarte (0)]          │
│                                                         [Cementerio (0)]        │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### Interacciones clave en Menús, Combate y Mapa
- **Selección de Héroe (`HeroSelectView` + `HeroCardView`)**: Las tarjetas de héroe reaccionan con física de resorte exponencial igual que las cartas de batalla: en reposo quedan ligeramente retraídas (`0.95x`) con un tinte gris acero suave; al pasar el mouse crecen a `1.04x` encendiendo el color de acento de su clase; y al hacer clic pegan un pulso elástico (`1.13x`) quedando fijas y destacadas al frente en `1.08x` con el color vivo de hover.
- **Clic rápido en carta de la mano**: Si es instantánea (`Robo`), se consume en el acto; si es normal y hay energía, sube al final de la `ComboZone`.
- **Clic rápido en carta de la `ComboZone`**: La devuelve a la mano y reembolsa su energía.
- **Drag & Drop en `ComboZone` / `HandZone`**: Permite arrastrar cartas entre zonas e **intercalar su orden horizontalmente en vivo**, recalculando instantáneamente el `ComboBanner`.
- **Botón `INVENTARIO`**: Abre `InventoryModalView` para ver `STR / INT / DEX / LUCK` y cambiar el arma equipada desde la mochila.
- **Botones `Mazo`, `Descarte`, `Cementerio`**: Abren `PileInspector` mostrando el conteo agrupado de cartas en esa pila.
- **`ESC`**: Abre `PauseMenuView` (Continuar, Abandonar Partida con confirmación, Guardar y Salir).
- **`F3` / `F4`** *(solo builds debug)*: Abre/oculta el `DebugOverlay`.

---

## Arte y audio

- **Estado actual**: Toda la interfaz está construida con estilizado procedural (`StyleBoxFlat`, bordes temáticos por rareza/tipo de sala, texto BBCode y animaciones por `Tween` / resortes exponenciales). Las carpetas `assets/audio/`, `assets/fonts/` y `assets/textures/` están preparadas con `.gitkeep`.
- **Implementación de sprites, shaders custom y pistas de audio**: `🚧 [FUTURO / PENDIENTE]`.

---

## Roadmap

### Fase 1: Core & Combate por Combos (Completado ✅)
- [x] Combate 1v1 con `ComboZone`, reordenamiento drag & drop y `ComboBanner` predictivo.
- [x] Mazo con 3 pilas (`draw_pile`, `discard_pile`, `graveyard_pile`) y cartas instantáneas.
- [x] 5 estados alterados (`Burn`, `Poison`, `Freeze`, `Shock`, `Hemorrhage`) y 3 reacciones elementales (`StatusReactions`).
- [x] Sistema de Armas con clases, requisitos/escalado RPG (`STR`, `INT`, `DEX`) y mochila de hasta 4 armas.
- [x] 5 perfiles de héroe `.tres` y habilidades activas (`HeroAbility`).
- [x] IA enemiga componible mediante `EnemyBehavior` (`Attack`, `Defend`, `Charge`).

### Fase 2: Loop de Expedición y Persistencia (Completado ✅)
- [x] Generador procedural de pisos `FloorGenerator` en grilla ortogonal `8x8` con niebla de guerra.
- [x] Salas de Combate, Jefe, Tesoro, Hoguera (`REST`), Santuario (`SANCTUARY`) y Tienda (`SHOP`).
- [x] Pantalla de recompensas `RewardView` con animaciones estilo Balatro.
- [x] Máquina de estados `RunStateMachine` y `RunDirector`.
- [x] Sistema de guardado atómico JSON en 3 slots (`PersistenceManager`) y `DebugOverlay` (`F3`/`F4`).

### Fase 3: Testing, Subsistemas y Contenido (`🚧 [FUTURO / PENDIENTE]`)
- [ ] Escribir suites de tests automatizados con GUT en `test/combat/`, `test/deck/` y `test/run/` (`🚧 [FUTURO / PENDIENTE]`).
- [ ] Implementar wrappers `CardInstance` (`cards/card_instance.gd`) y `RelicInstance` para upgrades de cartas en partida (`🚧 [FUTURO / PENDIENTE]`).
- [ ] Implementar eventos narrativos con opciones (`systems/events/` y `scenes/event/`) (`🚧 [FUTURO / PENDIENTE]`).
- [ ] Agregar servicio de eliminar/mejorar cartas en Tienda y Hoguera (`🚧 [FUTURO / PENDIENTE]`).
- [ ] Expandir catálogo de enemigos comunes, élites y jefes por planta (`🚧 [FUTURO / PENDIENTE]`).
- [ ] Integrar assets visuales y SFX/música en `assets/` (`🚧 [FUTURO / PENDIENTE]`).

---

## Matriz de transiciones legales (FSM)

Definida en `core/run/run_state_machine.gd`:

| Desde \ Hacia | MENU | MAP | BATTLE | REWARD | EVENT | SHOP | DEAD | VICTORY |
|---|---|---|---|---|---|---|---|---|
| **MENU** | — | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| **MAP** | ❌ | — | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ |
| **BATTLE** | ❌ | ❌ | — | ✅ | ❌ | ❌ | ✅ | ❌ |
| **REWARD** | ❌ | ✅ | ❌ | — | ❌ | ✅ | ❌ | ❌ |
| **EVENT** | ❌ | ✅ | ✅ | ❌ | — | ❌ | ✅ | ❌ |
| **SHOP** | ❌ | ✅ | ❌ | ❌ | ❌ | — | ❌ | ❌ |
| **DEAD** | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | — | ❌ |
| **VICTORY** | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | — |

> **Nota:** En `RunDirector._on_pause_abandon_run()`, cuando el jugador abandona la run desde pausa (estando en `MAP`, `BATTLE` o `SHOP`), la transición hacia `MENU` hoy emite un `push_error` en la FSM si el estado previo no era `DEAD` o `VICTORY`. Se recomienda transicionar primero a `DEAD` o habilitar `to == State.MENU` desde cualquier estado al abandonar.

---

## Open questions

1. **¿Cómo se consiguen nuevas armas durante la run?** Actualmente cada héroe inicia con su `starting_weapon` y se pueden inyectar armas a la mochila desde el `DebugOverlay` (`F3`). Falta definir si las armas dropearán en salas de `TREASURE` / `BOSS` o si tendrán su propia sección en `ShopView` (`🚧 [FUTURO / PENDIENTE]`).
2. **¿Condición de `VICTORY` final?** Actualmente al derrotar al `BOSS` de una planta, `RunDirector._clear_room_after_combat()` avanza indefinidamente a `current_floor + 1` (escalando hasta 28 salas en Planta 7+). Falta definir en qué planta se dispara `RunStateMachine.State.VICTORY` en lugar de generar otro piso.
3. **¿Pociones / Consumibles?** Evaluar si las cartas `single_use` (que van al Cementerio) cubren ese rol o si se agregará un cinturón de pociones separado.
