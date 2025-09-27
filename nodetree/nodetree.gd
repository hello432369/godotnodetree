@tool
extends EditorPlugin

var 面板 = preload("res://addons/nodetree/ui.tscn").instantiate()

# region 音效
var 音效播放器 := AudioStreamPlayer.new()
var 监听器连接 := []
var 已初始化 := false
var 初始化完成 := false
var 音效启用 := true  # 添加音效开关变量，默认启用
# endregion

func _enter_tree():
	面板.ed = self
	面板.name = "节点速览"
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, 面板)

	# region 音效
	_初始化音效播放器()
	# endregion
	
func _exit_tree():
	if is_instance_valid(面板):
		remove_control_from_docks(面板)
		if is_instance_valid(面板.ed):
			面板.ed = null

	# region 音效
	_清理连接()
	if is_instance_valid(音效播放器):
		音效播放器.queue_free()
	# endregion



# ----------------------------------------------------音效开始
# region 音效
func _enable_plugin() -> void:
	# 插件启用时，如果编辑器已打开，手动触发进入场景树
	if get_tree():
		_enter_tree()

func _disable_plugin() -> void:
	# 插件禁用时，触发离开场景树
	_exit_tree()

# endregion

# region 初始化与连接
func _初始化音效播放器():
	if 已初始化:
		return
	已初始化 = true
	
	# 重新创建播放器实例以确保干净的状态
	音效播放器 = AudioStreamPlayer.new()
	
	# 添加到编辑器场景树
	var 编辑器界面 = get_editor_interface().get_base_control()
	if 编辑器界面:
		编辑器界面.add_child(音效播放器)
	else:
		push_warning("无法获取编辑器界面，音效插件初始化失败。")
		return
	
	# 加载音效文件
	#随机生成 1 到 5
	var 随机数 = randi_range(1, 5)
	var 音效路径 = "res://addons/nodetree/bt" + str(随机数) + ".mp3"
	var 音效资源 = load(音效路径)
	if 音效资源:
		音效播放器.stream = 音效资源
		音效播放器.volume_db = -8.0
		音效播放器.autoplay = false
		音效播放器.max_polyphony = 2 # 增加复音数以允许快速点击
		
		# 等待编辑器完全加载后再连接按钮
		await get_tree().process_frame
		await get_tree().process_frame
		call_deferred("_连接编辑器按钮")
	else:
		push_warning("无法加载音效文件: %s" % 音效路径)

# 公共函数，连接编辑器和插件面板中的按钮音效
func _连接编辑器按钮():
	var 编辑器界面 = get_editor_interface().get_base_control()
	if 编辑器界面:
		_递归连接按钮(编辑器界面)

		# 单独处理检查器的属性树折叠事件
		var inspector = get_editor_interface().get_inspector()
		if inspector:
			var property_tree = inspector.find_child("property_editor", true, false)
			if property_tree:
				_安全连接(property_tree, "item_collapsed", _播放按钮音效_带参)

		# 连接插件面板中的按钮
		if is_instance_valid(面板):
			_递归连接按钮(面板)

		# 标记初始化完成，此时开始允许播放音效
		# 延迟一小段时间再激活音效，以避免编辑器启动时因UI状态恢复而自动触发
		if get_tree():
			get_tree().create_timer(0.5, false).timeout.connect(func(): 初始化完成 = true)
		else:
			初始化完成 = true # Fallback

func _递归连接按钮(节点: Node):
	if not is_instance_valid(节点):
		return

	# 根据节点类型连接不同信号
	if 节点 is BaseButton:
		_连接按钮交互(节点)
	elif 节点 is TabContainer or 节点 is TabBar:
		_连接标签页交互(节点)
	elif 节点 is Tree:
		_连接树控件交互(节点)
	elif 节点 is ItemList or 节点 is OptionButton:
		_连接列表交互(节点)
	elif 节点 is LineEdit or 节点 is TextEdit:
		_连接文本交互(节点)
	elif 节点 is SpinBox or 节点 is Slider:
		_连接数值交互(节点)
	elif 节点 is SplitContainer:
		_连接分割器交互(节点)
	elif 节点 is ScrollBar:
		_连接滚动条交互(节点)
	elif 节点 is GraphNode or 节点 is GraphEdit:
		_连接图形编辑器交互(节点)
	elif 节点.get_class() == "MenuBar" or 节点.get_class() == "PopupMenu":
		_连接菜单交互(节点)
	elif 节点.get_class() == "EditorInspectorSection":
		# 在 Godot 4 中，EditorInspectorSection 的折叠按钮可能通过其他方式获取
		# 我们尝试查找子节点中的按钮
		var fold_button = null
		for child in 节点.get_children():
			if child is BaseButton:
				fold_button = child
				break
		if is_instance_valid(fold_button):
			_安全连接(fold_button, "pressed", _播放按钮音效)
	elif 节点 is EditorProperty:
		_连接属性编辑器交互(节点)

	for 子节点 in 节点.get_children():
		_递归连接按钮(子节点)
# endregion

# region 控件交互连接
func _连接按钮交互(按钮: BaseButton):
	_安全连接(按钮, "pressed", _播放按钮音效)
	if 按钮 is CheckBox or 按钮 is CheckButton or 按钮 is MenuButton:
		_安全连接(按钮, "toggled", _播放按钮音效_带参)

func _连接标签页交互(标签: Control):
	if 标签.has_signal("tab_selected"):
		_安全连接(标签, "tab_selected", _播放按钮音效_带参)
	if 标签.has_signal("tab_changed"):
		_安全连接(标签, "tab_changed", _播放按钮音效_带参)

func _连接树控件交互(树: Tree):
	_安全连接(树, "item_selected", _播放按钮音效)
	_安全连接(树, "item_mouse_selected", _播放按钮音效_多参)
	_安全连接(树, "item_collapsed", _播放按钮音效_带参)

func _连接列表交互(列表: Control):
	if 列表.has_signal("item_selected"):
		_安全连接(列表, "item_selected", _播放按钮音效_带参)

func _连接数值交互(数值控件: Control):
	if 数值控件 is SpinBox:
		_安全连接(数值控件, "value_changed", _播放数值音效_防重复)
	elif 数值控件 is Range: # Slider, ScrollBar etc.
		# Range控件只在拖拽结束时播放一次音效
		_安全连接(数值控件, "drag_ended", _播放按钮音效_带参)

func _连接文本交互(文本控件: Control):
	_安全连接(文本控件, "text_submitted", _播放按钮音效_带参)
	_安全连接(文本控件, "focus_entered", _播放按钮音效)

func _连接分割器交互(分割器: Control):
	_安全连接(分割器, "dragged", _播放按钮音效_带参)

func _连接滚动条交互(滚动条: ScrollBar):
	# 滚动条的按钮点击由_连接按钮交互处理
	# 拖拽由_连接数值交互处理
	pass

func _连接图形编辑器交互(图形节点: Control):
	if 图形节点.has_signal("connection_request"):
		_安全连接(图形节点, "connection_request", _播放按钮音效_多参)
	if 图形节点.has_signal("node_selected"):
		_安全连接(图形节点, "node_selected", _播放按钮音效)

func _连接菜单交互(菜单: Node):
	if 菜单.has_signal("id_pressed"):
		_安全连接(菜单, "id_pressed", _播放按钮音效_带参)
	if 菜单.has_signal("index_pressed"):
		_安全连接(菜单, "index_pressed", _播放按钮音效_带参)

func _连接属性编辑器交互(属性编辑器: EditorProperty):
	# 属性值被修改
	_安全连接(属性编辑器, "property_changed", _播放按钮音效_带参)
	# 属性本身是可折叠的（例如资源）
	_安全连接(属性编辑器, "object_id_selected", _播放按钮音效_多参)

func _连接检查器分组交互(分组控件: Control):
	# 查找并连接内部的折叠按钮
	for 子控件 in 分组控件.get_children():
		if 子控件 is BaseButton and (子控件.name.to_lower().contains("fold") or 子控件.name.to_lower().contains("arrow")):
			_连接按钮交互(子控件)

func _连接折叠控件交互(折叠控件: Control):
	# 通用折叠控件交互
	if 折叠控件.has_signal("toggled"):
		_安全连接(折叠控件, "toggled", _播放按钮音效_带参)
	if 折叠控件.has_signal("folded"): # 兼容不同控件
		_安全连接(折叠控件, "folded", _播放按钮音效_带参)
# endregion

# region 音效播放逻辑
var 上次数值变化时间_ms := 0
const 数值音效间隔_ms := 100

func _播放数值音效_防重复(_值 = null):
	var 当前时间_ms = Time.get_ticks_msec()
	if 当前时间_ms - 上次数值变化时间_ms > 数值音效间隔_ms:
		_播放按钮音效()
		上次数值变化时间_ms = 当前时间_ms

func _播放按钮音效_多参(_参数1 = null, _参数2 = null, _参数3 = null, _参数4 = null):
	_播放按钮音效()

func _播放按钮音效_带参(_参数 = null):
	_播放按钮音效()

func _播放按钮音效():
	if 音效启用 and 初始化完成 and is_instance_valid(音效播放器) and 音效播放器.stream:
		# 如果正在播放，先停止再播放，以实现快速重复点击的"biu"声
		if 音效播放器.playing:
			音效播放器.stop()
		音效播放器.play()

# 公共函数，供UI脚本调用
func 播放按钮音效():
	_播放按钮音效()
# endregion

# region 连接管理
func _安全连接(节点: Object, 信号: StringName, 回调: Callable):
	if is_instance_valid(节点) and 节点.has_signal(信号) and not 节点.is_connected(信号, 回调):
		var err = 节点.connect(信号, 回调)
		if err == OK:
			监听器连接.append({"node": 节点, "signal": 信号, "callable": 回调})

func _清理连接():
	for 连接 in 监听器连接:
		var 节点 = 连接["node"]
		if is_instance_valid(节点) and 节点.is_connected(连接["signal"], 连接["callable"]):
			节点.disconnect(连接["signal"], 连接["callable"])
	监听器连接.clear()
	已初始化 = false
	初始化完成 = false

# 设置音效开关状态的公共函数
func 设置音效开关(启用: bool):
	音效启用 = 启用
	# 如果启用音效，则随机选择一个新的音效文件
	if 音效启用 and is_instance_valid(音效播放器):
		_随机切换音效()

# 随机切换音效文件
func _随机切换音效():
	if not is_instance_valid(音效播放器):
		return
	
	# 随机生成 1 到 5
	var 随机数 = randi_range(1, 5)
	var 音效路径 = "res://addons/nodetree/bt" + str(随机数) + ".mp3"
	var 音效资源 = load(音效路径)
	if 音效资源:
		音效播放器.stream = 音效资源
		print("已切换到音效文件: " + str(随机数))
	else:
		push_warning("无法加载音效文件: %s" % str(随机数))
# endregion

# ----------------------------------------------------音效结束
