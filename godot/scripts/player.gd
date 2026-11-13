extends CharacterBody3D

const SPEED := 7.0
const GRAVITY := 22.0

func _physics_process(delta: float) -> void:
    var input := Vector2.ZERO
    if Input.is_action_pressed("ui_left"):
        input.x -= 1
    if Input.is_action_pressed("ui_right"):
        input.x += 1
    if Input.is_action_pressed("ui_up"):
        input.y -= 1
    if Input.is_action_pressed("ui_down"):
        input.y += 1
    if get_parent().has_method("get"):
        var pad = get_parent().get("move_pad")
        if pad != null and pad.vector.length() > 0.12:
            input = pad.vector
    var direction := Vector3(input.x, 0, input.y).normalized()
    velocity.x = direction.x * SPEED
    velocity.z = direction.z * SPEED
    if not is_on_floor():
        velocity.y -= GRAVITY * delta
    else:
        velocity.y = 0
    move_and_slide()
