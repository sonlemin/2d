extends Node
## AR46, Story 1.12 D5: applies the ≤ 6 light budget once per physics tick, after every actor has
## moved and set its light (priority 0) and the camera rig has moved (so light_rect() is this
## tick's), and before DevTools and its perf run (100), which read the result. Its own node, not
## World._physics_process(): World ticks before its descendants, so a lurker glow that wakes on a
## tick would be drawn past the budget for a frame; and World's early return (a dead player, a
## pending swap) must not stop it. Pausable with World. No class_name: World preloads it.

const PRIORITY := 50

var world: World  ## set by World before add_child


func _init() -> void:
	name = "LightBudget"
	process_physics_priority = PRIORITY


func _physics_process(_delta: float) -> void:
	BudgetLight.apply(get_tree().get_nodes_in_group(BudgetLight.GROUP), world.light_rect())
