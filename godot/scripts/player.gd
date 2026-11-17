extends CharacterBody3D

const WALK_SPEED := 5.2
const RUN_SPEED := 8.5
const JUMP_VELOCITY := 8.0
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
var skeleton: Skeleton3D
var sprinting := false
var jump_requested := false
var locomotion_clock := 0.0
var bone_ids: Dictionary = {}

func _ready() -> void:
    visual = get_node_or_null("CharacterVisual")
    animator = _find_animation_player(visual)
    skeleton = _find_skeleton(visual)
    if skeleton:
        for bone_name in ["thigh_l_097", "thigh_r_0107", "calf_l_098", "calf_r_0108", "foot_l_0103", "foot_r_0113", "upperarm_l_010", "upperarm_r_037", "lowerarm_l_011", "lowerarm_r_038"]:
            var bone_id := skeleton.find_bone(bone_name)
            if bone_id >= 0:
                bone_ids[bone_name] = bone_id
    if visual:
        left_arm = visual.get_node_or_null("ArmLeft") as Node3D
        right_arm = visual.get_node_or_null("ArmRight") as Node3D
        left_leg = visual.get_node_or_null("LegLeft") as Node3D
        right_leg = visual.get_node_or_null("LegRight") as Node3D
    if animator:
        animator.stop()
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
    var speed := RUN_SPEED if sprinting else WALK_SPEED
    velocity.x = direction.x * speed
    velocity.z = direction.z * speed
    var moving := direction.length() > 0.05
    if moving:
        rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), min(delta * 10.0, 1.0))
        walk_clock += delta * (13.5 if sprinting else 9.0)
        locomotion_clock += delta
        _animate_rig(false)
        _play_character_animation(move_animation if move_animation != "" else idle_animation)
    else:
        walk_clock = 0.0
        _reset_limbs()
        _animate_rig(true)
    if visual:
        visual.position.y = abs(sin(walk_clock)) * 0.055 if moving and move_animation == "" else 0.0
    if jump_requested and is_on_floor():
        velocity.y = JUMP_VELOCITY
    jump_requested = false
    if not is_on_floor():
        velocity.y -= GRAVITY * delta
        _animate_rig(false, true)
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


func request_jump() -> void:
    jump_requested = true

func set_sprinting(value: bool) -> void:
    sprinting = value

func _find_skeleton(node: Node) -> Skeleton3D:
    if node == null:
        return null
    if node is Skeleton3D:
        return node as Skeleton3D
    for child in node.get_children():
        var found := _find_skeleton(child)
        if found:
            return found
    return null

func _animate_rig(idle: bool, airborne: bool = false) -> void:
    if skeleton == null:
        return
    var phase := locomotion_clock * (13.5 if sprinting else 9.0)
    var stride := 0.0 if idle else (0.95 if sprinting else 0.62)
    if airborne:
        stride = 0.18
    var leg_l := sin(phase) * stride
    var leg_r := -leg_l
    var arm_l := -leg_l * 0.85
    var arm_r := -leg_r * 0.85
    var knee_l := maxf(0.0, -leg_l) * (0.75 if sprinting else 0.45)
    var knee_r := maxf(0.0, -leg_r) * (0.75 if sprinting else 0.45)
    if airborne:
        leg_l = -0.30
        leg_r = -0.30
        arm_l = -0.75
        arm_r = -0.75
        knee_l = 0.45
        knee_r = 0.45
    _set_bone_x("thigh_l_097", leg_l)
    _set_bone_x("thigh_r_0107", leg_r)
    _set_bone_x("calf_l_098", knee_l)
    _set_bone_x("calf_r_0108", knee_r)
    _set_bone_x("upperarm_l_010", arm_l)
    _set_bone_x("upperarm_r_037", arm_r)
    _set_bone_x("lowerarm_l_011", -0.12 if not idle else 0.0)
    _set_bone_x("lowerarm_r_038", -0.12 if not idle else 0.0)
    _set_bone_x("foot_l_0103", -knee_l * 0.45)
    _set_bone_x("foot_r_0113", -knee_r * 0.45)

func _set_bone_x(bone_name: String, angle: float) -> void:
    if not bone_ids.has(bone_name):
        return
    skeleton.set_bone_pose_rotation(int(bone_ids[bone_name]), Quaternion(Vector3.RIGHT, angle))
