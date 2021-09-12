extends Node
class_name StateMachine

var _current_state : State
var _previous_states : Array = []

func _ready():
	# Pick the top state by default!
	set_state(get_child(0).name)

func push_state(newStateName : String, extra_params := []) -> void:
	var newState = get_node(newStateName) as State
	if _current_state == newState:
		return
	if _current_state:
		_previous_states.append(_current_state)
		_current_state.exit()
	_current_state = newState
	_current_state.enter(extra_params)

# Pop the current state off the stack.
# If a previous state exists we'll return to it
func pop_state():
	if _current_state:
		_current_state.exit()
	if _previous_states.size() > 0:
		_current_state = _previous_states.pop_back()
		_current_state.enter()
	
func set_state(newStateName : String, extra_params := []) -> void:
	var newState = get_node(newStateName) as State
	if _current_state == newState:
		return
	_previous_states.clear()
	if _current_state:
		_current_state.exit()
	_current_state = newState
	_current_state.enter(extra_params)

func next_state() -> void:
	var nextChildIndex = _current_state.get_index() + 1
	assert(get_children().size() >= nextChildIndex)
	set_state(get_child(nextChildIndex).name)

func process(delta : float) -> void:
	assert(_current_state)
	if _current_state.IsReady:
		_current_state.process(delta)

# TODO - blurgh. Shouldn't be hardcoded to slime.
# Maybe we need a Unit class or something, which slime & others could inherit..
func get_slime() -> Slime:
	return get_parent() as Slime
