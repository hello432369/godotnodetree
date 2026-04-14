@tool
extends EditorPlugin
## 插件主脚本 - 负责生命周期管理和 Dock 挂载
## 音效系统已独立到 sound_manager.gd

var _dock: Control = null
var _sound_manager: Node = null

func _enter_tree() -> void:
	# 创建音效管理器
	_sound_manager = load("res://addons/nodetree_v2/sound_manager.gd").new()
	add_child(_sound_manager)

	# 实例化面板并注入引用
	_dock = load("res://addons/nodetree_v2/ui.tscn").instantiate()
	_dock.set("editor_plugin", self)
	_dock.set("sound_manager", _sound_manager)

	add_control_to_dock(DOCK_SLOT_LEFT_UL, _dock)

	# 延迟初始化音效连接和 undo_redo（避免热重载时 Dock 冲突）
	call_deferred("_deferred_init")


func _deferred_init() -> void:
	if not is_instance_valid(_sound_manager):
		return
	if _sound_manager.has_method("connect_editor_sounds"):
		_sound_manager.connect_editor_sounds(self)
	if is_instance_valid(_dock) and _dock.has_method("on_editor_ready"):
		_dock.on_editor_ready()


func _exit_tree() -> void:
	if is_instance_valid(_dock):
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null

	if is_instance_valid(_sound_manager):
		if _sound_manager.has_method("cleanup"):
			_sound_manager.cleanup()
		_sound_manager.queue_free()
		_sound_manager = null


## 刷新面板（供 UI 调用）
func refresh_panel() -> void:
	if is_instance_valid(_dock):
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null

	_dock = load("res://addons/nodetree_v2/ui.tscn").instantiate()
	_dock.set("editor_plugin", self)
	_dock.set("sound_manager", _sound_manager)
	add_control_to_dock(DOCK_SLOT_LEFT_UL, _dock)

	call_deferred("_deferred_init")
	print("插件已刷新")
