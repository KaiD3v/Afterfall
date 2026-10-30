# Efeitos do tiro, feitos por código (permitido para elementos simples: Guia de estilo, seção 7):
# rastro, clarão, cápsula, projétil e impacto (faísca na parede, sangue em quem tem Health).
class_name ShotFx


static func style_tracer(tracer: Line2D) -> void:
	tracer.width = 1.6
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.25))
	curve.add_point(Vector2(0.7, 0.65))
	curve.add_point(Vector2(1.0, 1.0))
	tracer.width_curve = curve
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	grad.colors = PackedColorArray([
		Color(0.55, 0.58, 0.62, 0.0),
		Color8(227, 154, 59, 210),
		Color8(248, 236, 200, 255),
	])
	tracer.gradient = grad


# Projétil em alta velocidade, clarão no cano, cápsula ejetada e impacto no alvo. host é a arma:
# os tweens do rastro ficam presos a ela; os efeitos soltos vão para a cena do dono.
static func fire(host: Node2D, scene_root: Node, tracer: Line2D, muzzle: Vector2, end: Vector2, aim: Vector2, hit_collider: Object, light: Texture2D) -> void:
	if scene_root == null:
		host.get_tree().create_timer(0.05).timeout.connect(tracer.hide)
		return

	# 1. Clarão rápido na boca do cano (luz dinâmica + faísca pixelada)
	var flash := Node2D.new()
	flash.global_position = muzzle
	flash.rotation = aim.angle()
	var spark_outer := Polygon2D.new()
	spark_outer.color = Color8(227, 154, 59, 230)
	spark_outer.polygon = PackedVector2Array([Vector2(-1, -2.5), Vector2(5.5, 0), Vector2(-1, 2.5), Vector2(1.5, 0)])
	flash.add_child(spark_outer)
	var spark_core := Polygon2D.new()
	spark_core.color = Color8(248, 236, 200, 255)
	spark_core.polygon = PackedVector2Array([Vector2(0, -1.2), Vector2(3.5, 0), Vector2(0, 1.2)])
	flash.add_child(spark_core)
	if light:
		var m_light := PointLight2D.new()
		m_light.texture = light
		m_light.color = Color8(235, 168, 72)
		m_light.energy = 1.25
		m_light.texture_scale = 0.28
		flash.add_child(m_light)
	scene_root.add_child(flash)
	host.get_tree().create_timer(0.045).timeout.connect(flash.queue_free)

	# 2. Cápsula de latão 9 mm ejetada lateralmente
	var casing := Node2D.new()
	casing.global_position = muzzle - aim * 2.5
	var c_border := Polygon2D.new()
	c_border.color = Color8(20, 24, 32)
	c_border.polygon = PackedVector2Array([Vector2(-1.6, -1.1), Vector2(1.6, -1.1), Vector2(1.6, 1.1), Vector2(-1.6, 1.1)])
	casing.add_child(c_border)
	var c_brass := Polygon2D.new()
	c_brass.color = Color8(212, 163, 73)
	c_brass.polygon = PackedVector2Array([Vector2(-1.0, -0.6), Vector2(1.0, -0.6), Vector2(1.0, 0.6), Vector2(-1.0, 0.6)])
	casing.add_child(c_brass)
	scene_root.add_child(casing)
	var eject_side := -1.0 if aim.x < 0.0 else 1.0
	var eject_dir := (aim.rotated(-1.35 * eject_side) + Vector2(0.0, -0.5)).normalized()
	var land_pos := casing.global_position + eject_dir * randf_range(8.0, 13.0) + Vector2(0.0, randf_range(16.0, 21.0))
	var tw_c := casing.create_tween()
	tw_c.tween_property(casing, "global_position", land_pos, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw_c.parallel().tween_property(casing, "rotation", randf_range(-5.0, 5.0), 0.22)
	tw_c.tween_interval(0.55)
	tw_c.tween_property(casing, "modulate:a", 0.0, 0.25)
	tw_c.tween_callback(casing.queue_free)

	# 3. Projétil 9 mm em deslocamento balístico rápido + rastro curto
	var bullet := Node2D.new()
	bullet.global_position = muzzle
	bullet.rotation = aim.angle()
	var b_outline := Polygon2D.new()
	b_outline.color = Color8(20, 24, 32)
	b_outline.polygon = PackedVector2Array([Vector2(-2.5, -1.3), Vector2(2.5, -1.0), Vector2(3.4, 0.0), Vector2(2.5, 1.0), Vector2(-2.5, 1.3)])
	bullet.add_child(b_outline)
	var b_core := Polygon2D.new()
	b_core.color = Color8(248, 236, 200)
	b_core.polygon = PackedVector2Array([Vector2(-1.8, -0.7), Vector2(2.2, -0.5), Vector2(2.8, 0.0), Vector2(2.2, 0.5), Vector2(-1.8, 0.7)])
	bullet.add_child(b_core)
	scene_root.add_child(bullet)

	var total_dist := muzzle.distance_to(end)
	var flight_time := clampf(total_dist / 1800.0, 0.035, 0.085)
	var wake_len := minf(34.0, total_dist)
	var is_blood := Health.of(hit_collider) != null
	var had_hit := hit_collider != null
	var tw_b := host.create_tween()
	tw_b.tween_method(func(p: float) -> void:
		var head := muzzle.lerp(end, p)
		var tail_d := maxf(0.0, p * total_dist - wake_len)
		var tail := muzzle + aim * tail_d
		if is_instance_valid(bullet):
			bullet.global_position = head
		tracer.points = PackedVector2Array([tail, head])
	, 0.0, 1.0, flight_time)
	tw_b.tween_callback(func() -> void:
		tracer.hide()
		if is_instance_valid(bullet):
			bullet.queue_free()
		if had_hit and is_instance_valid(scene_root):
			_impact(scene_root, end, aim, is_blood)
	)


static func _impact(scene_root: Node, pos: Vector2, aim: Vector2, is_blood: bool) -> void:
	var count := 4 if is_blood else 3
	for i in count:
		var p := Polygon2D.new()
		p.global_position = pos
		if is_blood:
			p.color = Color8(138, 38, 38) if i % 2 == 0 else Color8(92, 24, 24)
			p.polygon = PackedVector2Array([Vector2(-1.2, -1.2), Vector2(1.2, -1.2), Vector2(1.2, 1.2), Vector2(-1.2, 1.2)])
		else:
			p.color = Color8(227, 154, 59) if i == 0 else Color8(168, 174, 179)
			p.polygon = PackedVector2Array([Vector2(-1.0, -0.8), Vector2(1.0, -0.8), Vector2(1.0, 0.8), Vector2(-1.0, 0.8)])
		scene_root.add_child(p)
		var base_dir := aim if is_blood else -aim
		var dir := base_dir.rotated(randf_range(-0.65, 0.65))
		var target := pos + dir * randf_range(5.0, 14.0) + (Vector2(0.0, randf_range(3.0, 8.0)) if is_blood else Vector2.ZERO)
		var tw := p.create_tween()
		tw.tween_property(p, "global_position", target, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(p, "modulate:a", 0.0, 0.16)
		tw.tween_callback(p.queue_free)
