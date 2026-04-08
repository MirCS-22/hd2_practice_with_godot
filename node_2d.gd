extends Node2D

enum GameMode { TIME_ATTACK, BLITZ_MODE }
var Special_Mode = false

var current_mode = GameMode.BLITZ_MODE # 默认模式
var target_batches = 10  # 模式1：目标组数
var time_limit = 20.0    # 模式2：时间限制（秒）
const NORMAL_TIME = 0.25

var completed_batches = 0 # 已完成组数计数
var is_game_over = false

var selected_icons = [] # 存储当前激活的图标 ID 或 索引
var icon_buttons = []   # 引用所有的按钮节点以便批量操作

# 导出变量，方便在编辑器里拖拽节点
@onready var arrow_container = $ArrowContainer
@onready var score_label = $CanvasLayer/ScoreLabel
@onready var timer_label = $CanvasLayer/TimerLabel
@onready var mode_label = $CanvasLayer/ModeLabel
@onready var batch_icon = $BatchIcon
@onready var start_menu = $CanvasLayer/StartMenu
@onready var game_bg = $Gamebg
@onready var time_attack_btn = $CanvasLayer/TimeAttackButton
@onready var blitz_btn = $CanvasLayer/BlitzeButton
@onready var special_btn = $CanvasLayer/SpecialButton
@onready var result_label = $CanvasLayer/ResultContainer/ResultLabel
@onready var select_all_btn = $CanvasLayer/SelectAllButton
@onready var deselect_all_btn = $CanvasLayer/DeselectAllButton

@onready var selection_panel = $CanvasLayer/ScrollContainer
@onready var grid_container = $CanvasLayer/ScrollContainer/GridContainer
@onready var gray_shader = preload("res://grayscale.gdshader")

@onready var detail_panel = $CanvasLayer/DetailPanel
@onready var detail_label = $CanvasLayer/DetailPanel/DetailLabel

@onready var check_button = $CanvasLayer/CheckButton
var is_hd2_mode: bool = false

@onready var hover_timer = $HoverTimer
var pending_comment = ""

@onready var squid_button = $CanvasLayer/SquidButton
var is_shaking: bool = false
var special_keep: bool = false
@onready var refresh_timer = $Timer
var shake_timer = 0.0
const SHAKE_INTERVAL = 0.05 # 每0.2秒移动一次
const MAX_MOVE_PERCENT = 0.05 # 20%

@onready var squid_icon = $CanvasLayer/ResultContainer/SquidIcon

@onready var diff_timer = $DiffTimer

@onready var mute_button = $CanvasLayer/MuteButton
var is_mute = false

# 加载图片资源（请确认路径与你文件夹一致）
var arrow_images = {
	"move_up": preload("res://sprites/Stratagem_Arrow_Up.svg"),
	"move_down": preload("res://sprites/Stratagem_Arrow_Down.svg"),
	"move_left": preload("res://sprites/Stratagem_Arrow_Left.svg"),
	"move_right": preload("res://sprites/Stratagem_Arrow_Right.svg"),
}

# 预加载音效资源
var press_sounds = [
	preload("res://audio/press_1.wav"),
	preload("res://audio/press_2.wav"),
	preload("res://audio/press_3.wav"),
	preload("res://audio/press_4.wav"),
	preload("res://audio/press_5.wav"),
	preload("res://audio/press_6.wav"),
	preload("res://audio/press_7.wav")
]

var round_sounds = [
	preload("res://audio/once_fin_1.wav"),
	preload("res://audio/once_fin_2.wav"),
	preload("res://audio/once_fin_3.wav"),
	preload("res://audio/once_fin_4.wav")
]

var finish_sound = [
	preload("res://audio/full_suc_fixed_01.mp3"),
	preload("res://audio/full_suc_fixed_02.mp3"),
	preload("res://audio/full_suc_fixed_03.mp3")
]

var all_batches = [] # 存储从JSON读取的所有批次
var current_batch = [] # 当前显示的按键序列
var current_index = 0 # 玩家当前按到了第几个键
var score = 0
var time_elapsed = 0.0
var arrow_combo = 0
var first_press_en = false
var first_press = false

func _ready():
	is_game_over = true 
	var custom_font = load("res://fonts/SmileySans-Oblique.ttf")
	start_menu.show()
	squid_icon.hide()
	game_bg.hide()
	detail_panel.hide()
	load_json_data()
	select_all_btn.text = "全选"
	select_all_btn.add_theme_font_size_override("font_size", 20)
	select_all_btn.add_theme_font_override("font", custom_font)
	select_all_btn.pressed.connect(set_all_icons.bind(true))
	deselect_all_btn.text = "全不选"
	deselect_all_btn.add_theme_font_size_override("font_size", 20)
	deselect_all_btn.add_theme_font_override("font", custom_font)
	deselect_all_btn.pressed.connect(set_all_icons.bind(false))
	check_button.show()
	check_button.toggled.connect(_on_mode_switch_toggled)
	is_hd2_mode = check_button.button_pressed
	check_button.text = "潜兵模式（无需空格）"
	check_button.add_theme_font_size_override("font_size", 20)
	check_button.add_theme_font_override("font", custom_font)
	squid_button.show()
	squid_button.toggled.connect(_on_shake_switch_toggled)
	is_shaking = squid_button.button_pressed
	squid_button.text = "干扰模式（顶塔硬搓）"
	squid_button.add_theme_font_size_override("font_size", 20)
	squid_button.add_theme_font_override("font", custom_font)
	mute_button.show()
	mute_button.toggled.connect(_on_mute_switch_toggled)
	is_mute = mute_button.button_pressed
	mute_button.text = "静音"
	mute_button.add_theme_font_size_override("font_size", 20)
	mute_button.add_theme_font_override("font", custom_font)
	setup_icon_selection_ui()
	
	# 连接按钮信号（也可以在编辑器里手动连接）
	time_attack_btn.text = "固定组数：%d" % target_batches
	blitz_btn.text = "固定时间：%d s" % time_limit
	special_btn.text = "Hell+ %d" % target_batches
	result_label.text = "潜兵搓球练习，WASD/↑↓←→控制，左侧自选战备组"
	time_attack_btn.add_theme_font_size_override("font_size", 30)
	blitz_btn.add_theme_font_size_override("font_size", 30)
	special_btn.add_theme_font_size_override("font_size", 30)
	detail_label.add_theme_font_size_override("font_size", 25)
	time_attack_btn.pressed.connect(start_game.bind(GameMode.TIME_ATTACK, false))
	blitz_btn.pressed.connect(start_game.bind(GameMode.BLITZ_MODE, false))
	special_btn.pressed.connect(start_game.bind(GameMode.TIME_ATTACK, true))
	
	score_label.add_theme_font_override("font", custom_font)
	timer_label.add_theme_font_override("font", custom_font)
	mode_label.add_theme_font_override("font", custom_font)
	result_label.add_theme_font_override("font", custom_font)
	time_attack_btn.add_theme_font_override("font", custom_font)
	blitz_btn.add_theme_font_override("font", custom_font)
	special_btn.add_theme_font_override("font", custom_font)
	detail_label.add_theme_font_override("font", custom_font)
	
	hover_timer.timeout.connect(_on_hover_timer_timeout)
	
	refresh_timer.timeout.connect(_on_refresh_timeout)
	
	var window_size = get_viewport_rect().size
	
	game_bg.position = (window_size / 2) - (start_menu.size / 2)
	game_bg.size = window_size
	
	# 监听窗口尺寸变化的信号
	get_tree().root.size_changed.connect(_on_window_resized)
	# 初始化时执行一次对齐
	_on_window_resized()

func _process(delta):
	if detail_panel.visible:
		detail_panel.global_position = get_global_mouse_position() + Vector2(15, -30)
		
	if is_game_over:
		return
	
	shake_timer += delta
	if is_shaking and shake_timer >= SHAKE_INTERVAL:
		shake_timer = 0.0
		_apply_arrow_shake()

	if current_mode == GameMode.TIME_ATTACK:
		if first_press:
		# 模式1：正计时，目标是达成指定组数
			time_elapsed += delta
		timer_label.text = "用时: %.2f" % time_elapsed
		if completed_batches >= target_batches:
			end_game()
			
	elif current_mode == GameMode.BLITZ_MODE:
		if first_press:
		# 模式2：倒计时，目标是规定时间内完成更多
			time_limit -= delta
		timer_label.text = "剩余时间: %.2f" % max(0, time_limit)
		if time_limit <= 0:
			end_game()

func _on_refresh_timeout():
	refresh_timer.stop()
	# 如果玩家当前进度为 0（即一个正确箭头都没按），则刷新
	if is_shaking and current_index == 0:
		next_round(false)
		refresh_timer.start(1.5)
		
func _apply_arrow_shake():
	# 遍历 HBoxContainer 的子节点（即那些 Wrapper）
	for wrapper in arrow_container.get_children():
		# 获取 Wrapper 内部的 TextureRect
		var arrow = wrapper.get_child(0) 
		if arrow is TextureRect:
			var max_offset = 64 * MAX_MOVE_PERCENT # 12.8 像素
			
			# 产生随机偏移
			var random_offset = Vector2(
				randf_range(-max_offset, max_offset),
				randf_range(-max_offset, max_offset)
			)
			
			# 移动内部箭头，此时不会影响 Wrapper 在 HBoxContainer 中的排队位置
			arrow.position = random_offset

func generate_random_batch(get_mode: bool):
	current_batch.clear()
	var random_length
	if get_mode:
		random_length = 20
	else:
		random_length = randi_range(3, 9)
	# 假设你的 arrow_images 字典的键是方向字符串，如 ["up", "down", "left", "right"]
	var keys = arrow_images.keys() 
	for i in range(random_length):
		current_batch.append(keys.pick_random())

# 当浏览器窗口大小改变时触发
func _on_window_resized():
	var window_size = get_viewport_rect().size
	
	# 1. 让开始菜单始终保持在屏幕正中央
	if start_menu:
		# 如果你移除了 Container，手动计算中心点
		start_menu.position = (window_size / 2) - (start_menu.size / 2)
	
	if game_bg:
		game_bg.position = (window_size / 2) - (start_menu.size / 2)
		game_bg.size = window_size
	
	# 2. 让箭头显示区域保持在屏幕中下方
	if arrow_container:
		arrow_container.position.x = (window_size.x / 2) - (arrow_container.get_minimum_size().x / 2)
		arrow_container.position.y = window_size.y * 0.7 # 位于屏幕 70% 高度处
		
	# 3. 让大图标跟随箭头区域
	if batch_icon:
		batch_icon.position.x = (window_size.x / 2) - (batch_icon.size.x / 2)
		batch_icon.position.y = arrow_container.position.y - 2 * batch_icon.size.y - 20

	# 4. UI 文本对齐
	# 如果 ScoreLabel 放在 CanvasLayer 左上角，通常不需要手动调，
	# 但如果你想让它靠右，可以这样做：
	# score_label.position.x = window_size.x - score_label.size.x - 20

func start_game(mode, special_mode):
	current_mode = mode
	Special_Mode = special_mode
	# 初始化数据
	score = 0
	time_elapsed = 0.0
	completed_batches = 0
	is_game_over = false
	
	# UI 更新
	start_menu.hide()
	time_attack_btn.hide()
	blitz_btn.hide()
	special_btn.hide()
	result_label.hide()
	check_button.hide()
	squid_button.hide()
	squid_icon.hide()
	toggle_selection_ui(false)
	game_bg.show()
	batch_icon.modulate = Color.WHITE
	if current_mode == GameMode.TIME_ATTACK:
		mode_label.text = "固定组数：%d" % target_batches
		score_label.text = "进度: %d / %d" % [completed_batches, target_batches]
	elif current_mode == GameMode.BLITZ_MODE:
		time_limit = 20.0
		mode_label.text = "固定时间：%d s" % time_limit
		score_label.text = "得分: 0"
	
	# 启动逻辑
	first_press_en = true
	refresh_timer.start()
	next_round(true)

func setup_icon_selection_ui():
	# 清空现有节点
	#for child in grid_container.get_children():
		#child.queue_free()
	#icon_buttons.clear()
	
	# 遍历 JSON 中的所有图标（假设 all_batches 存储了它们）
	for i in range(all_batches.size()):
		var btn = TextureButton.new()
		var icon_path = all_batches[i]["icon"] # 根据你 JSON 结构修改
		btn.texture_normal = load(icon_path)
		if i == all_batches.size() - 1:
			btn.texture_normal = load("res://sprites/Super_Credit.svg")
		btn.custom_minimum_size = Vector2(64, 64) 
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		if all_batches[i].has("comment") and all_batches[i]["comment"] != "":
			btn.mouse_entered.connect(_on_btn_mouse_entered.bind(all_batches[i]["comment"]))
			btn.mouse_exited.connect(_on_btn_mouse_exited)
		
		# 绑定 Shader 材质
		var mat = ShaderMaterial.new()
		mat.shader = gray_shader
		btn.material = mat
		
		# 默认状态：点亮
		btn.material.set_shader_parameter("is_active", true)
		selected_icons.append(i)
		
		# 绑定点击事件 (使用 bind 传递索引)
		btn.pressed.connect(_on_icon_clicked.bind(i, btn))
		
		grid_container.add_child(btn)
		icon_buttons.append(btn)

func _on_mode_switch_toggled(toggled_on: bool):
	is_hd2_mode = toggled_on

func _on_shake_switch_toggled(toggled_on: bool):
	is_shaking = toggled_on
	
func _on_mute_switch_toggled(toggled_on: bool):
	is_mute = toggled_on
	var master_bus_index = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(master_bus_index, toggled_on)

func _on_btn_mouse_entered(comment_text):
	pending_comment = comment_text
	hover_timer.start()

func _on_btn_mouse_exited():
	hover_timer.stop()
	pending_comment = ""
	detail_panel.hide()
	
func _on_hover_timer_timeout():
	if pending_comment != "":
		_show_detail(pending_comment)

func _show_detail(text):
	detail_label.text = text
	detail_panel.show()
	detail_panel.reset_size()
	# 将面板定位到鼠标右下角 (加一点偏移量 15, 15)
	detail_panel.global_position = get_global_mouse_position() + Vector2(15, -30)

func toggle_selection_ui(is_show: bool):
	selection_panel.visible = is_show
	select_all_btn.visible = is_show
	deselect_all_btn.visible = is_show
	
	# 如果关闭时没有选择任何图标，自动全选（防止游戏崩溃）
	if !is_show and selected_icons.is_empty():
		print("未选择图标，已自动全选")
		set_all_icons(true)

func _on_icon_clicked(index, btn):
	if index in selected_icons:
		selected_icons.erase(index)
		btn.material.set_shader_parameter("is_active", false)
	else:
		selected_icons.append(index)
		btn.material.set_shader_parameter("is_active", true)

# 全选/全不选功能
func set_all_icons(active: bool):
	selected_icons.clear()
	for i in range(icon_buttons.size()):
		if active:
			selected_icons.append(i)
		icon_buttons[i].material.set_shader_parameter("is_active", active)

func get_random_batch():
	if selected_icons.is_empty():
		print("警告：请至少选择一个图标！")
		return null
	var random_idx = selected_icons.pick_random()
	return all_batches[random_idx]

# 读取 JSON 文件
func load_json_data():
	var file = FileAccess.open("res://arrow_batches.json", FileAccess.READ)
	var json_text = file.get_as_text()
	var data = JSON.parse_string(json_text)
	all_batches = data["batches"] # 此时获取的是包含字典的数组

# 刷新下一组箭头
func next_round(change_icon: bool):
	# 1. 随机选一个字典数据
	var random_data
	if change_icon:
		special_keep = false
	if Special_Mode or special_keep:
		random_data = all_batches[-1]
	else:
		#random_data = all_batches.pick_random()
		random_data = get_random_batch()
	current_batch = random_data["sequence"] # 提取按键序列
	if len(current_batch) == 1 and current_batch[0] == "special":
		current_batch = []
		special_keep = true
		if is_shaking:
			generate_random_batch(true)
		else:
			var sum_actions = ["move_up", "move_down", "move_left", "move_right"]
			for i in range(20):
				current_batch.append(sum_actions.pick_random())
	else:
		special_keep = false
		if is_shaking:
			generate_random_batch(false)
	var icon_name = random_data["icon"]     # 提取图标文件名
	
	current_index = 0
	
	# 2. 更新上方的大图标
	if change_icon:
		var icon_path = icon_name
		batch_icon.texture = load(icon_path)
	#if FileAccess.file_exists(icon_path):
		#batch_icon.texture = load(icon_path)
	#else:
		#print("警告: 找不到图标文件 ", icon_path)

	# 3. 清空旧的箭头并生成新的（逻辑同前，保持不变）
	for child in arrow_container.get_children():
		child.queue_free()
	
	for action in current_batch:
		# 1. 创建 Wrapper (占位符)
		var wrapper = Control.new()
		# 关键：设置最小尺寸，确保 HBoxContainer 给它留出空间
		wrapper.custom_minimum_size = Vector2(64, 64) 
		# 开启裁剪（可选），防止箭头抖动出界太远
		wrapper.clip_contents = false 
		arrow_container.add_child(wrapper)
		
		# 2. 创建 TextureRect (箭头)
		var rect = TextureRect.new()
		rect.texture = arrow_images[action]
		
		# 关键：设置大小为 64x64，并开启 ignore_texture_size
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.size = Vector2(64, 64) # 强制它从 256 缩到 64
		
		# 默认让它居中于 Wrapper（如果偏移量为 0）
		rect.position = Vector2.ZERO 
		
		wrapper.add_child(rect)

func _unhandled_input(event):
	if is_game_over:
		return
	# 1. 检查玩家是否按下了方向键动作
	var actions = ["move_up", "move_down", "move_left", "move_right"]
	for action in actions:
		if event.is_action_pressed(action):
			if first_press_en:
				if not first_press:
					$Timer.start()
					first_press = true
			check_input(action)
			return # 找到匹配动作后直接返回，防止一帧触发多次

	# 2. 检查玩家是否按下空格键提交（必须在输入完全部序列后）
	if event.is_action_pressed("submit_batch") or is_hd2_mode:
		if current_index >= current_batch.size():
			complete_round()
		#else:
			#print("序列尚未完成！")

func show_menu():
	start_menu.show()
	game_bg.hide()
	# 在菜单里显示之前的成绩（可选）

# 验证输入准确性
func check_input(pressed_action):
	# 检查当前按下的键是否匹配序列中的目标
	if current_index == len(current_batch):
		return
	if pressed_action == current_batch[current_index]:
		if not is_mute:
			play_random_press_sfx()
		# 输入正确：将对应位置的图标变绿（或你喜欢的颜色）
		var current_arrow = arrow_container.get_child(current_index)
		current_arrow.modulate = Color.YELLOW
		
		current_index += 1
		arrow_combo += 1
		diff_timer.stop()
		var last_time = 1.0 - diff_timer.get_time_left()
		if current_mode == GameMode.TIME_ATTACK:
			score += 4 * (0.25 - last_time ** 2) * 20
		print("正确！进度: ", current_index)
		refresh_timer.start(1.5)
		diff_timer.start()
	else:
		# 输入错误：重置当前进度
		reset_current_round()
		arrow_combo = 0
		print("按错了！重置本轮。")

func play_random_press_sfx():
	# 1. 创建一个新的播放器节点
	var player = AudioStreamPlayer.new()
	add_child(player)
	
	# 2. 随机抽取一个音效
	player.stream = press_sounds.pick_random()
	
	# 3. 可选：微调音高让听感更丰富（0.9 - 1.1 之间随机）
	player.pitch_scale = randf_range(0.9, 1.1)
	
	# 4. 关键设置：播放完后自动删除节点，释放内存
	player.finished.connect(player.queue_free)
	
	# 5. 开始播放
	player.play()

func play_random_round_sfx():
	# 1. 创建一个新的播放器节点
	var player = AudioStreamPlayer.new()
	add_child(player)
	
	# 2. 随机抽取一个音效
	player.stream = round_sounds.pick_random()
	
	# 3. 可选：微调音高让听感更丰富（0.9 - 1.1 之间随机）
	player.pitch_scale = randf_range(0.9, 1.1)
	
	# 4. 关键设置：播放完后自动删除节点，释放内存
	player.finished.connect(player.queue_free)
	
	# 5. 开始播放
	player.play()
	
func play_finish_sfx():
	# 1. 创建一个新的播放器节点
	var player = AudioStreamPlayer.new()
	add_child(player)
	
	# 2. 随机抽取一个音效
	player.stream = finish_sound.pick_random()
	
	# 3. 可选：微调音高让听感更丰富（0.9 - 1.1 之间随机）
	player.pitch_scale = randf_range(1, 1.1)
	
	# 4. 关键设置：播放完后自动删除节点，释放内存
	player.finished.connect(player.queue_free)
	
	# 5. 开始播放
	player.play()

# 如果按错，重置当前这一轮的颜色和进度
func reset_current_round():
	current_index = 0
	for arrow in arrow_container.get_children():
		arrow.modulate = Color.WHITE
	if is_shaking:
		refresh_timer.start(0.5)

# 完成本轮并加分
func complete_round():
	if not is_mute:
		play_random_round_sfx()
	completed_batches += 1
	
	# 根据模式更新界面和检查结束条件
	if current_mode == GameMode.TIME_ATTACK:
		score += current_batch.size() * 100 + arrow_combo * 10
		score_label.text = "进度: %d / %d" % [completed_batches, target_batches]
		if completed_batches >= target_batches:
			end_game()
			return # 结束了，不再执行下面的 next_round()
			
	elif current_mode == GameMode.BLITZ_MODE:
		score += current_batch.size() * 100 + arrow_combo * 10
		score_label.text = "得分: %d (已完成: %d组)" % [score, completed_batches]
		# 倒计时模式在 _process 里检查时间，这里只需判断是否已超时
		if time_limit <= 0:
			end_game()
			return

	# 只有在游戏未结束时才刷新下一组
	refresh_timer.start()
	next_round(true)

func end_game():
	is_game_over = true
	if not is_mute:
		play_finish_sfx()
	
	# 停止计时器节点（如果有的话）
	$Timer.stop() 
	
	# 清空屏幕上的箭头，防止玩家误以为还能继续按
	for child in arrow_container.get_children():
		child.queue_free()
	
	# 改变图标颜色或显示结束文案
	batch_icon.modulate = Color(0.5, 0.5, 0.5, 0.5) # 使图标变暗透明
	
	var result_text = ""
	if current_mode == GameMode.TIME_ATTACK:
		result_text = "挑战完成！总用时: %.2f 秒，得分 %d" % [time_elapsed, score]
	else:
		result_text = "时间到！总得分: %d" % score
	
	result_label.text = result_text
	
	# 在控制台打印，或更新你的 Label
	timer_label.text = "游戏结束！"
	first_press = false
	first_press_en = false
	if is_shaking:
		squid_icon.show()
	start_menu.show() # 重新显示面板
	time_attack_btn.show()
	blitz_btn.show()
	special_btn.show()
	result_label.show()
	check_button.show()
	squid_button.show()
	toggle_selection_ui(true)
	# 隐藏两个开始按钮，直到玩家按 R 或者用鼠标点击重新开始
