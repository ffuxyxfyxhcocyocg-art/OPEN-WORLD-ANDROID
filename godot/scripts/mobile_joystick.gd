extends Control

signal direction_changed(value: Vector2)
var finger := -1
var stick := Vector2.ZERO
var base_radius := 64.0

func _ready() -> void:
	custom_minimum_size = Vector2(160, 160)
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and finger == -1:
			finger = event.index
			_update_stick(event.position)
		elif not event.pressed and event.index == finger:
			finger = -1
			stick = Vector2.ZERO
			direction_changed.emit(stick)
			queue_redraw()
	elif event is InputEventScreenDrag and event.index == finger:
		_update_stick(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			finger = 0
			_update_stick(event.position)
		else:
			finger = -1
			stick = Vector2.ZERO
			direction_changed.emit(stick)
			queue_redraw()
	elif event is InputEventMouseMotion and finger == 0 and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_update_stick(event.position)

func _update_stick(local_pos: Vector2) -> void:
	var center := size * 0.5
	stick = ((local_pos - center) / base_radius).limit_length(1.0)
	direction_changed.emit(stick)
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	draw_circle(center, base_radius, Color(0.04, 0.06, 0.10, 0.42))
	draw_arc(center, base_radius, 0, TAU, 48, Color(0.8, 0.88, 1, 0.7), 3.0)
	draw_circle(center + stick * base_radius, 27.0, Color(0.85, 0.91, 1, 0.82))
