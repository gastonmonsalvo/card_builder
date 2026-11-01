# Game Design Document (GDD)

**Card Prototype** — Roguelike deckbuilder en Godot 4.

Última actualización: 2026-11-01
Estado: prototipo

---

## Tabla de contenidos

1. [Visión general](#visión-general)
2. [Público objetivo](#público-objetivo)
3. [Inspiraciones](#inspiraciones)
4. [Core loop](#core-loop)
5. [Mecánicas principales](#mecánicas-principales)
6. [Héroes](#héroes)
7. [Cartas](#cartas)
8. [Reliquias](#reliquias)
9. [Armas](#armas)
10. [Statuses](#statuses)
11. [Enemigos](#enemigos)
12. [Mapa procedural](#mapa-procedural)
13. [Eventos](#eventos)
14. [Sistema de rarezas](#sistema-de-rarezas)
15. [Economía](#economía)
16. [Progresión meta](#progresión-meta)
17. [Balance numérico](#balance-numérico)
18. [UI/UX](#uiux)
19. [Arte y audio](#arte-y-audio)
20. [Roadmap](#roadmap)

---

## Visión general

**Card Prototype** es un roguelike deckbuilder de un solo jugador donde cada partida es una run procedural distinta. El jugador construye su mazo en partida, combina reliquias y armas para sinergias únicas, y asciende por un mapa procedural hasta derrotar al boss final.

**Premisa narrativa**: tres aventureros (guerrero, mago, pícaro) descienden a una mazmorra antigua buscando un artefacto legendario. Cada piso es más profundo y peligroso. La muerte es permanente dentro de la run; el meta-progreso desbloquea nuevas cartas, reliquias y héroes.

### Pilares de diseño

1. **Cada run se siente distinta**: combinaciones de mazo + reliquias + mapa generan runs memorables.
2. **Decisiones significativas**: cada carta jugada, cada nodo del mapa elegido, cada compra importa.
3. **Profundidad sobre complejidad**: pocas mecánicas que se combinan en formas ricas (no 30 sistemas superficiales).
4. **Legible**: el jugador siempre entiende qué va a pasar antes de jugar una carta. Intents del enemigo claros, interacciones predecibles.
5. **Ajustable**: balance centralizado en `.tres` y constantes para iterar rápido.

---

## Público objetivo

- Fans de *Slay the Spire*, *Monster Train*, *Inscryption*, *Balatro*.
- Jugadores que disfrutan optimización y sinergias.
- Sesiones de 30-60 minutos por run.
- Plataforma inicial: PC (Windows/Linux/Mac). Consola (Switch) como objetivo secundario.

---

## Inspiraciones

| Juego | Qué tomamos | Qué NO tomamos |
|---|---|---|
| Slay the Spire | Mapa de nodos, statuses (vulnerable/weak), intents enemigos, rarezas | — |
| Monster Train | Múltiples pisos por run | No multilane, solo 1 lane |
| Inscryption | Cartas con efectos narrativos | No horror/ARG |
| Balatro | Sinergias explosivas | No poker scoring |

---

## Core loop

```
┌─────────────────────────────────────────────────────┐
│  MENU PRINCIPAL                                     │
│  → Seleccionar slot (3 disponibles)                 │
│  → Seleccionar héroe                                │
└─────────────────────────────────────────────────────┘
						│
						▼
┌─────────────────────────────────────────────────────┐
│  MAPA (procedural por piso)                         │
│  Elegir próximo nodo: BATTLE / ELITE / EVENT /     │
│  SHOP / REST / TREASURE                             │
└─────────────────────────────────────────────────────┘
						│
						▼
┌─────────────────────────────────────────────────────┐
│  BATALLA (1v1 a 1v3)                               │
│  Robar 5, 3 energía/turno                           │
│  Jugar cartas, terminar turno                       │
│  Enemigo muestra intent antes de actuar             │
└─────────────────────────────────────────────────────┘
						│
						▼
┌─────────────────────────────────────────────────────┐
│  RECOMPENSA                                          │
│  Elegir 1 de 3 cartas (raridad roll)                │
│  + oro                                               │
│  Posible relic drop                                  │
└─────────────────────────────────────────────────────┘
						│
						▼
				  (volver a MAPA)
						│
						▼ al llegar al final del piso
┌─────────────────────────────────────────────────────┐
│  BOSS del piso                                       │
│  Recompensa: relic garantizada + carta rare          │
└─────────────────────────────────────────────────────┘
						│
						▼
				  (siguiente piso, más difícil)
						│
						▼ al piso 3
┌─────────────────────────────────────────────────────┐
│  BOSS FINAL                                          │
│  → VICTORIA                                          │
└─────────────────────────────────────────────────────┘
```

### Duración estimada

| Hito | Tiempo |
|---|---|
| 1 piso | 8-12 min |
| 3 pisos (run completa) | 30-45 min |
| Run + muerte temprana | 10-20 min |

---

## Mecánicas principales

### Energía

- **3 energía por turno** (`combat_constants.STARTING_ENERGY`).
- Las cartas cuestan 0, 1, 2 o 3 energía.
- La energía **no** se acumula entre turnos. Al terminar turno, se resetea.
- Modificadores: reliquias/efectos pueden dar energía extra temporaria.

### Mano

- **5 cartas por robo** al inicio de turno.
- Sin límite máximo de mano (puede subir por efectos).
- Al terminar turno, **descarta toda la mano** al pile de descarte.

### Mazo

- Mazo inicial depende del héroe (10 cartas base).
- Al ganar batalla, **elegís 1 carta de 3** para agregar al mazo.
- **No hay forma de sacar cartas del mazo** excepto eventos especiales (descanso, relic específica).
- Capacidad de mazo: ilimitada, pero mazo muy grande diluye consistencia (constituye balance natural).

### Robo y pilas

3 pilas gestionadas por `deck_manager.gd`:
- `draw_pile`: cartas no robadas todavía.
- `hand`: cartas en mano del jugador.
- `discard_pile`: cartas ya jugadas.

Cuando `draw_pile` está vacío y se pide robar, **se mezcla el `discard_pile` y se convierte en el nuevo `draw_pile`**.

### Block (escudo)

- Cartas de skill dan `block`.
- Block absorbe daño antes de tocar HP.
- **Block se resetea al inicio del turno del jugador** (no persiste entre turnos).
- Block enemigo persiste hasta que recibe daño que lo elimina.

### Intent enemigo

Antes de actuar, cada enemigo muestra un **intent** visible:
- Icono de espada + número = va a hacer X daño.
- Icono de escudo + número = va a ganar X block.
- Icono de status = va a aplicar un status.

Esto permite al jugador planificar su turno: si el enemigo va a hacer 10 daño, ¿me conviene bloquear o atacar para matarlo antes?

### Tipos de carta

| Tipo | Tag | Descripción |
|---|---|---|
| Attack | `"attack"` | Causa daño al enemigo. Afectada por `Strength` (+1 daño/stack) y `Weak` (-25% daño). |
| Skill | `"skill"` | Utilidad: block, draw, heal, statuses. No afectada por Strength. |
| Power | `"power"` | Efecto permanente por el resto del combate. Se descarta del mazo tras jugarla. |

### Objetivos

- HP del héroe llega a 0 → **muerte, run termina**.
- Derrotar al boss final del piso 3 → **victoria**.

---

## Héroes

Tres clases jugables, cada una con un estilo distinto.

### Guerrero

- **Max HP**: 80
- **Mazo inicial** (10 cartas):
  - 5x Tajo (Attack, 1 cost, 6 daño)
  - 3x Bloqueo (Skill, 1 cost, 5 block)
  - 2x Golpe Fuerte (Attack, 2 cost, 14 daño)
- **Reliquia inicial**: `anillo_brasas` (cartas de ataque +2 daño).
- **Habilidad**: `Grito de Guerra` — 1 uso por combate, gana 3 Strength por 2 turnos.
- **Estilo**: tanky, lentamente domina con Strength acumulada.

### Mago

- **Max HP**: 60
- **Mazo inicial** (10 cartas):
  - 4x Estocada (Attack, 1 cost, 4 daño + robar 1)
  - 3x Meditar (Skill, 0 cost, robar 2)
  - 2x Llama (Attack, 1 cost, aplicar Veneno 2)
  - 1x Bola de Fuego (Attack, 2 cost, 10 daño + 2 Veneno a todos)
- **Reliquia inicial**: `baculo` (+0 daño, +1 Strength al inicio de combate).
- **Habilidad**: `Flujo Arcano` — 1 uso por combate, robar 3 cartas gratis.
- **Estilo**: cycle de mazo, sinergias con Veneno y daño en area.

### Pícaro

- **Max HP**: 50
- **Mazo inicial** (10 cartas):
  - 4x Puñalada (Attack, 0 cost, 3 daño)
  - 3x Sigilo (Skill, 1 cost, +5 block + robar 1)
  - 2x Emboscada (Attack, 1 cost, 8 daño si enemigo tiene 50% HP o menos)
  - 1x Asesinato (Attack, 2 cost, 20 daño)
- **Reliquia inicial**: `ojo_auditivo` (+1 energía en el primer turno de cada combate).
- **Habilidad**: `Sombra` — 1 uso por combate, este turno las cartas cuestan 0 energía.
- **Estilo**: burst, combos de cartas baratas, ejecución.

---

## Cartas

Catálogo inicial (extensible). Formato: **Nombre** (tipo, cost, efecto).

### Comunes

| Carta | Cost | Tipo | Efecto |
|---|---|---|---|
| Tajo | 1 | Attack | 6 daño |
| Estocada | 1 | Attack | 4 daño + robar 1 |
| Bloqueo | 1 | Skill | 5 block |
| Meditar | 0 | Skill | Robar 2 |
| Puñalada | 0 | Attack | 3 daño |
| Golpe Fuerte | 2 | Attack | 14 daño |
| Llama | 1 | Attack | 4 daño + Veneno 2 |
| Sigilo | 1 | Skill | 5 block + robar 1 |

### Infrecuentes

| Carta | Cost | Tipo | Efecto |
|---|---|---|---|
| Emboscada | 1 | Attack | 8 daño (12 si HP enemigo ≤ 50%) |
| Bola de Fuego | 2 | Attack | 10 daño + Veneno 2 a todos los enemigos |
| Curación | 1 | Skill | Curar 8 HP |
| Ira | 1 | Power | +2 Strength permanente |
| Reflejo | 1 | Skill | 6 block + 3 daño al atacante siguiente |

### Raras

| Carta | Cost | Tipo | Efecto |
|---|---|---|---|
| Asesinato | 2 | Attack | 20 daño |
| Tormenta | 3 | Attack | 6 daño a todos los enemigos x3 |
| Fortaleza | 2 | Power | +3 Dexterity permanente |
| Renacer | 3 | Skill | Curar a full HP. Exhaust. |

### Criterios de diseño

- **Ataques comunes**: damage/cost ≈ 6. Variaciones con sub-efectos reducen damage.
- **Skills**: valor ≈ 5 block o 2 draw por 1 cost.
- **Powers**: deben ser impactantes para justificar no reciclarse.
- **Raras**: pueden romper reglas de eficiencia.

---

## Reliquias

Las reliquias son **pasivas o reactivas**, persisten toda la run.

### Comunes

| Reliquia | Efecto |
|---|---|
| Anillo de Brasas | Cartas de ataque hacen +2 daño |
| Piedra de Vida | +10 HP máximo |
| Bolsa del Aventurero | +25 oro al inicio de cada piso |

### Infrecuentes

| Reliquia | Efecto |
|---|---|
| Ojo Auditivo | +1 energía en el primer turno de cada combate |
| Daga Envenenada | Al jugar carta de ataque, 1 Veneno al enemigo |
| Capa Etérea | El primer golpe recibido cada combate hace 0 daño |

### Raras

| Reliquia | Efecto |
|---|---|
| Cenizas de Fénix | Al morir, resucitar con 50% HP (1 carga) |
| Corazón del Dragón | +3 Strength permanente (cada combate) |
| Espejo del Tiempo | Una vez por piso, rehacer la última acción |

### Boss (garantizadas al matar boss)

| Reliquia | Efecto |
|---|---|
| Alma del Vencedor | +1 energía máxima permanente |
| Garra del Demonio | Cartas cuestan -1 (mín 0), pero pierdes 1 HP al jugarlas |
| Corona del Rey | Al inicio de combate, todos los enemigos empiezan con 1 Vulnerable |

### Reglas de diseño de reliquias

1. **Sinergia > stacked stats**: preferimos reliquias que cambian cómo jugás sobre las que suman +X.
2. **Counterplay**: las reliquias con downside (`Garra del Demonio`) permiten construir alrededor.
3. **Triggerable**: cada reliquia debe disparar efectos visibles (no "+0.5% crit" invisible).

---

## Armas

Sistema de equipamiento. 1 arma activa por héroe, ocupa 1 o 2 slots de manos.

| Arma | Bonus | Slots | Especial |
|---|---|---|---|
| Arma Básica | +1 daño | 1 | — |
| Báculo | +0 daño | 1 | +1 Strength al inicio de combate |
| Espadón | +4 daño | 2 | Solo equipable por Guerrero |
| Katana Básica | +3 daño | 1 | Al atacar, aplicar Sangrado 2 |

### Diseño

- Las armas modifican el daño base de las cartas de ataque.
- El "daño base" de una carta = su valor en `.tres`. El arma aplica como modifier aditivo.
- `special_effect` puede aplicar un status, activar una vez por combate, etc.

---

## Statuses

###_statuses del jugador (positivos)

| Status | Efecto | Duración | Stack |
|---|---|---|---|
| Strength | +1 daño a cada carta de ataque | Permanente (combate) | ADD |
| Dexterity | +1 block a cada carta de skill | Permanente (combate) | ADD |
| Energía Arcana | +1 energía por turno | X turnos | REPLACE |

### Statuses del jugador (negativos)

| Status | Efecto | Duración | Stack |
|---|---|---|---|
| Vulnerable | +50% daño recibido | 3 turnos | REPLACE |
| Frágil | Block reduce en 25% | 3 turnos | REPLACE |

### Statuses del enemigo (aplicables)

| Status | Efecto | Duración | Stack |
|---|---|---|---|
| Veneno | Daño = stacks al final del turno del enemigo | Hasta curarse | ADD |
| Sangrado | Daño = stacks al atacar | 3 turnos | ADD |
| Vulnerable | +50% daño recibido | 3 turnos | REPLACE |
| Weak | -25% daño hecho | 3 turnos | REPLACE |
| Aturdir | No actúa este turno | 1 turno | REPLACE |

### Reglas de stack

- **REPLACE**: aplicar de nuevo resetea duration, no suma stacks.
- **ADD**: aplica stacks adicionales, duration se resetea al máximo.
- **MAX_CAP**: stacks hasta un máximo definido (Veneno: 99, Sangrado: 5).

---

## Enemigos

Sistema de IA
Los enemigos usan un sistema de behaviors componibles. Cada EnemyData declara un intent_pattern: Array[EnemyBehavior] que el EnemyAI itera para decidir el intent de cada turno. Si el array está vacío, el enemigo solo ataca (compatibilidad con el sistema viejo).

Behaviors disponibles:

AttackBehavior(damage, every_n_turns) — ataca cada N turnos.
DefendBehavior(block, every_n_turns) — gana escudo cada N turnos.
ChargeBehavior(bonus_multiplier, every_n_turns) — carga un turno, golpea fuerte el siguiente.
Ciclo de block: el escudo ganado en el turno del enemigo persiste durante tu próximo combo y se resetea al inicio del siguiente turno del enemigo (no entre medias).

### Comunes (Acto 1)

| Enemigo | HP | Patrón de IA | Loot |
|---|---|---|---|
| Esqueleto | 20-25 | Atacar (8 daño) | 8-12 oro |
| Goblin | 15-20 | Atacar (5 daño) + huir si HP<30% | 10-15 oro |
| Limo | 25-30 | Defensa (5 block) → Atacar (10 daño) | 6-10 oro |
| Murciélago | 12-18 | Atacar (4 daño) x2 | 5-8 oro |

### Élites (Acto 1)

| Enemigo | HP | Patrón | Loot |
|---|---|---|---|
| Caballero Caído | 45-50 | Atacar (12 daño) → Bloquear (10) → Atacar (15) | 25-35 oro + 1 relic garantizada |

### Bosses (Acto 1)

| Boss | HP | Mecánica |
|---|---|---|
| Ogro del Bosque | 80 | Carga 2 turnos → golpe 25 daño. Vulnerable al frente. |

### Acto 2 y 3 (placeholder)

A definir en iteración. Estructura similar con escalado de HP, nuevos patrones, mecánicas únicas (multi-fase, summons).

---

## Mapa procedural

### Estructura por piso

```
Piso = columnas conectadas
Cada columna: 2-4 nodos
Última columna: BOSS (1 nodo)

   [BATTLE] ─┬─ [EVENT] ── [BATTLE] ── [SHOP] ── [BOSS]
			 │
   [BATTLE] ─┴─ [ELITE] ── [REST] ──── [TREASURE] ─┘
```

### Tipos de nodo

| Nodo | Frecuencia | Descripción |
|---|---|---|
| BATTLE | 40% | Combate normal, recompensa de carta + oro |
| ELITE | 10% | Combate difícil, recompensa de relic garantizada |
| EVENT | 15% | Evento con choices |
| SHOP | 8% | Tienda (cartas, reliquias, poción) por oro |
| REST | 12% | Descansar (curar 30% HP) o forjar (+5 max HP) |
| TREASURE | 5% | Reliquia garantizada sin combate |
| BOSS | 1 por piso | Boss final, recompensa grande |

### Reglas de generación

1. **Garantizar camino al boss**: todos los caminos llegan al boss.
2. **Bifurcaciones**: cada nodo se conecta a 1-3 nodos de la columna siguiente.
3. **No backtrack**: solo se avanza hacia adelante.
4. **Semilla reproducible**: dado el `floor_num` y `seed`, el floor generado es idéntico.
5. **Dificultad escalante**: piso 2 tiene más élites, piso 3 tiene eventos más riesgosos.

---

## Eventos

Eventos con **choices**. Cada choice tiene riesgo/recompensa.

### Ejemplos

#### El Santuario Olvidado

> Un altar antiguo pulsa con energía. ¿Te acercas?

- **Rezar**: +5 max HP, pero -10 HP actuales.
- **Sacrificar sangre**: -15 HP, +1 relic aleatoria.
- **Ignorar**: nada.

#### El Mercader Errante

> Un mercader te ofrece un trato. 50 oro por una carta infrecuente aleatoria.

- **Aceptar**: -50 oro, +1 carta infrecuente.
- **Regatear**: 50% chance → -30 oro, +1 carta; 50% chance → -50 oro, nada.
- **Rechazar**: nada.

#### El Espejo Roto

> Ves tu reflejo hacer algo distinto a ti.

- **Cruzar el espejo**: -1 carta aleatoria del mazo, +1 relic rara.
- **Romperlo**: +20 oro, -2 cartas aleatorias del mazo.
- **Mirar y marcharse**: nada.

### Reglas de diseño

1. **Siempre una opción "ignorar"** para jugadores conservadores.
2. **Riesgo proporcional a recompensa**: alto riesgo = alta recompensa.
3. **Visible antes de decidir**: el jugador sabe qué puede perder.
4. **Algunos eventos pueden repetirse** en pisos distintos con variaciones.

---

## Sistema de rarezas

Cuando el jugador gana una carta, se rolla la rareza:

| Rareza | Peso piso 1 | Peso piso 2 | Peso piso 3 |
|---|---|---|---|
| COMMON | 70 | 60 | 50 |
| UNCOMMON | 25 | 30 | 35 |
| RARE | 5 | 10 | 15 |

Implementado en `core/run/rarity_system.gd`. `roll_rarity(floor_num) -> Rarity` devuelve un valor del enum.

### Reliquias

Las reliquias siguen un sistema similar pero con pool más pequeño (más control sobre qué drops):

| Rareza | Pool size | Drop chance |
|---|---|---|
| COMMON | 8 | 50% |
| UNCOMMON | 10 | 35% |
| RARE | 6 | 15% |

Bosses siempre dropean una **boss relic** específica (no rollada).

---

## Economía

### Oro

- Drop base por batalla: 8-15 oro.
- Drop por elite: 25-35 oro.
- Drop por boss: 50-80 oro.
- Eventos pueden dar/quitar oro.

### Tienda

- Cartas: precio = `10 + cost * 5` oro (común), `25 + cost * 8` (infrecuente), `50 + cost * 10` (rara).
- Reliquia: 100-150 oro (random pool).
- Poción (cuando se implemente): 50 oro.
- **Servicio de remover carta**: 75 oro, sube 25 por uso en la misma run.

### HP

- HP inicial depende del héroe (50-80).
- Descansar en REST cura 30% HP máximo.
- Cartas/events pueden curar.
- **No hay regen entre batallas** excepto eventos.

---

## Progresión meta

### Slots de guardado

3 slots. Cada slot guarda:
- Run actual (si está en curso).
- Stats del slot (partidas jugadas, victorias, derrotas).

### Stats globales

Compartidos entre slots:
- Total de oro ganado.
- Total de runs completadas.
- Enemigos derrotados (counter por tipo).
- Mejor tiempo de run.

### Unlocks (sistema de desbloqueo)

A definir. Sugerencia: unlocks basados en logros (matar X boss con héroe Y → desbloquea nueva carta inicial para ese héroe).

---

## Balance numérico

### Constantes (en `core/constants/combat_constants.gd`)

```gdscript
const STARTING_ENERGY: int = 3
const HAND_SIZE: int = 5
const BLOCK_DECAY_AT_TURN_END: bool = true  # block se resetea al inicio del turno del jugador
const POISON_TICK: bool = true               # poison aplica al final del turno del enemigo
const VULNERABLE_MULTIPLIER: float = 1.5
const WEAK_MULTIPLIER: float = 0.75
```

### Curva de daño esperada

| Costo | Daño ataque común | Block skill común | Draw skill común |
|---|---|---|---|
| 0 | 3-4 | — | 1-2 |
| 1 | 6-8 | 5-6 | 2 |
| 2 | 12-15 | 10-12 | 3 |
| 3 | 20-25 | 18-20 | 4-5 |

### HP enemigos por piso

| Piso | Común | Elite | Boss |
|---|---|---|---|
| 1 | 15-30 | 40-50 | 70-90 |
| 2 | 30-50 | 60-80 | 120-150 |
| 3 | 50-70 | 90-120 | 180-220 |

### Daño enemigo por piso

| Piso | Hit básico | Hit fuerte |
|---|---|---|
| 1 | 5-10 | 12-18 |
| 2 | 10-15 | 18-25 |
| 3 | 15-20 | 25-35 |

### Reglas de balance

1. **HP jugador > HP enemigo**: el héroe tiene 50-80 HP, los enemigos comunes 15-30. El jugador debe tomar muchos golpes para morir, pero cada uno importa.
2. **Combates duren 4-7 turnos**: ni muy cortos (aburridos) ni muy largos (slogs).
3. **Damage/energy ≈ 6-8 para comunes**: cualquier carta muy por encima rompe balance.
4. **Statuses tienen counterplay**: Vulnerable dura poco, Veneno se acumula pero el enemigo puede tener curación.

---

## UI/UX

### Layout de batalla

```
┌─────────────────────────────────────────────┐
│  [HUD: Piso 2 | Oro 45 | HP 60/80]          │
│                                              │
│  ┌─────────┐                ┌────────────┐ │
│  │ Enemigo │ ←─ intent ─── │  Heroe     │ │
│  │   ❤ 25  │   (⚔ 10)     │   ❤ 60/80  │ │
│  └─────────┘                │  🛡 5      │ │
│                              └────────────┘ │
│                                              │
│  ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐        │
│  │cart│ │cart│ │cart│ │cart│ │cart│ ← mano  │
│  └────┘ └────┘ └────┘ └────┘ └────┘        │
│                                              │
│  ⚡ 3/3 energía        [Fin de Turno]       │
└─────────────────────────────────────────────┘
```

### Interacciones clave

- **Hover carta**: agranda + muestra descripción completa.
- **Drag carta al enemigo**: juega carta de ataque dirigida.
- **Click carta**: juega carta (auto-target si single enemy).
- **Botón fin de turno**: termina turno, enemigo actúa.
- **Tab**: abre inventario (mazo actual, reliquias).
- **Esc**: pausa.

### Feedback visual

- **Daño**: número flotante rojo.
- **Block**: número flotante azul.
- **Curación**: número flotante verde.
- **Status aplicado**: icono del status con popup del nombre.
- **Carta jugada**: animación de carta volando al objetivo.
- **Muerte enemigo**: fade out + partículas.

### Accesibilidad

- **Tamaño de fuente escalable** (pequeño/mediano/grande).
- **Modo alto contraste** (opción).
- **Sonidos con feedback visual duplicado** (no dependen solo de audio).
- **Sin mecánicas de tiempo real**: todo es por turnos.

---

## Arte y audio

### Estilo visual

- **Pixel art** con paleta limitada (16-32 colores).
- **Color scheme**: oscuro con acentos vibrantes (no fantasy genérico).
- **Referencias**: Hades, Dead Cells, Slay the Spire (animaciones 2D con personalidad).

### Tipografías

- **UI body**: Noto Sans (legible a baja resolución).
- **Títulos**: una display font con personalidad (TBD).

### Audio

- **Música**: por piso/zona. Boss tiene track dedicado.
- **SFX**: удар, robo, descarte, jugar carta, daño recibido, muerte enemigo.
- **UI**: clicks, hovers, transiciones.

### Asset pipeline

- Arte: importado a `assets/art/` como PNG.
- Audio: `assets/audio/` como WAV (SFX) y OGG (música).
- Compresión Godot: VRAM para textures, lossless para UI.

---

## Roadmap

### MVP (2-3 semanas)

- [ ] Combate 1v1 funcionando.
- [ ] 1 héroe (Guerrero) con mazo inicial.
- [ ] 5 cartas jugables.
- [ ] 3 statuses (Veneno, Vulnerable, Block).
- [ ] 1 enemigo común.
- [ ] UI mínima (HUD, mano, intent enemigo).
- [ ] Tests de `combat_resolver` y `deck_manager` en verde.

### Run loop (2-3 semanas)

- [ ] Mapa procedural de 1 piso.
- [ ] 3 nodos: BATTLE, REST, BOSS.
- [ ] Recompensa post-batalla (1 carta de 3).
- [ ] Save/load de run.
- [ ] 1 boss.

### Sistemas completos (3-4 semanas)

- [ ] Statuses completos (8-10).
- [ ] Reliquias (5-10).
- [ ] Armas (3-4).
- [ ] Eventos (3-5).
- [ ] Tienda.
- [ ] 3 héroes jugables.
- [ ] 3 pisos por run.
- [ ] 3 bosses.

### Contenido completo (4-6 semanas)

- [ ] 30 cartas.
- [ ] 15 reliquias.
- [ ] 10 enemigos.
- [ ] 6-8 eventos.
- [ ] Balance fino iterativo.

### Meta (2-3 semanas)

- [ ] 3 slots de guardado.
- [ ] Stats globales.
- [ ] Unlocks básicos (3-5).
- [ ] Pantalla de créditos.

### Polish (ongoing)

- [ ] Arte final.
- [ ] Música.
- [ ] SFX.
- [ ] Animaciones.
- [ ] Localización (ES + EN).

---

## Open questions

1. **¿Pociones?** StS las tiene, agregan otro layer de decisiones. MVP sin ellas, evaluar después.
2. **¿Diferentes armas por héroe?** Sí, pero cuántas y con qué frecuencia se consiguen.
3. **¿Modo diario?** Para comunidad. Evaluar post-launch.
4. **¿Mods?** Tooling de modding desde día 1 vale la pena? Probablemente no en MVP.
5. **¿Idiomas?** Empezar con ES + EN. Otros según demanda.

---

## Apéndice: referencias técnicas

- Godot 4.3+
- GDScript
- GUT para tests
- Save: `ConfigFile` para run, JSON para stats globales
- Assets: PNG para arte, WAV/OGG para audio

Para la arquitectura técnica completa, ver [`ARCHITECTURE.md`](ARCHITECTURE.md).
