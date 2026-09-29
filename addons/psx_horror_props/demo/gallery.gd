extends Node
## The pack's gallery: each prop on its own or all of them laid out, turned with the mouse, its
## animations on buttons. With PSX Look installed (res://addons/psx_look/), they show through it.
## Keys: left / right, 1 to 3 for the animations, A for all, P for PSX Look.

const PSX_LOOK := "res://addons/psx_look/"
const FLOOR := Color(0.13, 0.12, 0.11)
const WALL := Color(0.2, 0.19, 0.17)
const GAP := 0.05

## Hides the panel and stops the camera turning on its own, for the store captures.
@export var still := false
## Opens on the first prop. Off for the captures of a set: Godot 4.7 errors on a converted prop's
## scene put up again in the frame after its first instance went.
@export var start := true

var dir: String
var props: Array
var index := 0
var all_view := false
var world := Node3D.new()
var shown := Node3D.new()
var cam := Camera3D.new()
var wall := MeshInstance3D.new()
var ground := MeshInstance3D.new()
var env := Environment.new()
var yaw := 0.5
var pitch := -0.4
var dist := 1.0
var target := Vector3.ZERO
var idle := 0.0
var psx_screen: Control
var psx_on := false
var ui := CanvasLayer.new()
var icon := TextureRect.new()
var title := Label.new()
var info := Label.new()
var anim_bar := HBoxContainer.new()
var psx_button := Button.new()


func _ready() -> void:
	dir = (get_script() as Script).resource_path.get_base_dir().get_base_dir()
	props = JSON.parse_string(FileAccess.get_file_as_string(dir + "/props.json"))["props"]
	add_child(world)
	_stage()
	world.add_child(shown)
	world.add_child(cam)
	cam.current = true
	cam.fov = 40
	_ui()
	if ResourceLoader.exists(PSX_LOOK + "psx_screen.gd"):
		psx_screen = load(PSX_LOOK + "psx_screen.gd").new()
		psx_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(psx_screen)
		move_child(psx_screen, 0)
		set_psx(true)
	else:
		psx_button.hide()
	if start:
		show_prop(0)


func _stage() -> void:
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.04, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.55, 0.62)
	env.ambient_light_energy = 0.7
	env.fog_enabled = true
	env.fog_light_color = Color(0.04, 0.04, 0.05)
	env.fog_density = 0.04
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-55, -30, 0)
	key.light_color = Color(1.0, 0.9, 0.75)
	key.light_energy = 1.0
	key.shadow_enabled = true
	world.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-25, 150, 0)
	rim.light_color = Color(0.5, 0.6, 0.9)
	rim.light_energy = 0.4
	world.add_child(rim)
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	ground.mesh = plane
	ground.material_override = _flat(FLOOR)
	world.add_child(ground)
	var quad := QuadMesh.new()
	quad.size = Vector2(40, 6)
	wall.mesh = quad
	wall.position = Vector3(0, 3, -0.002)
	wall.material_override = _flat(WALL)
	world.add_child(wall)


func _flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	m.metallic_specular = 0.0
	return m


func _ui() -> void:
	add_child(ui)
	var top := VBoxContainer.new()
	top.position = Vector2(20, 16)
	ui.add_child(top)
	icon.custom_minimum_size = Vector2(96, 96)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	top.add_child(icon)
	for l in [title, info]:
		l.add_theme_color_override("font_shadow_color", Color.BLACK)
		l.add_theme_constant_override("shadow_offset_x", 2)
		l.add_theme_constant_override("shadow_offset_y", 2)
		top.add_child(l)
	title.add_theme_font_size_override("font_size", 26)
	info.add_theme_font_size_override("font_size", 15)
	info.modulate = Color(0.85, 0.82, 0.75)
	var bar := HBoxContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bar.position.y -= 16
	ui.add_child(bar)
	_button(bar, "<", func() -> void: show_prop(index - 1))
	_button(bar, ">", func() -> void: show_prop(index + 1))
	bar.add_child(anim_bar)
	_button(bar, "All", toggle_all)
	psx_button.text = "PSX Look"
	psx_button.toggle_mode = true
	psx_button.focus_mode = Control.FOCUS_NONE
	psx_button.toggled.connect(set_psx)
	bar.add_child(psx_button)
	var hint := Label.new()
	hint.text = "drag to turn, wheel to zoom"
	hint.add_theme_font_size_override("font_size", 13)
	hint.modulate = Color(1, 1, 1, 0.5)
	hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hint.position += Vector2(-16, 16)
	ui.add_child(hint)
	ui.visible = not still


func _button(box: Container, text: String, pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.x = 44
	b.pressed.connect(pressed)
	box.add_child(b)
	return b


## Shows the prop at `i` (wrapping round) alone, framed.
func show_prop(i: int) -> void:
	index = posmod(i, props.size())
	all_view = false
	_clear()
	var p: Dictionary = props[index]
	var node := _place(p, Vector3.ZERO)
	var lo := _gd(p["min"])
	var hi := _gd(p["max"])
	var box := AABB(lo, Vector3.ZERO).expand(hi)
	target = box.get_center()
	dist = maxf(0.12, box.size.length() * 0.5 / sin(deg_to_rad(cam.fov * 0.5)) * 1.15)
	pitch = -0.75 if p["place"] == "item" and box.size.y < 0.1 else -0.3
	yaw = 0.5
	wall.visible = p["place"] == "wall"
	var icon_path := "%s/icons/%s.png" % [dir, p["name"]]
	icon.texture = load(icon_path) if ResourceLoader.exists(icon_path) else null
	icon.visible = icon.texture != null
	title.text = p["title"]
	info.text = "%s  |  %d / %d  |  %d triangles  |  %s m\n%s" % [
		p["group"].capitalize(), index + 1, props.size(), p["tris"], _size(p["size"]), p["note"]]
	for b in anim_bar.get_children():
		b.queue_free()
	for a in p["anims"]:
		_button(anim_bar, a["name"], func() -> void: play(a["name"]))


## Every prop at once: the wall props on the wall, the floor props before it and the small
## items in front, a cluster per group.
func show_all() -> void:
	all_view = true
	_clear()
	for b in anim_bar.get_children():
		b.queue_free()
	var rows := {"wall": [], "floor": [], "item": []}
	for p in props:
		rows[p["place"]].append(p)
	_row(rows["wall"], 0.0, 0.18)
	_row(rows["floor"], 0.3, 0.25)
	var groups: Array = []
	var by_group := {}
	for p in rows["item"]:
		if p["group"] not in by_group:
			by_group[p["group"]] = []
			groups.append(p["group"])
		by_group[p["group"]].append(p)
	var clusters: Array = []
	for g in groups:
		clusters.append(_cluster(by_group[g]))
	var per_row := ceili(clusters.size() / 2.0)
	var z := 1.2
	for r in range(0, clusters.size(), per_row):
		var line := clusters.slice(r, r + per_row)
		var width := 0.0
		var depth := 0.0
		for c in line:
			width += c.get_meta("size").x + 0.25
			depth = maxf(depth, c.get_meta("size").y)
		var x := -width * 0.5
		for c in line:
			c.position = Vector3(x, 0, z)
			x += c.get_meta("size").x + 0.25
		z += depth + 0.35
	wall.visible = true
	target = Vector3(0, 0.45, z * 0.45)
	dist = 5.2
	pitch = -0.42
	yaw = 0.0
	icon.hide()
	title.text = "All %d props" % props.size()
	info.text = "%d triangles in all" % props.reduce(func(s, p): return s + p["tris"], 0)


func toggle_all() -> void:
	if all_view:
		show_prop(index)
	else:
		show_all()


## Props laid out as given: [name, [x, y, z] in metres, turn in degrees], for a composed shot.
func show_set(items: Array) -> void:
	all_view = true
	_clear()
	var named := {}
	for p in props:
		named[p["name"]] = p
	for it in items:
		var n := _place(named[it[0]], Vector3(it[1][0], it[1][1], it[1][2]))
		n.rotation_degrees.y = it[2] if it.size() > 2 else 0.0
	wall.visible = true


## Frames the view: target point, distance, yaw and pitch in radians.
func look(at: Vector3, distance: float, turn: float, tilt: float) -> void:
	target = at
	dist = distance
	yaw = turn
	pitch = tilt


func play(anim: String) -> void:
	for p in shown.get_children():
		var player := p.find_child("AnimationPlayer") as AnimationPlayer
		if player and player.has_animation(anim):
			player.stop()
			player.play(anim)


func set_psx(on: bool) -> void:
	if not psx_screen:
		return
	psx_on = on
	psx_button.set_pressed_no_signal(on)
	world.get_parent().remove_child(world)
	if on:
		psx_screen.viewport.add_child(world)
	else:
		add_child(world)
	psx_screen.visible = on
	for n in shown.get_children():
		_convert(n)


func _convert(node: Node) -> void:
	if not psx_screen:
		return
	if psx_on:
		load(PSX_LOOK + "psx.gd").convert(node)
		return
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		for s in (mi as MeshInstance3D).get_surface_override_material_count():
			(mi as MeshInstance3D).set_surface_override_material(s, null)


func _place(p: Dictionary, at: Vector3, parent: Node3D = shown) -> Node3D:
	var node: Node3D = load("%s/props/%s.tscn" % [dir, p["name"]]).instantiate()
	node.position = at
	parent.add_child(node)
	_convert(node)
	return node


func _row(list: Array, back: float, gap: float) -> void:
	var width := -gap
	for p in list:
		width += p["size"][0] + gap
	var x := -width * 0.5
	for p in list:
		var z: float = 0.0 if p["place"] == "wall" else back + p["max"][1]
		_place(p, Vector3(x - p["min"][0], 0, z))
		x += p["size"][0] + gap


## A group's items packed in rows under 0.6 m.
func _cluster(list: Array) -> Node3D:
	var c := Node3D.new()
	shown.add_child(c)
	var x := 0.0
	var z := 0.0
	var depth := 0.0
	var width := 0.0
	for p in list:
		if x > 0 and x + p["size"][0] > 0.6:
			x = 0.0
			z += depth + GAP
			depth = 0.0
		_place(p, Vector3(x - p["min"][0], 0, z + p["max"][1]), c)
		x += p["size"][0] + GAP
		width = maxf(width, x - GAP)
		depth = maxf(depth, p["size"][1])
	c.set_meta("size", Vector2(width, z + depth))
	return c


func _clear() -> void:
	for n in shown.get_children():
		shown.remove_child(n)
		n.queue_free()


func _gd(a: Array) -> Vector3:
	return Vector3(a[0], a[2], -a[1])


func _size(s: Array) -> String:
	return "%.2f x %.2f x %.2f" % [s[0], s[2], s[1]]


func _process(delta: float) -> void:
	idle += delta
	if not still and idle > 3.0:
		yaw += delta * 0.25
	pitch = clampf(pitch, -1.45, 0.2)
	var b := Basis.from_euler(Vector3(pitch, yaw, 0))
	cam.position = target + b * Vector3(0, 0, dist)
	cam.look_at(target)
	cam.near = dist * 0.02
	cam.far = dist * 20 + 20


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		yaw -= event.relative.x * 0.008
		pitch -= event.relative.y * 0.008
		idle = 0.0
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			dist *= 0.9
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			dist *= 1.1
		idle = 0.0
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_LEFT:
				show_prop(index - 1)
			KEY_RIGHT:
				show_prop(index + 1)
			KEY_A:
				toggle_all()
			KEY_P:
				set_psx(not psx_on)
			KEY_1, KEY_2, KEY_3:
				var anims: Array = props[index]["anims"]
				var k: int = event.keycode - KEY_1
				if not all_view and k < anims.size():
					play(anims[k]["name"])
