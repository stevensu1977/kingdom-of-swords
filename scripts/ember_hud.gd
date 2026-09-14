extends Control
## Resolution independent, deliberately quiet editorial HUD.

const GOLD := Color("#d4b27a")
const IVORY := Color("#eee9da")
const MUTED := Color("#8f9d9d")
const INK := Color("#101d24")
const CONSECRATION_CARD := Rect2(346, 590, 300, 88)
const SHIELD_CARD := Rect2(658, 590, 298, 88)
var game: Node3D
var serif: Font = preload("res://assets/fonts/Title.ttf")
var body: Font = preload("res://assets/fonts/Body.ttf")
var bold: Font = preload("res://assets/fonts/Display.ttf")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	queue_redraw()

func text(value: String, point: Vector2, size: int, color := IVORY, font: Font = null) -> void:
	draw_string(body if font == null else font, point, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func centered(value: String, point: Vector2, size: int, color := IVORY, font: Font = null) -> void:
	var chosen: Font = body if font == null else font
	var width := chosen.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	text(value, point - Vector2(width * 0.5, 0), size, color, chosen)

func diamond(point: Vector2, radius: float, color: Color, filled := false) -> void:
	var points := PackedVector2Array([point + Vector2(0, -radius), point + Vector2(radius, 0), point + Vector2(0, radius), point + Vector2(-radius, 0), point + Vector2(0, -radius)])
	if filled:
		draw_colored_polygon(points, color)
	else:
		draw_polyline(points, color, 1.0, true)

func panel(rect: Rect2) -> void:
	draw_style_box(style(Color(0.035, 0.067, 0.083, 0.89)), rect)

func _draw() -> void:
	if game == null or game.player == null:
		return
	# Slight edge shade, with unobstructed play in the middle.
	for i in range(70):
		var alpha := 0.008 * (1.0 - i / 70.0)
		draw_rect(Rect2(0, i, 1280, 1), Color(0.01, 0.02, 0.03, alpha * 60))
		draw_rect(Rect2(0, 719 - i, 1280, 1), Color(0.01, 0.02, 0.03, alpha * 65))
	diamond(Vector2(42, 42), 13, GOLD)
	draw_line(Vector2(42, 32), Vector2(42, 51), GOLD, 2, true)
	draw_line(Vector2(36, 40), Vector2(48, 40), GOLD, 1, true)
	text("KINGDOM OF SWORDS", Vector2(67, 38), 16, IVORY, serif)
	text("T H E   L A S T   E M B E R", Vector2(68, 58), 10, GOLD)
	centered("T H E   S U N K E N   S A N C T U M", Vector2(640, 36), 11, MUTED)
	draw_line(Vector2(478, 51), Vector2(588, 51), Color("#6b6452"))
	draw_line(Vector2(692, 51), Vector2(802, 51), Color("#6b6452"))
	centered("CHAMBER  I", Vector2(640, 55), 11, GOLD)
	text("%02d:%02d" % [int(game.elapsed) / 60, int(game.elapsed) % 60], Vector2(1155, 38), 19, IVORY, serif)
	text("ESC  PAUSE", Vector2(1149, 58), 10, MUTED)
	text("N  BGM " + ("ON" if game.music_enabled else "OFF"), Vector2(995, 54), 10, GOLD if game.music_enabled else MUTED)
	# Objective, composed against a translucent plaque.
	panel(Rect2(971, 90, 277, 100))
	text("YOUR OATH", Vector2(991, 114), 10, GOLD)
	text(game.objective_title(), Vector2(991, 140), 17, IVORY, serif)
	text(game.objective_detail(), Vector2(991, 166), 11, MUTED)
	# Enemy health strips and anticipatory attack rings live with the world.
	for enemy in game.enemies:
		if enemy.dead:
			continue
		var p: Vector2 = game.camera.unproject_position(enemy.position + Vector3(0, float(enemy.config.height) + 0.32, 0))
		if p.y < 90 or p.y > 595:
			continue
		draw_rect(Rect2(p - Vector2(23, 0), Vector2(46, 4)), Color("#151e23"))
		draw_rect(Rect2(p - Vector2(23, 0), Vector2(46 * float(enemy.hp) / float(enemy.config.health), 3)), Color("#d79972") if not enemy.get_meta("elite", false) else GOLD)
		if enemy.get_meta("elite", false):
			centered("OATHBREAKER", p - Vector2(0, 9), 10, GOLD)
		elif enemy.get_meta("archetype", "") == "archer":
			centered("ARCHER", p - Vector2(0, 9), 10, Color("#edbe8d"))
			if enemy.phase in ["draw", "shoot"] and not enemy.hit_sent:
				var charge: float = clampf(enemy.attack_time / float(enemy.config.impact), 0, 1)
				draw_rect(Rect2(p + Vector2(-23, 6), Vector2(46 * charge, 2)), Color("#ffdda0"))
	# Lower-left vitality and dodge feedback.
	panel(Rect2(32, 590, 296, 88))
	diamond(Vector2(56, 617), 8, GOLD, true)
	text("IMMUNE" if game.player.shielded > 0 else "THE WARDEN", Vector2(77, 620), 12, GOLD if game.player.shielded > 0 else IVORY)
	text("%d / 100" % game.player.hp, Vector2(245, 620), 11, GOLD)
	draw_rect(Rect2(50, 634, 260, 7), Color("#35413f"))
	draw_rect(Rect2(50, 634, 260 * game.player.hp / 100.0, 7), Color("#a9c6b7"))
	text("EVADE", Vector2(50, 663), 9, MUTED)
	draw_rect(Rect2(97, 655, 174, 3), Color("#35413f"))
	draw_rect(Rect2(97, 655, 174 * (1.0 - game.player.dodge_cooldown / 0.9), 3), GOLD)
	# Three seals are the level's complete progress indicator.
	panel(Rect2(973, 590, 275, 88))
	text("SEALS OF THE OLD KING", Vector2(993, 614), 10, GOLD)
	for i in range(3):
		var p := Vector2(1013 + i * 93, 650)
		if i < 2:
			draw_line(p + Vector2(15, 0), p + Vector2(78, 0), Color("#5d624f"))
		diamond(p, 13, GOLD if i < game.seals else Color("#536466"), i < game.seals)
		centered(["I", "II", "III"][i], p + Vector2(0, 5), 13, INK if i < game.seals else MUTED, serif)
	draw_consecration()
	draw_divine_shield()
	centered("WASD  MOVE     LMB  STRIKE     Q  CONSECRATION     F  DIVINE SHIELD     SPACE  EVADE     E  INTERACT", Vector2(640, 699), 10, MUTED)
	if not game.interaction_hint.is_empty() and not game.ended and not game.paused:
		var hint_width := body.get_string_size(game.interaction_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 82
		panel(Rect2(640 - hint_width / 2, 545, hint_width, 41))
		diamond(Vector2(665 - hint_width / 2, 565), 12, GOLD)
		centered("E", Vector2(665 - hint_width / 2, 570), 13, GOLD)
		text(game.interaction_hint, Vector2(689 - hint_width / 2, 571), 14)
	if game.banner_time > 0 and not game.paused:
		var alpha: float = minf(1, game.banner_time)
		draw_rect(Rect2(350, 102, 580, 65), Color(0.03, 0.06, 0.08, alpha * 0.9))
		centered(game.banner_title, Vector2(640, 130), 22, Color(0.94, 0.88, 0.74, alpha), serif)
		centered(game.banner_subtitle, Vector2(640, 153), 11, Color(0.63, 0.72, 0.72, alpha))
	if game.hurt_flash > 0:
		draw_rect(Rect2(0, 0, 1280, 720), Color(0.53, 0.12, 0.07, game.hurt_flash * 0.35))
	if not game.overlay.visible and CONSECRATION_CARD.has_point(get_local_mouse_position()):
		panel(Rect2(402, 399, 476, 177))
		text("Consecration", Vector2(426, 430), 22, IVORY, serif)
		text("Q   /   18s cooldown   /   6s duration   /   3m radius", Vector2(426, 455), 11, GOLD)
		text("Each second: heal allies for 4% maximum health.", Vector2(426, 481), 12, IVORY)
		text("Burn enemies for 6 damage. 12% chance for +2.", Vector2(426, 504), 12, IVORY)
		text("The light stays where you cast it.", Vector2(426, 531), 12, MUTED)
		text("Stay inside to heal. Move and strike freely.", Vector2(426, 552), 12, MUTED)
	if not game.overlay.visible and SHIELD_CARD.has_point(get_local_mouse_position()):
		panel(Rect2(402, 399, 476, 177))
		text("Divine Shield", Vector2(426, 430), 22, IVORY, serif)
		text("F   /   24s cooldown   /   3s immunity", Vector2(426, 455), 11, GOLD)
		text("Holy light protects you from all incoming damage.", Vector2(426, 481), 12, IVORY)
		text("The shield moves with you. Keep moving and striking.", Vector2(426, 504), 12, IVORY)
		text("Also blocks burning; no healing or damage bonus.", Vector2(426, 531), 12, MUTED)
		text("Protection ends when the golden shell fades.", Vector2(426, 552), 12, MUTED)
	if game.overlay.visible:
		draw_rect(Rect2(0, 0, 1280, 720), Color(0.015, 0.03, 0.04, 0.68))

func draw_consecration() -> void:
	if game.consecration == null:
		return
	var skill: Node3D = game.consecration
	draw_skill_card(CONSECRATION_CARD, "Q", "CONSECRATION", "HEAL 4% / s    ·    BURN 6 / s", skill.active_remaining, skill.cooldown_remaining, skill.DURATION, skill.COOLDOWN)

func draw_divine_shield() -> void:
	var actor: CharacterBody3D = game.player
	draw_skill_card(SHIELD_CARD, "F", "DIVINE SHIELD", "IMMUNE TO ALL DAMAGE", actor.shielded, actor.shield_cooldown, actor.SHIELD_DURATION, actor.SHIELD_COOLDOWN)

func draw_skill_card(rect: Rect2, key: String, title: String, detail: String, remaining: float, cooldown: float, duration: float, total_cooldown: float) -> void:
	var active := remaining > 0
	var ready := cooldown <= 0.0001
	var color := GOLD if ready or active else MUTED
	var x := rect.position.x
	panel(rect)
	diamond(Vector2(x + 27, 630), 18, color)
	centered(key, Vector2(x + 27, 636), 18, color, serif)
	text(title, Vector2(x + 56, 611), 11, color)
	centered("READY" if ready else "%.1fs" % cooldown, Vector2(rect.end.x - 35, 611), 10, color)
	text(detail, Vector2(x + 56, 632), 10, IVORY if active else MUTED)
	text("ACTIVE %.1fs" % remaining if active else ("PRESS " + key if ready else "RECHARGING"), Vector2(x + 56, 651), 9, color)
	var bar := Rect2(x + 56, 662, rect.size.x - 76, 3)
	draw_rect(bar, Color("#35413f"))
	var progress := remaining / duration if active else 1.0 - cooldown / total_cooldown
	bar.size.x *= clampf(progress, 0, 1)
	draw_rect(bar, Color("#fff0b5") if active and key == "F" else (Color("#c9e8bb") if active else color))

static func style(color := Color("#111f27"), border := Color("#625a43")) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = color
	result.border_color = border
	result.set_border_width_all(1)
	result.content_margin_left = 24
	result.content_margin_right = 24
	result.content_margin_top = 14
	result.content_margin_bottom = 14
	return result

static func button_theme(button: Button, primary := false) -> void:
	button.custom_minimum_size.y = 46
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", preload("res://assets/fonts/Body.ttf"))
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", Color("#172127") if primary else IVORY)
	button.add_theme_color_override("font_hover_color", Color("#172127"))
	button.add_theme_color_override("font_pressed_color", Color("#172127"))
	button.add_theme_stylebox_override("normal", style(GOLD if primary else Color("#15272d")))
	button.add_theme_stylebox_override("hover", style(Color("#e4c38c"), Color("#eed6a7")))
	button.add_theme_stylebox_override("pressed", style(Color("#b79c6a")))
	button.add_theme_stylebox_override("focus", style(Color(0, 0, 0, 0), Color("#f6e5be")))
