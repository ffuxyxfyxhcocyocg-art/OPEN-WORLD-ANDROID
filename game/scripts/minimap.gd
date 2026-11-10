extends Control

var actor: CharacterBody3D
var game: Node3D
var elapsed := 0.0

func setup(character: CharacterBody3D, match_game: Node3D) -> void:
	actor = character
	game = match_game

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= 0.15:
		elapsed = 0.0
		queue_redraw()

func _draw() -> void:
	if actor == null or game == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.13, 0.16, 0.89))
	var center := size * 0.5
	var ratio := size.x / 275.0
	draw_rect(Rect2(center - Vector2(126, 126) * ratio, Vector2(252, 252) * ratio), Color(0.18, 0.35, 0.23))
	for i in range(-2, 3):
		var a := float(i) * 42.0 * ratio
		draw_line(center + Vector2(a, -126 * ratio), center + Vector2(a, 126 * ratio), Color(0.13, 0.17, 0.18), 5.0 * ratio)
		draw_line(center + Vector2(-126 * ratio, a), center + Vector2(126 * ratio, a), Color(0.13, 0.17, 0.18), 5.0 * ratio)
	var zone_center: Vector2 = game.zone_center
	draw_arc(center + zone_center * ratio, game.safe_radius * ratio, 0, TAU, 96, Color(1.0, 0.8, 0.28), 2.5)
	for loot in game.crates:
		if loot.visible:
			var p: Vector3 = loot.position
			draw_circle(center + Vector2(p.x, p.z) * ratio, 2.4, Color(0.4, 0.95, 0.65))
	draw_circle(center + Vector2(actor.position.x, actor.position.z) * ratio, 4.8, Color(1.0, 0.96, 0.36))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.80, 0.93, 0.88), false, 2.0)
