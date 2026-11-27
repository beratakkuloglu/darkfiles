extends Node2D
## Gri kutu sürümü: tüm oyun bu tek sahnede, vaka verisi data/case1.json içinde.
## Görseller şimdilik renkli kutular. Pixel art hazır olunca kutular sprite ile değişecek.

const VIEW_W := 640.0
const VIEW_H := 360.0
const FLOOR_Y := 290.0
const SPEED := 140.0
const INTERACT_RANGE := 40.0
## art/oscar.png sağa bakıyorsa true, sola bakıyorsa false yap.
const PLAYER_ART_FACES_RIGHT := false

# Palet: siyah, kahverengi, sarı
const C_BLACK := Color("#0f0b08")
const C_BROWN := Color("#5a3d2b")
const C_LIGHT := Color("#8a6a4f")
const C_YELLOW := Color("#e8c547")
const C_PALE := Color("#f2e3b3")

var data: Dictionary = {}
var room_id: String = ""
var room_w: float = 640.0
var flags: Dictionary = {}
var clues: Dictionary = {}
var lab_done: Dictionary = {}
var deductions: Dictionary = {}
var pending_lab: Array = []
var eye_on: bool = false
var eye_uses: int = 3
var debt: int = 12480
var wrong_shows: int = 0
var final_hint_shown: bool = false
var hinted: Dictionary = {}

var room_layer: Node2D
var player: Node2D
var player_sprite: TextureRect
var walk_time: float = 0.0
var camera: Camera2D
var target_x: float = -1.0
var pending_action: Callable = Callable()
var room_objects: Array = []
var bg_nodes: Array = []

var ui_root: Control
var msg_label: Label
var debt_label: Label
var eye_button: Button
var dialog_panel: PanelContainer
var dialog_text: Label
var dialog_choices: VBoxContainer
var notebook_panel: PanelContainer
var notebook_list: VBoxContainer
var notebook_info: Label
var notebook_title: Label
var link_button: Button
var accuse_button: Button
var accuse_panel: PanelContainer
var accuse_list: VBoxContainer
var accuse_hud: Button
var progress_label: Label

var line_queue: Array = []
var after_lines: Callable = Callable()
var busy: bool = false
var current_npc: String = ""
var select_mode: String = ""
var link_first: String = ""
var msg_tween: Tween


func _ready() -> void:
	var f := FileAccess.open("res://data/case1.json", FileAccess.READ)
	data = JSON.parse_string(f.get_as_text())
	room_layer = Node2D.new()
	add_child(room_layer)
	_build_player()
	_build_ui()
	load_room(str(data["start_room"]), float(data["start_x"]))
	play_lines(data["intro"], Callable())


# ---------------------------------------------------------------- kurulum

func _build_player() -> void:
	player = Node2D.new()
	add_child(player)
	var tex := _art("oscar")
	if tex:
		player_sprite = _child_tex(player, Vector2(-tex.get_width() / 2.0, -tex.get_height()), tex)
	else:
		_child_rect(player, Vector2(-8, -40), Vector2(16, 40), C_PALE)
		_child_rect(player, Vector2(-11, -45), Vector2(22, 6), C_BROWN) # şapka
	camera = Camera2D.new()
	camera.position = Vector2(0, VIEW_H / 2.0 - FLOOR_Y)
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_bottom = int(VIEW_H)
	camera.position_smoothing_enabled = true
	player.add_child(camera)
	camera.make_current()


func _child_rect(parent: Node, pos: Vector2, sz: Vector2, col: Color) -> ColorRect:
	var r := ColorRect.new()
	r.position = pos
	r.size = sz
	r.color = col
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


## art/<anahtar>.png varsa kutu yerine o çizim kullanılır.
func _art(key: String) -> Texture2D:
	var p := "res://art/" + key + ".png"
	if ResourceLoader.exists(p):
		return load(p)
	return null


func _child_tex(parent: Node, pos: Vector2, tex: Texture2D) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.position = pos
	t.size = tex.get_size()
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(t)
	return t


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui_root = Control.new()
	ui_root.size = Vector2(VIEW_W, VIEW_H)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var th := Theme.new()
	th.default_font_size = 11
	ui_root.theme = th
	layer.add_child(ui_root)

	msg_label = Label.new()
	msg_label.position = Vector2(0, 40)
	msg_label.size = Vector2(VIEW_W, 20)
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.add_theme_color_override("font_color", C_YELLOW)
	ui_root.add_child(msg_label)

	debt_label = Label.new()
	debt_label.position = Vector2(VIEW_W - 190, 10)
	debt_label.size = Vector2(180, 20)
	debt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ui_root.add_child(debt_label)
	_update_debt()

	var nb_btn := Button.new()
	nb_btn.text = "Defter"
	nb_btn.position = Vector2(8, 8)
	nb_btn.pressed.connect(func(): open_notebook(""))
	ui_root.add_child(nb_btn)

	eye_button = Button.new()
	eye_button.position = Vector2(72, 8)
	eye_button.pressed.connect(toggle_eye)
	ui_root.add_child(eye_button)
	_update_eye_button()

	accuse_hud = Button.new()
	accuse_hud.text = "SUÇLA"
	accuse_hud.position = Vector2(200, 8)
	accuse_hud.add_theme_color_override("font_color", C_YELLOW)
	accuse_hud.visible = false
	accuse_hud.pressed.connect(func():
		if busy:
			return
		busy = true
		_open_accuse())
	ui_root.add_child(accuse_hud)

	# Diyalog kutusu
	dialog_panel = PanelContainer.new()
	dialog_panel.position = Vector2(20, 240)
	dialog_panel.visible = false
	dialog_panel.gui_input.connect(_on_dialog_input)
	ui_root.add_child(dialog_panel)
	var vb := VBoxContainer.new()
	dialog_panel.add_child(vb)
	dialog_text = Label.new()
	dialog_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog_text.custom_minimum_size = Vector2(VIEW_W - 60, 36)
	vb.add_child(dialog_text)
	dialog_choices = VBoxContainer.new()
	vb.add_child(dialog_choices)

	# Defter
	notebook_panel = PanelContainer.new()
	notebook_panel.position = Vector2(30, 24)
	notebook_panel.custom_minimum_size = Vector2(VIEW_W - 60, VIEW_H - 48)
	notebook_panel.visible = false
	ui_root.add_child(notebook_panel)
	var hb := HBoxContainer.new()
	notebook_panel.add_child(hb)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(260, 0)
	hb.add_child(left)
	notebook_title = Label.new()
	left.add_child(notebook_title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(260, 270)
	left.add_child(scroll)
	notebook_list = VBoxContainer.new()
	notebook_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(notebook_list)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(right)
	progress_label = Label.new()
	progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	progress_label.custom_minimum_size = Vector2(270, 0)
	progress_label.add_theme_color_override("font_color", C_YELLOW)
	right.add_child(progress_label)
	notebook_info = Label.new()
	notebook_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notebook_info.custom_minimum_size = Vector2(270, 160)
	right.add_child(notebook_info)
	var hint_btn := Button.new()
	hint_btn.text = "Maya'ya sor (ipucu)"
	hint_btn.pressed.connect(func(): notebook_info.text = _hint_text())
	right.add_child(hint_btn)
	link_button = Button.new()
	link_button.text = "Dedüksiyon tahtası: iki ipucunu bağla"
	link_button.pressed.connect(_start_link)
	right.add_child(link_button)
	accuse_button = Button.new()
	accuse_button.text = "FCD sorgu odasına git ve suçla"
	accuse_button.pressed.connect(_open_accuse)
	right.add_child(accuse_button)
	var close_btn := Button.new()
	close_btn.text = "Kapat"
	close_btn.pressed.connect(_close_notebook)
	right.add_child(close_btn)

	# Suçlama
	accuse_panel = PanelContainer.new()
	accuse_panel.position = Vector2(200, 80)
	accuse_panel.custom_minimum_size = Vector2(240, 0)
	accuse_panel.visible = false
	ui_root.add_child(accuse_panel)
	accuse_list = VBoxContainer.new()
	accuse_panel.add_child(accuse_list)


# ---------------------------------------------------------------- mekan

func load_room(id: String, spawn_x: float) -> void:
	room_id = id
	for c in room_layer.get_children():
		room_layer.remove_child(c)
		c.queue_free()
	room_objects.clear()
	bg_nodes.clear()
	var r: Dictionary = data["rooms"][id]
	room_w = float(r["width"])
	var bg_tex := _art("rooms/" + id)
	if bg_tex:
		bg_nodes.append(_child_tex(room_layer, Vector2.ZERO, bg_tex))
	else:
		bg_nodes.append(_child_rect(room_layer, Vector2.ZERO, Vector2(room_w, VIEW_H), Color.html(str(r["bg"]))))
		bg_nodes.append(_child_rect(room_layer, Vector2(0, FLOOR_Y - 8), Vector2(room_w, 8), C_BROWN))
		bg_nodes.append(_child_rect(room_layer, Vector2(0, FLOOR_Y), Vector2(room_w, VIEW_H - FLOOR_Y), C_BLACK))
	var decor: Array = [] if bg_tex else r.get("decor", [])
	for d in decor:
		var w: float = float(d["w"])
		var h: float = float(d["h"])
		var pos := Vector2(float(d["x"]) - w / 2.0, FLOOR_Y - float(d.get("y", 0)) - h)
		bg_nodes.append(_child_rect(room_layer, pos, Vector2(w, h), Color.html(str(d.get("color", "#3a2a1e")))))
	for o in r["objects"]:
		_spawn_object(o)
	player.position = Vector2(spawn_x, FLOOR_Y)
	camera.limit_right = int(room_w)
	camera.reset_smoothing()
	eye_on = false
	eye_uses = 3
	_update_eye_button()
	target_x = -1.0
	pending_action = Callable()
	_refresh_visibility()
	show_msg(str(r["name"]))
	_complete_lab()


func _spawn_object(o: Dictionary) -> void:
	var t: String = str(o["type"])
	var w: float = float(o.get("w", 10))
	var h: float = float(o.get("h", 10))
	var col := C_YELLOW
	var label_text := ""
	if t == "npc":
		w = float(o.get("w", 18))
		h = float(o.get("h", 42))
		col = C_LIGHT
		label_text = str(data["dialogues"][o["dialogue"]]["name"])
	elif t == "door":
		w = 34.0
		h = 64.0
		col = C_BROWN
		label_text = "> " + str(data["rooms"][o["to"]]["name"])
	var art_key := ""
	match t:
		"clue":
			art_key = str(o["id"])
		"npc":
			art_key = str(o.get("art", o["dialogue"]))
		"door":
			art_key = "door"
	var tex := _art(art_key)
	if tex:
		w = tex.get_width()
		h = tex.get_height()
	var pos := Vector2(float(o["x"]) - w / 2.0, FLOOR_Y - float(o.get("y", 0)) - h)
	var n: Control
	if tex:
		n = _child_tex(room_layer, pos, tex)
	else:
		n = _child_rect(room_layer, pos, Vector2(w, h), col)
	if label_text != "":
		var lb := Label.new()
		lb.text = label_text
		lb.position = Vector2(-50, -16)
		lb.size = Vector2(w + 100, 14)
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lb.add_theme_font_size_override("font_size", 9)
		n.add_child(lb)
	room_objects.append({"data": o, "node": n})


func _obj_visible(o: Dictionary) -> bool:
	if o.has("requires_flag") and not flags.has(o["requires_flag"]):
		return false
	if o.has("hide_if_flag") and flags.has(o["hide_if_flag"]):
		return false
	if str(o["type"]) == "clue":
		if clues.has(o["id"]):
			return false
		if bool(o.get("hidden", false)) and not eye_on:
			return false
	return true


func _refresh_visibility() -> void:
	for e in room_objects:
		var o: Dictionary = e["data"]
		var n: Control = e["node"]
		n.visible = _obj_visible(o)
		if eye_on and str(o["type"]) != "clue":
			n.modulate = Color(0.35, 0.35, 0.35)
		else:
			n.modulate = Color(1, 1, 1)
	for b in bg_nodes:
		b.modulate = Color(0.35, 0.35, 0.35) if eye_on else Color(1, 1, 1)


# ---------------------------------------------------------------- hareket ve girdi

func _process(delta: float) -> void:
	_bob(delta)
	if busy:
		return
	var dir := 0.0
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		dir -= 1.0
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		dir += 1.0
	if dir != 0.0:
		target_x = -1.0
		pending_action = Callable()
		player.position.x = clampf(player.position.x + dir * SPEED * delta, 8.0, room_w - 8.0)
		_face(dir)
		return
	if target_x >= 0.0:
		var dx: float = target_x - player.position.x
		var step: float = SPEED * delta
		if absf(dx) <= step:
			player.position.x = target_x
			target_x = -1.0
			var cb := pending_action
			pending_action = Callable()
			if cb.is_valid():
				cb.call()
		else:
			player.position.x += signf(dx) * step
			_face(dx)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null:
		if not key.pressed or key.echo:
			return
		if busy:
			if dialog_panel.visible and dialog_choices.get_child_count() == 0 and (key.keycode == KEY_SPACE or key.keycode == KEY_ENTER or key.keycode == KEY_E):
				_next_line()
			return
		if key.keycode == KEY_E:
			_interact_nearest()
		elif key.keycode == KEY_Q:
			toggle_eye()
		elif key.keycode == KEY_TAB:
			open_notebook("")
		return
	if busy:
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		var pos := get_global_mouse_position()
		for i in range(room_objects.size() - 1, -1, -1):
			var e: Dictionary = room_objects[i]
			var n: Control = e["node"]
			if not n.visible:
				continue
			if Rect2(n.position, n.size).grow(6).has_point(pos):
				var o: Dictionary = e["data"]
				walk_to(float(o["x"]), _interact.bind(o))
				return
		walk_to(pos.x, Callable())


## Animasyon kareleri gelene kadar: yürürken hafif zıplama ve sallanma.
func _bob(delta: float) -> void:
	if not player_sprite:
		return
	var moving := not busy and (target_x >= 0.0 or Input.is_action_pressed("ui_left") or Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_D))
	var base_y := -player_sprite.size.y
	if moving:
		walk_time += delta * 10.0
		player_sprite.position.y = base_y - absf(sin(walk_time)) * 2.0
		player_sprite.pivot_offset = Vector2(player_sprite.size.x / 2.0, player_sprite.size.y)
		player_sprite.rotation = sin(walk_time) * 0.04
	else:
		walk_time = 0.0
		player_sprite.position.y = base_y
		player_sprite.rotation = 0.0


func _face(dir: float) -> void:
	if player_sprite and dir != 0.0:
		player_sprite.flip_h = (dir > 0.0) != PLAYER_ART_FACES_RIGHT


func walk_to(x: float, cb: Callable) -> void:
	target_x = clampf(x, 8.0, room_w - 8.0)
	pending_action = cb


func _interact_nearest() -> void:
	var best: Dictionary = {}
	var best_d := INTERACT_RANGE
	for e in room_objects:
		var n: Control = e["node"]
		if not n.visible:
			continue
		var o: Dictionary = e["data"]
		var d := absf(float(o["x"]) - player.position.x)
		if d < best_d:
			best_d = d
			best = o
	if not best.is_empty():
		_interact(best)


func _interact(o: Dictionary) -> void:
	match str(o["type"]):
		"clue":
			give_clue(str(o["id"]), Callable())
		"door":
			if o.has("requires_flag") and not flags.has(o["requires_flag"]):
				play_lines([["Oscar", str(o.get("locked_text", "Kilitli."))]], Callable())
			else:
				load_room(str(o["to"]), float(o["spawn_x"]))
		"npc":
			start_dialogue(str(o["dialogue"]))


# ---------------------------------------------------------------- ipuçları

func give_clue(id: String, done: Callable) -> void:
	if clues.has(id):
		if done.is_valid():
			done.call()
		return
	clues[id] = true
	var c: Dictionary = data["clues"][id]
	if c.has("sets_flag"):
		flags[c["sets_flag"]] = true
	var lines: Array = [["", "Yeni ipucu: " + str(c["name"])]]
	if c.has("comment"):
		lines.append(["Oscar", str(c["comment"])])
	if c.has("analysis"):
		pending_lab.append(id)
		lines.append(["Maya", "Bunu laboratuvara yolluyorum. Sonuç bir sonraki mekanda gelir."])
	_add_link_hint(lines)
	_refresh_visibility()
	play_lines(lines, done)


func _complete_lab() -> void:
	if pending_lab.is_empty():
		return
	var lines: Array = []
	for id in pending_lab:
		lab_done[id] = true
		var c: Dictionary = data["clues"][id]
		lines.append(["Maya", "Lab sonucu, " + str(c["name"]) + ": " + str(c["analysis"])])
	pending_lab.clear()
	_add_link_hint(lines)
	play_lines(lines, Callable())


## Bağlanmaya hazır (iki ipucu da elde, lab bitmiş, henüz bağlanmamış) dedüksiyonlar.
func _ready_pairs() -> Array:
	var out: Array = []
	for d in data["deductions"]:
		if deductions.has(d["id"]):
			continue
		var p: Array = d["pair"]
		if clues.has(p[0]) and clues.has(p[1]) and not pending_lab.has(p[0]) and not pending_lab.has(p[1]):
			out.append(d)
	return out


func _add_link_hint(lines: Array) -> void:
	for d in _ready_pairs():
		if not hinted.has(d["id"]):
			hinted[d["id"]] = true
			lines.append(["Oscar", "Dur bir dakika... Defterimdeki iki ipucu birbirine bağlanıyor. Dedüksiyon tahtasına bakmalıyım."])
			return


func _hint_text() -> String:
	var req: Array = data["final"]["required"]
	var ready_list := _ready_pairs()
	var pick: Dictionary = {}
	for d in ready_list:
		if req.has(d["id"]):
			pick = d
			break
	if pick.is_empty() and not ready_list.is_empty():
		pick = ready_list[0]
	if not pick.is_empty():
		var p: Array = pick["pair"]
		return "Maya: '" + str(data["clues"][p[0]]["name"]) + "' ve '" + str(data["clues"][p[1]]["name"]) + "'. Bu ikisini dedüksiyon tahtasında bağla."
	if _final_ready():
		return "Maya: Yeterince kanıtın var. Üstteki SUÇLA butonuna bas."
	if not pending_lab.is_empty():
		return "Maya: Laboratuvar sonucu bekleniyor. Başka bir mekana geç, sonuç gelir."
	for d in data["deductions"]:
		if req.has(d["id"]) and not deductions.has(d["id"]):
			return "Maya: " + str(d.get("where", "Bir şey eksik. Mekanları tekrar ara."))
	return "Maya: Bilmiyorum, Penn. Sen danışmansın."


func _update_hud() -> void:
	accuse_hud.visible = _final_ready()


func _clue_text(id: String) -> String:
	var c: Dictionary = data["clues"][id]
	var t := str(c["name"]) + "\n\n" + str(c["desc"])
	if lab_done.has(id):
		t += "\n\nLab: " + str(c["analysis"])
	elif pending_lab.has(id):
		t += "\n\nLab: sonuç bekleniyor."
	return t


# ---------------------------------------------------------------- diyalog

func play_lines(lines: Array, done: Callable) -> void:
	line_queue = lines.duplicate()
	after_lines = done
	busy = true
	dialog_panel.visible = true
	_clear_choices()
	_next_line()


func _next_line() -> void:
	if line_queue.is_empty():
		var cb := after_lines
		after_lines = Callable()
		if cb.is_valid():
			cb.call()
		else:
			_close_dialog()
		return
	var l: Array = line_queue.pop_front()
	var who := str(l[0])
	dialog_text.text = (who + ": " if who != "" else "") + str(l[1]) + "   [tıkla]"
	_layout_dialog()


func _on_dialog_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		if dialog_choices.get_child_count() == 0:
			_next_line()


func _clear_choices() -> void:
	for c in dialog_choices.get_children():
		dialog_choices.remove_child(c)
		c.queue_free()


func _add_choice(text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(cb)
	dialog_choices.add_child(b)


func _layout_dialog() -> void:
	dialog_panel.reset_size()
	dialog_panel.position.y = VIEW_H - 10.0 - dialog_panel.get_combined_minimum_size().y


func _close_dialog() -> void:
	dialog_panel.visible = false
	_clear_choices()
	busy = false
	current_npc = ""


func start_dialogue(did: String) -> void:
	current_npc = did
	var d: Dictionary = data["dialogues"][did]
	var key := "seen_" + did
	var lines: Array = []
	if not flags.has(key):
		flags[key] = true
		lines = d.get("intro", [])
	play_lines(lines, _npc_menu)


func _npc_menu() -> void:
	_clear_choices()
	busy = true
	dialog_panel.visible = true
	var d: Dictionary = data["dialogues"][current_npc]
	dialog_text.text = str(d["name"]) + ": \"" + str(d.get("claim", "...")) + "\""
	for t in d.get("topics", []):
		if t.has("requires_clue") and not clues.has(t["requires_clue"]):
			continue
		if t.has("requires_flag") and not flags.has(t["requires_flag"]):
			continue
		_add_choice(str(t["q"]), _run_result.bind(t))
	_add_choice("Kanıt göster", func(): open_notebook("show"))
	_add_choice("Ayrıl", _close_dialog)
	_layout_dialog()


func _run_result(r: Dictionary) -> void:
	if r.has("set_flag"):
		flags[r["set_flag"]] = true
	play_lines(r.get("lines", []), _after_result.bind(str(r.get("gives_clue", ""))))


func _after_result(gives: String) -> void:
	if gives != "" and not clues.has(gives):
		give_clue(gives, _npc_menu)
	else:
		_npc_menu()


func _show_clue(id: String) -> void:
	var d: Dictionary = data["dialogues"][current_npc]
	var shows: Dictionary = d.get("show", {})
	if shows.has(id):
		_run_result(shows[id])
	else:
		wrong_shows += 1
		var q: Array = data["wrong_quips"]
		play_lines([["Maya", str(q[randi() % q.size()])]], _npc_menu)


# ---------------------------------------------------------------- defter ve dedüksiyon

func open_notebook(mode: String) -> void:
	if mode == "" and busy:
		return
	busy = true
	select_mode = mode
	link_first = ""
	dialog_panel.visible = false
	notebook_panel.visible = true
	_fill_notebook("Bir ipucuna tıkla." if mode == "" else "Hangi kanıtı göstereceksin?")


func _fill_notebook(info: String) -> void:
	for c in notebook_list.get_children():
		notebook_list.remove_child(c)
		c.queue_free()
	match select_mode:
		"show":
			notebook_title.text = "KANIT GÖSTER"
		"link":
			notebook_title.text = "DEDÜKSİYON TAHTASI"
		_:
			notebook_title.text = "DEFTER (" + str(clues.size()) + " ipucu)"
	for id in clues.keys():
		var b := Button.new()
		var nm := str(data["clues"][id]["name"])
		if id == link_first:
			nm = "> " + nm
		b.text = nm
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_on_clue_pressed.bind(str(id)))
		notebook_list.add_child(b)
	if not deductions.is_empty():
		var sep := Label.new()
		sep.text = "\nSONUÇLAR"
		sep.add_theme_color_override("font_color", C_YELLOW)
		notebook_list.add_child(sep)
		for d in data["deductions"]:
			if deductions.has(d["id"]):
				var lb := Label.new()
				lb.text = "- " + str(d["text"])
				lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				lb.custom_minimum_size = Vector2(240, 0)
				notebook_list.add_child(lb)
	notebook_info.text = info
	var req: Array = data["final"]["required"]
	var done := 0
	for rid in req:
		if deductions.has(rid):
			done += 1
	progress_label.text = "Gerekli sonuçlar: " + str(done) + "/" + str(req.size()) + "  (NASIL, FIRSAT, MOTİF, FİZİKSEL KANIT)"
	_update_hud()
	link_button.visible = select_mode == ""
	accuse_button.visible = select_mode == "" and _final_ready()


func _on_clue_pressed(id: String) -> void:
	match select_mode:
		"show":
			notebook_panel.visible = false
			dialog_panel.visible = true
			_show_clue(id)
		"link":
			if link_first == "":
				link_first = id
				_fill_notebook("İkinci ipucunu seç.")
			else:
				var a := link_first
				link_first = ""
				select_mode = ""
				_fill_notebook(_try_link(a, id))
		_:
			notebook_info.text = _clue_text(id)


func _start_link() -> void:
	select_mode = "link"
	link_first = ""
	_fill_notebook("Bağlamak istediğin ilk ipucunu seç.")


func _try_link(a: String, b: String) -> String:
	if a == b:
		return "Oscar: Aynı ipucunu kendisiyle bağlamak. Yorgunum ama bu kadar değil."
	if pending_lab.has(a) or pending_lab.has(b):
		return "Maya: Önce laboratuvar sonucunu bekle."
	for d in data["deductions"]:
		var p: Array = d["pair"]
		if (p[0] == a and p[1] == b) or (p[0] == b and p[1] == a):
			if deductions.has(d["id"]):
				return "Bu bağlantıyı zaten kurdun."
			deductions[d["id"]] = true
			var t := "YENİ SONUÇ: " + str(d["text"])
			if _final_ready() and not final_hint_shown:
				final_hint_shown = true
				t += "\n\nOscar: Yeterince kanıtım var. Sorgu odasına gidelim."
			return t
	var q: Array = data["link_fail_quips"]
	return "Oscar: " + str(q[randi() % q.size()])


func _final_ready() -> bool:
	for id in data["final"]["required"]:
		if not deductions.has(id):
			return false
	return true


func _close_notebook() -> void:
	notebook_panel.visible = false
	if select_mode == "show":
		select_mode = ""
		dialog_panel.visible = true
		_npc_menu()
	else:
		select_mode = ""
		busy = false


# ---------------------------------------------------------------- suçlama ve final

func _open_accuse() -> void:
	notebook_panel.visible = false
	for c in accuse_list.get_children():
		accuse_list.remove_child(c)
		c.queue_free()
	var t := Label.new()
	t.text = "FCD sorgu odası. Suçlu kim?"
	accuse_list.add_child(t)
	for s in data["final"]["suspects"]:
		var b := Button.new()
		b.text = str(s[1])
		b.pressed.connect(_accuse.bind(str(s[0])))
		accuse_list.add_child(b)
	var back := Button.new()
	back.text = "Vazgeç"
	back.pressed.connect(func():
		accuse_panel.visible = false
		busy = false)
	accuse_list.add_child(back)
	accuse_panel.visible = true


func _accuse(id: String) -> void:
	accuse_panel.visible = false
	var fin: Dictionary = data["final"]
	if id == str(fin["culprit"]):
		play_lines(fin["lines"], _win)
	else:
		wrong_shows += 2
		play_lines(fin["wrong"][id], Callable())


func _win() -> void:
	var stars := 3
	if wrong_shows > 2:
		stars = 2
	if wrong_shows > 6:
		stars = 1
	var reward: int = int(data["final"]["reward"]) * stars
	debt -= reward
	_update_debt()
	_clear_choices()
	busy = true
	dialog_panel.visible = true
	dialog_text.text = "VAKA ÇÖZÜLDÜ  " + "*".repeat(stars) + "\nÖdül: $" + str(reward) + ". Ev sahibi Bayan Kowalski bir hafta daha sabredecek."
	_add_choice("Baştan oyna", func(): get_tree().reload_current_scene())
	_layout_dialog()


# ---------------------------------------------------------------- küçük yardımcılar

func toggle_eye() -> void:
	if busy:
		return
	if eye_on:
		eye_on = false
	elif eye_uses > 0:
		eye_on = true
		eye_uses -= 1
	else:
		show_msg("Oscar'ın Gözü bu mekanda yoruldu.")
		return
	_refresh_visibility()
	_update_eye_button()


func _update_eye_button() -> void:
	if eye_button:
		eye_button.text = ("Gözü kapat" if eye_on else "Oscar'ın Gözü") + " (" + str(eye_uses) + ")"


func _update_debt() -> void:
	debt_label.text = "Borç: $" + str(debt)


func show_msg(t: String) -> void:
	msg_label.text = t
	msg_label.modulate.a = 1.0
	if msg_tween:
		msg_tween.kill()
	msg_tween = create_tween()
	msg_tween.tween_interval(2.0)
	msg_tween.tween_property(msg_label, "modulate:a", 0.0, 0.8)
