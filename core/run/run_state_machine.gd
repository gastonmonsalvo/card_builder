## Máquina de estados explícita para la run.
## Valida transiciones legales y emite señales globales para que las vistas reaccionen.
extends RefCounted
class_name RunStateMachine

enum State { MENU, MAP, BATTLE, REWARD, EVENT, SHOP, DEAD, VICTORY }

var current_state: State = State.MENU

signal state_changed(new_state: State)


## Valida si la transición es legal. Evita bugs de estados simultáneos.
func _is_valid_transition(from: State, to: State) -> bool:
	match from:
		State.MENU: return to in [State.MAP]
		State.MAP: return to in [State.BATTLE, State.EVENT, State.SHOP, State.DEAD, State.VICTORY, State.MENU]
		State.BATTLE: return to in [State.REWARD, State.DEAD, State.MENU]
		State.REWARD: return to in [State.MAP, State.SHOP, State.MENU]
		State.EVENT: return to in [State.MAP, State.BATTLE, State.DEAD, State.MENU]
		State.SHOP: return to in [State.MAP, State.MENU]
		State.DEAD: return to in [State.MENU]
		State.VICTORY: return to in [State.MENU]
	return false


## Cambia de estado. Emite signal si la transición es válida.
func transition_to(new_state: State) -> bool:
	if current_state == new_state:
		return true
	if not _is_valid_transition(current_state, new_state):
		push_error("[FSM] Transición inválida: %s → %s" % [State.keys()[current_state], State.keys()[new_state]])
		return false
	var prev := current_state
	current_state = new_state
	print("[FSM] %s → %s" % [State.keys()[prev], State.keys()[new_state]])
	state_changed.emit(current_state)
	return true


## Consulta si se puede transicionar a un estado (sin ejecutarla).
func can_transition_to(new_state: State) -> bool:
	return _is_valid_transition(current_state, new_state)
