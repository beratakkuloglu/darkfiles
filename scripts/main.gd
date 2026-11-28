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
const BAR_H := 30.0
const CARD_W := 46.0              # kanıt tahtası kart ölçüsü
const CARD_H := 56.0              # alt/üst siyah bant yüksekliği (ekran birimi)
const TYPE_SPEED := 55.0         # daktilo efekti, saniyede karakter
const TEXT_SPEEDS := [0.55, 1.0, 1.8, 400.0]   # ayarlardaki yazı hızı çarpanı
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
var walk_min := 8.0
var walk_max := 336.0
var room_w: float = 320.0
var floor_y: float = DEFAULT_FLOOR_Y
var room_h: float = WORLD_H
var char_scale: float = 1.0   # hep 1.0: karakter ölçüsü sabit, mekan çizimleri ona uyar
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
var looked: Dictionary = {}
var in_menu: bool = true

# Açılış sahnesi (data "cutscene": [{text, art?}])
var cut_panel: ColorRect
var cut_actors: Control
var cut_img: TextureRect
var cut_text: Label
var cut_cards: Array = []
var cut_i: int = 0
var cut_tween: Tween
var cut_done: Callable = Callable()
var in_cutscene: bool = false

# Dünya
var room_layer: Node2D
var fx_layer: Node2D
var front_layer: Node2D        # oyuncunun önünde çizilenler (yoldaki araba)
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
var door_labels: Array = []      # [{label, x, data}] sadece yakındaki/üzerine gelinen kapının yazısı görünür
var anim_clock: float = 0.0
var maya_chat_idle := 0.0      # odada sakin geçen süre; dolunca Maya kendiliğinden laf atar
var maya_chat_cool := 20.0     # iki sohbet arası bekleme
# Ajan Maya Cole: Oscar'ı arkasından takip eder; tıklayınca ipucu verir.
var maya: TextureRect
var maya_x: float = 0.0
var maya_walk: Array = []
var maya_idle: Array = []
var maya_moving: bool = false
var maya_script: bool = false     # true: Maya senaryoyla yürür, Oscar'ı takip etmez
var maya_target: float = 0.0
var maya_speed: float = 1.0
var maya_cb: Callable = Callable()
var player_pose: Texture2D = null  # oturma gibi sabit poz (null: normal animasyon)
var in_car: bool = false
var drive_panel: Control
var drive_layers: Array = []      # [{node, speed, wrap}]
var drive_offset: float = 0.0
var driving: bool = false
var car_tween: Tween
var player_walking_script := false   # arabaya yürürken yürüme animasyonu
const EYE_TIME := 8.0
var eye_time: float = 0.0
var eye_bar: ColorRect
var quip_bag: Dictionary = {}     # tekrarsız rastgele replik torbaları
var npc_marks: Array = []         # [{data, mark}]
const CAR_SCALE := 1.0            # araba çizimi karakterlerle aynı ölçüde (PixelLab)
const CAR_WHEELS := [Vector2(30, 29), Vector2(101, 29)]  # araba.png'de teker merkezleri
var wheels: Array = []            # [{node, car, last_x, road}]
var wrong_accuse: int = 0
var summoned: String = ""
var return_room: String = ""
var return_x: float = 0.0
var drive_street: Control
var drive_road: Control
var drive_street_car: Control

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
## Atanabilir tuşlar (Ayarlar > Kontroller). user://settings.cfg [keys] bölümüne kaydedilir.
const DEFAULT_KEYS := {"left": KEY_A, "right": KEY_D, "interact": KEY_F, "interact2": KEY_E, "eye": KEY_Q, "notebook": KEY_TAB, "fullscreen": KEY_F11}
const KEY_NAMES := [["left", "Sola yürü"], ["right", "Sağa yürü"], ["interact", "Etkileşim"], ["interact2", "Etkileşim (2)"], ["eye", "Oscar'ın Gözü"], ["notebook", "Defter / kanıt tahtası"], ["fullscreen", "Tam ekran"]]
var keys: Dictionary = DEFAULT_KEYS.duplicate()
var controls_panel: Control
var rebinding := ""             # tuşu değiştirilen eylem; boşsa bekleme yok
var rebind_buttons: Dictionary = {}
var case_panel: Control          # Vaka seç ekranı (Telltale tarzı)
var case_idx := 0
var case_widgets: Dictionary = {}
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
var settings := {"music": 0.7, "sfx": 0.8, "fullscreen": true, "text_speed": 1, "atmosphere": true, "brightness": 0.5}
var pause_panel: Control
var settings_panel: Control
var atmo_dust: CPUParticles2D
var bright_add: ColorRect    # parlaklık ayarı: aydınlatma katmanı
var bright_dark: ColorRect   # parlaklık ayarı: karartma katmanı
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
const BIG_PORTRAIT_SCALE := 3.0
const BIG_PORTRAIT_ROWS := 34
var big_portraits: Dictionary = {}   # "left" / "right" -> {"root", "img", "glow", "key", "tween"}


func _ready() -> void:
	var f := FileAccess.open("res://data/case1.json", FileAccess.READ)
	data = JSON.parse_string(f.get_as_text())
	# Araba içi çizimi varsa ipuçları torpido/bagajda; yoksa otoparktaki arabada.
	if ResourceLoader.exists("res://art/rooms/araba_ic.png"):
		flags["has_car_art"] = true
	room_layer = Node2D.new()
	add_child(room_layer)
	fx_layer = Node2D.new()
	add_child(fx_layer)
	_build_player()
	front_layer = Node2D.new()
	add_child(front_layer)
	_build_atmosphere()
	_build_ui()
	_build_sfx()
	load_room(str(data["start_room"]), float(data["start_x"]))
	_build_menu()


# ================================================================ kurulum

func _build_player() -> void:
	var mtex := _art("maya")
	if mtex:
		maya = _child_tex(self, Vector2.ZERO, mtex)
		maya.pivot_offset = Vector2(mtex.get_width() / 2.0, mtex.get_height())
		maya_walk = _strip_frames(_art("maya_walk"), mtex.get_width())
		maya_idle = _strip_frames(_art("maya_idle"), mtex.get_width())
		if maya_idle.is_empty():
			maya_idle = [mtex]
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

	# Parlaklık ayarı (göz yormasın): sahnenin üstüne ekleyen ya da karartan iki katman.
	bright_add = ColorRect.new()
	bright_add.size = Vector2(VIEW_W, VIEW_H)
	bright_add.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var addm := CanvasItemMaterial.new()
	addm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	bright_add.material = addm
	layer.add_child(bright_add)
	bright_dark = ColorRect.new()
	bright_dark.size = Vector2(VIEW_W, VIEW_H)
	bright_dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(bright_dark)

	# Havada süzülen toz
	var dust := CPUParticles2D.new()
	atmo_dust = dust
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
## Okunaklı yazı tipi (Rubik, OFL): diyalog ve arayüz. Ekran çözünürlüğünde net çizilir.
func _ui_font() -> Font:
	var p := "res://fonts/Rubik-Medium.ttf"
	if not ResourceLoader.exists(p):
		return null
	var f: FontFile = load(p)
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_ONE_QUARTER   # harfler eşit aralıklı, kaymasın
	return f


## Dünyadaki yazılar (kapı tabelaları) için MSDF Rubik: kamera yakınlaştırınca bulanıklaşmaz.
var _wfont: Font = null
func _world_font() -> Font:
	if _wfont == null:
		var p := "res://fonts/Rubik-Medium.ttf"
		if not ResourceLoader.exists(p):
			return null
		var f := (load(p) as FontFile).duplicate() as FontFile
		f.multichannel_signed_distance_field = true
		f.msdf_pixel_range = 16
		f.msdf_size = 48
		_wfont = f
	return _wfont


## Pixel yazı tipi (Pixelify Sans, OFL): sadece büyük başlıklar.
func _title_font() -> Font:
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
	th.default_font_size = 11

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
	# Sinematik siyah bantlar (alt ve üst); HUD alttaki bandın içinde durur.
	for y in [0.0, VIEW_H - BAR_H]:
		var bar := ColorRect.new()
		bar.color = Color(0, 0, 0, 1)
		bar.position = Vector2(0, y)
		bar.size = Vector2(VIEW_W, BAR_H)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui_root.add_child(bar)

	msg_label = Label.new()
	msg_label.position = Vector2(0, BAR_H + 6)
	msg_label.size = Vector2(VIEW_W, 24)
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.add_theme_color_override("font_color", C_YELLOW)
	msg_label.add_theme_font_size_override("font_size", 12)
	ui_root.add_child(msg_label)

	debt_label = Label.new()
	debt_label.position = Vector2(VIEW_W - 200, 10)
	debt_label.size = Vector2(190, 20)
	debt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ui_root.add_child(debt_label)
	_update_debt()

	notebook_button = _hud_button("ui/icon_notebook", "Defter", _key_name("notebook"))
	notebook_button.position = Vector2(VIEW_W - 100, VIEW_H - BAR_H + 2)
	notebook_button.pressed.connect(func(): open_notebook(""))
	ui_root.add_child(notebook_button)

	eye_bar = ColorRect.new()
	eye_bar.color = Color(1, 1, 1, 0.9)
	eye_bar.size = Vector2(300, 3)
	eye_bar.position = Vector2(VIEW_W / 2.0 - 150, BAR_H + 3)
	eye_bar.visible = false
	eye_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(eye_bar)
	eye_button = _hud_button("ui/icon_eye", "Göz", _key_name("eye"))
	eye_button.position = Vector2(VIEW_W - 64, VIEW_H - BAR_H + 2)
	eye_button.pressed.connect(toggle_eye)
	ui_root.add_child(eye_button)
	_update_eye_button()

	accuse_hud = Button.new()
	accuse_hud.text = "SUÇLA"
	accuse_hud.position = Vector2(VIEW_W / 2.0 - 30, VIEW_H - BAR_H + 2)
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
	# Daha dar ve alçak kutu: sahne görünsün.
	dialog_panel.position = Vector2(70, 250)
	dialog_panel.custom_minimum_size = Vector2(VIEW_W - 140, 0)
	var dps := StyleBoxFlat.new()
	dps.bg_color = Color(0.06, 0.045, 0.03, 0.9)
	dps.border_color = C_YELLOW.darkened(0.25)
	dps.set_border_width_all(1)
	dps.content_margin_left = 8
	dps.content_margin_right = 8
	dps.content_margin_top = 5
	dps.content_margin_bottom = 4
	dialog_panel.add_theme_stylebox_override("panel", dps)
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
	portrait.custom_minimum_size = Vector2(44, 44)
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
	name_label.add_theme_font_size_override("font_size", 8)
	vb.add_child(name_label)
	dialog_text = Label.new()
	dialog_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog_text.custom_minimum_size = Vector2(VIEW_W - 170, 22)
	dialog_text.add_theme_font_size_override("font_size", 10)
	vb.add_child(dialog_text)
	dialog_choices = VBoxContainer.new()
	dialog_choices.add_theme_constant_override("separation", 1)
	vb.add_child(dialog_choices)
	continue_label = Label.new()
	continue_label.text = "tıkla / boşluk"
	continue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	continue_label.add_theme_color_override("font_color", C_LIGHT)
	continue_label.add_theme_font_size_override("font_size", 7)
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
	var case_lb := Label.new()
	case_lb.text = str(data.get("case_name", "")).to_upper()
	case_lb.add_theme_font_size_override("font_size", 13)
	case_lb.add_theme_color_override("font_color", C_PALE)   # mantar panoda sarı okunmuyordu
	case_lb.add_theme_color_override("font_outline_color", Color("#1a120c"))
	case_lb.add_theme_constant_override("outline_size", 5)
	case_lb.add_theme_constant_override("shadow_offset_x", 0)
	case_lb.add_theme_constant_override("shadow_offset_y", 0)
	left.add_child(case_lb)
	var glow := case_lb.create_tween().set_loops()
	glow.tween_property(case_lb, "modulate", Color(1.25, 1.2, 1.0), 0.9).set_trans(Tween.TRANS_SINE)
	glow.tween_property(case_lb, "modulate", Color(1, 1, 1), 0.9).set_trans(Tween.TRANS_SINE)
	notebook_title = Label.new()
	notebook_title.add_theme_color_override("font_color", C_PALE)
	notebook_title.add_theme_font_size_override("font_size", 11)
	notebook_title.add_theme_constant_override("shadow_offset_x", 2)
	notebook_title.add_theme_constant_override("shadow_offset_y", 2)
	left.add_child(notebook_title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(392, 274)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	board_content = Control.new()
	scroll.add_child(board_content)
	notebook_list = GridContainer.new()
	(notebook_list as GridContainer).columns = 7
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

	# Menü: üç çizgili (hamburger) simge, yazısız.
	menu_button = _hud_button("", "", "")
	menu_button.custom_minimum_size = Vector2(20, BAR_H - 4)
	menu_button.size = Vector2(20, BAR_H - 4)
	menu_button.position = Vector2(8, VIEW_H - BAR_H + 2)
	menu_button.tooltip_text = "Menü (Esc)"
	for i in 3:
		var ln := ColorRect.new()
		ln.color = C_LIGHT
		ln.size = Vector2(14, 2)
		ln.position = Vector2(3, (BAR_H - 4) / 2.0 - 5.0 + i * 4.0)
		ln.mouse_filter = Control.MOUSE_FILTER_IGNORE
		menu_button.add_child(ln)
	menu_button.mouse_entered.connect(func():
		for c in menu_button.get_children():
			(c as ColorRect).color = C_YELLOW)
	menu_button.mouse_exited.connect(func():
		for c in menu_button.get_children():
			(c as ColorRect).color = C_LIGHT)
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
	menu_panel = Control.new()
	menu_panel.size = Vector2(VIEW_W, VIEW_H)
	menu_panel.clip_contents = true
	ui_root.add_child(menu_panel)
	var under := ColorRect.new()
	under.color = C_BLACK
	under.size = Vector2(VIEW_W, VIEW_H)
	menu_panel.add_child(under)
	# Arka plan: yağmurlu müze önü, yavaşça yaklaşan kamera (Ken Burns).
	var bgt := _art("ui/menu_bg")
	if bgt == null:
		bgt = _art("rooms/oscar_ofis")
	if bgt == null:
		bgt = _art("rooms/muze_onu")
	if bgt:
		var bg := TextureRect.new()
		bg.texture = bgt
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.size = Vector2(VIEW_W, VIEW_H)
		bg.pivot_offset = Vector2(VIEW_W * 0.7, VIEW_H * 0.5)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		menu_panel.add_child(bg)
		var kb := bg.create_tween().set_loops()
		kb.tween_property(bg, "scale", Vector2(1.12, 1.12), 18.0).set_trans(Tween.TRANS_SINE)
		kb.tween_property(bg, "scale", Vector2.ONE, 18.0).set_trans(Tween.TRANS_SINE)
	# Soldan sağa koyulaşan perde: yazılar okunur, sağda müze görünür.
	var g := Gradient.new()
	g.set_color(0, Color(0.03, 0.02, 0.01, 0.94))
	g.set_color(1, Color(0.03, 0.02, 0.01, 0.15))
	g.add_point(0.45, Color(0.03, 0.02, 0.01, 0.78))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 64
	gt.height = 4
	var shade := TextureRect.new()
	shade.texture = gt
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.size = Vector2(VIEW_W, VIEW_H)
	shade.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_panel.add_child(shade)
	# Yağmur
	var rain := CPUParticles2D.new()
	rain.amount = 220
	rain.lifetime = 0.7
	rain.preprocess = 1.0
	rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	rain.emission_rect_extents = Vector2(VIEW_W * 0.6, 2)
	rain.position = Vector2(VIEW_W / 2.0 + 40, -8)
	rain.direction = Vector2(-0.18, 1)
	rain.spread = 1.5
	rain.gravity = Vector2.ZERO
	rain.initial_velocity_min = 520.0
	rain.initial_velocity_max = 600.0
	rain.scale_amount_min = 1.0
	rain.scale_amount_max = 1.0
	rain.color = Color(0.8, 0.75, 0.62, 0.28)
	menu_panel.add_child(rain)
	# Arada bir şimşek
	var flash := ColorRect.new()
	flash.color = Color(0.95, 0.92, 0.8, 0.0)
	flash.size = Vector2(VIEW_W, VIEW_H)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_panel.add_child(flash)
	var ft := flash.create_tween().set_loops()
	ft.tween_interval(7.0)
	ft.tween_property(flash, "color:a", 0.22, 0.05)
	ft.tween_property(flash, "color:a", 0.0, 0.1)
	ft.tween_property(flash, "color:a", 0.14, 0.05)
	ft.tween_property(flash, "color:a", 0.0, 0.5)
	ft.tween_interval(4.0)

	var tf := _title_font()
	var title := Label.new()
	title.text = "DARK FILES"
	title.position = Vector2(44, 62)
	title.size = Vector2(360, 56)
	title.add_theme_font_size_override("font_size", 52)
	if tf:
		title.add_theme_font_override("font", tf)
	title.add_theme_color_override("font_color", C_YELLOW)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 3)
	menu_panel.add_child(title)
	# Eski neon tabela gibi ara ara titreyen başlık
	var fl := title.create_tween().set_loops()
	fl.tween_interval(3.2)
	fl.tween_property(title, "modulate:a", 0.35, 0.04)
	fl.tween_property(title, "modulate:a", 1.0, 0.04)
	fl.tween_property(title, "modulate:a", 0.6, 0.05)
	fl.tween_property(title, "modulate:a", 1.0, 0.08)
	var line := ColorRect.new()
	line.color = C_YELLOW
	line.position = Vector2(46, 122)
	line.size = Vector2(0, 2)
	menu_panel.add_child(line)
	line.create_tween().tween_property(line, "size:x", 210.0, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Başlığın altında Oscar'ın kısa ön hikayesi (vaka adı Vaka seç ekranında).
	var sub := Label.new()
	sub.text = "Bir zamanlar adı Büyük Valentino'ydu."
	sub.position = Vector2(46, 128)
	sub.size = Vector2(330, 16)
	sub.add_theme_font_size_override("font_size", 11)
	sub.add_theme_color_override("font_color", C_PALE)
	menu_panel.add_child(sub)
	var tag := Label.new()
	tag.text = "1998'de son numarasında sahne çöktü. Herkes kaza dedi, o hâlâ inanmıyor. Şimdi FCD için yalancıları okuyor, kirasını da zar zor ödüyor."
	tag.position = Vector2(46, 145)
	tag.size = Vector2(300, 36)
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tag.add_theme_font_size_override("font_size", 9)
	tag.add_theme_color_override("font_color", C_LIGHT)
	menu_panel.add_child(tag)

	var box := VBoxContainer.new()
	box.position = Vector2(40, 192)
	box.add_theme_constant_override("separation", 6)
	menu_panel.add_child(box)
	var play := _menu_item(box, "VAKA SEÇ", true, _open_case_select)
	play.grab_focus.call_deferred()
	_menu_item(box, "Kontroller", false, open_controls)
	_menu_item(box, "Ayarlar", false, open_settings)
	_menu_item(box, "Çıkış", false, func(): get_tree().quit())
	var help := Label.new()
	help.text = ""
	help.visible = false
	help.position = Vector2(0, VIEW_H - 22)
	help.size = Vector2(VIEW_W, 14)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 9)
	help.add_theme_color_override("font_color", C_LIGHT)
	menu_panel.add_child(help)
	menu_panel.modulate.a = 0.0
	menu_panel.create_tween().tween_property(menu_panel, "modulate:a", 1.0, 1.0)
	_set_hud_visible(false)
	busy = true
	in_menu = true
	_build_pause()
	_build_settings()


## Ana menü satırı: düz yazı; üzerine gelince sarıya döner ve sağa kayar. big: büyük, çerçeveli, nabız gibi atan "oyna" düğmesi.
func _menu_item(box: Control, text: String, big: bool, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(190 if big else 150, 34 if big else 22)
	b.add_theme_font_size_override("font_size", 20 if big else 14)
	var tf := _title_font()
	if big and tf:
		b.add_theme_font_override("font", tf)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.06, 0.04, 0.02, 0.75) if big else Color(0, 0, 0, 0)
	normal.border_color = C_YELLOW if big else Color(0, 0, 0, 0)
	normal.set_border_width_all(2 if big else 0)
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.91, 0.77, 0.28, 0.95) if big else Color(0.91, 0.77, 0.28, 0.12)
	hover.border_color = C_YELLOW
	hover.border_width_left = 3
	for st in ["normal", "focus"]:
		b.add_theme_stylebox_override(st, normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_color_override("font_color", C_YELLOW if big else C_PALE)
	b.add_theme_color_override("font_hover_color", C_BLACK if big else C_YELLOW)
	b.add_theme_color_override("font_focus_color", C_YELLOW if big else C_PALE)
	b.add_theme_color_override("font_pressed_color", C_BLACK if big else C_YELLOW)
	b.mouse_entered.connect(func():
		_sfx("blip")
		b.create_tween().tween_property(b, "position:x", 8.0, 0.12))
	b.mouse_exited.connect(func(): b.create_tween().tween_property(b, "position:x", 0.0, 0.12))
	b.pressed.connect(func():
		_sfx("click")
		cb.call())
	box.add_child(b)
	if big:
		var pulse := b.create_tween().set_loops()
		pulse.tween_property(b, "self_modulate", Color(1.25, 1.2, 1.0), 0.8).set_trans(Tween.TRANS_SINE)
		pulse.tween_property(b, "self_modulate", Color(1, 1, 1), 0.8).set_trans(Tween.TRANS_SINE)
	return b


func _start_game() -> void:
	if not in_menu:
		return
	_sfx("click")
	in_menu = false
	var tw := create_tween()
	tw.tween_property(menu_panel, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func():
		menu_panel.visible = false
		_play_cutscene(data.get("cutscene", []), _office_intro))


# ================================================================ açılış sahnesi

## Siyah ekranda resimli, daktiloyla yazılan kartlar. Tıkla/Boşluk devam, Esc atla.
func _play_cutscene(cards: Array, done: Callable) -> void:
	if cards.is_empty():
		done.call()
		return
	cut_cards = cards
	cut_i = 0
	cut_done = done
	in_cutscene = true
	busy = true
	if cut_panel == null:
		cut_panel = ColorRect.new()
		cut_panel.color = Color(0, 0, 0, 1)
		cut_panel.size = Vector2(VIEW_W, VIEW_H)
		cut_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		cut_panel.gui_input.connect(func(ev: InputEvent):
			var mb := ev as InputEventMouseButton
			if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				_cut_advance())
		ui_root.add_child(cut_panel)
		cut_img = TextureRect.new()
		cut_img.position = Vector2(VIEW_W / 2.0 - 200, 24)
		cut_img.size = Vector2(400, 225)
		cut_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cut_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		cut_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cut_panel.add_child(cut_img)
		cut_actors = Control.new()
		cut_actors.position = cut_img.position
		cut_actors.size = cut_img.size
		cut_actors.clip_contents = true
		cut_actors.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cut_panel.add_child(cut_actors)
		cut_text = Label.new()
		cut_text.position = Vector2(60, 262)
		cut_text.size = Vector2(VIEW_W - 120, 60)
		cut_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cut_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cut_text.add_theme_font_size_override("font_size", 15)
		cut_text.add_theme_color_override("font_color", C_PALE)
		cut_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cut_panel.add_child(cut_text)
		var hint := Label.new()
		hint.text = "Tıkla / Boşluk: devam     Esc: atla"
		hint.position = Vector2(0, VIEW_H - 22)
		hint.size = Vector2(VIEW_W - 16, 14)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hint.add_theme_font_size_override("font_size", 9)
		hint.add_theme_color_override("font_color", C_BROWN)
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cut_panel.add_child(hint)
	ui_root.move_child(cut_panel, -1)
	cut_panel.visible = true
	cut_panel.modulate.a = 1.0
	_show_cut_card()


func _show_cut_card() -> void:
	var c: Dictionary = cut_cards[cut_i]
	var tex: Texture2D = _art(str(c["art"])) if c.has("art") else null
	cut_img.texture = tex
	# Resim yoksa yazı ekranın ortasına iner.
	cut_text.position.y = 262.0 if tex else VIEW_H / 2.0 - 30.0
	cut_text.text = str(c["text"])
	var note := str(c.get("style", "")) == "note"
	cut_text.add_theme_font_size_override("font_size", 19 if note else 15)
	cut_text.add_theme_color_override("font_color", C_YELLOW if note else C_PALE)
	# Sahnedeki kişiler: "actors": [[çizim, x, zemin_y, sola_bak], ...] (mekan pikseli, 344x192 sahneye göre)
	for ch in cut_actors.get_children():
		cut_actors.remove_child(ch)
		ch.queue_free()
	if tex:
		var k: float = minf(cut_img.size.x / tex.get_width(), cut_img.size.y / tex.get_height())
		var off := (cut_img.size - Vector2(tex.get_size()) * k) / 2.0
		for a in c.get("actors", []):
			var at := _art(str(a[0]))
			if at == null:
				continue
			var tr := TextureRect.new()
			tr.texture = at
			tr.size = at.get_size()
			tr.scale = Vector2(k, k) * float(a[4] if a.size() > 4 else 1.0)
			tr.position = off + Vector2(float(a[1]) * k - at.get_width() * tr.scale.x / 2.0, float(a[2]) * k - at.get_height() * tr.scale.y)
			tr.flip_h = a.size() > 3 and bool(a[3])
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cut_actors.add_child(tr)
	cut_actors.modulate.a = 0.0
	if c.has("sfx"):
		_sfx(str(c["sfx"]))
	cut_text.visible_ratio = 0.0
	cut_img.modulate.a = 0.0
	if cut_tween:
		cut_tween.kill()
	cut_tween = create_tween()
	cut_tween.tween_property(cut_img, "modulate:a", 1.0, 0.6)
	cut_tween.parallel().tween_property(cut_actors, "modulate:a", 1.0, 0.6)
	cut_tween.parallel().tween_property(cut_text, "visible_ratio", 1.0, 0.035 * cut_text.text.length())


func _cut_advance() -> void:
	if not in_cutscene:
		return
	if cut_tween and cut_tween.is_running():
		cut_tween.kill()
		cut_img.modulate.a = 1.0
		cut_actors.modulate.a = 1.0
		cut_text.visible_ratio = 1.0
		return
	_sfx("blip")
	cut_i += 1
	if cut_i >= cut_cards.size():
		_end_cutscene()
	else:
		_show_cut_card()


func _end_cutscene() -> void:
	if not in_cutscene:
		return
	in_cutscene = false
	if cut_tween:
		cut_tween.kill()
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 1.0, 0.6)
	tw.tween_callback(func():
		cut_panel.visible = false
		var cb := cut_done
		cut_done = Callable()
		if cb.is_valid():
			cb.call())


func _set_hud_visible(v: bool) -> void:
	notebook_button.visible = v
	menu_button.visible = v
	eye_button.visible = v
	debt_label.visible = false   # borç HUD'da değil, Oscar'ın odasında görünür
	if not v:
		accuse_hud.visible = false


## sfx/<ad>.wav dosyaları varsa çalınır; yoksa sessiz geçer.
func _build_sfx() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
	_load_settings()
	for n in ["blip", "pickup", "door", "click", "deduce", "wrong", "solve", "eye", "car_door", "engine", "lighter", "car_remote", "trunk_open", "trunk_close", "book"]:
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
				busy = false
				_room_event())


# ================================================================ açılış akışı

func _scene(key: String) -> Array:
	return data.get("scenes", {}).get(key, [])


func _room_obj(type_name: String) -> Dictionary:
	for e in room_objects:
		if str(e["data"]["type"]) == type_name:
			return e
	return {}


## Maya'yı senaryoyla x'e yürütür; varınca cb çağrılır. speed_mul: Oscar hızına oran.
func maya_go(x: float, speed_mul: float, cb: Callable) -> void:
	maya_script = true
	maya_target = x
	maya_speed = speed_mul
	maya_cb = cb


func maya_follow() -> void:
	maya_script = false
	maya_cb = Callable()
	if maya:
		maya.visible = true


func _wait(sec: float, cb: Callable) -> void:
	get_tree().create_timer(sec).timeout.connect(cb)


## Mekan yüklenince (ekran karanlıkken) kişilerin yerleşimi.
func _room_setup(id: String, spawn_x: float) -> void:
	player.visible = true
	player_pose = null
	if player_sprite:
		player_sprite.position.y = -player_sprite.size.y
	in_car = false
	maya_follow()
	player.modulate.a = 1.0
	if _no_player():
		player.visible = false
		if maya:
			maya.visible = false
		show_msg(str(data["rooms"][id].get("exit_hint", "E: dışarı çık")))
		return
	match id:
		"oscar_ofis":
			_spawn_office_chair()
			if not flags.has("ofis_done"):
				var sit := _art("oscar_sit")
				player_pose = sit if sit else _art("oscar")
				var rr: Dictionary = data["rooms"][id]
				player.position.x = float(rr.get("sit_x", player.position.x))
				player_sprite.position.y = -player_sprite.size.y + float(rr.get("sit_dy", 0.0))
				camera.reset_smoothing()
				_face(1.0)
				if maya:
					maya.visible = false
		"sorgu":
			if summoned != "":
				_spawn_object({"type": "npc", "dialogue": summoned, "art": _npc_art(summoned), "x": 214}, _art("rooms/sorgu") != null)
				player.position.x = 132.0
				if maya:
					maya_x = 96.0
				_refresh_npc_marks()
		"koridor":
			if not flags.has("koridor_done") and maya:
				maya_x = spawn_x + 20.0
				maya_go(maya_x, 1.0, Callable())
		"muze_onu":
			if not flags.has("arrived"):
				in_car = true
				player.visible = false
				if maya:
					maya.visible = false
				var car := _room_obj("car")
				if not car.is_empty():
					player.position.x = float(car["data"]["x"])
					# Araba ekran açılmadan önce solda, görünmeyen yerde beklesin; _car_arrive sürer.
					var cn: Control = car["node"]
					if not cn.has_meta("final_x"):
						cn.set_meta("final_x", cn.position.x)
					cn.position.x = -cn.size.x * cn.scale.x - 40.0
				camera.reset_smoothing()


## Kapıdan girip ekran açılınca: odaya özel sahne, yoksa "enter_lines".
func _room_event() -> void:
	match room_id:
		"koridor":
			if not flags.has("koridor_done"):
				flags["koridor_done"] = true
				var elev := float(data["rooms"]["koridor"].get("elevator_x", room_w - 30.0))
				play_lines(_scene("koridor"), func():
					_close_dialog()
					maya_go(elev - 12.0, 1.7, Callable()))
				return
		"muze_onu":
			if not flags.has("arrived"):
				_car_arrive()
				return
		"sorgu":
			if summoned != "":
				var who := summoned
				current_npc = who
				play_lines(data["final"].get("interrogation_intro", []), func(): _accuse(who))
				return
	_play_enter_lines()


## Oyun başı: hikaye kartlarından sonra Oscar'ın odası yavaşça aydınlanır, Maya gelir.
func _office_intro() -> void:
	busy = true
	var door := float(data["rooms"]["oscar_ofis"].get("door_x", room_w - 30.0))
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 0.0, 3.0).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(1.2)
	tw.tween_callback(func():
		if maya == null:
			_office_talk()
			return
		maya_x = door
		maya.visible = true
		maya.modulate.a = 0.0
		maya.create_tween().tween_property(maya, "modulate:a", 1.0, 0.3)
		_sfx("door")
		maya_go(door - 70.0, 1.0, _office_talk))


func _office_talk() -> void:
	play_lines(_scene("ofis"), func():
		_close_dialog()
		busy = true
		# son yudum, sonra ayağa kalk
		var sip := _art("oscar_sip")
		var sit := player_pose
		var tw := create_tween()
		tw.tween_interval(0.4)
		if sip:
			tw.tween_callback(func(): player_pose = sip)
			tw.tween_interval(1.3)
			tw.tween_callback(func(): player_pose = sit)
			tw.tween_interval(0.5)
		else:
			tw.tween_property(player_sprite, "position:y", player_sprite.position.y - 1.0, 0.4)
			tw.tween_property(player_sprite, "position:y", player_sprite.position.y, 0.4)
			tw.tween_interval(0.6)
		# ayağa kalkma kareleri (art/oscar_stand.png)
		var stand: Array = _strip_frames(_art("oscar_stand"), 32) if _art("oscar_stand") != null else []
		# Kalkma karelerinde sandalye çizimden silinir; boş sandalye arkada belirir.
		tw.tween_callback(func():
			if office_chair:
				office_chair.visible = true)
		for f in stand:
			tw.tween_callback(func(): player_pose = f)
			tw.tween_interval(0.14)
		tw.tween_callback(func():
			player_pose = null
			player_sprite.position.y = -player_sprite.size.y
			flags["ofis_done"] = true
			if office_chair:
				office_chair.visible = true
			_set_hud_visible(true)
			var door := float(data["rooms"]["oscar_ofis"].get("door_x", room_w - 30.0))
			if maya:
				maya_go(door, 1.1, func():
					_sfx("door")
					var mt := maya.create_tween()
					mt.tween_property(maya, "modulate:a", 0.0, 0.3)
					mt.tween_callback(func():
						maya.visible = false
						maya.modulate.a = 1.0))
			play_lines(_scene("ofis_after"), Callable())))


# ---------------------------------------------------------------- araba

## Sokakta arabaya biniş: Maya ve Oscar arabaya yürür, kapılar çarpar, araba hafifçe çöker, motor çalışır.
func _board_car() -> void:
	var car := _room_obj("car")
	if car.is_empty():
		_start_drive()
		return
	busy = true
	var n: Control = car["node"]
	var cx := float(car["data"]["x"])
	var px := clampf(cx + 14.0, walk_min, walk_max)
	var mx := clampf(cx - 18.0, walk_min, walk_max)
	if maya:
		maya_go(mx, 1.3, Callable())
	var walk_t := absf(player.position.x - px) / SPEED
	player_walking_script = true
	_face(px - player.position.x)
	var tw := create_tween()
	tw.tween_property(player, "position:x", px, walk_t)
	tw.tween_callback(func():
		player_walking_script = false
		_face(-1.0))
	tw.tween_interval(maxf(0.0, absf(maya_x - mx) / (SPEED * 1.3) - walk_t) + 0.15)
	# Önce Maya biner
	tw.tween_callback(func(): _sfx("car_door"))
	if maya:
		tw.tween_property(maya, "modulate:a", 0.0, 0.25)
	tw.tween_property(n, "position:y", n.position.y + 1.0, 0.08)
	tw.tween_property(n, "position:y", n.position.y, 0.12)
	tw.tween_interval(0.35)
	# Sonra Oscar
	tw.tween_property(player, "modulate:a", 0.0, 0.25)
	tw.tween_callback(func(): _sfx("car_door"))
	tw.tween_property(n, "position:y", n.position.y + 1.5, 0.08)
	tw.tween_property(n, "position:y", n.position.y, 0.14)
	tw.tween_interval(0.3)
	tw.tween_callback(func(): _sfx("engine"))
	# Motor titremesi
	for i in range(6):
		tw.tween_property(n, "position:y", n.position.y + (0.5 if i % 2 == 0 else 0.0), 0.06)
	tw.tween_interval(0.5)
	tw.tween_callback(func():
		player.visible = false
		player.modulate.a = 1.0
		if maya:
			maya.visible = false
			maya.modulate.a = 1.0
		_start_drive())


func _start_drive() -> void:
	busy = true
	_build_drive()   # tween'ler düğümlere şimdiden bağlanabilsin diye önce kur
	drive_panel.visible = false
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 1.0, 0.5)
	tw.tween_callback(func():
		drive_panel.visible = true
		drive_street.visible = true
		drive_road.visible = false
		drive_street.scale = Vector2.ONE
		drive_street_car.position.x = -drive_street_car.size.x * drive_street_car.scale.x - 20.0)
	tw.tween_property(fade_rect, "color:a", 0.0, 0.8)
	# 1) Sokak: araba durmadan soldan girip sağdan çıkar (kamera hafif yakınlaşır).
	tw.tween_property(drive_street_car, "position:x", VIEW_W + 40.0, 3.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(drive_street, "scale", Vector2(1.1, 1.1), 3.4).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(fade_rect, "color:a", 1.0, 0.7).set_delay(2.7)
	# 2) Yolculuk: araba ortada, yol ve direkler altından kayar.
	tw.tween_callback(func():
		drive_street.visible = false
		drive_road.visible = true
		driving = true
		drive_offset = 0.0)
	tw.tween_property(fade_rect, "color:a", 0.0, 0.8)
	tw.tween_interval(1.0)
	tw.tween_callback(func():
		play_lines(_scene("drive"), func():
			_close_dialog()
			busy = true
			var t2 := create_tween()
			t2.tween_interval(1.0)
			t2.tween_property(fade_rect, "color:a", 1.0, 0.8)
			t2.tween_callback(func():
				driving = false
				drive_panel.visible = false
				load_room("muze_onu", 0.0))
			t2.tween_property(fade_rect, "color:a", 0.0, 0.8)
			t2.tween_callback(_car_arrive)))


## Arabanın üstüne iki dönen teker koyar (art/araba_wheel.png). road: yolculukta sürekli döner.
func _add_wheels(car: Control, road: bool) -> void:
	var wt := _art("araba_wheel")
	if wt == null or not (car is TextureRect):
		return
	for c in CAR_WHEELS:
		var w := TextureRect.new()
		w.texture = wt
		w.size = wt.get_size()
		w.pivot_offset = wt.get_size() / 2.0
		w.position = (c as Vector2) - wt.get_size() / 2.0
		w.mouse_filter = Control.MOUSE_FILTER_IGNORE
		car.add_child(w)
		wheels.append({"node": w, "car": car, "last_x": car.global_position.x, "road": road})


func _spin_wheels(delta: float) -> void:
	var keep: Array = []
	for e in wheels:
		var w = e["node"]
		if not is_instance_valid(w):
			continue
		keep.append(e)
		var car: Control = e["car"]
		var sc := car.get_global_transform().get_scale().x
		var x := car.global_position.x
		var spin := (x - float(e["last_x"])) / (5.0 * sc)
		if bool(e["road"]) and driving:
			spin += 220.0 / (5.0 * sc) * delta
		e["last_x"] = x
		(w as Control).rotation += spin
	wheels = keep


func _car_w() -> float:
	var t := _art("araba")
	return t.get_width() * DRIVE_CAR_SCALE if t else 160.0


## Arabanın tekerlek hizası (ekran pikseli). Çizim gelince yola göre ayarlanır.
const DRIVE_CAR_BOTTOM := 306.0
const DRIVE_CAR_SCALE := 3.0     # yol sahnelerinde araba (dünyada 1x, burada daha yakın çekim)


func _make_drive_car(parent: Control, x: float) -> Control:
	var car_tex := _art("araba")
	var car: Control
	if car_tex:
		car = TextureRect.new()
		(car as TextureRect).texture = car_tex
		car.size = car_tex.get_size()
		car.scale = Vector2(DRIVE_CAR_SCALE, DRIVE_CAR_SCALE)
		car.position = Vector2(x, DRIVE_CAR_BOTTOM - car_tex.get_height() * DRIVE_CAR_SCALE)
	else:
		car = ColorRect.new()
		(car as ColorRect).color = C_BROWN
		car.size = Vector2(160, 50)
		car.position = Vector2(x, DRIVE_CAR_BOTTOM - 50.0)
	car.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(car)
	return car


## 344x192 çizimi 2x büyütüp ekrana ortalar.
func _drive_bg(parent: Control, tex: Texture2D, tile: bool) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = tex
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if tile:
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_TILE
		tr.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		tr.size = Vector2(VIEW_W / ZOOM + tex.get_width() * 2.0, tex.get_height())
	else:
		tr.size = tex.get_size()
	tr.scale = Vector2(ZOOM, ZOOM)
	tr.position = Vector2(-(tex.get_width() * ZOOM - VIEW_W) / 2.0 if not tile else 0.0, -(tex.get_height() * ZOOM - VIEW_H) / 2.0)
	parent.add_child(tr)
	return tr


## Çizimler: art/drive/street.png (sokak, 344x192), art/drive/sky.png (gökyüzü, sabit),
## art/drive/road.png (yol ve direkler, şeffaf üst, yatayda kesintisiz tekrar eden), isteğe bağlı art/drive/lamps.png.
func _build_drive() -> void:
	if drive_panel != null:
		return
	drive_panel = Control.new()
	drive_panel.size = Vector2(VIEW_W, VIEW_H)
	drive_panel.clip_contents = true
	drive_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_root.add_child(drive_panel)
	ui_root.move_child(drive_panel, 0)
	# sokak sahnesi
	drive_street = Control.new()
	drive_street.size = Vector2(VIEW_W, VIEW_H)
	drive_street.pivot_offset = Vector2(VIEW_W / 2.0, VIEW_H * 0.75)
	drive_panel.add_child(drive_street)
	var st := _art("drive/street")
	var sky_t := _art("drive/sky")
	var road_t := _art("drive/road")
	if st:
		_drive_bg(drive_street, st, false)
	elif sky_t and road_t:
		# Ayrı sokak çizimi yoksa gökyüzü + yol katmanı durağan olarak kullanılır.
		_drive_bg(drive_street, sky_t, false)
		_drive_bg(drive_street, road_t, false)
	else:
		_build_drive_placeholder(drive_street, false)
	drive_street_car = _make_drive_car(drive_street, -200.0)
	_add_wheels(drive_street_car, false)
	# yolculuk sahnesi
	drive_road = Control.new()
	drive_road.size = Vector2(VIEW_W, VIEW_H)
	drive_panel.add_child(drive_road)
	var any_layer := false
	for layer in [["drive/sky", 0.0], ["drive/lamps", 90.0], ["drive/road", 220.0]]:
		var tex := _art(str(layer[0]))
		if tex == null:
			continue
		any_layer = true
		var sp := float(layer[1])
		var tr := _drive_bg(drive_road, tex, sp > 0.0)
		if sp > 0.0:
			drive_layers.append({"node": tr, "speed": sp, "wrap": tex.get_width() * ZOOM})
	if not any_layer:
		_build_drive_placeholder(drive_road, true)
	var car := _make_drive_car(drive_road, VIEW_W / 2.0 - _car_w() / 2.0)
	_add_wheels(car, true)
	var bob := car.create_tween().set_loops()
	bob.tween_property(car, "position:y", car.position.y - 2.0, 0.18)
	bob.tween_property(car, "position:y", car.position.y, 0.18)


## Gece yolu çizimleri gelene kadar geçici görüntü. moving: direkler ve şeritler kayar.
func _build_drive_placeholder(parent: Control, moving: bool) -> void:
	var sky := ColorRect.new()
	sky.color = Color("#0b0c16")
	sky.size = Vector2(VIEW_W, VIEW_H)
	parent.add_child(sky)
	var moon := ColorRect.new()
	moon.color = C_PALE
	moon.size = Vector2(22, 22)
	moon.position = Vector2(500, 40)
	parent.add_child(moon)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in range(40):
		var star := ColorRect.new()
		star.color = Color(C_PALE, rng.randf_range(0.3, 0.9))
		star.size = Vector2(2, 2)
		star.position = Vector2(rng.randf_range(0, VIEW_W), rng.randf_range(0, 180))
		parent.add_child(star)
	var lamps := Control.new()
	parent.add_child(lamps)
	for i in range(8):
		var x: float = i * 120.0
		var pole := ColorRect.new()
		pole.color = C_DARK
		pole.size = Vector2(4, 130)
		pole.position = Vector2(x, 160)
		lamps.add_child(pole)
		var head := ColorRect.new()
		head.color = C_YELLOW
		head.size = Vector2(16, 4)
		head.position = Vector2(x - 6, 158)
		lamps.add_child(head)
	var road := ColorRect.new()
	road.color = Color("#1a1612")
	road.size = Vector2(VIEW_W, 70)
	road.position = Vector2(0, 290)
	parent.add_child(road)
	var dashes := Control.new()
	parent.add_child(dashes)
	for i in range(12):
		var d := ColorRect.new()
		d.color = C_YELLOW
		d.size = Vector2(30, 3)
		d.position = Vector2(i * 70.0, 330)
		dashes.add_child(d)
	if moving:
		drive_layers.append({"node": lamps, "speed": 90.0, "wrap": 120.0})
		drive_layers.append({"node": dashes, "speed": 220.0, "wrap": 70.0})


func _update_drive(delta: float) -> void:
	if not driving:
		return
	drive_offset += delta
	for l in drive_layers:
		var sp: float = l["speed"]
		if sp <= 0.0:
			continue
		(l["node"] as Control).position.x = -fmod(drive_offset * sp, float(l["wrap"]))


## Müzenin önünde araba soldan gelip yanaşır; E/F ya da tıklama ile inilir.
func _car_arrive() -> void:
	busy = true
	in_car = true
	player.visible = false
	if maya:
		maya.visible = false
	var car := _room_obj("car")
	if car.is_empty():
		_exit_car()
		return
	var n: Control = car["node"]
	var final_x: float = float(n.get_meta("final_x", n.position.x))
	n.position.x = -n.size.x * n.scale.x - 40.0
	car_tween = create_tween()
	var tw := car_tween
	tw.tween_property(n, "position:x", final_x, 2.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): show_msg("Arabadan in: E / F"))


func _exit_car() -> void:
	if not in_car or (car_tween and car_tween.is_running()):
		return
	in_car = false
	flags["arrived"] = true
	var car := _room_obj("car")
	var cx := float(car["data"]["x"]) if not car.is_empty() else player.position.x
	player.position.x = clampf(cx + 26.0, walk_min, walk_max)
	player.visible = true
	player.modulate.a = 0.0
	_face(1.0)
	busy = true
	_sfx("car_door")
	var tw := create_tween()
	tw.tween_property(player, "modulate:a", 1.0, 0.3)
	tw.tween_interval(0.3)
	tw.tween_callback(func():
		_sfx("car_door")
		if maya:
			maya_x = clampf(cx + 4.0, walk_min, walk_max)
			maya.modulate.a = 0.0
			maya_follow()
			maya.create_tween().tween_property(maya, "modulate:a", 1.0, 0.3))
	tw.tween_interval(0.4)
	tw.tween_callback(func():
		busy = false
		_play_enter_lines())


## Torbadan tekrarsız bir replik çeker; torba bitince karıştırılıp yeniden dolar.
## Replik "metin" ya da ["Konuşan", "metin"] olabilir.
func _pick_quip(key: String) -> Array:
	var bag: Array = quip_bag.get(key, [])
	if bag.is_empty():
		bag = (data.get(key, ["..."]) as Array).duplicate()
		bag.shuffle()
	var q = bag.pop_back()
	quip_bag[key] = bag
	if q is Array:
		return q
	return ["Maya", str(q)]


## Tanışılmamış kişinin adı görünmez.
func _npc_label(did: String) -> String:
	if not flags.has("seen_" + did) and not flags.has("seen_" + did.rstrip("0123456789")):
		return "???"
	return str(data["dialogues"][did]["name"])


## Kafadaki ünlem: tanışılmadıysa ya da sorulmamış soru varsa görünür.
func _refresh_npc_marks() -> void:
	for m in npc_marks:
		var did := str(m["data"]["dialogue"])
		var open := _npc_label(did) == "???"
		for t in data["dialogues"][did].get("topics", []):
			if t.has("requires_clue") and not clues.has(t["requires_clue"]):
				continue
			if t.has("requires_flag") and not flags.has(t["requires_flag"]):
				continue
			if not flags.has("asked:" + did + ":" + str(t["q"])):
				open = true
		(m["mark"] as Control).visible = open


## Bir diyaloğun portre çizimi: speakers tablosu, yoksa id'nin rakamsız hali (vivian2 -> vivian).
func _npc_art(did: String) -> String:
	var d: Dictionary = data["dialogues"][did]
	if d.has("art"):
		return str(d["art"])
	var speakers: Dictionary = data.get("speakers", {})
	var nm := str(d["name"])
	if speakers.has(nm):
		return str(speakers[nm])
	if speakers.has(nm.split(" ")[0]):
		return str(speakers[nm.split(" ")[0]])
	return did.rstrip("0123456789")


## Mekanın "enter_lines" satırları ilk girişte bir kez oynar; yoksa sırası gelen bir NPC çıkışı.
func _play_enter_lines() -> void:
	var r: Dictionary = data["rooms"][room_id]
	var key := "entered_" + room_id
	if r.has("enter_lines") and not flags.has(key):
		flags[key] = true
		play_lines(r["enter_lines"], Callable())
		return
	_try_interjection()


## Şüpheli, Oscar odaya girince yanına gelip itiraz eder; oyuncu cevap seçer.
func _try_interjection() -> void:
	for it in data.get("interjections", []):
		var id := "inter_" + str(it["id"])
		if flags.has(id) or str(it["room"]) != room_id:
			continue
		if it.has("clue") and not clues.has(it["clue"]):
			continue
		# Oscar'la henüz tanışmamış biri kendiliğinden gelip konuşmaz.
		if not flags.has("seen_" + str(it["npc"])):
			continue
		var npc := {}
		for e in room_objects:
			if str(e["data"]["type"]) == "npc" and str(e["data"]["dialogue"]).rstrip("0123456789") == str(it["npc"]) and (e["node"] as Control).visible:
				npc = e
		if npc.is_empty():
			continue
		flags[id] = true
		current_npc = str(npc["data"]["dialogue"])
		_npc_walk_up(npc, func():
			_face_each_other(npc["data"])
			_sfx("blip")
			_interjection_talk(it))
		return


func _interjection_talk(it: Dictionary) -> void:
	play_lines(it["lines"], func():
		_clear_choices()
		busy = true
		dialog_panel.visible = true
		for ch in it.get("choices", []):
			var c: Dictionary = ch
			_add_choice(str(c["text"]), func():
				play_lines(c.get("lines", []), Callable()))
		_layout_dialog())


## Şüpheli itiraz etmeden önce yürüyerek Oscar'ın yanına gelir (art/<ad>_walk.png).
func _npc_walk_up(e: Dictionary, done: Callable) -> void:
	var o: Dictionary = e["data"]
	var n: Control = e["node"]
	var ox := float(o["x"])
	var side := 1.0 if ox > player.position.x else -1.0
	var tx := clampf(player.position.x + side * 26.0, walk_min, walk_max)
	var dist := absf(tx - ox)
	if dist < 6.0:
		done.call()
		return
	busy = true
	var anim := {}
	for a in npc_anims:
		if a["node"] == n:
			anim = a
	if not anim.is_empty():
		anim["moving"] = true
	var step := func(x: float) -> void:
		o["x"] = x
		n.position.x = x - n.size.x / 2.0
	var tw := create_tween()
	tw.tween_method(step, ox, tx, dist / 45.0)
	tw.tween_callback(func():
		if not anim.is_empty():
			anim["moving"] = false
		busy = false
		done.call())


func load_room(id: String, spawn_x: float) -> void:
	room_id = id
	for c in room_layer.get_children():
		room_layer.remove_child(c)
		c.queue_free()
	for c in fx_layer.get_children():
		fx_layer.remove_child(c)
		c.queue_free()
	for c in front_layer.get_children():
		front_layer.remove_child(c)
		c.queue_free()
	room_objects.clear()
	npc_marks.clear()
	bg_nodes.clear()
	npc_anims.clear()
	door_labels.clear()
	var r: Dictionary = data["rooms"][id]
	room_w = float(r["width"])
	floor_y = float(r.get("floor_y", DEFAULT_FLOOR_Y))
	char_scale = 1.0   # Berat kararı (2026-11-28): karakterler her mekanda sabit 1x, sahneler bu ölçüye göre çizilir
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
	# Yürünebilir aralık: "walk": [min, max] (ör. holde soldaki kapıların üstüne basılmasın).
	var wl: Array = r.get("walk", [8.0, room_w - 8.0])
	if bool(r.get("no_player", false)):
		wl = [room_w / 2.0, room_w / 2.0]
		spawn_x = room_w / 2.0
	walk_min = float(wl[0])
	walk_max = float(wl[1])
	for o in r["objects"]:
		_spawn_object(o, bg_tex != null)
	if bool(r.get("rain", false)):
		_add_rain()
	player.position = Vector2(clampf(spawn_x, walk_min, walk_max), floor_y)
	maya_x = clampf(spawn_x + (-22.0 if spawn_x > room_w / 2.0 else 22.0) * char_scale, walk_min, walk_max)
	# Sahne 180'den uzunsa (PixelLab 192) dikeyde ortala.
	# Alt/üst siyah bantlar dünyadan BAR_H/ZOOM kadar örter: zemini bandın üstünde tut,
	# gerekirse kamera odanın altına taşabilsin (bandın arkası zaten siyah).
	var bar_w := BAR_H / ZOOM
	camera.limit_top = int(-bar_w)
	if bool(r.get("no_player", false)):
		camera.position = Vector2(0, room_h / 2.0 - floor_y)
	else:
		camera.position = Vector2(0, -(VIEW_H / ZOOM / 2.0 - bar_w - 8.0))
	camera.limit_right = int(room_w)
	camera.limit_bottom = int(maxf(room_h, floor_y + bar_w + 8.0))
	camera.reset_smoothing()
	eye_on = false
	eye_uses = 3
	_update_eye_button()
	target_x = -1.0
	pending_action = Callable()
	_refresh_visibility()
	_refresh_npc_marks()
	show_msg((str(r["place"]) + "  ·  " if r.has("place") else "") + str(r["name"]))
	_complete_lab()
	maya_chat_idle = 0.0
	_room_setup(id, spawn_x)


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
		"look":
			art_key = str(o.get("art", ""))
			col = C_LIGHT
		"car":
			art_key = str(o.get("art", "araba"))
			w = 80.0
			h = 30.0
			col = C_BROWN
		"door":
			art_key = str(o.get("art", "door"))
			w = float(o.get("w", 24))
			h = float(o.get("h", 54))
			col = C_DARK
			label_text = str(o.get("label", data["rooms"][o["to"]]["name"]))
	var tex := _art(art_key)
	var frames: Array = []
	var walk_frames_npc: Array = []
	if t == "npc" and tex:
		var idle_key := str(o.get("idle", art_key + "_idle"))
		frames = _strip_frames(_art(idle_key), tex.get_width())
		if _art(art_key + "_walk"):
			walk_frames_npc = _strip_frames(_art(art_key + "_walk"), tex.get_width())
	if tex:
		w = tex.get_width()
		h = tex.get_height()
	var pos := Vector2(float(o["x"]) - w / 2.0, floor_y - float(o.get("y", 0)) - h)
	var n: Control
	var parent: Node = front_layer if t == "car" else room_layer
	if tex:
		n = _child_tex(parent, pos, tex)
	else:
		n = _child_rect(parent, pos, Vector2(w, h), col)
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
	if t == "car":
		n.pivot_offset = Vector2(w / 2.0, h)
		n.scale = Vector2(CAR_SCALE, CAR_SCALE) * char_scale
		if bool(o.get("flip", false)) and n is TextureRect:
			(n as TextureRect).flip_h = true
		_add_wheels(n, false)
	if t == "npc" and not frames.is_empty():
		npc_anims.append({"node": n, "frames": frames, "walk": walk_frames_npc, "data": o, "moving": false, "phase": randf() * 2.0})
	if t == "clue" or t == "look":
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
	if t == "door" and label_text != "":
		# Kapı yazısı: büyük punto yarım ölçekte + kalın siyah kontur, silik görünmesin.
		var lb := Label.new()
		lb.text = label_text
		var wf := _world_font()
		# Kutu yazının kendi genişliğinde: yazı kapının tam üstünde ortalanır,
		# sadece gerçekten ekran dışına taşacaksa kenara kayar.
		var text_w: float = label_text.length() * 9.0
		if wf:
			text_w = wf.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		lb.size = Vector2(text_w + 12.0, 20)
		lb.scale = Vector2(0.4, 0.4)
		var lbw := lb.size.x * 0.4
		var left_w := clampf(float(o["x"]) - lbw / 2.0, 1.0, room_w - lbw - 1.0)
		lb.position = Vector2(left_w - pos.x, -12)
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lb.add_theme_font_size_override("font_size", 16)
		if wf:
			lb.add_theme_font_override("font", wf)
		lb.add_theme_color_override("font_color", C_YELLOW)
		lb.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.02))
		lb.add_theme_constant_override("outline_size", 5)
		lb.add_theme_constant_override("shadow_offset_x", 0)
		lb.add_theme_constant_override("shadow_offset_y", 0)
		lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lb.visible = false
		lb.modulate.a = 0.0
		n.add_child(lb)
		door_labels.append({"label": lb, "x": float(o["x"]), "data": o})
	if t == "npc":
		# İsim yok; konuşulacak bir şey varsa başın üstünde parlayan ünlem (art/ui/unlem.png).
		var mk := TextureRect.new()
		var mtex := _art("ui/unlem")
		mk.texture = mtex
		var ms := Vector2(7, 18) if mtex == null else Vector2(mtex.get_size())
		mk.size = ms
		mk.scale = Vector2(1.0 / char_scale, 1.0 / char_scale)
		var top := -ms.y / char_scale - 4.0 / char_scale
		var head_x: float = _head_center_x(tex) if tex else w / 2.0
		mk.position = Vector2(head_x - ms.x / 2.0 / char_scale, top)
		mk.mouse_filter = Control.MOUSE_FILTER_IGNORE
		n.add_child(mk)
		var bt := mk.create_tween().set_loops()
		bt.tween_property(mk, "position:y", top - 3.0 / char_scale, 0.45).set_trans(Tween.TRANS_SINE)
		bt.tween_property(mk, "position:y", top, 0.45).set_trans(Tween.TRANS_SINE)
		var sh := mk.create_tween().set_loops()
		sh.tween_interval(1.1)
		sh.tween_property(mk, "self_modulate", Color(1.9, 1.9, 1.7), 0.12)
		sh.tween_property(mk, "self_modulate", Color(1, 1, 1), 0.35)
		sh.tween_interval(0.6)
		npc_marks.append({"data": o, "mark": mk})
	room_objects.append({"data": o, "node": n})


## Bayrak ya da bayrak listesi (listede hepsi gerekir).
func _has_flags(v: Variant) -> bool:
	if v is Array:
		for f in v:
			if not flags.has(str(f)):
				return false
		return true
	return flags.has(str(v))


## Yerdeki ipucunu alırken eğilme (art/oscar_crouch.png): in, bekle, kalk.
func _crouch_then(done: Callable) -> void:
	var fr := _strip_frames(_art("oscar_crouch"), 32)
	busy = true
	var tw := create_tween()
	for f in fr:
		tw.tween_callback(func(): player_pose = f)
		tw.tween_interval(0.08)
	tw.tween_interval(0.25)
	for i in range(fr.size() - 2, -1, -1):
		var f2: Texture2D = fr[i]
		tw.tween_callback(func(): player_pose = f2)
		tw.tween_interval(0.08)
	tw.tween_callback(func():
		player_pose = null
		busy = false
		done.call())


## Bir kez incelenen eşya bir daha parlamaz ve tıklanmaz ("keep": true olanlar hariç).
func _look_key(o: Dictionary) -> String:
	return room_id + ":" + str(o.get("name", o.get("x", "")))


func _obj_visible(o: Dictionary) -> bool:
	if o.has("requires_flag") and not _has_flags(o["requires_flag"]):
		return false
	if o.has("hide_if_flag") and _has_flags(o["hide_if_flag"]):
		return false
	if str(o["type"]) == "look" and looked.has(_look_key(o)) and not bool(o.get("keep", false)):
		return false
	if str(o["type"]) == "clue":
		if clues.has(o["id"]):
			return false
		if bool(o.get("hidden", false)) and not eye_on:
			return false
	return true


func _refresh_visibility() -> void:
	# Oscar'ın Gözü: sahne ve herkes kararır, sadece Oscar ve ipuçları parlak kalır.
	var dim := Color(0.22, 0.2, 0.2)
	for e in room_objects:
		var o: Dictionary = e["data"]
		var n: Control = e["node"]
		n.visible = _obj_visible(o)
		n.modulate = dim if (eye_on and str(o["type"]) != "clue") else Color(1, 1, 1)
	for b in bg_nodes:
		b.modulate = dim if eye_on else Color(1, 1, 1)
	if maya:
		maya.self_modulate = dim if eye_on else Color(1, 1, 1)
	if player_sprite:
		player_sprite.modulate = Color(1.3, 1.22, 1.0) if eye_on else Color(1, 1, 1)


func _object_at(pos: Vector2) -> Dictionary:
	# Önce ipucu/kapı/eşya, sonra kişi: kişinin geniş alanı ayağının dibindeki ipucunu yutmasın.
	for pass_npc in [false, true]:
		for i in range(room_objects.size() - 1, -1, -1):
			var e: Dictionary = room_objects[i]
			var n: Control = e["node"]
			if not n.visible:
				continue
			if (str(e["data"]["type"]) == "npc") != pass_npc:
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
			return "Konuş: " + _npc_label(str(o["dialogue"]))
		"door":
			return "Git: " + str(data["rooms"][o["to"]]["name"])
		"look":
			return "Bak: " + str(o.get("name", ""))
		"car":
			return "Arabaya bin" if room_id == "sokak" else "Araba"
	return ""


# ================================================================ hareket ve girdi

func _process(delta: float) -> void:
	_update_door_labels(delta)
	_update_maya_chat(delta)
	_update_maya(delta)
	_update_drive(delta)
	_update_eye_timer(delta)
	_spin_wheels(delta)
	_animate(delta)
	_type_step(delta)
	_update_hover()
	if busy or paused:
		return
	var dir := 0.0
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(_key("left")):
		dir -= 1.0
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(_key("right")):
		dir += 1.0
	if dir != 0.0:
		target_x = -1.0
		pending_action = Callable()
		player.position.x = clampf(player.position.x + dir * SPEED * delta, walk_min, walk_max)
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
	var mpos := get_global_mouse_position()
	var o := _object_at(mpos)
	var txt := ""
	if not o.is_empty():
		txt = _hover_text(o)
	elif maya and maya.visible and not _player_moving() and _maya_rect().has_point(mpos):
		txt = "Konuş: Maya (ipucu)"
	if txt == "":
		hover_label.visible = false
		return
	hover_label.text = txt
	hover_label.position = get_viewport().get_mouse_position() + Vector2(12, -18)
	hover_label.visible = true


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null:
		if not key.pressed or key.echo:
			return
		if in_cutscene:
			if key.keycode == KEY_ESCAPE:
				_end_cutscene()
			elif key.keycode in [KEY_SPACE, KEY_ENTER] or _is_interact(key):
				_cut_advance()
			return
		if key.keycode == KEY_ESCAPE:
			if settings_panel.visible:
				_close_settings()
			elif controls_panel and controls_panel.visible:
				_close_controls()
			elif case_panel and case_panel.visible:
				_close_case_select()
			elif inspect_panel.visible:
				_close_inspect()
			elif notebook_panel.visible:
				_close_notebook()
			elif dialog_panel.visible:
				_esc_dialog()
			elif paused:
				close_pause()
			elif not in_menu:
				open_pause()
			return
		if key.keycode == _key("fullscreen"):
			settings["fullscreen"] = not bool(settings["fullscreen"])
			_apply_settings()
			_save_settings()
			return
		if paused or settings_panel.visible or (controls_panel and controls_panel.visible):
			return
		if inspect_panel.visible:
			if key.keycode == _key("interact"):
				_flip_inspect()
			elif key.keycode == KEY_SPACE or key.keycode == KEY_ENTER or key.keycode == _key("interact2"):
				_close_inspect()
			return
		if in_menu:
			if case_panel and case_panel.visible:
				if key.keycode in [KEY_LEFT, _key("left")]:
					_case_step(-1)
				elif key.keycode in [KEY_RIGHT, _key("right")]:
					_case_step(1)
				elif key.keycode == KEY_ENTER or key.keycode == KEY_SPACE:
					_case_start()
			elif key.keycode == KEY_ENTER or key.keycode == KEY_SPACE:
				_open_case_select()
			return
		if key.keycode == _key("notebook"):
			if notebook_panel.visible:
				_close_notebook()
			else:
				open_notebook("")
			return
		if in_car and not dialog_panel.visible and _is_interact(key):
			_exit_car()
			return
		if _no_player() and not busy and _is_interact(key):
			_leave_interior()
			return
		if busy:
			if dialog_panel.visible and dialog_choices.get_child_count() == 0 and (key.keycode == KEY_SPACE or key.keycode == KEY_ENTER or _is_interact(key)):
				_advance()
			return
		if _is_interact(key):
			_interact_nearest()
		elif key.keycode == _key("eye"):
			toggle_eye()
		return
	var mb := event as InputEventMouseButton
	if in_car and mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and not dialog_panel.visible:
		_exit_car()
		return
	if busy:
		return
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		var pos := get_global_mouse_position()
		if maya and maya.visible and not _player_moving() and _maya_rect().has_point(pos):
			if eye_on:
				_eye_warning()
				return
			walk_to(maya_x + (24.0 if player.position.x > maya_x else -24.0), _talk_to_maya)
			return
		var o := _object_at(pos)
		if _no_player():
			if not o.is_empty():
				_interact(o)
			return
		if not o.is_empty():
			walk_to(_approach_x(o), _interact.bind(o))
		else:
			walk_to(pos.x, Callable())


## Kapı yazıları sürekli ekranda durmaz: sadece Oscar'ın yakınındaki ya da farenin üstündeki tek kapınınki belirir.
func _update_door_labels(delta: float) -> void:
	if door_labels.is_empty():
		return
	var hovered: Dictionary = _object_at(get_global_mouse_position()) if not busy else {}
	var best: Dictionary = {}
	var best_d := 46.0
	for e in door_labels:
		var d := absf(float(e["x"]) - player.position.x)
		if (e["data"] as Dictionary) == hovered:
			d = -1.0
		if d < best_d and (e["label"] as Label).get_parent().visible:
			best_d = d
			best = e
	for e in door_labels:
		var lb: Label = e["label"]
		var want := 1.0 if e == best and not busy else 0.0
		lb.modulate.a = move_toward(lb.modulate.a, want, delta * 5.0)
		lb.visible = lb.modulate.a > 0.01


## Oscar'ın yürüme / durma kareleri ve şüphelilerin nefes alma kareleri.
func _animate(delta: float) -> void:
	anim_clock += delta
	for a in npc_anims:
		var frames: Array = a["frames"]
		var ft := IDLE_FRAME_TIME if frames.size() <= 2 else 0.22
		if bool(a["moving"]) and not (a["walk"] as Array).is_empty():
			frames = a["walk"]
			ft = 0.1
		var i := int((anim_clock + float(a["phase"])) / ft) % frames.size()
		var od: Dictionary = a["data"]
		var pause := float(od.get("idle_pause", 0.0))
		if pause > 0.0 and not bool(a["moving"]):
			var play_t := frames.size() * ft
			var t := fmod(anim_clock + float(a["phase"]) * 3.0, play_t + pause)
			i = mini(int(t / ft), frames.size() - 1) if t < play_t else 0
		(a["node"] as TextureRect).texture = frames[i]
	if not player_sprite:
		return
	# Kişiler her zaman Oscar'a doğru bakar (çizimler sağa bakıyor varsayılır, "faces":"left" ile ters).
	for e in room_objects:
		var o: Dictionary = e["data"]
		if str(o["type"]) != "npc" or not (e["node"] is TextureRect):
			continue
		var dx := player.position.x - float(o["x"])
		if absf(dx) > 3.0:
			var faces_right := str(o.get("faces", "right")) == "right"
			(e["node"] as TextureRect).flip_h = (dx < 0.0) == faces_right
	if player_pose != null:
		player_sprite.texture = player_pose
		return
	var moving := not busy and (target_x >= 0.0 or Input.is_action_pressed("ui_left") or Input.is_action_pressed("ui_right") or Input.is_key_pressed(_key("left")) or Input.is_key_pressed(_key("right")))
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
	target_x = clampf(x, walk_min, walk_max)
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
			if d > 2.0 and best_d < INTERACT_RANGE:
				continue
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
			if float(o.get("y", 0)) <= 6.0 and _art("oscar_crouch"):
				_crouch_then(func(): give_clue(str(o["id"]), Callable()))
			else:
				give_clue(str(o["id"]), Callable())
		"door":
			var lock := str(o.get("lock_flag", o.get("requires_flag", "")))
			if lock != "" and not flags.has(lock):
				play_lines([["Oscar", str(o.get("locked_text", "Kilitli."))]], Callable())
			else:
				go_room(str(o["to"]), float(o["spawn_x"]))
		"npc":
			if eye_on:
				_eye_warning()
				return
			_face_each_other(o)
			start_dialogue(str(o["dialogue"]))
		"look":
			looked[_look_key(o)] = true
			if o.has("enter") and flags.has(str(o.get("set_flag", ""))) and _art("rooms/" + str(o["enter"])):
				_enter_interior(str(o["enter"]), str(o.get("enter_sfx", "car_door")))
				return
			if o.has("set_flag") and not flags.has(o["set_flag"]):
				flags[o["set_flag"]] = true
				if o.has("sfx"):
					_sfx(str(o["sfx"]))
				_refresh_visibility()
				play_lines(_fill_lines(o.get("lines", [])), func():
					_refresh_visibility()
					if o.has("enter") and _art("rooms/" + str(o["enter"])):
						_close_dialog()
						_enter_interior(str(o["enter"]), str(o.get("enter_sfx", "car_door"))))
			else:
				play_lines(_fill_lines(o.get("lines_after", o.get("lines", []))), _refresh_visibility)
		"car":
			if room_id == "sokak":
				_board_car()
			else:
				play_lines([["Oscar", "Daha yeni geldik. Önce yakut."]], Callable())


## Metindeki {debt} yerine güncel borç yazılır.
func _fill_lines(lines: Array) -> Array:
	var out: Array = []
	for l in lines:
		var row: Array = (l as Array).duplicate()
		row[1] = str(row[1]).replace("{debt}", str(debt))
		out.append(row)
	return out


## Arabanın içine/bagajına geçiş: Oscar kapıyı açıp eğilerek girer, ekran kararır, iç görünüm açılır.
func _enter_interior(room: String, sound: String = "car_door") -> void:
	busy = true
	_sfx(sound)
	var tw := create_tween()
	tw.tween_property(player, "modulate:a", 0.0, 0.35)
	if maya:
		tw.parallel().tween_property(maya, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func():
		player.modulate.a = 1.0
		if maya:
			maya.modulate.a = 1.0
		go_room(room, 0.0))


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
	var lines: Array = [["", "Yeni kanıt: " + str(c["name"]) + ("" if c.has("inspect") else "\n" + str(c["desc"]))]]
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
	if room_id in ["oscar_ofis", "koridor", "fcd", "sokak"]:
		return "Maya: Araba binanın önünde. Asansörle in, çıkıştan dışarı."
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
		return "Maya: Yeterince kanıtın var. Kim olduğunu düşünüyorsan onunla konuş ve FCD'ye çağır."
	if not pending_lab.is_empty():
		return "Maya: Laboratuvar sonucu bekleniyor. Başka bir mekana geç, sonuç gelir."
	for d in data["deductions"]:
		if req.has(d["id"]) and not deductions.has(d["id"]):
			return "Maya: " + str(d.get("where", "Bir şey eksik. Mekanları tekrar ara."))
	return "Maya: Bilmiyorum, Penn. Sen danışmansın."


func _update_hud() -> void:
	accuse_hud.visible = false


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
		right_key = _npc_art(current_npc)
	if key != "" and key != "oscar" and key != right_key:
		right_key = key   # konuşan sağda değilse (ör. Maya araya girdi) sağa o gelir
	var left_on := key == "oscar" or right_key != ""
	_show_big_portrait("left", "oscar" if left_on else "", key == "oscar")
	_show_big_portrait("right", right_key, key != "" and key == right_key)


func _type_step(delta: float) -> void:
	if not typing:
		return
	type_acc += delta * TYPE_SPEED * float(TEXT_SPEEDS[clampi(int(settings["text_speed"]), 0, 3)])
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


## Diyalogda Esc: "Ayrıl" seçeneği varsa ona basar; yoksa hiçbir şey yapmaz (oyun duraklamaz).
func _esc_dialog() -> void:
	for c in dialog_choices.get_children():
		var b := c as Button
		if b != null and b.text.begins_with("Ayrıl"):
			b.pressed.emit()
			return


func _clear_choices() -> void:
	for c in dialog_choices.get_children():
		dialog_choices.remove_child(c)
		c.queue_free()


func _add_choice(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 9)
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(0.17, 0.12, 0.08, 0.85)
	cs.content_margin_left = 6
	cs.content_margin_top = 1
	cs.content_margin_bottom = 1
	var ch := cs.duplicate() as StyleBoxFlat
	ch.bg_color = Color(0.35, 0.25, 0.12, 0.95)
	ch.border_color = C_YELLOW
	ch.border_width_left = 2
	b.add_theme_stylebox_override("normal", cs)
	b.add_theme_stylebox_override("focus", cs)
	b.add_theme_stylebox_override("hover", ch)
	b.add_theme_stylebox_override("pressed", ch)
	b.add_theme_color_override("font_hover_color", C_YELLOW)
	b.pressed.connect(func():
		_sfx("click")
		cb.call())
	dialog_choices.add_child(b)
	return b


func _ask_topic(t: Dictionary, akey: String) -> void:
	flags[akey] = true
	_run_result(t)


func _layout_dialog() -> void:
	dialog_panel.reset_size()
	dialog_panel.position.y = VIEW_H - BAR_H - 4.0 - dialog_panel.get_combined_minimum_size().y
	for side in big_portraits:
		var root: Control = big_portraits[side]["root"]
		root.position.y = dialog_panel.position.y - BIG_PORTRAIT_ROWS * BIG_PORTRAIT_SCALE + 1.0
		if not root.visible or root.position.x == 0.0:
			continue
		root.position.x = _portrait_home_x(str(side), root.size.x)


func _close_dialog() -> void:
	dialog_panel.visible = false
	_hide_big_portraits()
	typing = false
	_clear_choices()
	busy = false
	current_npc = ""
	_refresh_npc_marks()


func start_dialogue(did: String) -> void:
	current_npc = did
	var d: Dictionary = data["dialogues"][did]
	var key := "seen_" + did
	var lines: Array = []
	if not flags.has(key):
		flags[key] = true
		lines = d.get("intro", [])
		if d.has("intro_flag"):
			flags[d["intro_flag"]] = true
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
		var akey := "asked:" + current_npc + ":" + str(t["q"])
		var b := _add_choice("Sor: " + str(t["q"]), _ask_topic.bind(t, akey))
		if flags.has(akey):
			b.disabled = true
			b.modulate = Color(0.55, 0.55, 0.55)
	_add_choice("Kanıt göster", func(): open_notebook("show"))
	var base := current_npc.rstrip("0123456789")
	if _final_ready() and _is_suspect(base):
		var sb := _add_choice("Bizimle FCD'ye geliyorsun. (Suçla)", _summon.bind(base))
		sb.add_theme_color_override("font_color", C_YELLOW)
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
		var q: Array = _pick_quip("wrong_quips")
		play_lines([[str(q[0]), str(q[1])]], _npc_menu)


# ================================================================ defter ve dedüksiyon

func open_notebook(mode: String) -> void:
	if in_menu:
		return
	if mode == "" and busy:
		return
	busy = true
	_sfx("book")
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
			notebook_title.text = "KANIT GÖSTER"
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
	# Gerekli sonuçların etiketleri çıkarım metnindeki parantezden: "(NASIL)" vb.
	var tags := PackedStringArray()
	for dd in data["deductions"]:
		if req.has(dd["id"]) and not deductions.has(dd["id"]):
			var tx := str(dd["text"])
			var a := tx.rfind("(")
			if a != -1 and tx.ends_with(")"):
				var tg := tx.substr(a + 1, tx.length() - a - 2)
				tags.append(tg)
	progress_label.text = "Gerekli sonuçlar: " + str(done) + "/" + str(req.size())
	if not tags.is_empty():
		progress_label.text += "\nEksik: " + ", ".join(tags)
	_update_hud()
	link_button.visible = select_mode == ""
	accuse_button.visible = false
	if select_mode == "" and _final_ready():
		progress_label.text += "\nHAZIR: Suçluyla konuş ve onu FCD'ye çağır."



## Bir kanıt polaroidi: çizim, ad, raptiye; üstüne gelince büyür ve sağda detayı gösterir.
func _add_board_card(id: String, relevant: bool) -> void:
	var b := Button.new()
	b.custom_minimum_size = Vector2(CARD_W, CARD_H)
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
	icon.position = Vector2(4, 4)
	icon.size = Vector2(CARD_W - 8, CARD_H - 18)
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
	# Kart yazısı tek satır, kartın tam ortasında; sığmazsa punto küçülür (kesilmez, kaymaz).
	var lb := Label.new()
	var txt := str(data["clues"][id].get("short", data["clues"][id]["name"]))
	lb.text = txt
	var fsz := 7
	var fnt := _ui_font()
	if fnt:
		while fsz > 5 and fnt.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x > CARD_W - 4:
			fsz -= 1
	_paper_label(lb, fsz, Color("#2b1d14"))
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lb.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(lb)
	lb.custom_minimum_size = Vector2(CARD_W - 4, 12)
	lb.position = Vector2(2, CARD_H - 14)
	lb.size = Vector2(CARD_W - 4, 12)
	var pin := ColorRect.new()
	pin.size = Vector2(5, 5)
	pin.position = Vector2(CARD_W / 2.0 - 2.0, -2)
	pin.color = Color("#b3261e")
	pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(pin)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	b.pivot_offset = Vector2(CARD_W / 2.0, CARD_H / 2.0)
	b.rotation = deg_to_rad(rng.randf_range(-2.0, 2.0))
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
		var pa := notebook_list.position + a.position + Vector2(CARD_W / 2.0, 0)
		var pb := notebook_list.position + b.position + Vector2(CARD_W / 2.0, 0)
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


func _is_suspect(id: String) -> bool:
	for sp in data["final"]["suspects"]:
		if str(sp[0]) == id:
			return true
	return false


## Kişiye FCD'ye gelmesini söyle; sorgu odasına geçilir.
func _summon(id: String) -> void:
	var fin: Dictionary = data["final"]
	var nm := str(data["dialogues"][id]["name"])
	var lines: Array = [["Oscar", nm + ", bizimle FCD'ye gelmen gerekiyor. Birkaç sorumuz var."]]
	lines.append_array(fin.get("summon", {}).get(id, [[nm, "Ne? Şimdi mi? ...Peki. Ama avukatımı arayacağım."]]))
	play_lines(lines, func():
		_close_dialog()
		summoned = id
		return_room = room_id
		return_x = player.position.x
		go_room("sorgu", 70.0))


func _accuse(id: String) -> void:
	accuse_panel.visible = false
	var fin: Dictionary = data["final"]
	if id == str(fin["culprit"]):
		play_lines(fin["lines"], func():
			_close_dialog()
			if fin.has("reveal_item"):
				open_inspect(str(fin["reveal_item"]), func(): play_lines(fin.get("reveal_lines", []), _win))
			else:
				_win())
	else:
		wrong_accuse += 1
		_sfx("wrong")
		var lines: Array = (fin["wrong"].get(id, []) as Array).duplicate()
		lines.append(_pick_quip("accuse_quips"))
		play_lines(lines, func():
			_close_dialog()
			summoned = ""
			# Yanlış suçlamanın ardından: şüphelinin kendi sahnesi, sonra arabayla müzeye dönüş.
			var cards: Array = (fin.get("wrong_after", {}).get(id, []) as Array).duplicate()
			cards.append_array(fin.get("wrong_return", []))
			busy = true
			var tw := create_tween()
			tw.tween_property(fade_rect, "color:a", 1.0, 0.5)
			tw.tween_callback(func():
				fade_rect.color.a = 0.0
				_play_cutscene(cards, func(): go_room(return_room, return_x))))


func _win() -> void:
	_sfx("solve")
	var fin: Dictionary = data["final"]
	var base: int = int(fin.get("reward", 900))
	var cut_show := wrong_shows * 25
	var cut_acc := wrong_accuse * 150
	var total_clues: int = data["clues"].size() - (1 if fin.has("reveal_item") else 0)
	var bonus := 0
	if clues.size() >= total_clues:
		bonus = 100
	var pay := maxi(150, base - cut_show - cut_acc + bonus)
	debt -= pay
	_update_debt()
	_clear_choices()
	busy = true
	dialog_panel.visible = true
	var t := "Şef Calloway'in raporu\n"
	t += "Vaka ücreti: $" + str(base) + "\n"
	t += "Yersiz kanıt gösterme (" + str(wrong_shows) + "): -$" + str(cut_show) + "\n"
	t += "Yanlış suçlama (" + str(wrong_accuse) + "): -$" + str(cut_acc) + "\n"
	t += "Tüm kanıtlar bulundu: " + ("+$100" if bonus > 0 else "hayır (" + str(clues.size()) + "/" + str(total_clues) + ")") + "\n"
	t += "Ödenen: $" + str(pay) + "    Kalan borç: $" + str(debt) + "\n\nVesper & Co. ... Bu isim Oscar'ın peşini bırakmayacak."
	_show_line("VAKA KAPANDI", t, false)
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
		eye_time = EYE_TIME
		_sfx("eye")
	else:
		show_msg("Oscar'ın Gözü bu mekanda yoruldu.")
		return
	_refresh_visibility()
	_update_eye_button()


func _update_eye_timer(delta: float) -> void:
	if eye_bar == null:
		return
	eye_bar.visible = eye_on
	if not eye_on:
		return
	if not (busy or paused):
		eye_time -= delta
	var w := 300.0 * clampf(eye_time / EYE_TIME, 0.0, 1.0)
	eye_bar.size.x = w
	eye_bar.position.x = VIEW_W / 2.0 - w / 2.0
	if eye_time <= 0.0:
		eye_on = false
		_refresh_visibility()
		_update_eye_button()


func _eye_warning() -> void:
	_sfx("wrong")
	show_msg("Oscar'ın Gözü açıkken konuşamazsın. Kapatmak için Q.")


func _update_eye_button() -> void:
	if eye_button:
		var has_icon := eye_button.icon != null
		eye_button.text = ("" if has_icon else ("Gözü kapat " if eye_on else "Göz ")) + _key_name("eye") + "  " + str(eye_uses)
		eye_button.modulate = Color(1.4, 1.3, 0.9) if eye_on else Color(1, 1, 1)
		eye_button.tooltip_text = "Oscar'ın Gözü (" + str(eye_uses) + " hak)"


## Alttaki banttaki sade HUD düğmesi: simge (art/ui/...) + küçük tuş ipucu. Simge yoksa kısa yazı.
func _hud_button(icon_key: String, fallback: String, key_hint: String) -> Button:
	var b := Button.new()
	var tex: Texture2D = _art(icon_key) if icon_key != "" else null
	b.icon = tex
	b.expand_icon = false
	b.text = (key_hint if tex else fallback + " " + key_hint)
	b.add_theme_font_size_override("font_size", 9)
	b.add_theme_color_override("font_color", C_LIGHT)
	b.add_theme_color_override("font_hover_color", C_YELLOW)
	b.add_theme_constant_override("h_separation", 2)
	b.add_theme_constant_override("icon_max_width", 16)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var flat := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, flat)
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, BAR_H - 4)
	b.size = Vector2(0, BAR_H - 4)
	return b


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
	_menu_btn(box, "Kontroller", open_controls)
	_menu_btn(box, "Ana menüye dön", func(): get_tree().reload_current_scene())
	_menu_btn(box, "Oyundan çık", func(): get_tree().quit())


func _build_settings() -> void:
	var o := _overlay("AYARLAR")
	settings_panel = o[0]
	var outer: VBoxContainer = o[1]
	var panel := outer.get_parent() as Control
	panel.custom_minimum_size = Vector2(440, 0)
	panel.position = Vector2(VIEW_W / 2.0 - 220, 62)
	# İki sütun: solda ses ve oyun, sağda görüntü ve kontroller. Ekrana sığar.
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 18)
	outer.add_child(cols)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(200, 0)
	cols.add_child(box)
	var box2 := VBoxContainer.new()
	box2.custom_minimum_size = Vector2(200, 0)
	cols.add_child(box2)
	_settings_header(box, "SES")
	_add_slider(box, "Müzik", "music")
	_add_slider(box, "Efekt sesleri", "sfx")
	_settings_header(box, "OYUN")
	var speed_btn := Button.new()
	var names := ["Yavaş", "Normal", "Hızlı", "Anında"]
	speed_btn.text = "Yazı hızı: " + str(names[int(settings["text_speed"])])
	speed_btn.pressed.connect(func():
		settings["text_speed"] = (int(settings["text_speed"]) + 1) % 4
		speed_btn.text = "Yazı hızı: " + str(names[int(settings["text_speed"])])
		_sfx("click")
		_save_settings())
	box.add_child(speed_btn)
	box = box2
	_settings_header(box, "GÖRÜNTÜ")
	var fs := CheckButton.new()
	fs.text = "Tam ekran"
	fs.button_pressed = bool(settings["fullscreen"])
	fs.add_theme_color_override("font_color", C_PALE)
	fs.add_theme_font_size_override("font_size", 10)
	fs.toggled.connect(func(on: bool):
		settings["fullscreen"] = on
		_apply_settings()
		_save_settings())
	box.add_child(fs)
	_add_slider(box, "Parlaklık", "brightness")
	var at := CheckButton.new()
	at.text = "Toz efekti"
	at.add_theme_font_size_override("font_size", 10)
	at.button_pressed = bool(settings["atmosphere"])
	at.add_theme_color_override("font_color", C_PALE)
	at.toggled.connect(func(on: bool):
		settings["atmosphere"] = on
		_apply_settings()
		_save_settings())
	box.add_child(at)
	_settings_header(box, "KONTROLLER")
	var kb := Button.new()
	kb.text = "Tuşları değiştir"
	kb.add_theme_font_size_override("font_size", 10)
	kb.pressed.connect(open_controls)
	box.add_child(kb)
	_menu_btn(outer, "Geri [Esc]", _close_settings)


func _settings_header(box: Control, text: String) -> void:
	var h := Label.new()
	h.text = text
	h.add_theme_font_size_override("font_size", 10)
	h.add_theme_color_override("font_color", C_YELLOW)
	box.add_child(h)
	var ln := ColorRect.new()
	ln.color = C_BROWN
	ln.custom_minimum_size = Vector2(0, 1)
	box.add_child(ln)


func _add_slider(box: Control, label_text: String, key: String) -> void:
	var lb := Label.new()
	box.add_child(lb)
	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.05
	sl.value = float(settings[key])
	sl.custom_minimum_size = Vector2(190, 12)
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
		for k in DEFAULT_KEYS.keys():
			keys[k] = int(cf.get_value("keys", k, DEFAULT_KEYS[k]))
	_apply_settings()
	_refresh_controls()


func _save_settings() -> void:
	var cf := ConfigFile.new()
	for k in settings.keys():
		cf.set_value("settings", k, settings[k])
	for k in keys.keys():
		cf.set_value("keys", k, keys[k])
	cf.save(SETTINGS_PATH)


func _apply_settings() -> void:
	for pair in [["Music", "music"], ["SFX", "sfx"]]:
		var idx := AudioServer.get_bus_index(pair[0])
		if idx == -1:
			continue
		var v: float = float(settings[pair[1]])
		AudioServer.set_bus_mute(idx, v <= 0.001)
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.001)))
	if atmo_dust:
		atmo_dust.visible = bool(settings["atmosphere"])
	if bright_add:
		var b: float = float(settings["brightness"])
		var up: float = maxf(0.0, b - 0.5) * 0.36
		bright_add.color = Color(up, up * 0.94, up * 0.82, 1.0)
		bright_add.visible = up > 0.001
		bright_dark.color = Color(0, 0, 0, maxf(0.0, 0.5 - b) * 1.1)
		bright_dark.visible = b < 0.499
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
	var next_key := _next_spot_key(inspect_id)
	var other_has_next := next_key != "" and not next_key.begins_with(inspect_id + ":" + inspect_side + ":")
	inspect_side_label.text = ("ÖN YÜZ" if inspect_side == "front" else "ARKA YÜZ") + ("   (çevirip arkasına bak)" if other_has_next else ("   (parlayan noktaya tıkla)" if next_key != "" else "   (her şey incelendi)"))
	for i in range(spots.size()):
		var sp: Dictionary = spots[i]
		var key := inspect_id + ":" + inspect_side + ":" + str(i)
		if key != next_key:
			continue   # sadece sıradaki nokta görünür; bulunanlar kaybolur
		var b := Button.new()
		b.text = "?"
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
	var notes := _found_notes(inspect_id)
	inspect_notes.text = notes if notes != "" else str(c["desc"])


func _on_inspect_spot(key: String) -> void:
	if found_details.has(key):
		return
	found_details[key] = true
	_sfx("pickup")
	_show_inspect_side()


## Detaylar sırayla açılır: önce ön yüz, sonra arka yüz.
func _next_spot_key(id: String) -> String:
	var ins: Dictionary = data["clues"][id].get("inspect", {})
	for side in ["front", "back"]:
		var spots: Array = ins.get(side, [])
		for i in range(spots.size()):
			var key: String = id + ":" + side + ":" + str(i)
			if not found_details.has(key):
				return key
	return ""


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
	if found.is_empty():
		return "Henüz bir şey fark etmedin. Parlayan soru işaretine tıkla."
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
		var home_x: float = _portrait_home_x(side, root.size.x)
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


# ================================================================ Maya

func _update_maya(delta: float) -> void:
	if maya == null:
		return
	var facing_right := not player_sprite.flip_h if PLAYER_ART_FACES_RIGHT else player_sprite.flip_h
	var target := player.position.x + (-22.0 if facing_right else 22.0) * char_scale
	var speed := SPEED * 1.05
	if maya_script:
		target = maya_target
		speed = SPEED * maya_speed
	target = clampf(target, walk_min, walk_max)
	var dx := target - maya_x
	maya_moving = absf(dx) > (0.5 if maya_script else 4.0)
	if maya_moving:
		maya_x += signf(dx) * minf(absf(dx), speed * delta)
		maya.flip_h = dx < 0.0
	else:
		maya.flip_h = player.position.x < maya_x
		if maya_script and maya_cb.is_valid():
			var cb := maya_cb
			maya_cb = Callable()
			cb.call()
	maya.scale = Vector2(char_scale, char_scale)
	maya.position = Vector2(maya_x - maya.size.x / 2.0, floor_y - maya.size.y)
	var frames: Array = maya_walk if maya_moving and not maya_walk.is_empty() else maya_idle
	var ft := WALK_FRAME_TIME if maya_moving else IDLE_FRAME_TIME
	maya.texture = frames[int(anim_clock / ft) % frames.size()]


func _maya_rect() -> Rect2:
	# Çizimin tamamı değil, gövdenin ortası: yürürken yanlışlıkla tıklanmasın.
	var sz := maya.size * maya.scale
	var w := sz.x * 0.45
	return Rect2(Vector2(maya_x - w / 2.0, floor_y - sz.y * 0.9), Vector2(w, sz.y * 0.9))


func _player_moving() -> bool:
	return player_walking_script or target_x >= 0.0 or Input.is_key_pressed(_key("left")) or Input.is_key_pressed(_key("right")) or Input.is_action_pressed("ui_left") or Input.is_action_pressed("ui_right")


## Maya ara ara kendiliğinden sohbet açar (data maya_chats). Her sohbet bir kez, cevabı oyuncu seçer.
func _update_maya_chat(delta: float) -> void:
	maya_chat_cool = maxf(0.0, maya_chat_cool - delta)
	if busy or paused or in_menu or eye_on or maya == null or not maya.visible or _player_moving():
		maya_chat_idle = 0.0
		return
	maya_chat_idle += delta
	if maya_chat_idle < 8.0 or maya_chat_cool > 0.0:
		return
	for c in data.get("maya_chats", []):
		var chat: Dictionary = c
		var key := "maya_chat:" + str(chat["id"])
		if flags.has(key):
			continue
		if chat.has("room") and str(chat["room"]) != room_id:
			continue
		if chat.has("requires_flag") and not flags.has(str(chat["requires_flag"])):
			continue
		if chat.has("requires_clue") and not clues.has(str(chat["requires_clue"])):
			continue
		flags[key] = true
		maya_chat_idle = 0.0
		maya_chat_cool = 45.0
		_face(maya_x - player.position.x)
		play_lines(chat["lines"], func():
			var last: Array = (chat["lines"] as Array).back()
			_show_line(str(last[0]), str(last[1]), false)
			for ch in chat.get("choices", []):
				var choice: Dictionary = ch
				_add_choice(str(choice["text"]), func():
					var reply: Array = [["Oscar", str(choice["text"])]]
					reply.append_array(choice.get("reply", []))
					play_lines(reply, Callable()))
			_layout_dialog())
		return


## İç görünüm mekanları (araba içi, bagaj): Oscar ve Maya görünmez, tıklanan şey doğrudan incelenir.
func _no_player() -> bool:
	return bool(data["rooms"].get(room_id, {}).get("no_player", false))


func _talk_to_maya() -> void:
	_face(maya_x - player.position.x)
	var t := _hint_text()
	if t.begins_with("Maya: "):
		t = t.substr(6)
	play_lines([["Oscar", "Cole, ne düşünüyorsun?"], ["Maya", t]], Callable())

# ================================================================ vaka seç

## Vaka listesi. Yeni vaka eklenince buraya bir satır: kapak art/ui/<cover>.png (320x180).
const CASES := [
	{"no": 1, "title": "BOŞ VİTRİN", "tag": "Finch-Moore Müzesi. Kızıl Göz yakutu bir gecede kayboldu.", "cover": "ui/case1_cover", "fallback": "rooms/hol", "open": true},
	{"no": 2, "title": "???", "tag": "Dosya henüz mühürlü.", "cover": "ui/case_locked", "fallback": "rooms/fcd", "open": false},
	{"no": 3, "title": "???", "tag": "Dosya henüz mühürlü.", "cover": "ui/case_locked", "fallback": "rooms/oscar_ofis", "open": false},
	{"no": 4, "title": "???", "tag": "Dosya henüz mühürlü.", "cover": "ui/case_locked", "fallback": "rooms/sokak", "open": false},
]


func _build_case_select() -> void:
	case_panel = Control.new()
	case_panel.size = Vector2(VIEW_W, VIEW_H)
	case_panel.clip_contents = true
	case_panel.visible = false
	ui_root.add_child(case_panel)
	var under := ColorRect.new()
	under.color = C_BLACK
	under.size = Vector2(VIEW_W, VIEW_H)
	case_panel.add_child(under)
	var cover := TextureRect.new()
	cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	cover.size = Vector2(VIEW_W, VIEW_H)
	cover.pivot_offset = Vector2(VIEW_W / 2.0, VIEW_H / 2.0)
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	case_panel.add_child(cover)
	var kb := cover.create_tween().set_loops()
	kb.tween_property(cover, "scale", Vector2(1.06, 1.06), 14.0).set_trans(Tween.TRANS_SINE)
	kb.tween_property(cover, "scale", Vector2.ONE, 14.0).set_trans(Tween.TRANS_SINE)
	# Üstte ve altta koyulaşan perde: yazılar okunsun.
	var g := Gradient.new()
	g.set_color(0, Color(0.03, 0.02, 0.01, 0.85))
	g.set_color(1, Color(0.03, 0.02, 0.01, 0.95))
	g.add_point(0.22, Color(0.03, 0.02, 0.01, 0.0))
	g.add_point(0.6, Color(0.03, 0.02, 0.01, 0.15))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 64
	var shade := TextureRect.new()
	shade.texture = gt
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.size = Vector2(VIEW_W, VIEW_H)
	shade.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	case_panel.add_child(shade)
	# Yağmur (ana menüdeki gibi, daha seyrek)
	var rain := CPUParticles2D.new()
	rain.amount = 120
	rain.lifetime = 0.7
	rain.preprocess = 1.0
	rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	rain.emission_rect_extents = Vector2(VIEW_W * 0.6, 2)
	rain.position = Vector2(VIEW_W / 2.0 + 40, -8)
	rain.direction = Vector2(-0.18, 1)
	rain.spread = 1.5
	rain.gravity = Vector2.ZERO
	rain.initial_velocity_min = 520.0
	rain.initial_velocity_max = 600.0
	rain.color = Color(0.8, 0.75, 0.62, 0.18)
	case_panel.add_child(rain)

	var tf := _title_font()
	var head := Label.new()
	head.text = "VAKA SEÇ"
	head.position = Vector2(0, 14)
	head.size = Vector2(VIEW_W, 26)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 24)
	if tf:
		head.add_theme_font_override("font", tf)
	head.add_theme_color_override("font_color", C_PALE)
	head.add_theme_color_override("font_outline_color", C_BLACK)
	head.add_theme_constant_override("outline_size", 6)
	case_panel.add_child(head)
	var sub := Label.new()
	sub.position = Vector2(0, 42)
	sub.size = Vector2(VIEW_W, 16)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 11)
	sub.add_theme_color_override("font_color", C_YELLOW)
	sub.add_theme_color_override("font_outline_color", C_BLACK)
	sub.add_theme_constant_override("outline_size", 4)
	case_panel.add_child(sub)
	for dir in [-1, 1]:
		var ar := Button.new()
		ar.text = "<" if dir < 0 else ">"
		ar.flat = true
		if tf:
			ar.add_theme_font_override("font", tf)
		ar.focus_mode = Control.FOCUS_NONE
		ar.add_theme_font_size_override("font_size", 22)
		ar.add_theme_color_override("font_color", C_PALE)
		ar.add_theme_color_override("font_hover_color", C_YELLOW)
		ar.add_theme_color_override("font_pressed_color", C_YELLOW)
		ar.add_theme_color_override("font_outline_color", C_BLACK)
		ar.add_theme_constant_override("outline_size", 5)
		ar.size = Vector2(40, 34)
		ar.position = Vector2(VIEW_W / 2.0 - 150 if dir < 0 else VIEW_W / 2.0 + 110, 12)
		var d: int = dir
		ar.pressed.connect(func(): _case_step(d))
		case_panel.add_child(ar)
		case_widgets["arrow%d" % dir] = ar
	# Altta fırça darbesi gibi açık şerit + koyu yazılı "Vakaya başla".
	var band := ColorRect.new()
	band.color = Color(0.95, 0.89, 0.7, 0.92)
	band.position = Vector2(VIEW_W / 2.0 - 130, VIEW_H - 88)
	band.size = Vector2(260, 30)
	band.rotation = deg_to_rad(-1.2)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	case_panel.add_child(band)
	var start := Button.new()
	start.flat = true
	start.focus_mode = Control.FOCUS_NONE
	start.position = band.position
	start.size = band.size
	start.add_theme_font_size_override("font_size", 18)
	if tf:
		start.add_theme_font_override("font", tf)
	start.add_theme_color_override("font_color", C_BLACK)
	start.add_theme_color_override("font_hover_color", C_BROWN)
	start.add_theme_color_override("font_pressed_color", C_BROWN)
	start.add_theme_color_override("font_disabled_color", Color(0.25, 0.2, 0.15))
	start.mouse_entered.connect(func(): _sfx("blip"))
	start.pressed.connect(_case_start)
	case_panel.add_child(start)
	var tag := Label.new()
	tag.position = Vector2(0, VIEW_H - 52)
	tag.size = Vector2(VIEW_W, 14)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", 10)
	tag.add_theme_color_override("font_color", C_PALE)
	case_panel.add_child(tag)
	var back := Button.new()
	back.text = "Esc   Önceki menü"
	back.flat = true
	back.focus_mode = Control.FOCUS_NONE
	back.position = Vector2(14, VIEW_H - 30)
	back.add_theme_font_size_override("font_size", 10)
	back.add_theme_color_override("font_color", C_LIGHT)
	back.add_theme_color_override("font_hover_color", C_YELLOW)
	back.pressed.connect(_close_case_select)
	case_panel.add_child(back)
	var dots := HBoxContainer.new()
	dots.add_theme_constant_override("separation", 6)
	dots.position = Vector2(VIEW_W / 2.0 - CASES.size() * 5, VIEW_H - 24)
	case_panel.add_child(dots)
	for i in CASES.size():
		var dt := ColorRect.new()
		dt.custom_minimum_size = Vector2(4, 4)
		dots.add_child(dt)
	case_widgets["cover"] = cover
	case_widgets["sub"] = sub
	case_widgets["start"] = start
	case_widgets["tag"] = tag
	case_widgets["dots"] = dots


func _open_case_select() -> void:
	if case_panel == null:
		_build_case_select()
	_sfx("click")
	case_idx = 0
	_case_refresh()
	case_panel.visible = true
	case_panel.modulate.a = 0.0
	ui_root.move_child(case_panel, ui_root.get_child_count() - 1)
	case_panel.create_tween().tween_property(case_panel, "modulate:a", 1.0, 0.35)


func _close_case_select() -> void:
	_sfx("click")
	case_panel.visible = false


func _case_step(dir: int) -> void:
	var n: int = clampi(case_idx + dir, 0, CASES.size() - 1)
	if n == case_idx:
		return
	case_idx = n
	_sfx("blip")
	var cover: TextureRect = case_widgets["cover"]
	var tw := cover.create_tween()
	tw.tween_property(cover, "modulate:a", 0.0, 0.15)
	tw.tween_callback(_case_refresh)
	tw.tween_property(cover, "modulate:a", 1.0, 0.25)


func _case_refresh() -> void:
	var c: Dictionary = CASES[case_idx]
	var is_open: bool = bool(c["open"])
	var cover: TextureRect = case_widgets["cover"]
	var tex := _art(str(c["cover"]))
	var dim := false
	if tex == null:
		tex = _art(str(c["fallback"]))
		dim = not is_open
	cover.texture = tex
	cover.self_modulate = Color(0.32, 0.27, 0.22) if dim else Color.WHITE
	var sub: Label = case_widgets["sub"]
	sub.text = "VAKA %d: %s" % [int(c["no"]), str(c["title"])]
	var start: Button = case_widgets["start"]
	start.text = "VAKAYA BAŞLA" if is_open else "?  YAKINDA"
	start.disabled = not is_open
	var tag: Label = case_widgets["tag"]
	tag.text = str(c["tag"])
	(case_widgets["arrow-1"] as Button).modulate.a = 0.25 if case_idx == 0 else 1.0
	(case_widgets["arrow1"] as Button).modulate.a = 0.25 if case_idx == CASES.size() - 1 else 1.0
	var dots: HBoxContainer = case_widgets["dots"]
	for i in dots.get_child_count():
		(dots.get_child(i) as ColorRect).color = C_YELLOW if i == case_idx else C_BROWN


func _case_start() -> void:
	var c: Dictionary = CASES[case_idx]
	if not bool(c["open"]):
		_sfx("wrong")
		return
	case_panel.create_tween().tween_property(case_panel, "modulate:a", 0.0, 0.4)
	_start_game()
	get_tree().create_timer(0.5).timeout.connect(func(): case_panel.visible = false)


## Araba içi / bagaj: E ile dışarı çık (odanın "exit": [oda, x] alanı).
func _leave_interior() -> void:
	var ex: Array = data["rooms"][room_id].get("exit", ["otopark", 200])
	_sfx(str(data["rooms"][room_id].get("exit_sfx", "car_door")))
	go_room(str(ex[0]), float(ex[1]))


## Büyük konuşma portreleri diyalog kutusunun iki üst köşesine oturur.
func _portrait_home_x(side: String, w: float) -> float:
	var left := dialog_panel.position.x + 8.0
	var right := dialog_panel.position.x + dialog_panel.size.x - 8.0 - w
	return left if side == "left" else right


var _head_cache: Dictionary = {}

## Çizimde kafanın yatay ortası (üstteki dolu piksellere göre); ünlem tam başın üstüne gelsin.
func _head_center_x(tex: Texture2D) -> float:
	var key := tex.resource_path
	if _head_cache.has(key):
		return float(_head_cache[key])
	var img := tex.get_image()
	var cx := tex.get_width() / 2.0
	if img:
		var top := -1
		for y in img.get_height():
			for x in img.get_width():
				if img.get_pixel(x, y).a > 0.5:
					top = y
					break
			if top != -1:
				break
		if top != -1:
			var xs: Array = []
			for y in range(top, mini(top + 8, img.get_height())):
				for x in img.get_width():
					if img.get_pixel(x, y).a > 0.5:
						xs.append(x)
			if not xs.is_empty():
				cx = (float(xs.min()) + float(xs.max()) + 1.0) / 2.0
	_head_cache[key] = cx
	return cx


# ================================================================ kontroller (tuş atama)

func _key(action: String) -> int:
	return int(keys.get(action, DEFAULT_KEYS.get(action, 0)))


func _key_name(action: String) -> String:
	return OS.get_keycode_string(_key(action))


func _is_interact(key: InputEventKey) -> bool:
	return key.keycode == _key("interact") or key.keycode == _key("interact2")


func _build_controls() -> void:
	var o := _overlay("KONTROLLER")
	controls_panel = o[0]
	var outer: VBoxContainer = o[1]
	var panel := outer.get_parent() as Control
	panel.custom_minimum_size = Vector2(340, 0)
	panel.position = Vector2(VIEW_W / 2.0 - 170, 40)
	var mouse := Label.new()
	mouse.text = "Sol tık: yürü, incele, konuş     Esc: menü / geri"
	mouse.add_theme_font_size_override("font_size", 9)
	mouse.add_theme_color_override("font_color", C_LIGHT)
	outer.add_child(mouse)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 3)
	outer.add_child(grid)
	for pair in KEY_NAMES:
		var action: String = pair[0]
		var lb := Label.new()
		lb.text = str(pair[1])
		lb.custom_minimum_size = Vector2(180, 0)
		lb.add_theme_font_size_override("font_size", 10)
		lb.add_theme_color_override("font_color", C_PALE)
		grid.add_child(lb)
		var b := Button.new()
		b.custom_minimum_size = Vector2(110, 16)
		b.add_theme_font_size_override("font_size", 10)
		b.pressed.connect(func():
			_sfx("click")
			rebinding = action
			_refresh_controls())
		grid.add_child(b)
		rebind_buttons[action] = b
	var hint := Label.new()
	hint.text = "Değiştirmek için tuşa tıkla, sonra yeni tuşa bas."
	hint.add_theme_font_size_override("font_size", 8)
	hint.add_theme_color_override("font_color", C_LIGHT)
	outer.add_child(hint)
	_menu_btn(outer, "Varsayılana dön", func():
		keys = DEFAULT_KEYS.duplicate()
		rebinding = ""
		_save_settings()
		_refresh_controls())
	_menu_btn(outer, "Geri [Esc]", _close_controls)


func _refresh_controls() -> void:
	for action in rebind_buttons:
		var b: Button = rebind_buttons[action]
		b.text = "... bir tuşa bas" if rebinding == action else _key_name(str(action))
	if notebook_button:
		notebook_button.text = _key_name("notebook") if notebook_button.icon else "Defter " + _key_name("notebook")
	_update_eye_button()


func open_controls() -> void:
	if controls_panel == null:
		_build_controls()
	_sfx("click")
	rebinding = ""
	_refresh_controls()
	controls_panel.visible = true
	ui_root.move_child(controls_panel, ui_root.get_child_count() - 1)


func _close_controls() -> void:
	rebinding = ""
	controls_panel.visible = false
	_save_settings()


## Tuş atama beklerken basılan ilk tuşu yakalar (Esc iptal eder). Aynı tuş başka eylemdeyse yer değiştirir.
func _input(event: InputEvent) -> void:
	if rebinding == "":
		return
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	get_viewport().set_input_as_handled()
	if k.keycode != KEY_ESCAPE:
		var old := _key(rebinding)
		for a in keys.keys():
			if a != rebinding and int(keys[a]) == k.keycode:
				keys[a] = old
		keys[rebinding] = k.keycode
		_sfx("click")
		_save_settings()
	rebinding = ""
	_refresh_controls()


var office_chair: TextureRect

## Oscar kalkınca sandalye yerinde kalır (art/oscar_chair.png, oscar_sit ile aynı tuval ve konum).
func _spawn_office_chair() -> void:
	office_chair = null
	var t := _art("oscar_chair")
	if t == null:
		return
	var rr: Dictionary = data["rooms"]["oscar_ofis"]
	office_chair = TextureRect.new()
	office_chair.texture = t
	office_chair.size = t.get_size()
	office_chair.position = Vector2(float(rr.get("sit_x", 140.0)) - t.get_width() / 2.0, floor_y - t.get_height() + float(rr.get("sit_dy", 0.0)))
	office_chair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	office_chair.visible = flags.has("ofis_done")
	room_layer.add_child(office_chair)
