extends CharacterBody3D

const SPEED := 7.0
const GRAVITY := 22.0
var walk_clock := 0.0
var visual: Node3D
var animator: AnimationPlayer
var idle_animation := ""
var move_animation := ""
var active_animation := ""
var left_arm: Node3D
var right_arm: Node3D
var left_leg: Node3D
var right_leg: Node3D

func _ready() -> void:
    visual = get_node_or_null("CharacterVisual")
    animator = _find_animation_player(visual)
    if visual:
        left_arm = visual.get_node_or_null("ArmLeft") as Node3D
        right_arm = visual.get_node_or_null("ArmRight") as Node3D
        left_leg = visual.get_node_or_null("LegLeft") as Node3D
        right_leg = visual.get_node_or_null("LegRight") as Node3D
    if animator:
        for clip in animator.get_animation_list():
            var key := str(clip).to_lower()
            if idle_animation == "" and ("idle" in key or "stand" in key):
                idle_animation = str(clip)
            if move_animation == "" and ("walk" in key or "run" in key or "locomotion" in key):
                move_animation = str(clip)
        if idle_animation == "" and not animator.get_animation_list().is_empty():
            idle_animation = str(animator.get_animation_list()[0])
        _play_character_animation(idle_animation)

func _physics_process(delta: float) -> void:
    var input := Vector2.ZERO
    if Input.is_action_pressed("ui_left"):
        input.x -= 1.0
    if Input.is_action_pressed("ui_right"):
        input.x += 1.0
    if Input.is_action_pressed("ui_up"):
        input.y -= 1.0
    if Input.is_action_pressed("ui_down"):
        input.y += 1.0
    var parent_node := get_parent()
    if parent_node != null:
        var pad = parent_node.get("move_pad")
        if pad != null and pad.vector.length() > 0.12:
            input = pad.vector
    var direction := Vector3(input.x, 0.0, input.y).normalized()
    velocity.x = direction.x * SPEED
    velocity.z = direction.z * SPEED
    var moving := direction.length() > 0.05
    if moving:
        rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), min(delta * 10.0, 1.0))
        walk_clock += delta * 10.0
        _animate_limbs()
        _play_character_animation(move_animation if move_animation != "" else idle_animation)
    else:
        walk_clock = 0.0
        _reset_limbs()
        _play_character_animation(idle_animation)
    if visual:
        visual.position.y = abs(sin(walk_clock)) * 0.055 if moving and move_animation == "" else 0.0
    if not is_on_floor():
        velocity.y -= GRAVITY * delta
    else:
        velocity.y = 0.0
    move_and_slide()

func _animate_limbs() -> void:
    var swing := sin(walk_clock) * 0.62
    if left_arm: left_arm.rotation.x = -swing
    if right_arm: right_arm.rotation.x = swing
    if left_leg: left_leg.rotation.x = swing
    if right_leg: right_leg.rotation.x = -swing

func _reset_limbs() -> void:
    for limb in [left_arm, right_arm, left_leg, right_leg]:
        if limb: limb.rotation.x = 0.0

func _play_character_animation(animation_name: String) -> void:
    if animator == null or animation_name == "" or not animator.has_animation(animation_name):
        return
    if active_animation == animation_name and animator.is_playing():
        return
    active_animation = animation_name
    animator.play(animation_name)

func _find_animation_player(node: Node) -> AnimationPlayer:
    if node == null:
        return null
    if node is AnimationPlayer:
        return node as AnimationPlayer
    for child in node.get_children():
        var found := _find_animation_player(child)
        if found != null:
            return found
    return null
