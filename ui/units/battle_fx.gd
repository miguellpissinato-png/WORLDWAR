class_name BattleFx
extends Node2D
## Efeitos das batalhas no mapa: clarões de disparo, traçantes entre os dois lados, explosões com
## fumaça e os sons (tiros, rajadas e explosões, pelo autoload Audio). Só enfeite da interface:
## usa um sorteio próprio, fora da simulação. Nada aparece com o jogo pausado.

const FLASH_PER_S := 7.0       # clarões por segundo, de cada lado
const TRACER_PER_S := 4.0
const BLAST_PER_S := 0.55      # explosões por segundo (mais com artilharia ou blindados)
const MAX_SOUNDS_PER_S := 3.5

var _main
var _rng := RandomNumberGenerator.new()
var _fx: Array = []            # {kind, p, q, t, life, size}
var _sound_budget := 0.0


func setup(main) -> void:
	_main = main
	_rng.randomize()


func _process(delta: float) -> void:
	if _main == null or not _main.started:
		return
	var running: bool = not _main.paused
	for f in _fx:
		f.t += delta
	_fx = _fx.filter(func(f): return f.t < f.life)
	if running:
		_sound_budget = minf(_sound_budget + delta * MAX_SOUNDS_PER_S, 3.0)
		_spawn(delta)
	if running or not _fx.is_empty():
		queue_redraw()


func _spawn(delta: float) -> void:
	var st: GameState = _main.sim.state
	var cam: MapCamera = _main.camera
	var zoom: float = cam.zoom.x
	var view := Rect2(cam.position - get_viewport_rect().size / (2.0 * zoom), get_viewport_rect().size / zoom).grow(60.0 / zoom)
	for sid in st.battles:
		var b: Dictionary = st.battles[sid]
		var dpos: Vector2 = cam.near(st.state(sid).center)
		var apos := Vector2.ZERO
		var n := 0
		var heavy := false
		for gid in b.attackers + b.defenders:
			var g: ArmyGroup = st.group(gid)
			if g == null:
				continue
			for r in g.regiments:
				if r.type in ["artilharia", "tanquistas"]:
					heavy = true
			if gid in b.attackers:
				apos += cam.near(MovementSystem.map_position(st, g))
				n += 1
		if n == 0:
			continue
		apos /= n
		if not view.has_point((apos + dpos) * 0.5):
			continue
		var spread := (apos.distance_to(dpos) * 0.35 + 14.0 / zoom)
		# clarões dos dois lados
		for side in [apos, dpos]:
			if _rng.randf() < FLASH_PER_S * delta:
				_fx.append({"kind": "flash", "p": side + _jitter(spread * 0.6), "t": 0.0,
					"life": _rng.randf_range(0.06, 0.12), "size": _rng.randf_range(2.0, 3.5) / zoom})
		# traçantes de um lado para o outro
		if _rng.randf() < TRACER_PER_S * delta:
			var from_att := _rng.randf() < 0.55
			var p: Vector2 = (apos if from_att else dpos) + _jitter(spread * 0.5)
			var q: Vector2 = (dpos if from_att else apos) + _jitter(spread * 0.7)
			_fx.append({"kind": "tracer", "p": p, "q": q, "t": 0.0, "life": _rng.randf_range(0.22, 0.35), "size": 1.6 / zoom})
			if _rng.randf() < 0.45:
				_sound(("rajada_%d" % _rng.randi_range(1, 2)) if _rng.randf() < 0.4 else ("tiro_%d" % _rng.randi_range(1, 3)), zoom, -6.0)
		# explosões (artilharia, morteiros, granadas)
		if _rng.randf() < (BLAST_PER_S * (1.8 if heavy else 1.0)) * delta:
			var target: Vector2 = (dpos if _rng.randf() < 0.6 else apos) + _jitter(spread)
			var big := _rng.randf_range(0.8, 1.4) * (1.25 if heavy else 1.0)
			_fx.append({"kind": "blast", "p": target, "t": 0.0, "life": 1.8, "size": 11.0 * big / zoom,
				"seed": _rng.randi()})
			_sound("explosao_%d" % _rng.randi_range(1, 3), zoom, 0.0)


func _jitter(r: float) -> Vector2:
	return Vector2(_rng.randf_range(-r, r), _rng.randf_range(-r, r) * 0.6)


## Som mais alto quanto mais perto a câmera está; limitado para não virar barulho contínuo.
func _sound(name: String, zoom: float, extra_db: float) -> void:
	if _sound_budget < 1.0:
		return
	_sound_budget -= 1.0
	var near := clampf((zoom - 0.8) / 3.5, 0.0, 1.0)
	Audio.play_sfx(name, lerpf(-22.0, -4.0, near) + extra_db, _rng.randf_range(0.9, 1.1))


func _draw() -> void:
	for f in _fx:
		var k: float = f.t / f.life
		match f.kind:
			"flash":
				draw_circle(f.p, f.size * (1.0 + k), Color(1.0, 0.92, 0.6, 1.0 - k))
				draw_circle(f.p, f.size * 0.45, Color(1, 1, 1, 1.0 - k))
			"tracer":
				var head: Vector2 = f.p.lerp(f.q, k)
				var tail: Vector2 = f.p.lerp(f.q, maxf(0.0, k - 0.18))
				draw_line(tail, head, Color(1.0, 0.78, 0.35, 0.9 * (1.0 - k * 0.5)), f.size, true)
			"blast":
				_draw_blast(f, k)


func _draw_blast(f: Dictionary, k: float) -> void:
	var r: float = f.size
	var p: Vector2 = f.p
	var rr := RandomNumberGenerator.new()
	rr.seed = f.seed
	# fumaça: algumas nuvens cinza que sobem e se espalham
	for i in 5:
		var off := Vector2(rr.randf_range(-0.6, 0.6), rr.randf_range(-0.4, 0.2)) * r
		var grow := 0.6 + k * 1.6 + rr.randf() * 0.3
		var a := clampf(0.55 * (1.0 - k) * smoothstep(0.05, 0.25, k), 0.0, 0.55)
		draw_circle(p + off - Vector2(0, r * k * 0.9), r * grow * 0.55, Color(0.22, 0.21, 0.2, a))
	# bola de fogo e clarão
	if k < 0.35:
		var fk := k / 0.35
		draw_circle(p, r * (0.5 + fk * 0.9), Color(1.0, 0.55, 0.15, 0.85 * (1.0 - fk)))
		draw_circle(p, r * (0.3 + fk * 0.5), Color(1.0, 0.85, 0.45, 0.9 * (1.0 - fk)))
	if k < 0.08:
		draw_circle(p, r * 1.6, Color(1.0, 0.95, 0.8, 0.35 * (1.0 - k / 0.08)))
	# terra e estilhaços voando
	if k < 0.5:
		for i in 7:
			var ang := rr.randf_range(-PI * 0.95, -PI * 0.05)
			var d := r * (0.4 + k * 2.4) * rr.randf_range(0.6, 1.0)
			draw_circle(p + Vector2(cos(ang), sin(ang)) * d, r * 0.07, Color(0.16, 0.12, 0.08, 1.0 - k * 2.0))
