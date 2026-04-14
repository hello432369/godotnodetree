@tool
extends Node
## 音效管理器 - 独立管理所有编辑器音效
## 负责音效播放、开关、随机切换、编辑器控件信号连接

# ============================================================
# 公共状态
# ============================================================
var enabled: bool = true  # 音效开关，默认启用

# ============================================================
# 内部变量
# ============================================================
var _player: AudioStreamPlayer = null
var _connections: Array[Dictionary] = []  # {node, signal, callable}
var _activated: bool = false  # 延迟激活标志，防止启动时误触发

const _SOUND_COUNT := 5
const _INIT_DELAY_SEC := 0.5

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_create_player()
	_load_random_sound()


func cleanup() -> void:
	_disconnect_all()
	if is_instance_valid(_player):
		_player.queue_free()
		_player = null
	_activated = false


# ============================================================
# 公共方法
# ============================================================

## 播放一次音效
func play() -> void:
	if not enabled or not _activated:
		return
	if not is_instance_valid(_player) or not _player.stream:
		return
	if _player.playing:
		_player.stop()
	_player.play()


## 设置音效开关
func set_enabled(v: bool) -> void:
	enabled = v
	if v and is_instance_valid(_player):
		_load_random_sound()


## 连接编辑器中所有控件的交互音效
func connect_editor_sounds(plugin: EditorPlugin) -> void:
	var base := plugin.get_editor_interface().get_base_control()
	if not base:
		return
	_connect_tree(base)

	# 单独处理 Inspector 的属性树折叠
	var inspector := plugin.get_editor_interface().get_inspector()
	if inspector:
		var prop_tree = inspector.find_child("property_editor", true, false)
		if prop_tree:
			_safe_connect(prop_tree, "item_collapsed", _play_multi_param)

	# 延迟激活，避免编辑器启动时 UI 状态恢复触发音效
	if get_tree():
		get_tree().create_timer(_INIT_DELAY_SEC, false).timeout.connect(func(): _activated = true)
	else:
		_activated = true


# ============================================================
# 内部 - 音效播放器
# ============================================================

func _create_player() -> void:
	_player = AudioStreamPlayer.new()
	_player.volume_db = -8.0
	_player.max_polyphony = 2
	add_child(_player)


func _load_random_sound() -> void:
	if not is_instance_valid(_player):
		return
	var idx := randi_range(1, _SOUND_COUNT)
	var res = load("res://addons/nodetree_v2/bt%d.mp3" % idx)
	if res:
		_player.stream = res


# ============================================================
# 内部 - 信号连接
# ============================================================

func _connect_tree(node: Node) -> void:
	if not is_instance_valid(node):
		return

	# 按钮类
	if node is BaseButton:
		_safe_connect(node, "pressed", _play_no_param)
		if node is CheckBox or node is CheckButton or node is MenuButton:
			_safe_connect(node, "toggled", _play_one_param)

	# 标签页
	elif node is TabContainer or node is TabBar:
		_safe_connect(node, "tab_selected", _play_one_param)
		_safe_connect(node, "tab_changed", _play_one_param)

	# 树控件
	elif node is Tree:
		_safe_connect(node, "item_selected", _play_no_param)
		_safe_connect(node, "item_mouse_selected", _play_multi_param)
		_safe_connect(node, "item_collapsed", _play_one_param)

	# 列表
	elif node is ItemList or node is OptionButton:
		if node.has_signal("item_selected"):
			_safe_connect(node, "item_selected", _play_one_param)

	# 数值控件
	elif node is SpinBox:
		_safe_connect(node, "value_changed", _play_spinbox)
	elif node is Range:
		_safe_connect(node, "drag_ended", _play_one_param)

	# 文本
	elif node is LineEdit or node is TextEdit:
		_safe_connect(node, "text_submitted", _play_one_param)
		_safe_connect(node, "focus_entered", _play_no_param)

	# 分割器
	elif node is SplitContainer:
		_safe_connect(node, "dragged", _play_one_param)

	# 图形编辑器
	elif node is GraphNode or node is GraphEdit:
		if node.has_signal("connection_request"):
			_safe_connect(node, "connection_request", _play_multi_param)
		if node.has_signal("node_selected"):
			_safe_connect(node, "node_selected", _play_no_param)

	# 菜单
	elif node.get_class() == "MenuBar" or node.get_class() == "PopupMenu":
		if node.has_signal("id_pressed"):
			_safe_connect(node, "id_pressed", _play_one_param)
		if node.has_signal("index_pressed"):
			_safe_connect(node, "index_pressed", _play_one_param)

	# 属性编辑器
	elif node is EditorProperty:
		_safe_connect(node, "property_changed", _play_multi_param)
		_safe_connect(node, "object_id_selected", _play_multi_param)

	# Inspector 分组折叠按钮
	elif node.get_class() == "EditorInspectorSection":
		for child in node.get_children():
			if child is BaseButton:
				_safe_connect(child, "pressed", _play_no_param)
				break

	# 递归子节点
	for child in node.get_children():
		_connect_tree(child)


func _safe_connect(node: Object, sig: StringName, cb: Callable) -> void:
	if is_instance_valid(node) and node.has_signal(sig) and not node.is_connected(sig, cb):
		var err := node.connect(sig, cb)
		if err == OK:
			_connections.append({"node": node, "signal": sig, "callable": cb})


func _disconnect_all() -> void:
	for entry in _connections:
		var node = entry["node"]
		if is_instance_valid(node) and node.is_connected(entry["signal"], entry["callable"]):
			node.disconnect(entry["signal"], entry["callable"])
	_connections.clear()


# ============================================================
# 内部 - 音效回调（不同参数签名适配不同信号）
# ============================================================

var _last_spinbox_time_ms: int = 0
const _SPINBOX_INTERVAL_MS: int = 100

func _play_no_param() -> void:
	play()

func _play_one_param(_p = null) -> void:
	play()

func _play_multi_param(_p1 = null, _p2 = null, _p3 = null, _p4 = null) -> void:
	play()

func _play_spinbox(_val = null) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_spinbox_time_ms > _SPINBOX_INTERVAL_MS:
		play()
		_last_spinbox_time_ms = now
