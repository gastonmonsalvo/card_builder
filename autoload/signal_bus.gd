## Singleton global (Autoload) que implementa el patrón Event Bus (Observer).
## Desacopla la comunicación de eventos transversales entre el motor de combate,
##  el estado de la partida y la UI (ej. para reproducir Audio, instanciar VFX o desbloquear Logros).
extends Node

# Event Bus global (Patron Observer Desacoplado) para audio, VFX, logros o reliquias reactivas
## Emitida por el `CombatResolver` cada vez que se consume una carta instantánea o se evalúa una carta dentro del combo.
@warning_ignore("unused_signal")
signal card_played(card_data: CardData)

## Emitida cuando el jugador adquiere y equipa una reliquia (desde Tesoros, Santuarios, Tiendas o Debug).
@warning_ignore("unused_signal")
signal relic_acquired(relic: RelicData)

## Emitida por el `RunDirector` cuando el jugador se desplaza y confirma su entrada a una nueva sala en el mapa.
@warning_ignore("unused_signal")
signal room_entered(room: RoomData)

## Emitida cuando el `RunState` genera la matriz y arranca una nueva planta (o al iniciar la partida en la planta 1).
@warning_ignore("unused_signal")
signal floor_started(floor_number: int)
