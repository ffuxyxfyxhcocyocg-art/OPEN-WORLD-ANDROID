extends Control
signal direction_changed(axis: Vector2)

var pointer_id := -1
var input_axis := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process_input(true)
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.38
	draw_circle(center, radius, Color(0.03, 0.08, 0.11, 0.55))
	draw_arc(center, radius, 0, TAU, 64, Color(0.72, 0.87, 0.92, 0.75), 3.5)
	draw_circle(center + Vector2(input_axis.x, -input_axis.y) * radius, radius * 0.4, Color(0.77, 0.87, 0.92, 0.92))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and pointer_id < 0:
			pointer_id = event.index
			_update_axis(event.position)
			accept_event()
		elif not event.pressed and event.index == pointer_id:
			pointer_id = -1
			input_axis = Vector2.ZERO
			direction_changed.emit(input_axis)
			queue_redraw()
			accept_event()
	elif event is InputEventScreenDrag and event.index == pointer_id:
		_update_axis(event.position)
		accept_event()
	elif event is InputEventMouseButton:
		if event.pressed:
			pointer_id = 100
			_update_axis(event.position)
		else:
			pointer_id = -1
			input_axis = Vector2.ZERO
			direction_changed.emit(input_axis)
			queue_redraw()
	elif event is InputEventMouseMotion and pointer_id == 100:
		_update_axis(event.position)

func _update_axis(pos: Vector2) -> void:
	var radius := minf(size.x, size.y) * 0.38
	var raw := (pos - size * 0.5) / radius
	raw = raw.limit_length(1.0)
	input_axis = Vector2(raw.x, -raw.y)
	direction_changed.emit(input_axis)
	queue_redraw()
