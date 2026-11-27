extends Node2D
## Dark Files - Vaka 1. Tüm oyun bu tek sahnede, vaka verisi data/case1.json içinde.
##
## Dünya "çizim pikseli" biriminde kurulur ve kamera 2x yakınlaştırır: ekran 640x360,
## dünya görünümü 320x180. Böylece 32x48 karakterler ve 344x192 PixelLab sahneleri aynı
## piksel boyutunda görünür. Arayüz (yazılar, paneller) 640x360 ekran biriminde kalır.

const VIEW_W := 640.0
const VIEW_H := 360.0
const ZOOM := 2.0
const WORLD_H := 180.0           # VIEW_H / ZOOM
const DEFAULT_FLOOR_Y := 168.0   # mekanda "floor_y" yoksa zemin çizgisi
const SPEED := 70.0
const INTERACT_RANGE := 22.0
const TYPE_SPEED := 55.0         # daktilo efekti, saniyede karakter
## art/oscar.png sağa bakıyorsa true, sola bakıyorsa false yap.
const PLAYER_ART_FACES_RIGHT := true
## Yürüme şeridi (art/oscar_walk.png): yan yana eşit kareler, kare başına süre.
const WALK_FRAME_TIME := 0.13
const IDLE_FRAME_TIME := 0.7

# Palet: siyah, kahverengi, sarı
const C_BLACK := Color("#0f0b08")
const C_DARK := Color("#2b1d14")
const C_BROWN := Color("#5a3d2b")
const C_LIGHT := Color("#8a6a4f")
const C_YELLOW := Color("#e8c547")
const C_PALE := Color("#f2e3b3")

var data: Dictionary = {}
var room_id: String = ""
var room_w: float = 320.0
var floor_y: float = DEFAULT_FLOOR_Y
var room_h: float = WORLD_H
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
var in_menu: bool = true

# Dünya
var room_layer: Node2D
var fx_layer: Node2D
var player: Node2D
var player_sprite: TextureRect
var walk_time: float = 0.0
var idle_time: float = 0.0
var idle_frames: Array = []
var walk_frames: Array = []
var camera: Camera2D
var target_x: float = -1.0
var pending_action: Callable = Callable()
var room_objects: Array = []
var bg_nodes: Array = []
var npc_anims: Array = []
var anim_clock: float = 0.0

# Arayüz
var ui_root: Control
var msg_label: Label
var debt_label: Label
var eye_button: Button
var notebook_button: Button
var accuse_hud: Button
var hover_label: Label
var dialog_panel: PanelContainer
var portrait_box: PanelContainer
var portrait: TextureRect
var name_label: Label
var dialog_text: Label
var continue_label: Label
var dialog_choices: VBoxContainer
var notebook_panel: PanelContainer
var notebook_list: VBoxContainer
var notebook_info: Label
var notebook_title: Label
var progress_label: Label
var link_button: Button
var accuse_button: Button
var accuse_panel: PanelContainer
var accuse_list: VBoxContainer
var menu_panel: Control
var fade_rect: ColorRect
var sfx: Dictionary = {}

# Diyalog durumu
var line_queue: Array = []
var after_lines: Callable = Callable()
var busy: bool = true
var current_npc: String = ""
var select_mode: String = ""
var link_first: String = ""
var typing: bool = false
var type_acc: float = 0.0
var blip_count: int = 0
var msg_tween: Tween


func _ready() -> void:
	var f := FileAccess.open("res://data/case1.json", FileAccess.READ)
	data = JSON.parse_string(f.get_as_text())
	room_layer = Node2D.new()
	add_child(room_layer)
	fx_layer = Node2D.new()
	add_child(fx_layer)
	_build_player()
	_build_atmosphere()
	_build_ui()
	_build_sfx()
	load_room(str(data["start_room"]), float(data["start_x"]))
	_build_menu()


# ================================================================ kurulum

func _build_player() -> void:
	player = Node2D.new()
	add_child(player)
	var tex := _art("oscar")
	if tex:
		player_sprite = _child_tex(player, Vector2(-tex.get_width() / 2.0, -tex.get_height()), tex)
		walk_frames = _strip_frames(_art("oscar_walk"), tex.get_width())
		idle_frames = _strip_frames(_art("oscar_idle"), tex.get_width())
		if idle_frames.is_empty():
			idle_frames = [tex]
	else:
		_child_rect(player, Vector2(-8, -44), Vector2(16, 44), C_PALE)
	camera = Camera2D.new()
	camera.zoom = Vector2(ZOOM, ZOOM)
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_bottom = int(WORLD_H)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	player.add_child(camera)
	camera.make_current()


## Yan yana eşit karelerden oluşan bir şeridi karelere böler.
func _strip_frames(sheet: Texture2D, frame_w: int) -> Array:
	var out: Array = []
	if sheet == null or frame_w <= 0:
		return out
	var count: int = int(sheet.get_width() / frame_w)
	for i in range(count):
		var at := AtlasTexture.new()
		at.atlas = sheet
		at.region = Rect2(i * frame_w, 0, frame_w, sheet.get_height())
		out.append(at)
	return out


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


func _build_atmosphere() -> void:
	# Vinyet: kenarları karartan radyal gradyan (dosya gerekmez)
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(0.02, 0.01, 0.0, 0.75))
	g.add_point(0.55, Color(0, 0, 0, 0.05))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.05, 0.5)
	gt.width = 128
	gt.height = 72
	var v := TextureRect.new()
	v.texture = gt
	v.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	v.stretch_mode = TextureRect.STRETCH_SCALE
	v.size = Vector2(VIEW_W, VIEW_H)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	layer.add_child(v)

	# Havada süzülen toz
	var dust := CPUParticles2D.new()
	dust.amount = 40
	dust.lifetime = 9.0
	dust.preprocess = 9.0
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(VIEW_W / 2.0, VIEW_H / 2.0)
	dust.position = Vector2(VIEW_W / 2.0, VIEW_H / 2.0)
	dust.direction = Vector2(1, -0.2)
	dust.spread = 60.0
	dust.gravity = Vector2(0, 1.5)
	dust.initial_velocity_min = 2.0
	dust.initial_velocity_max = 6.0
	dust.scale_amount_min = 2.0
	dust.scale_amount_max = 2.0
	dust.color = Color(0.95, 0.89, 0.7, 0.18)
	layer.add_child(dust)


func _make_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 12

	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.06, 0.043, 0.03, 0.94)
	panel.border_color = C_BROWN
	panel.set_border_width_all(2)
	panel.set_content_margin_all(10)
	th.set_stylebox("panel", "PanelContainer", panel)

	var btn := StyleBoxFlat.new()
	btn.bg_color = C_DARK
	btn.border_color = C_BROWN
	btn.set_border_width_all(1)
	btn.content_margin_left = 8
	btn.content_margin_right = 8
	btn.content_margin_top = 3
	btn.content_margin_bottom = 3
	var btn_hover := btn.duplicate() as StyleBoxFlat
	btn_hover.border_color = C_YELLOW
	btn_hover.bg_color = Color("#3a281b")
	var btn_pressed := btn.duplicate() as StyleBoxFlat
	btn_pressed.bg_color = C_BROWN
	btn_pressed.border_color = C_YELLOW
	var btn_disabled := btn.duplicate() as StyleBoxFlat
	btn_disabled.bg_color = Color(0.1, 0.07, 0.05)
	th.set_stylebox("normal", "Button", btn)
	th.set_stylebox("hover", "Button", btn_hover)
	th.set_stylebox("pressed", "Button", btn_pressed)
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_stylebox("disabled", "Button", btn_disabled)
	th.set_color("font_color", "Button", C_PALE)
	th.set_color("font_hover_color", "Button", C_YELLOW)
	th.set_color("font_pressed_color", "Button", C_YELLOW)
	th.set_color("font_focus_color", "Button", C_PALE)
	th.set_color("font_color", "Label", C_PALE)
	th.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.8))
	th.set_constant("shadow_offset_x", "Label", 1)
	th.set_constant("shadow_offset_y", "Label", 1)
	th.set_constant("separation", "VBoxContainer", 4)
	th.set_constant("separation", "HBoxContainer", 10)
	return th


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	ui_root = Control.new()
	ui_root.size = Vector2(VIEW_W, VIEW_H)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.theme = _make_theme()
	layer.add_child(ui_root)

	msg_label = Label.new()
	msg_label.position = Vector2(0, 44)
	msg_label.size = Vector2(VIEW_W, 24)
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.add_theme_color_override("font_color", C_YELLOW)
	msg_label.add_theme_font_size_override("font_size", 16)
	ui_root.add_child(msg_label)

	debt_label = Label.new()
	debt_label.position = Vector2(VIEW_W - 200, 10)
	debt_label.size = Vector2(190, 20)
	debt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ui_root.add_child(debt_label)
	_update_debt()

	notebook_button = Button.new()
	notebook_button.text = "Defter [Tab]"
	notebook_button.position = Vector2(8, 8)
	notebook_button.pressed.connect(func(): open_notebook(""))
	ui_root.add_child(notebook_button)

	eye_button = Button.new()
	eye_button.position = Vector2(104, 8)
	eye_button.pressed.connect(toggle_eye)
	ui_root.add_child(eye_button)
	_update_eye_button()

	accuse_hud = Button.new()
	accuse_hud.text = "SUÇLA"
	accuse_hud.position = Vector2(258, 8)
	accuse_hud.add_theme_color_override("font_color", C_YELLOW)
	accuse_hud.visible = false
	accuse_hud.pressed.connect(func():
		if busy:
			return
		busy = true
		_open_accuse())
	ui_root.add_child(accuse_hud)

	hover_label = Label.new()
	hover_label.add_theme_color_override("font_color", C_YELLOW)
	hover_label.visible = false
	ui_root.add_child(hover_label)

	# Diyalog kutusu: portre + isim + metin + seçenekler
	dialog_panel = PanelContainer.new()
	dialog_panel.position = Vector2(12, 250)
	dialog_panel.custom_minimum_size = Vector2(VIEW_W - 24, 0)
	dialog_panel.visible = false
	dialog_panel.gui_input.connect(_on_dialog_input)
	ui_root.add_child(dialog_panel)
	var hb := HBoxContainer.new()
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog_panel.add_child(hb)
	portrait_box = PanelContainer.new()
	portrait_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = C_DARK
	pstyle.border_color = C_YELLOW
	pstyle.set_border_width_all(1)
	pstyle.set_content_margin_all(2)
	portrait_box.add_theme_stylebox_override("panel", pstyle)
	portrait_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hb.add_child(portrait_box)
	portrait = TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(72, 72)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_box.add_child(portrait)
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(vb)
	name_label = Label.new()
	name_label.add_theme_color_override("font_color", C_YELLOW)
	vb.add_child(name_label)
	dialog_text = Label.new()
	dialog_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog_text.custom_minimum_size = Vector2(500, 34)
	dialog_text.add_theme_font_size_override("font_size", 13)
	vb.add_child(dialog_text)
	dialog_choices = VBoxContainer.new()
	vb.add_child(dialog_choices)
	continue_label = Label.new()
	continue_label.text = "tıkla / boşluk"
	continue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	continue_label.add_theme_color_override("font_color", C_LIGHT)
	continue_label.add_theme_font_size_override("font_size", 9)
	vb.add_child(continue_label)

	# Defter
	notebook_panel = PanelContainer.new()
	notebook_panel.position = Vector2(24, 40)
	notebook_panel.custom_minimum_size = Vector2(VIEW_W - 48, VIEW_H - 56)
	notebook_panel.visible = false
	ui_root.add_child(notebook_panel)
	var nhb := HBoxContainer.new()
	notebook_panel.add_child(nhb)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(270, 0)
	nhb.add_child(left)
	notebook_title = Label.new()
	notebook_title.add_theme_color_override("font_color", C_YELLOW)
	notebook_title.add_theme_font_size_override("font_size", 14)
	left.add_child(notebook_title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(270, 255)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	notebook_list = VBoxContainer.new()
	notebook_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(notebook_list)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nhb.add_child(right)
	progress_label = Label.new()
	progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	progress_label.custom_minimum_size = Vector2(280, 0)
	progress_label.add_theme_color_override("font_color", C_YELLOW)
	right.add_child(progress_label)
	notebook_info = Label.new()
	notebook_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notebook_info.custom_minimum_size = Vector2(280, 140)
	notebook_info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(notebook_info)
	var hint_btn := Button.new()
	hint_btn.text = "Maya'ya sor (ipucu)"
	hint_btn.pressed.connect(func():
		_sfx("click")
		notebook_info.text = _hint_text())
	right.add_child(hint_btn)
	link_button = Button.new()
	link_button.text = "Dedüksiyon tahtası: iki ipucunu bağla"
	link_button.pressed.connect(_start_link)
	right.add_child(link_button)
	accuse_button = Button.new()
	accuse_button.text = "FCD sorgu odasına git ve suçla"
	accuse_button.add_theme_color_override("font_color", C_YELLOW)
	accuse_button.pressed.connect(_open_accuse)
	right.add_child(accuse_button)
	var close_btn := Button.new()
	close_btn.text = "Kapat [Tab]"
	close_btn.pressed.connect(_close_notebook)
	right.add_child(close_btn)

	# Suçlama
	accuse_panel = PanelContainer.new()
	accuse_panel.position = Vector2(190, 70)
	accuse_panel.custom_minimum_size = Vector2(260, 0)
	accuse_panel.visible = false
	ui_root.add_child(accuse_panel)
	accuse_list = VBoxContainer.new()
	accuse_panel.add_child(accuse_list)

	# Sahne geçişi için kararma (her şeyin üstünde)
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 10
	add_child(fade_layer)
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.size = Vector2(VIEW_W, VIEW_H)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(fade_rect)


func _build_menu() -> void:
	menu_panel = ColorRect.new()
	(menu_panel as ColorRect).color = Color(0.03, 0.02, 0.01, 0.82)
	menu_panel.size = Vector2(VIEW_W, VIEW_H)
	ui_root.add_child(menu_panel)
	var title := Label.new()
	title.text = "DARK FILES"
	title.position = Vector2(0, 70)
	title.size = Vector2(VIEW_W, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", C_YELLOW)
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 3)
	menu_panel.add_child(title)
	var sub := Label.new()
	sub.text = str(data.get("case_name", "Vaka 1"))
	sub.position = Vector2(0, 126)
	sub.size = Vector2(VIEW_W, 20)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 15)
	menu_panel.add_child(sub)
	var box := VBoxContainer.new()
	box.position = Vector2(VIEW_W / 2.0 - 80, 172)
	box.custom_minimum_size = Vector2(160, 0)
	menu_panel.add_child(box)
	var start := Button.new()
	start.text = "Vakayı aç"
	start.pressed.connect(_start_game)
	box.add_child(start)
	var quit := Button.new()
	quit.text = "Çıkış"
	quit.pressed.connect(func(): get_tree().quit())
	box.add_child(quit)
	var help := Label.new()
	help.text = "Fare: tıkla, yürü, incele, konuş     Klavye: A/D yürü, E etkileşim, Q Oscar'ın Gözü, Tab defter"
	help.position = Vector2(0, 318)
	help.size = Vector2(VIEW_W, 20)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 10)
	help.add_theme_color_override("font_color", C_LIGHT)
	menu_panel.add_child(help)
	_set_hud_visible(false)
	busy = true
	in_menu = true


func _start_game() -> void:
	if not in_menu:
		return
	_sfx("click")
	in_menu = false
	var tw := create_tween()
	tw.tween_property(menu_panel, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func():
		menu_panel.visible = false
		_set_hud_visible(true)
		play_lines(data["intro"], Callable()))


func _set_hud_visible(v: bool) -> void:
	notebook_button.visible = v
	eye_button.visible = v
	debt_label.visible = v
	if not v:
		accuse_hud.visible = false


## sfx/<ad>.wav dosyaları varsa çalınır; yoksa sessiz geçer.
func _build_sfx() -> void:
	for n in ["blip", "pickup", "door", "click", "deduce", "wrong", "solve", "eye"]:
		var p: String = "res://sfx/" + n + ".wav"
		if ResourceLoader.exists(p):
			var a := AudioStreamPlayer.new()
			a.stream = load(p)
			a.volume_db = -8.0 if n == "blip" else -4.0
			add_child(a)
			sfx[n] = a
	# Arka plan müziği: sfx/music.wav varsa döngüde çalar.
	if ResourceLoader.exists("res://sfx/music.wav"):
		var m := AudioStreamPlayer.new()
		m.stream = load("res://sfx/music.wav")
		m.volume_db = -6.0
		add_child(m)
		m.finished.connect(m.play)
		m.play()


func _sfx(n: String) -> void:
	if sfx.has(n):
		var a: AudioStreamPlayer = sfx[n]
		if n == "blip":
			a.pitch_scale = randf_range(0.9, 1.1)
		a.play()


# ================================================================ mekan

func go_room(id: String, spawn_x: float) -> void:
	busy = true
	_sfx("door")
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 1.0, 0.25)
	tw.tween_callback(load_room.bind(id, spawn_x))
	tw.tween_property(fade_rect, "color:a", 0.0, 0.3)
	tw.tween_callback(func():
		if not dialog_panel.visible and not notebook_panel.visible:
			busy = false)


func load_room(id: String, spawn_x: float) -> void:
	room_id = id
	for c in room_layer.get_children():
		room_layer.remove_child(c)
		c.queue_free()
	for c in fx_layer.get_children():
		fx_layer.remove_child(c)
		c.queue_free()
	room_objects.clear()
	bg_nodes.clear()
	npc_anims.clear()
	var r: Dictionary = data["rooms"][id]
	room_w = float(r["width"])
	floor_y = float(r.get("floor_y", DEFAULT_FLOOR_Y))
	var bg_tex := _art("rooms/" + id)
	room_h = WORLD_H
	if bg_tex:
		room_w = maxf(room_w, bg_tex.get_width())
		room_h = maxf(WORLD_H, bg_tex.get_height())
		bg_nodes.append(_child_tex(room_layer, Vector2.ZERO, bg_tex))
	else:
		_draw_fallback_room(r)
	for o in r["objects"]:
		_spawn_object(o, bg_tex != null)
	if bool(r.get("rain", false)):
		_add_rain()
	player.position = Vector2(clampf(spawn_x, 8.0, room_w - 8.0), floor_y)
	# Sahne 180'den uzunsa (PixelLab 192) dikeyde ortala.
	camera.position = Vector2(0, room_h / 2.0 - floor_y)
	camera.limit_right = int(room_w)
	camera.limit_bottom = int(room_h)
	camera.reset_smoothing()
	eye_on = false
	eye_uses = 3
	_update_eye_button()
	target_x = -1.0
	pending_action = Callable()
	_refresh_visibility()
	show_msg(str(r["name"]))
	_complete_lab()


## Sahne çizimi (art/rooms/<id>.png) yokken basit duvar ve zemin.
func _draw_fallback_room(r: Dictionary) -> void:
	var wall := Color.html(str(r.get("bg", "#2b1d14")))
	bg_nodes.append(_child_rect(room_layer, Vector2.ZERO, Vector2(room_w, WORLD_H), wall))
	bg_nodes.append(_child_rect(room_layer, Vector2(0, floor_y - 40), Vector2(room_w, 40), wall.darkened(0.25)))
	bg_nodes.append(_child_rect(room_layer, Vector2(0, floor_y - 42), Vector2(room_w, 2), C_BROWN))
	bg_nodes.append(_child_rect(room_layer, Vector2(0, floor_y - 4), Vector2(room_w, 4), C_BROWN))
	bg_nodes.append(_child_rect(room_layer, Vector2(0, floor_y), Vector2(room_w, WORLD_H - floor_y), C_BLACK))
	for d in r.get("decor", []):
		var w: float = float(d["w"])
		var h: float = float(d["h"])
		var pos := Vector2(float(d["x"]) - w / 2.0, floor_y - float(d.get("y", 0)) - h)
		bg_nodes.append(_child_rect(room_layer, pos, Vector2(w, h), Color.html(str(d.get("color", "#3a2a1e")))))


func _add_rain() -> void:
	var rain := CPUParticles2D.new()
	rain.amount = 120
	rain.lifetime = 0.8
	rain.preprocess = 1.0
	rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	rain.emission_rect_extents = Vector2(room_w / 2.0, 2)
	rain.position = Vector2(room_w / 2.0, -4)
	rain.direction = Vector2(-0.15, 1)
	rain.spread = 2.0
	rain.gravity = Vector2(0, 0)
	rain.initial_velocity_min = 220.0
	rain.initial_velocity_max = 260.0
	rain.scale_amount_min = 1.0
	rain.scale_amount_max = 1.0
	rain.color = Color(0.75, 0.7, 0.6, 0.35)
	fx_layer.add_child(rain)


func _spawn_object(o: Dictionary, has_bg: bool) -> void:
	var t: String = str(o["type"])
	var w: float = maxf(float(o.get("w", 6)), 4.0)
	var h: float = maxf(float(o.get("h", 6)), 4.0)
	var col := C_YELLOW
	var label_text := ""
	var art_key := ""
	match t:
		"clue":
			art_key = str(o["id"])
		"npc":
			art_key = str(o.get("art", o["dialogue"]))
			w = 18.0
			h = 44.0
			col = C_LIGHT
			label_text = str(data["dialogues"][o["dialogue"]]["name"])
		"door":
			art_key = str(o.get("art", "door"))
			w = 24.0
			h = 54.0
			col = C_DARK
			label_text = str(data["rooms"][o["to"]]["name"])
	var tex := _art(art_key)
	var frames: Array = []
	if t == "npc" and tex:
		frames = _strip_frames(_art(art_key + "_idle"), tex.get_width())
	if tex:
		w = tex.get_width()
		h = tex.get_height()
	var pos := Vector2(float(o["x"]) - w / 2.0, floor_y - float(o.get("y", 0)) - h)
	var n: Control
	if tex:
		n = _child_tex(room_layer, pos, tex)
	else:
		n = _child_rect(room_layer, pos, Vector2(w, h), col)
		if t == "door":
			# kapı çerçevesi ve tokmak; sahne çizimi varsa kapı görünmez, sadece tıklanır
			if has_bg:
				(n as ColorRect).color = Color(0, 0, 0, 0)
			else:
				_child_rect(n, Vector2(-2, -2), Vector2(w + 4, 2), C_BROWN)
				_child_rect(n, Vector2(-2, 0), Vector2(2, h), C_BROWN)
				_child_rect(n, Vector2(w, 0), Vector2(2, h), C_BROWN)
				_child_rect(n, Vector2(w - 6, h / 2.0), Vector2(2, 2), C_YELLOW)
	if t == "npc" and not frames.is_empty():
		npc_anims.append({"node": n, "frames": frames, "phase": randf() * 2.0})
	if t == "clue":
		if has_bg and not tex:
			# Sahne çiziminde nesne zaten resimde: kutu yerine yanıp sönen bir yıldız.
			(n as ColorRect).color = Color(0, 0, 0, 0)
			var star := Control.new()
			star.position = Vector2(w / 2.0, h / 2.0)
			star.mouse_filter = Control.MOUSE_FILTER_IGNORE
			n.add_child(star)
			for sp in [[Vector2(-2, 0), Vector2(5, 1)], [Vector2(0, -2), Vector2(1, 5)]]:
				var arm := _child_rect(star, sp[0], sp[1], C_YELLOW)
				arm.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var core := _child_rect(star, Vector2.ZERO, Vector2(1, 1), C_PALE)
			core.mouse_filter = Control.MOUSE_FILTER_IGNORE
			star.modulate.a = 0.0
			var st := star.create_tween().set_loops()
			st.tween_interval(randf_range(0.2, 1.6))
			st.tween_property(star, "modulate:a", 1.0, 0.25)
			st.tween_property(star, "modulate:a", 0.0, 0.5)
		else:
			# ipucu parıltısı
			var tw := n.create_tween().set_loops()
			tw.tween_property(n, "self_modulate:a", 0.45, 0.7)
			tw.tween_property(n, "self_modulate:a", 1.0, 0.7)
	if label_text != "":
		var lb := Label.new()
		lb.text = label_text
		lb.position = Vector2(-40, -9)
		lb.size = Vector2(w + 80, 8)
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lb.add_theme_font_size_override("font_size", 6)
		lb.add_theme_color_override("font_color", C_YELLOW if t == "door" else C_PALE)
		lb.add_theme_constant_override("shadow_offset_x", 0)
		lb.add_theme_constant_override("shadow_offset_y", 0)
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
	var dim := Color(0.3, 0.3, 0.3)
	for e in room_objects:
		var o: Dictionary = e["data"]
		var n: Control = e["node"]
		n.visible = _obj_visible(o)
		n.modulate = dim if (eye_on and str(o["type"]) != "clue") else Color(1, 1, 1)
	for b in bg_nodes:
		b.modulate = dim if eye_on else Color(1, 1, 1)
	if player_sprite:
		player_sprite.modulate = Color(0.6, 0.6, 0.6) if eye_on else Color(1, 1, 1)


func _object_at(pos: Vector2) -> Dictionary:
	for i in range(room_objects.size() - 1, -1, -1):
		var e: Dictionary = room_objects[i]
		var n: Control = e["node"]
		if not n.visible:
			continue
		if Rect2(n.position, n.size).grow(4).has_point(pos):
			return e["data"]
	return {}


func _hover_text(o: Dictionary) -> String:
	match str(o["type"]):
		"clue":
			return "İncele"
		"npc":
			return "Konuş: " + str(data["dialogues"][o["dialogue"]]["name"])
		"door":
			return "Git: " + str(data["rooms"][o["to"]]["name"])
	return ""


# ================================================================ hareket ve girdi

func _process(delta: float) -> void:
	_animate(delta)
	_type_step(delta)
	_update_hover()
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


func _update_hover() -> void:
	if busy:
		hover_label.visible = false
		return
	var o := _object_at(get_global_mouse_position())
	if o.is_empty():
		hover_label.visible = false
		return
	hover_label.text = _hover_text(o)
	hover_label.position = get_viewport().get_mouse_position() + Vector2(12, -18)
	hover_label.visible = true


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null:
		if not key.pressed or key.echo:
			return
		if in_menu:
			if key.keycode == KEY_ENTER or key.keycode == KEY_SPACE:
				_start_game()
			return
		if key.keycode == KEY_TAB:
			if notebook_panel.visible:
				_close_notebook()
			else:
				open_notebook("")
			return
		if busy:
			if dialog_panel.visible and dialog_choices.get_child_count() == 0 and (key.keycode == KEY_SPACE or key.keycode == KEY_ENTER or key.keycode == KEY_E):
				_advance()
			return
		if key.keycode == KEY_E:
			_interact_nearest()
		elif key.keycode == KEY_Q:
			toggle_eye()
		return
	if busy:
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		var pos := get_global_mouse_position()
		var o := _object_at(pos)
		if not o.is_empty():
			walk_to(float(o["x"]), _interact.bind(o))
		else:
			walk_to(pos.x, Callable())


## Oscar'ın yürüme / durma kareleri ve şüphelilerin nefes alma kareleri.
func _animate(delta: float) -> void:
	anim_clock += delta
	for a in npc_anims:
		var frames: Array = a["frames"]
		var i := int((anim_clock + float(a["phase"])) / IDLE_FRAME_TIME) % frames.size()
		(a["node"] as TextureRect).texture = frames[i]
	if not player_sprite:
		return
	var moving := not busy and (target_x >= 0.0 or Input.is_action_pressed("ui_left") or Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_D))
	if moving and not walk_frames.is_empty():
		walk_time += delta
		var i := int(walk_time / WALK_FRAME_TIME) % walk_frames.size()
		player_sprite.texture = walk_frames[i]
	else:
		walk_time = 0.0
		idle_time += delta
		var j := int(idle_time / IDLE_FRAME_TIME) % idle_frames.size()
		player_sprite.texture = idle_frames[j]


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
				go_room(str(o["to"]), float(o["spawn_x"]))
		"npc":
			start_dialogue(str(o["dialogue"]))


# ================================================================ ipuçları

func give_clue(id: String, done: Callable) -> void:
	if clues.has(id):
		if done.is_valid():
			done.call()
		return
	clues[id] = true
	_sfx("pickup")
	var c: Dictionary = data["clues"][id]
	if c.has("sets_flag"):
		flags[c["sets_flag"]] = true
	var lines: Array = [["", "Yeni ipucu: " + str(c["name"]) + "\n" + str(c["desc"])]]
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
		lines.append(["Maya", "Lab sonucu geldi. " + str(c["name"]) + ": " + str(c["analysis"])])
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
			lines.append(["Oscar", "Dur bir dakika... Defterimdeki iki ipucu birbirine bağlanıyor. Dedüksiyon tahtasına bakmalıyım. [Tab]"])
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
	accuse_hud.visible = _final_ready() and not in_menu


func _clue_text(id: String) -> String:
	var c: Dictionary = data["clues"][id]
	var t := str(c["name"]) + "\n\n" + str(c["desc"])
	if lab_done.has(id):
		t += "\n\nLab: " + str(c["analysis"])
	elif pending_lab.has(id):
		t += "\n\nLab: sonuç bekleniyor."
	return t


# ================================================================ diyalog

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
	_show_line(str(l[0]), str(l[1]), true)


## Konuşan kişinin adını, portresini ve metni gösterir.
func _show_line(who: String, text: String, animate: bool) -> void:
	name_label.text = who
	name_label.visible = who != ""
	_set_portrait(who)
	dialog_text.text = text
	if animate:
		typing = true
		type_acc = 0.0
		dialog_text.visible_characters = 0
	else:
		typing = false
		dialog_text.visible_characters = -1
	continue_label.visible = animate
	_layout_dialog()


func _set_portrait(who: String) -> void:
	var speakers: Dictionary = data.get("speakers", {})
	var key: String = str(speakers.get(who, ""))
	var tex: Texture2D = _art(key) if key != "" else null
	if tex == null:
		portrait_box.visible = false
		return
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(0, 0, tex.get_width(), mini(30, tex.get_height()))
	portrait.texture = at
	portrait_box.visible = true


func _type_step(delta: float) -> void:
	if not typing:
		return
	type_acc += delta * TYPE_SPEED
	var n := int(type_acc)
	var total := dialog_text.get_total_character_count()
	if n >= total:
		typing = false
		dialog_text.visible_characters = -1
		return
	if n != dialog_text.visible_characters:
		dialog_text.visible_characters = n
		blip_count += 1
		if blip_count % 3 == 0:
			_sfx("blip")


func _advance() -> void:
	if typing:
		typing = false
		dialog_text.visible_characters = -1
		return
	_next_line()


func _on_dialog_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		if dialog_choices.get_child_count() == 0:
			_advance()


func _clear_choices() -> void:
	for c in dialog_choices.get_children():
		dialog_choices.remove_child(c)
		c.queue_free()


func _add_choice(text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(func():
		_sfx("click")
		cb.call())
	dialog_choices.add_child(b)


func _layout_dialog() -> void:
	dialog_panel.reset_size()
	dialog_panel.position.y = VIEW_H - 10.0 - dialog_panel.get_combined_minimum_size().y


func _close_dialog() -> void:
	dialog_panel.visible = false
	typing = false
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
	_show_line(str(d["name"]), "\"" + str(d.get("claim", "...")) + "\"", false)
	for t in d.get("topics", []):
		if t.has("requires_clue") and not clues.has(t["requires_clue"]):
			continue
		if t.has("requires_flag") and not flags.has(t["requires_flag"]):
			continue
		_add_choice("Sor: " + str(t["q"]), _run_result.bind(t))
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
		_sfx("deduce")
		_run_result(shows[id])
	else:
		wrong_shows += 1
		_sfx("wrong")
		var q: Array = data["wrong_quips"]
		play_lines([["Maya", str(q[randi() % q.size()])]], _npc_menu)


# ================================================================ defter ve dedüksiyon

func open_notebook(mode: String) -> void:
	if in_menu:
		return
	if mode == "" and busy:
		return
	busy = true
	_sfx("click")
	select_mode = mode
	link_first = ""
	dialog_panel.visible = false
	notebook_panel.visible = true
	_fill_notebook("Bir ipucuna tıkla, ayrıntısını gör." if mode == "" else "Hangi kanıtı göstereceksin?")


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
			notebook_title.text = "DEFTER  (" + str(clues.size()) + " ipucu)"
	if clues.is_empty():
		var empty := Label.new()
		empty.text = "Henüz ipucu yok. Mekanlardaki parlayan noktalara tıkla."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.custom_minimum_size = Vector2(250, 0)
		notebook_list.add_child(empty)
	for id in clues.keys():
		var b := Button.new()
		var nm := str(data["clues"][id]["name"])
		if id == link_first:
			nm = "> " + nm
			b.add_theme_color_override("font_color", C_YELLOW)
		b.text = nm
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_on_clue_pressed.bind(str(id)))
		notebook_list.add_child(b)
	if not deductions.is_empty():
		var sep := Label.new()
		sep.text = "SONUÇLAR"
		sep.add_theme_color_override("font_color", C_YELLOW)
		notebook_list.add_child(sep)
		for d in data["deductions"]:
			if deductions.has(d["id"]):
				var lb := Label.new()
				lb.text = "- " + str(d["text"])
				lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				lb.custom_minimum_size = Vector2(250, 0)
				notebook_list.add_child(lb)
	notebook_info.text = info
	var req: Array = data["final"]["required"]
	var done := 0
	for rid in req:
		if deductions.has(rid):
			done += 1
	progress_label.text = "Gerekli sonuçlar: " + str(done) + "/" + str(req.size()) + "\n(NASIL, FIRSAT, MOTİF, FİZİKSEL KANIT)"
	_update_hud()
	link_button.visible = select_mode == ""
	accuse_button.visible = select_mode == "" and _final_ready()


func _on_clue_pressed(id: String) -> void:
	_sfx("click")
	match select_mode:
		"show":
			notebook_panel.visible = false
			dialog_panel.visible = true
			select_mode = ""
			_show_clue(id)
		"link":
			if link_first == "":
				link_first = id
				_fill_notebook("İlk ipucu: " + str(data["clues"][id]["name"]) + "\nŞimdi ikinci ipucunu seç.")
			else:
				var a := link_first
				link_first = ""
				select_mode = ""
				_fill_notebook(_try_link(a, id))
		_:
			notebook_info.text = _clue_text(id)


func _start_link() -> void:
	_sfx("click")
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
			_sfx("deduce")
			var t := "YENİ SONUÇ:\n" + str(d["text"])
			if _final_ready() and not final_hint_shown:
				final_hint_shown = true
				t += "\n\nOscar: Yeterince kanıtım var. Sorgu odasına gidelim."
			return t
	_sfx("wrong")
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


# ================================================================ suçlama ve final

func _open_accuse() -> void:
	notebook_panel.visible = false
	select_mode = ""
	for c in accuse_list.get_children():
		accuse_list.remove_child(c)
		c.queue_free()
	var t := Label.new()
	t.text = "FCD SORGU ODASI\nSuçlu kim?"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_color_override("font_color", C_YELLOW)
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
		_sfx("wrong")
		play_lines(fin["wrong"][id], Callable())


func _win() -> void:
	_sfx("solve")
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
	_show_line("VAKA ÇÖZÜLDÜ", "Puan: " + str(stars) + "/3 yıldız   (yanlış kanıt / suçlama: " + str(wrong_shows) + ")\nÖdül: $" + str(reward) + ". Ev sahibi Bayan Kowalski bir hafta daha sabredecek.\n\nVesper & Co. ... Bu isim Oscar'ın peşini bırakmayacak.", false)
	_add_choice("Baştan oyna", func(): get_tree().reload_current_scene())
	_add_choice("Çıkış", func(): get_tree().quit())
	_layout_dialog()


# ================================================================ küçük yardımcılar

func toggle_eye() -> void:
	if busy:
		return
	if eye_on:
		eye_on = false
	elif eye_uses > 0:
		eye_on = true
		eye_uses -= 1
		_sfx("eye")
	else:
		show_msg("Oscar'ın Gözü bu mekanda yoruldu.")
		return
	_refresh_visibility()
	_update_eye_button()


func _update_eye_button() -> void:
	if eye_button:
		eye_button.text = ("Gözü kapat" if eye_on else "Oscar'ın Gözü") + " [Q] " + str(eye_uses)


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
