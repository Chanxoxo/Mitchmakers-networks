extends Node

var _units := []
var _score := 0
var _total_units := 0 # Total number of units that were added to the scene
var _acceptable_losses := 0

var _is_game_running := false
var _next_level : PackedScene
var _current_level : MicroManagerLevel

var _player_mode := "Default" # None, State node names

var blocker_count := 1 setget set_blocker_count
var digger_count := 1 setget set_digger_count
var ladder_count := 1 setget set_ladder_count

signal game_initialised # Called at the end of initialise() to let UI do it's initial state etc
signal game_started
signal game_ended # Signal to indicate the game ended. One parameter, true if you won.
signal unit_died
signal unit_escaped
signal player_mode_changed # Indicates player mode changed. One parameter, with the new mode
signal job_count_changed

# Clears and reconfigures the game state
func initialise(level, next_level, acceptable_losses, blockers, diggers, builders) -> void:
	_current_level = level
	_next_level = next_level
	_acceptable_losses = acceptable_losses
	
	_score = 0
	_total_units = _units.size()
	_is_game_running = false
	
	set_blocker_count(blockers)
	set_digger_count(diggers)
	set_ladder_count(builders)
	emit_signal("game_initialised")

func add_unit(unit) -> void:
	_units.append(unit)
	_total_units += 1

func save_unit(unit) -> void:
	if _remove_unit(unit):
		_add_score()
		emit_signal("unit_escaped")
		_check_game_ended()

func kill_unit(unit) -> void:
	if _remove_unit(unit):
		_acceptable_losses -= 1
		emit_signal("unit_died")
		_check_game_ended()

func _check_game_ended() -> void:
	if !_is_game_running:
		return
	if _acceptable_losses < 0:
		emit_signal("game_ended", false)
		_is_game_running = false
		return
	if _units.size() == 0:
		_is_game_running = false
		emit_signal("game_ended", true)
		return

func _remove_unit(unit) -> bool:
	var index = _units.find(unit)
	if index >= 0:
		_units.remove(index)
		return true
	return false
	

func count_units():
	return _units.size()

func _add_score() -> void:
	_score += 1

func get_score() -> int:
	return _score

func get_acceptable_losses() -> int:
	return _acceptable_losses

func go_to_next_level() -> void:
	# TODO scene change animation
	var changed = get_tree().change_scene_to(_next_level)
	assert(changed == OK)

func restart_level() -> void:
	var result = get_tree().reload_current_scene()
	assert(result == OK)

func has_next_level() -> bool:
	return _next_level != null

func set_player_mode(newMode : String):
	# TODO  -this whole thing should probably be a state machine!
	_player_mode = newMode
	emit_signal("player_mode_changed", get_player_mode())

func get_player_mode() -> String:
	return _player_mode

func get_current_level() -> MicroManagerLevel:
	return _current_level

# This needs to be called to start the game!
# Any initialisation stuff can start here
# Then we'll ask each unit to proceed to their next state
func start_game() -> void:
	emit_signal("game_started")
	_is_game_running = true

# TODO move this somewhere sensible!
func _process(_delta):
	if !_is_game_running and Input.is_action_just_pressed("ui_select"):
		start_game()

func set_blocker_count(new_val):
	blocker_count = new_val
	emit_signal("job_count_changed", "Blocker")
func set_digger_count(new_val):
	digger_count = new_val
	emit_signal("job_count_changed", "Digger")
func set_ladder_count(new_val):
	ladder_count = new_val
	emit_signal("job_count_changed", "LadderClimb")
