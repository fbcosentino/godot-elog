extends Control

var _is_dragging := false
var _is_resizing := false

func _on_top_bar_gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton) and (event.button_index == MOUSE_BUTTON_LEFT):
		_is_dragging = event.pressed
	
	elif _is_dragging and (event is InputEventMouseMotion):
		position += event.relative


func _on_resize_corner_gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton) and (event.button_index == MOUSE_BUTTON_LEFT):
		_is_resizing = event.pressed
	
	elif _is_resizing and (event is InputEventMouseMotion):
		size += event.relative
