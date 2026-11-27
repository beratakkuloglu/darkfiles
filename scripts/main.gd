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
var char_scale: float = 1.0   # mekanda "char_scale": yakın çekim mekanlarda karakterleri büyütür
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
var notebook_list: Control
var board_content: Control
var board_strings: Control
var board_preview: TextureRect
var board_cards: Dictionary = {}
var board_default_info: String = ""
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

# Ayarlar ve duraklatma
const SETTINGS_PATH := "user://settings.cfg"
var settings := {"music": 0.7, "sfx": 0.8, "fullscreen": false}
var pause_panel: Control
var settings_panel: Control
var menu_button: Button
var paused: bool = false
var busy_before_pause: bool = false

# Eşya inceleme
const INSPECT_SIZE := 192.0
var inspect_panel: Control
var inspect_area: Control
var inspect_img: TextureRect
var inspect_card: Label
var inspect_spots: Control
var inspect_title: Label
var inspect_side_label: Label
var inspect_notes: Label
var inspect_flip: Button
var inspect_id: String = ""
var inspect_side: String = "front"
var inspect_done: Callable = Callable()
var found_details: Dictionary = {}
var notebook_selected: String = ""
var notebook_inspect_btn: Button

# Konuşma portreleri (büyük, parlayan; Oscar solda, karşısındaki sağda)
const BIG_PORTRAIT_SCALE := 4.0
const BIG_PORTRAIT_ROWS := 34
var big_portraits: Dictionary = {}   # "left" / "right" -> {"root", "img", "glow", "key", "tween"}


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


## Piksel yazı tipi (Pixelify Sans, OFL lisanslı, Türkçe karakterli); yoksa Godot'un varsayılanı.
func _ui_font() -> Font:
	var p := "res://fonts/PixelifySans-Medium.ttf"
	if not ResourceLoader.exists(p):
		return null
	var f: FontFile = load(p)
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	return f


func _make_theme() -> Theme:
	var th := Theme.new()
	th.default_font = _ui_font()
	th.default_font_size = 13

	# 2003 dosya odası havası: koyu deri panel, pirinç çerçeve, gölge.
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.07, 0.05, 0.035, 0.96)
	panel.border_color = Color("#9c7a3c")
	panel.set_border_width_all(2)
	panel.border_width_top = 3
	panel.set_content_margin_all(12)
	panel.shadow_color = Color(0, 0, 0, 0.7)
	panel.shadow_size = 6
	panel.shadow_offset = Vector2(3, 4)
	th.set_stylebox("panel", "PanelContainer", panel)

	# Kabartmalı (bevel) butonlar: üst kenar açık, alt kenar koyu, basınca içeri göçer.
	var btn := StyleBoxFlat.new()
	btn.bg_color = Color("#3a281b")
	btn.border_color = Color("#6b4e2e")
	btn.set_border_width_all(1)
	btn.border_width_bottom = 3
	btn.content_margin_left = 10
	btn.content_margin_right = 10
	btn.content_margin_top = 3
	btn.content_margin_bottom = 2
	btn.shadow_color = Color(0, 0, 0, 0.5)
	btn.shadow_size = 2
	btn.shadow_offset = Vector2(1, 2)
	var btn_hover := btn.duplicate() as StyleBoxFlat
	btn_hover.border_color = C_YELLOW
	btn_hover.bg_color = Color("#4a3423")
	var btn_pressed := btn.duplicate() as StyleBoxFlat
	btn_pressed.bg_color = Color("#2b1d14")
	btn_pressed.border_color = C_YELLOW
	btn_pressed.border_width_bottom = 1
	btn_pressed.border_width_top = 3
	btn_pressed.shadow_size = 0
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

	_build_big_portraits()

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
	# Konuşanın adı, dosya sekmesi gibi sarı etiket üstünde koyu yazı.
	var tag := StyleBoxFlat.new()
	tag.bg_color = C_YELLOW
	tag.content_margin_left = 6
	tag.content_margin_right = 6
	tag.content_margin_top = 1
	tag.content_margin_bottom = 1
	name_label.add_theme_stylebox_override("normal", tag)
	name_label.add_theme_color_override("font_color", C_BLACK)
	name_label.add_theme_constant_override("shadow_offset_x", 0)
	name_label.add_theme_constant_override("shadow_offset_y", 0)
	name_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
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

	# Defter: mantar pano. Kanıtlar raptiyeli polaroidler, bağlantılar kırmızı ip.
	notebook_panel = PanelContainer.new()
	notebook_panel.position = Vector2(8, 8)
	notebook_panel.custom_minimum_size = Vector2(VIEW_W - 16, VIEW_H - 16)
	notebook_panel.visible = false
	notebook_panel.add_theme_stylebox_override("panel", _board_style())
	ui_root.add_child(notebook_panel)
	var nhb := HBoxContainer.new()
	nhb.add_theme_constant_override("separation", 10)
	notebook_panel.add_child(nhb)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(392, 0)
	nhb.add_child(left)
	notebook_title = Label.new()
	notebook_title.add_theme_color_override("font_color", C_PALE)
	notebook_title.add_theme_font_size_override("font_size", 16)
	notebook_title.add_theme_constant_override("shadow_offset_x", 2)
	notebook_title.add_theme_constant_override("shadow_offset_y", 2)
	left.add_child(notebook_title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(392, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	board_content = Control.new()
	scroll.add_child(board_content)
	notebook_list = GridContainer.new()
	(notebook_list as GridContainer).columns = 6
	notebook_list.position = Vector2(6, 6)
	notebook_list.add_theme_constant_override("h_separation", 6)
	notebook_list.add_theme_constant_override("v_separation", 8)
	board_content.add_child(notebook_list)
	board_strings = Control.new()
	board_strings.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_content.add_child(board_strings)

	# Sağda manila dosya kağıdı
	var paper := PanelContainer.new()
	paper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pst := StyleBoxFlat.new()
	pst.bg_color = Color("#d8c493")
	pst.border_color = Color("#8a6a3a")
	pst.set_border_width_all(1)
	pst.set_content_margin_all(8)
	pst.shadow_color = Color(0, 0, 0, 0.5)
	pst.shadow_size = 4
	pst.shadow_offset = Vector2(2, 3)
	paper.add_theme_stylebox_override("panel", pst)
	nhb.add_child(paper)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 4)
	paper.add_child(right)
	progress_label = Label.new()
	progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	progress_label.custom_minimum_size = Vector2(190, 0)
	_paper_label(progress_label, 11, Color("#7a1f12"))
	right.add_child(progress_label)
	board_preview = TextureRect.new()
	board_preview.custom_minimum_size = Vector2(190, 72)
	board_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	board_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	right.add_child(board_preview)
	var info_scroll := ScrollContainer.new()
	info_scroll.custom_minimum_size = Vector2(190, 86)
	info_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(info_scroll)
	notebook_info = Label.new()
	notebook_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notebook_info.custom_minimum_size = Vector2(180, 0)
	_paper_label(notebook_info, 11, Color("#2b1d14"))
	info_scroll.add_child(notebook_info)
	var hint_btn := Button.new()
	hint_btn.text = "Maya'ya sor (ipucu)"
	hint_btn.pressed.connect(func():
		_sfx("click")
		board_preview.texture = null
		notebook_info.text = _hint_text())
	right.add_child(hint_btn)
	notebook_inspect_btn = Button.new()
	notebook_inspect_btn.text = "Yakından incele"
	notebook_inspect_btn.visible = false
	notebook_inspect_btn.pressed.connect(func():
		if notebook_selected != "":
			var sel := notebook_selected
			open_inspect(sel, func(): notebook_info.text = _clue_text(sel)))
	right.add_child(notebook_inspect_btn)
	link_button = Button.new()
	link_button.text = "İki kanıtı iple bağla"
	link_button.pressed.connect(_start_link)
	right.add_child(link_button)
	accuse_button = Button.new()
	accuse_button.text = "Sorgu odasına git ve suçla"
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

	menu_button = Button.new()
	menu_button.text = "Menü [Esc]"
	menu_button.position = Vector2(VIEW_W - 92, 32)
	menu_button.pressed.connect(open_pause)
	ui_root.add_child(menu_button)

	_build_inspect()

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
	help.text = "Fare: tıkla, yürü, incele, konuş     Klavye: A/D yürü, F etkileşim, Q Oscar'ın Gözü, Tab defter"
	help.position = Vector2(0, 318)
	help.size = Vector2(VIEW_W, 20)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 10)
	help.add_theme_color_override("font_color", C_LIGHT)
	menu_panel.add_child(help)
	var settings_btn := Button.new()
	settings_btn.text = "Ayarlar"
	settings_btn.pressed.connect(open_settings)
	box.add_child(settings_btn)
	box.move_child(settings_btn, 1)
	_set_hud_visible(false)
	busy = true
	in_menu = true
	_build_pause()
	_build_settings()


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
	menu_button.visible = v
	eye_button.visible = v
	debt_label.visible = v
	if not v:
		accuse_hud.visible = false


## sfx/<ad>.wav dosyaları varsa çalınır; yoksa sessiz geçer.
func _build_sfx() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
	_load_settings()
	for n in ["blip", "pickup", "door", "click", "deduce", "wrong", "solve", "eye"]:
		var p: String = "res://sfx/" + n + ".wav"
		if ResourceLoader.exists(p):
			var a := AudioStreamPlayer.new()
			a.stream = load(p)
			a.volume_db = -8.0 if n == "blip" else -4.0
			a.bus = "SFX"
			add_child(a)
			sfx[n] = a
	# Arka plan müziği: sfx/music.mp3 (Berat'ın seçtiği parça) yoksa sfx/music.wav.
	var music_path := "res://sfx/music.mp3"
	if not ResourceLoader.exists(music_path):
		music_path = "res://sfx/music.wav"
	if ResourceLoader.exists(music_path):
		var m := AudioStreamPlayer.new()
		m.stream = load(music_path)
		m.volume_db = -6.0
		m.bus = "Music"
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
			if paused:
				busy_before_pause = false
			else:
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
	char_scale = float(r.get("char_scale", 1.0))
	if player_sprite:
		player_sprite.pivot_offset = Vector2(player_sprite.size.x / 2.0, player_sprite.size.y)
		player_sprite.scale = Vector2(char_scale, char_scale)
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
			w = float(o.get("w", 24))
			h = float(o.get("h", 54))
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
	if t == "npc":
		n.pivot_offset = Vector2(w / 2.0, h)
		n.scale = Vector2(char_scale, char_scale)
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
		lb.position = Vector2(-40, -11)
		lb.size = Vector2(w + 80, 10)
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lb.add_theme_font_size_override("font_size", 8)
		if t == "npc":
			lb.scale = Vector2(1.0 / char_scale, 1.0 / char_scale)
			lb.pivot_offset = Vector2(lb.size.x / 2.0, lb.size.y)
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
		if _obj_rect(e).has_point(pos):
			return e["data"]
	return {}


## Tıklama alanı: ölçek hesaba katılır, kişilerin alanı daha geniştir.
func _obj_rect(e: Dictionary) -> Rect2:
	var n: Control = e["node"]
	var sz := n.size * n.scale
	var r := Rect2(n.position + n.pivot_offset - n.pivot_offset * n.scale, sz)
	return r.grow(10.0 if str(e["data"]["type"]) == "npc" else 4.0)


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
	if busy or paused:
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
		if key.keycode == KEY_ESCAPE:
			if settings_panel.visible:
				_close_settings()
			elif inspect_panel.visible:
				_close_inspect()
			elif paused:
				close_pause()
			elif not in_menu:
				open_pause()
			return
		if paused or settings_panel.visible:
			return
		if inspect_panel.visible:
			if key.keycode == KEY_F:
				_flip_inspect()
			elif key.keycode == KEY_SPACE or key.keycode == KEY_ENTER or key.keycode == KEY_E:
				_close_inspect()
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
			if dialog_panel.visible and dialog_choices.get_child_count() == 0 and (key.keycode == KEY_SPACE or key.keycode == KEY_ENTER or key.keycode == KEY_E or key.keycode == KEY_F):
				_advance()
			return
		if key.keycode == KEY_F or key.keycode == KEY_E:
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
			walk_to(_approach_x(o), _interact.bind(o))
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


## Kişilerin dibine girmeden, durduğumuz taraftan biraz uzakta dur.
func _approach_x(o: Dictionary) -> float:
	var x := float(o["x"])
	if str(o["type"]) != "npc":
		return x
	var gap := 26.0 * char_scale
	if absf(player.position.x - x) <= gap:
		return player.position.x
	return x + (gap if player.position.x > x else -gap)


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
		if str(o["type"]) == "npc":
			d -= 16.0 * char_scale   # kişilerle biraz uzaktan da konuşulabilir
		if d < best_d:
			best_d = d
			best = o
	if not best.is_empty():
		_interact(best)


## Konuşurken Oscar kişiye, kişi Oscar'a döner (çizimler sağa bakıyor varsayılır;
## sola bakan bir çizim için JSON'da "faces": "left").
func _face_each_other(o: Dictionary) -> void:
	var dx := float(o["x"]) - player.position.x
	_face(dx)
	for e in room_objects:
		if e["data"] == o and e["node"] is TextureRect:
			var faces_right := str(o.get("faces", "right")) == "right"
			(e["node"] as TextureRect).flip_h = (dx > 0.0) == faces_right


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
			_face_each_other(o)
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
	if c.has("inspect"):
		open_inspect(id, func(): play_lines(lines, done))
	else:
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
			lines.append(["Oscar", "Dur bir dakika... Defterimdeki iki ipucu birbirine bağlanıyor. Kanıt tahtasına bakmalıyım. [Tab]"])
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
		return "Maya: '" + str(data["clues"][p[0]]["name"]) + "' ve '" + str(data["clues"][p[1]]["name"]) + "'. Bu ikisini kanıt tahtasında bağla."
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
	var notes := _found_notes(id)
	if notes != "":
		t += "\n\n" + notes
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
	# Küçük kutu portresi yerine büyük, parlayan portreler kullanılıyor.
	portrait_box.visible = false
	var speakers: Dictionary = data.get("speakers", {})
	var key: String = str(speakers.get(who, ""))
	var right_key := ""
	if current_npc != "":
		var npc_name := str(data["dialogues"][current_npc]["name"])
		right_key = str(speakers.get(npc_name, ""))
	elif who != "Oscar" and key != "":
		right_key = key
	var left_on := key == "oscar" or right_key != ""
	_show_big_portrait("left", "oscar" if left_on else "", key == "oscar")
	_show_big_portrait("right", right_key, key != "" and key == right_key)


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
	for side in big_portraits:
		var root: Control = big_portraits[side]["root"]
		root.position.y = dialog_panel.position.y - BIG_PORTRAIT_ROWS * BIG_PORTRAIT_SCALE + 18.0


func _close_dialog() -> void:
	dialog_panel.visible = false
	_hide_big_portraits()
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
	_hide_big_portraits()
	notebook_panel.visible = true
	_fill_notebook("Bir ipucuna tıkla, ayrıntısını gör." if mode == "" else "Hangi kanıtı göstereceksin?")


func _fill_notebook(info: String) -> void:
	for c in notebook_list.get_children():
		notebook_list.remove_child(c)
		c.queue_free()
	board_cards.clear()
	match select_mode:
		"show":
			notebook_title.text = "KANIT GÖSTER  (parlayanlar bu kişiyle ilgili)"
		"link":
			notebook_title.text = "KANIT TAHTASI  (bağlanacak iki kanıtı seç)"
		_:
			notebook_title.text = "KANIT TAHTASI  (" + str(clues.size()) + " kanıt)"
	var shows: Dictionary = {}
	if select_mode == "show" and current_npc != "":
		shows = data["dialogues"][current_npc].get("show", {})
	var ids: Array = clues.keys()
	if not shows.is_empty():
		var rel: Array = ids.filter(func(i): return shows.has(i))
		var rest: Array = ids.filter(func(i): return not shows.has(i))
		ids = rel + rest
	for id in ids:
		_add_board_card(str(id), shows.has(id))
	board_content.custom_minimum_size = notebook_list.get_combined_minimum_size() + Vector2(12, 12)
	_draw_board_strings.call_deferred()
	if clues.is_empty():
		info = "Henüz kanıt yok. Mekanlardaki parlayan noktalara tıkla."
	var concl := ""
	for d in data["deductions"]:
		if deductions.has(d["id"]):
			concl += "\n- " + str(d["text"])
	board_default_info = info + ("\n\nSONUÇLAR" + concl if concl != "" else "")
	board_preview.texture = null
	notebook_info.text = board_default_info
	notebook_selected = ""
	notebook_inspect_btn.visible = false
	var req: Array = data["final"]["required"]
	var done := 0
	for rid in req:
		if deductions.has(rid):
			done += 1
	progress_label.text = "Gerekli sonuçlar: " + str(done) + "/" + str(req.size()) + "\nNASIL, FIRSAT, MOTİF, FİZİKSEL KANIT"
	_update_hud()
	link_button.visible = select_mode == ""
	accuse_button.visible = select_mode == "" and _final_ready()


## Bir kanıt polaroidi: çizim, ad, raptiye; üstüne gelince büyür ve sağda detayı gösterir.
func _add_board_card(id: String, relevant: bool) -> void:
	var b := Button.new()
	b.custom_minimum_size = Vector2(58, 70)
	b.focus_mode = Control.FOCUS_NONE
	var st := StyleBoxFlat.new()
	st.bg_color = Color("#efe6cf")
	st.shadow_color = Color(0, 0, 0, 0.55)
	st.shadow_size = 3
	st.shadow_offset = Vector2(2, 2)
	st.set_border_width_all(2)
	st.border_color = Color("#efe6cf")
	if relevant:
		st.border_color = C_YELLOW
	if id == link_first:
		st.border_color = Color("#b3261e")
	var hv := st.duplicate() as StyleBoxFlat
	hv.border_color = C_YELLOW if id != link_first else Color("#b3261e")
	b.add_theme_stylebox_override("normal", st)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", hv)
	notebook_list.add_child(b)
	var icon := TextureRect.new()
	icon.position = Vector2(5, 5)
	icon.size = Vector2(48, 46)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = _art("items/" + id)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(icon)
	if icon.texture == null:
		var ph := ColorRect.new()
		ph.position = icon.position
		ph.size = icon.size
		ph.color = Color("#3a2a1e")
		ph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(ph)
	var lb := Label.new()
	lb.text = str(data["clues"][id]["name"])
	lb.position = Vector2(2, 52)
	lb.size = Vector2(54, 16)
	lb.clip_text = true
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_paper_label(lb, 8, Color("#2b1d14"))
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(lb)
	var pin := ColorRect.new()
	pin.size = Vector2(5, 5)
	pin.position = Vector2(26, -2)
	pin.color = Color("#b3261e")
	pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(pin)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	b.pivot_offset = Vector2(29, 35)
	b.rotation = deg_to_rad(rng.randf_range(-4.0, 4.0))
	b.pressed.connect(_on_clue_pressed.bind(id))
	b.mouse_entered.connect(func():
		b.scale = Vector2(1.18, 1.18)
		b.z_index = 2
		board_preview.texture = _art("items/" + id)
		notebook_info.text = _clue_text(id))
	b.mouse_exited.connect(func():
		b.scale = Vector2.ONE
		b.z_index = 0
		if notebook_selected != "":
			board_preview.texture = _art("items/" + notebook_selected)
			notebook_info.text = _clue_text(notebook_selected)
		else:
			board_preview.texture = null
			notebook_info.text = board_default_info)
	if relevant:
		var gt := b.create_tween().set_loops()
		gt.tween_property(b, "modulate", Color(1.3, 1.2, 0.85), 0.5)
		gt.tween_property(b, "modulate", Color(1, 1, 1), 0.5)
	board_cards[id] = b


## Bulunan her sonuç için iki kanıtın raptiyeleri arasına kırmızı ip.
func _draw_board_strings() -> void:
	for c in board_strings.get_children():
		board_strings.remove_child(c)
		c.queue_free()
	for d in data["deductions"]:
		if not deductions.has(d["id"]):
			continue
		var p: Array = d["pair"]
		if not board_cards.has(p[0]) or not board_cards.has(p[1]):
			continue
		var a: Control = board_cards[p[0]]
		var b: Control = board_cards[p[1]]
		var line := Line2D.new()
		line.width = 1.5
		line.default_color = Color("#b3261e")
		var pa := notebook_list.position + a.position + Vector2(28, 0)
		var pb := notebook_list.position + b.position + Vector2(28, 0)
		var mid := (pa + pb) / 2.0 + Vector2(0, 10)   # ip biraz sarkar
		line.points = PackedVector2Array([pa, mid, pb])
		board_strings.add_child(line)


func _board_style() -> StyleBox:
	var tex := _art("ui/board")
	if tex:
		var sb := StyleBoxTexture.new()
		sb.texture = tex
		sb.set_content_margin_all(14)
		return sb
	var f := StyleBoxFlat.new()
	f.bg_color = Color("#7a5232")
	f.border_color = Color("#2b1d14")
	f.set_border_width_all(6)
	f.set_content_margin_all(12)
	f.shadow_color = Color(0, 0, 0, 0.6)
	f.shadow_size = 6
	return f


func _paper_label(lb: Label, size: int, col: Color) -> void:
	lb.add_theme_font_size_override("font_size", size)
	lb.add_theme_color_override("font_color", col)
	lb.add_theme_constant_override("shadow_offset_x", 0)
	lb.add_theme_constant_override("shadow_offset_y", 0)


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
			notebook_selected = id
			notebook_inspect_btn.visible = data["clues"][id].has("inspect")
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


# ================================================================ ayarlar ve duraklatma

func _overlay(title_text: String) -> Array:
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.015, 0.01, 0.78)
	bg.size = Vector2(VIEW_W, VIEW_H)
	bg.visible = false
	ui_root.add_child(bg)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(240, 0)
	panel.position = Vector2(VIEW_W / 2.0 - 120, 80)
	bg.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var t := Label.new()
	t.text = title_text
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_color_override("font_color", C_YELLOW)
	t.add_theme_font_size_override("font_size", 18)
	box.add_child(t)
	return [bg, box]


func _menu_btn(box: Control, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.pressed.connect(func():
		_sfx("click")
		cb.call())
	box.add_child(b)


func _build_pause() -> void:
	var o := _overlay("DURAKLATILDI")
	pause_panel = o[0]
	var box: VBoxContainer = o[1]
	_menu_btn(box, "Devam et", close_pause)
	_menu_btn(box, "Ayarlar", open_settings)
	_menu_btn(box, "Ana menüye dön", func(): get_tree().reload_current_scene())
	_menu_btn(box, "Oyundan çık", func(): get_tree().quit())


func _build_settings() -> void:
	var o := _overlay("AYARLAR")
	settings_panel = o[0]
	var box: VBoxContainer = o[1]
	_add_slider(box, "Müzik", "music")
	_add_slider(box, "Efekt sesleri", "sfx")
	var fs := CheckButton.new()
	fs.text = "Tam ekran"
	fs.button_pressed = bool(settings["fullscreen"])
	fs.add_theme_color_override("font_color", C_PALE)
	fs.toggled.connect(func(on: bool):
		settings["fullscreen"] = on
		_apply_settings()
		_save_settings())
	box.add_child(fs)
	_menu_btn(box, "Geri [Esc]", _close_settings)


func _add_slider(box: Control, label_text: String, key: String) -> void:
	var lb := Label.new()
	box.add_child(lb)
	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.05
	sl.value = float(settings[key])
	sl.custom_minimum_size = Vector2(200, 16)
	box.add_child(sl)
	lb.text = label_text + ": %d%%" % int(round(sl.value * 100))
	sl.value_changed.connect(func(v: float):
		settings[key] = v
		lb.text = label_text + ": %d%%" % int(round(v * 100))
		_apply_settings()
		if key == "sfx":
			_sfx("blip"))
	sl.drag_ended.connect(func(_changed: bool): _save_settings())


func open_pause() -> void:
	if in_menu or paused:
		return
	paused = true
	busy_before_pause = busy
	busy = true
	target_x = -1.0
	pending_action = Callable()
	pause_panel.visible = true


func close_pause() -> void:
	paused = false
	pause_panel.visible = false
	busy = busy_before_pause


func open_settings() -> void:
	_sfx("click")
	settings_panel.visible = true
	ui_root.move_child(settings_panel, ui_root.get_child_count() - 1)


func _close_settings() -> void:
	settings_panel.visible = false
	_save_settings()


func _load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) == OK:
		for k in settings.keys():
			settings[k] = cf.get_value("settings", k, settings[k])
	_apply_settings()


func _save_settings() -> void:
	var cf := ConfigFile.new()
	for k in settings.keys():
		cf.set_value("settings", k, settings[k])
	cf.save(SETTINGS_PATH)


func _apply_settings() -> void:
	for pair in [["Music", "music"], ["SFX", "sfx"]]:
		var idx := AudioServer.get_bus_index(pair[0])
		if idx == -1:
			continue
		var v: float = float(settings[pair[1]])
		AudioServer.set_bus_mute(idx, v <= 0.001)
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.001)))
	var want: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_FULLSCREEN if bool(settings["fullscreen"]) else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != want:
		DisplayServer.window_set_mode(want)


# ================================================================ eşya inceleme

## İpucunu büyük gösterir: önünü / arkasını çevir, parlayan noktalara tıklayıp detay bul.
## Çizim: art/items/<id>.png (ön) ve art/items/<id>_back.png (arka), 96x96 (tools/pixelize.py bu boyutta üretir).
func _build_inspect() -> void:
	inspect_panel = ColorRect.new()
	(inspect_panel as ColorRect).color = Color(0.02, 0.015, 0.01, 0.85)
	inspect_panel.size = Vector2(VIEW_W, VIEW_H)
	inspect_panel.visible = false
	ui_root.add_child(inspect_panel)
	var panel := PanelContainer.new()
	panel.position = Vector2(48, 44)
	panel.custom_minimum_size = Vector2(VIEW_W - 96, 0)
	inspect_panel.add_child(panel)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	panel.add_child(hb)

	var frame := PanelContainer.new()
	var fstyle := StyleBoxFlat.new()
	fstyle.bg_color = Color("#1a120c")
	fstyle.border_color = C_YELLOW
	fstyle.set_border_width_all(1)
	fstyle.set_content_margin_all(6)
	frame.add_theme_stylebox_override("panel", fstyle)
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hb.add_child(frame)
	inspect_area = Control.new()
	inspect_area.custom_minimum_size = Vector2(INSPECT_SIZE, INSPECT_SIZE)
	inspect_area.pivot_offset = Vector2(INSPECT_SIZE / 2.0, INSPECT_SIZE / 2.0)
	frame.add_child(inspect_area)
	inspect_img = TextureRect.new()
	inspect_img.size = Vector2(INSPECT_SIZE, INSPECT_SIZE)
	inspect_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	inspect_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	inspect_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inspect_area.add_child(inspect_img)
	inspect_card = Label.new()
	inspect_card.size = Vector2(INSPECT_SIZE, INSPECT_SIZE)
	inspect_card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inspect_card.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	inspect_card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspect_card.add_theme_color_override("font_color", C_LIGHT)
	inspect_card.add_theme_font_size_override("font_size", 16)
	inspect_area.add_child(inspect_card)
	inspect_spots = Control.new()
	inspect_spots.size = Vector2(INSPECT_SIZE, INSPECT_SIZE)
	inspect_spots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inspect_area.add_child(inspect_spots)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	hb.add_child(right)
	inspect_title = Label.new()
	inspect_title.add_theme_color_override("font_color", C_YELLOW)
	inspect_title.add_theme_font_size_override("font_size", 16)
	inspect_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(inspect_title)
	inspect_side_label = Label.new()
	inspect_side_label.add_theme_color_override("font_color", C_LIGHT)
	inspect_side_label.add_theme_font_size_override("font_size", 11)
	right.add_child(inspect_side_label)
	inspect_notes = Label.new()
	inspect_notes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspect_notes.custom_minimum_size = Vector2(250, 150)
	inspect_notes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(inspect_notes)
	var row := HBoxContainer.new()
	right.add_child(row)
	inspect_flip = Button.new()
	inspect_flip.text = "Çevir [F]"
	inspect_flip.pressed.connect(_flip_inspect)
	row.add_child(inspect_flip)
	var ok := Button.new()
	ok.text = "Tamam [Boşluk]"
	ok.pressed.connect(_close_inspect)
	row.add_child(ok)


func open_inspect(id: String, done: Callable) -> void:
	busy = true
	inspect_id = id
	inspect_side = "front"
	inspect_done = done
	inspect_area.scale = Vector2.ONE
	inspect_panel.visible = true
	ui_root.move_child(inspect_panel, ui_root.get_child_count() - 1)
	inspect_panel.modulate.a = 0.0
	create_tween().tween_property(inspect_panel, "modulate:a", 1.0, 0.2)
	_show_inspect_side()


func _inspect_data() -> Dictionary:
	return data["clues"][inspect_id].get("inspect", {})


func _show_inspect_side() -> void:
	var c: Dictionary = data["clues"][inspect_id]
	var ins := _inspect_data()
	inspect_title.text = str(c["name"])
	inspect_side_label.text = ("ÖN YÜZ" if inspect_side == "front" else "ARKA YÜZ") + "   (parlayan noktalara tıkla)"
	inspect_flip.visible = ins.has("back")
	var tex := _art("items/" + inspect_id + ("" if inspect_side == "front" else "_back"))
	inspect_img.texture = tex
	inspect_card.visible = tex == null
	inspect_card.text = str(c["name"]) + ("" if inspect_side == "front" else "\n(arka yüz)")
	for ch in inspect_spots.get_children():
		inspect_spots.remove_child(ch)
		ch.queue_free()
	var spots: Array = ins.get(inspect_side, [])
	for i in range(spots.size()):
		var sp: Dictionary = spots[i]
		var key := inspect_id + ":" + inspect_side + ":" + str(i)
		var b := Button.new()
		b.text = "!" if found_details.has(key) else "?"
		b.custom_minimum_size = Vector2(18, 18)
		b.size = Vector2(18, 18)
		b.position = Vector2(float(sp["x"]), float(sp["y"])) * INSPECT_SIZE - Vector2(9, 9)
		b.add_theme_font_size_override("font_size", 11)
		b.pressed.connect(_on_inspect_spot.bind(key))
		inspect_spots.add_child(b)
		if not found_details.has(key):
			b.pivot_offset = Vector2(9, 9)
			var tw := b.create_tween().set_loops()
			tw.tween_property(b, "scale", Vector2(1.2, 1.2), 0.5)
			tw.tween_property(b, "scale", Vector2.ONE, 0.5)
	inspect_notes.text = str(c["desc"]) + "\n\n" + _found_notes(inspect_id)


func _on_inspect_spot(key: String) -> void:
	if found_details.has(key):
		return
	found_details[key] = true
	_sfx("pickup")
	_show_inspect_side()


## Bu ipucunda bulunan detaylar ve sayaç.
func _found_notes(id: String) -> String:
	var ins: Dictionary = data["clues"][id].get("inspect", {})
	var total := 0
	var found: Array = []
	for side in ["front", "back"]:
		var spots: Array = ins.get(side, [])
		for i in range(spots.size()):
			total += 1
			if found_details.has(id + ":" + side + ":" + str(i)):
				found.append("- " + str(spots[i]["text"]))
	if total == 0:
		return ""
	var t := "Detaylar " + str(found.size()) + "/" + str(total)
	for f in found:
		t += "\n" + str(f)
	return t


func _flip_inspect() -> void:
	if not _inspect_data().has("back"):
		return
	_sfx("click")
	var tw := create_tween()
	tw.tween_property(inspect_area, "scale:x", 0.0, 0.12)
	tw.tween_callback(func():
		inspect_side = "back" if inspect_side == "front" else "front"
		_show_inspect_side())
	tw.tween_property(inspect_area, "scale:x", 1.0, 0.12)


func _close_inspect() -> void:
	inspect_panel.visible = false
	var cb := inspect_done
	inspect_done = Callable()
	if cb.is_valid():
		cb.call()


# ================================================================ konuşma portreleri

## Hotline Miami tarzı: konuşanın portresi büyür, parlar ve hafifçe sallanır; dinleyen kararır.
func _build_big_portraits() -> void:
	var w := 32.0 * BIG_PORTRAIT_SCALE
	for side in ["left", "right"]:
		var root := Control.new()
		root.size = Vector2(w, BIG_PORTRAIT_ROWS * BIG_PORTRAIT_SCALE)
		root.pivot_offset = Vector2(w / 2.0, root.size.y)
		root.position = Vector2(20.0 if side == "left" else VIEW_W - 20.0 - w, 120)
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.visible = false
		ui_root.add_child(root)
		# Parıltı: aynı çizim sarıya boyanıp dört yöne kaydırılır, arkada kalır.
		var glow := Control.new()
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(glow)
		for off in [Vector2(-4, 0), Vector2(4, 0), Vector2(0, -4), Vector2(0, 4), Vector2(-3, -3), Vector2(3, -3), Vector2(-3, 3), Vector2(3, 3)]:
			var g := TextureRect.new()
			g.position = off
			g.size = root.size
			g.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			g.stretch_mode = TextureRect.STRETCH_SCALE
			g.modulate = Color(C_YELLOW.r, C_YELLOW.g, C_YELLOW.b, 0.55)
			g.material = _flat_color_material()
			g.flip_h = side == "right"
			g.mouse_filter = Control.MOUSE_FILTER_IGNORE
			glow.add_child(g)
		var img := TextureRect.new()
		img.size = root.size
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_SCALE
		img.flip_h = side == "right"
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(img)
		var tw := glow.create_tween().set_loops()
		tw.tween_property(glow, "modulate:a", 0.35, 0.45)
		tw.tween_property(glow, "modulate:a", 1.0, 0.45)
		big_portraits[side] = {"root": root, "img": img, "glow": glow, "key": "", "sway": null}


## Çizimi tek renge (beyaza) çeviren shader; modulate ile sarı parıltı olur.
func _flat_color_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nvarying vec4 tint;\nvoid vertex() { tint = COLOR; }\nvoid fragment() { COLOR = vec4(tint.rgb, tint.a * texture(TEXTURE, UV).a); }"
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


func _show_big_portrait(side: String, key: String, speaking: bool) -> void:
	var p: Dictionary = big_portraits[side]
	var root: Control = p["root"]
	var tex: Texture2D = _art(key) if key != "" else null
	if tex == null:
		root.visible = false
		p["key"] = ""
		return
	if str(p["key"]) != key or not root.visible:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(0, 0, tex.get_width(), mini(BIG_PORTRAIT_ROWS, tex.get_height()))
		(p["img"] as TextureRect).texture = at
		for g in (p["glow"] as Control).get_children():
			(g as TextureRect).texture = at
		p["key"] = key
		# İçeri kayarak gir
		var home_x: float = 20.0 if side == "left" else VIEW_W - 20.0 - root.size.x
		root.position.x = home_x + (-160.0 if side == "left" else 160.0)
		root.visible = true
		root.create_tween().tween_property(root, "position:x", home_x, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	(p["glow"] as Control).visible = speaking
	root.modulate = Color(1, 1, 1) if speaking else Color(0.45, 0.42, 0.4)
	var sway = p["sway"]
	if sway != null:
		(sway as Tween).kill()
		p["sway"] = null
	root.rotation = 0.0
	root.scale = Vector2.ONE
	if speaking:
		root.scale = Vector2(1.06, 1.06)
		var st := root.create_tween().set_loops()
		st.tween_property(root, "rotation", deg_to_rad(2.0), 0.35).set_trans(Tween.TRANS_SINE)
		st.tween_property(root, "rotation", deg_to_rad(-2.0), 0.7).set_trans(Tween.TRANS_SINE)
		st.tween_property(root, "rotation", 0.0, 0.35).set_trans(Tween.TRANS_SINE)
		p["sway"] = st


func _hide_big_portraits() -> void:
	for side in big_portraits:
		var p: Dictionary = big_portraits[side]
		(p["root"] as Control).visible = false
		p["key"] = ""
		var sway = p["sway"]
		if sway != null:
			(sway as Tween).kill()
			p["sway"] = null
