@tool
extends Control

# region 主题资源引用 - 可以在检查器中拖拽设置
@export var button_theme: Theme

var ed: EditorPlugin = null

func _ready():
	# 应用按钮样式
	apply_button_styles()
	
	# 设置所有VBoxContainer的间距为12
	set_vboxcontainer_spacing(12)
	
	# 连接面板中的按钮音效
	if is_instance_valid(ed) and ed.has_method("_连接编辑器按钮"):
		ed._连接编辑器按钮()

func set_vboxcontainer_spacing(spacing: int) -> void:
	# 遍历所有VBoxContainer节点
	var vbox_containers = _find_all_vbox_containers(self)
	for vbox in vbox_containers:
		vbox.add_theme_constant_override("separation", spacing)

func _find_all_vbox_containers(node: Node) -> Array:
	var vbox_containers = []
	
	# 如果是VBoxContainer，添加到数组
	if node is VBoxContainer:
		vbox_containers.append(node)
	
	# 递归查找子节点
	for child in node.get_children():
		vbox_containers.append_array(_find_all_vbox_containers(child))
	
	return vbox_containers

func apply_button_styles():
	# 如果主题资源存在，应用到所有按钮
	if button_theme:
		# 遍历所有按钮节点
		var buttons = _find_all_buttons(self)
		for button in buttons:
			button.theme = button_theme
			# 添加按钮到分组，便于后续管理
			button.add_to_group("node_buttons")
			# 连接按钮的pressed信号到音效播放函数
			if not button.is_connected("pressed", _on_plugin_button_pressed):
				button.pressed.connect(_on_plugin_button_pressed)

func _on_plugin_button_pressed():
	# 播放按钮音效
	if is_instance_valid(ed) and ed.has_method("播放按钮音效"):
		ed.播放按钮音效()

func _find_all_buttons(node: Node) -> Array:
	var buttons = []
	
	# 如果是按钮，添加到数组
	if node is Button:
		buttons.append(node)
	
	# 递归查找子节点
	for child in node.get_children():
		buttons.append_array(_find_all_buttons(child))
	
	return buttons
# endregion


# region 刷新
func _on_刷新_pressed() -> void:
	if is_instance_valid(ed.面板): #如果面板存在
		ed.remove_control_from_docks(ed.面板) #从右侧移除面板
		#ed.remove_control_from_bottom_panel(ed.面板) #从底部面板移除面板
		for child in ed.面板.get_children(): #遍历面板的子节点
			ed.面板.remove_child(child) #移除子节点
			child.queue_free() #释放子节点
		ed.面板.queue_free() #释放面板
	
	# 重新创建面板
	ed.面板 = preload("res://addons/nodetree/ui.tscn").instantiate()
	ed.面板.ed = ed
	ed.面板.name = "节点速览"
	ed.add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_UL, ed.面板)
	
	# 重新连接面板中的按钮音效
	if is_instance_valid(ed) and ed.has_method("_连接编辑器按钮"):
		ed._连接编辑器按钮()
	
	print("插件已刷新")

func _on_check_button_toggled(toggled_on: bool) -> void:
	# 控制音效开关
	if is_instance_valid(ed) and ed.has_method("设置音效开关"):
		ed.设置音效开关(toggled_on)
		print("音效已", "启用" if toggled_on else "禁用")
		


#------创建模板
func _on_模板_1_pressed() -> void:
	var 场景 = PackedScene.new()
	var 根节点 = Node2D.new()
	根节点.name = "Template1Root"
	
	var 图片 = Sprite2D.new()
	图片.name = "MySprite"
	根节点.add_child(图片)
	
	# 设置owner以便正确保存场景
	for child in 根节点.get_children():
		child.owner = 根节点
	
	场景.pack(根节点)
	var 新路径 = "res://模板_1_%d.tscn" % (randi() % 10000)
	ResourceSaver.save(场景, 新路径)
	ed.get_editor_interface().open_scene_from_path(新路径)
	pass
# endregion


# region 按钮代码
var editor
var selection
var selected_nodes
var parent_node 
var undo_redo: EditorUndoRedoManager = null

func selectnode() -> void:
	editor = ed.get_editor_interface() #获取编辑器接口
	print("编辑器接口: ", editor)  # 调试输出
	selection = editor.get_selection() #获取选择器
	print("选择器: ", selection)  # 调试输出
	selected_nodes = selection.get_selected_nodes() #获取选中的节点
	print("选中的节点数量: ", selected_nodes.size())  # 调试输出
	if selected_nodes.size() == 0:
		printerr("请先选择一个父节点")
		return
	parent_node = selected_nodes[0]
	print("父节点类型: ", parent_node.get_class())  # 调试输出
	
	# 初始化UndoRedo
	if undo_redo == null:
		undo_redo = ed.get_undo_redo()

# 创建带有撤销功能的通用节点创建函数
func create_node_with_undo(node_class: String, node_name: String = "") -> void:
	selectnode()
	if parent_node == null:
		return
	
	# 如果没有提供节点名称，使用类名作为默认名称
	if node_name == "":
		node_name = node_class
	
	# 创建撤销操作
	undo_redo.create_action("创建节点: " + node_name)
	
	# 创建节点
	var new_node = ClassDB.instantiate(node_class)
	new_node.name = node_name
	
	# 特殊处理Bone2D节点
	if node_class == "Bone2D":
		# 设置默认长度和角度，避免行列式为0的错误
		new_node.set_length(20.0)
		new_node.set_bone_angle(0.0)
		new_node.set_autocalculate_length_and_angle(false)
		
		# 设置默认变换，确保变换矩阵有效
		new_node.transform = Transform2D.IDENTITY
		
		# 如果父节点是Bone2D，确保相对于父节点的位置正确
		if parent_node.get_class() == "Bone2D":
			new_node.position = Vector2(parent_node.get_length(), 0)
	
	# 添加执行方法
	undo_redo.add_do_method(parent_node, "add_child", new_node)
	undo_redo.add_do_method(new_node, "set_owner", editor.get_edited_scene_root())
	
	# 添加撤销方法
	undo_redo.add_undo_method(parent_node, "remove_child", new_node)
	
	# 提交操作
	undo_redo.commit_action(true)

# endregion


# region 通用
#窗口
func _on_window_pressed() -> void:
	create_node_with_undo("Window")
func _on_accept_dialog_pressed() -> void:
	create_node_with_undo("AcceptDialog")
func _on_confirmation_dialog_pressed() -> void:
	create_node_with_undo("ConfirmationDialog")
func _on_file_dialog_pressed() -> void:
	create_node_with_undo("FileDialog")
func _on_popup_pressed() -> void:
	create_node_with_undo("Popup")
func _on_popup_menu_pressed() -> void:
	create_node_with_undo("PopupMenu")
func _on_popup_panel_pressed() -> void:
	create_node_with_undo("PopupPanel")

func _on_sub_viewport_pressed() -> void:
	create_node_with_undo("SubViewport")


func _on_animation_player_pressed() -> void:
	create_node_with_undo("AnimationPlayer")
func _on_animation_tree_pressed() -> void:
	create_node_with_undo("AnimationTree")

func _on_resource_preloader_pressed() -> void:
	create_node_with_undo("ResourcePreloader")

func _on_audio_stream_player_pressed() -> void:
	create_node_with_undo("AudioStreamPlayer")

func _on_timer_pressed() -> void:
	create_node_with_undo("Timer")

func _on_shader_globals_override_pressed() -> void:
	create_node_with_undo("ShaderGlobalsOverride")
func _on_http_request_pressed() -> void:
	create_node_with_undo("HTTPRequest")
func _on_multiplayer_spawner_pressed() -> void:
	create_node_with_undo("MultiplayerSpawner")
func _on_multiplayer_synchronizer_pressed() -> void:
	create_node_with_undo("MultiplayerSynchronizer")

func _on_status_indicator_pressed() -> void:
	create_node_with_undo("StatusIndicator")
func _on_editor_plugin_pressed() -> void:
	create_node_with_undo("EditorPlugin")
# endregion


# region ui
#根节点
func _on_canvas_layer_pressed() -> void:
	create_node_with_undo("CanvasLayer")
func _on_control_pressed() -> void:
	create_node_with_undo("Control")

#框架
func _on_box_container_pressed() -> void:
	create_node_with_undo("BoxContainer")
func _on_h_box_container_pressed() -> void:
	create_node_with_undo("HBoxContainer")
func _on_panel_container_pressed() -> void:
	create_node_with_undo("PanelContainer")
func _on_v_box_container_pressed() -> void:
	create_node_with_undo("VBoxContainer")
func _on_tab_container_pressed() -> void:
	create_node_with_undo("TabContainer")
func _on_flow_container_pressed() -> void:
	create_node_with_undo("FlowContainer")
func _on_h_flow_container_pressed() -> void:
	create_node_with_undo("HFlowContainer")
func _on_v_flow_container_pressed() -> void:
	create_node_with_undo("VFlowContainer")
func _on_split_container_pressed() -> void:
	create_node_with_undo("SplitContainer")
func _on_h_split_container_pressed() -> void:
	create_node_with_undo("HSplitContainer")
func _on_v_split_container_pressed() -> void:
	create_node_with_undo("VSplitContainer")
func _on_grid_container_pressed() -> void:
	create_node_with_undo("GridContainer")
func _on_scroll_container_pressed() -> void:
	create_node_with_undo("ScrollContainer")
func _on_margin_container_pressed() -> void:
	create_node_with_undo("MarginContainer")
func _on_aspect_ratio_container_pressed() -> void:
	create_node_with_undo("AspectRatioContainer")
func _on_center_container_pressed() -> void:
	create_node_with_undo("CenterContainer")
func _on_sub_viewport_container_pressed() -> void:
	create_node_with_undo("SubViewportContainer")
func _on_graph_element_pressed() -> void:
	create_node_with_undo("GraphElement")
func _on_graph_frame_pressed() -> void:
	create_node_with_undo("GraphFrame")
func _on_graph_node_pressed() -> void:
	create_node_with_undo("GraphNode")
func _on_color_picker_pressed() -> void:
	create_node_with_undo("ColorPicker")
func _on_foldable_container_pressed() -> void:
	create_node_with_undo("FoldableContainer")

func _on_panel_pressed() -> void:
	create_node_with_undo("Panel")

func _on_menu_bar_pressed() -> void:
	create_node_with_undo("MenuBar")

func _on_tab_bar_pressed() -> void:
	create_node_with_undo("TabBar")


#输入
func _on_button_pressed() -> void:
	create_node_with_undo("Button")
func _on_check_box_pressed() -> void:
	create_node_with_undo("CheckBox")
func _on_check_button_pressed() -> void:
	create_node_with_undo("CheckButton")
func _on_color_picker_button_pressed() -> void:
	create_node_with_undo("ColorPickerButton")
func _on_menu_button_pressed() -> void:
	create_node_with_undo("MenuButton")
func _on_option_button_pressed() -> void:
	create_node_with_undo("OptionButton")
func _on_link_button_pressed() -> void:
	create_node_with_undo("LinkButton")
func _on_texture_button_pressed() -> void:
	create_node_with_undo("TextureButton")

func _on_progress_bar_pressed() -> void:
	create_node_with_undo("ProgressBar")
func _on_texture_progress_bar_pressed() -> void:
	create_node_with_undo("TextureProgressBar")
func _on_h_slider_pressed() -> void:
	create_node_with_undo("HSlider")
func _on_v_slider_pressed() -> void:
	create_node_with_undo("VSlider")
func _on_h_scroll_bar_pressed() -> void:
	create_node_with_undo("HScrollBar")
func _on_v_scroll_bar_pressed() -> void:
	create_node_with_undo("VScrollBar")
func _on_spin_box_pressed() -> void:
	create_node_with_undo("SpinBox")

func _on_tree_pressed() -> void:
	create_node_with_undo("Tree")

func _on_graph_edit_pressed() -> void:
	create_node_with_undo("GraphEdit")

func _on_line_edit_pressed() -> void:
	create_node_with_undo("LineEdit")
func _on_text_edit_pressed() -> void:
	create_node_with_undo("TextEdit")
func _on_code_edit_pressed() -> void:
	create_node_with_undo("CodeEdit")

func _on_item_list_pressed() -> void:
	create_node_with_undo("ItemList")
func _on_video_stream_player_pressed() -> void:
	create_node_with_undo("VideoStreamPlayer")

#输出
func _on_label_pressed() -> void:
	create_node_with_undo("Label")
func _on_rich_text_label_pressed() -> void:
	create_node_with_undo("RichTextLabel")

func _on_color_rect_pressed() -> void:
	create_node_with_undo("ColorRect")
func _on_texture_rect_pressed() -> void:
	create_node_with_undo("TextureRect")
func _on_nine_patch_rect_pressed() -> void:
	create_node_with_undo("NinePatchRect")

#辅助
func _on_h_separator_pressed() -> void:
	create_node_with_undo("HSeparator")
func _on_v_separator_pressed() -> void:
	create_node_with_undo("VSeparator")

func _on_reference_rect_pressed() -> void:
	create_node_with_undo("ReferenceRect")
# endregion


# region 2D
#根节点
func _on_node_pressed() -> void:
	create_node_with_undo("Node")
func _on_node_2d_pressed() -> void:
	create_node_with_undo("Node2D")

func _on_static_body_2d_pressed() -> void:
	create_node_with_undo("StaticBody2D")
func _on_rigid_body_2d_pressed() -> void:
	create_node_with_undo("RigidBody2D")
func _on_animatable_body_2d_pressed() -> void:
	create_node_with_undo("AnimatableBody2D")

func _on_character_body_2d_pressed() -> void:
	create_node_with_undo("CharacterBody2D")

#环境
func _on_camera_2d_pressed() -> void:
	create_node_with_undo("Camera2D")

func _on_directional_light_2d_pressed() -> void:
	create_node_with_undo("DirectionalLight2D")
func _on_point_light_2d_pressed() -> void:
	create_node_with_undo("PointLight2D")
func _on_light_occluder_2d_pressed() -> void:
	create_node_with_undo("LightOccluder2D")

func _on_tile_map_layer_pressed() -> void:
	create_node_with_undo("TileMapLayer")

func _on_parallax_background_pressed() -> void:
	create_node_with_undo("ParallaxBackground")
func _on_parallax_2d_pressed() -> void:
	create_node_with_undo("Parallax2D")
func _on_parallax_layer_pressed() -> void:
	create_node_with_undo("ParallaxLayer")

#对象
func _on_sprite_2d_pressed() -> void:
	create_node_with_undo("Sprite2D")
func _on_animated_sprite_2d_pressed() -> void:
	create_node_with_undo("AnimatedSprite2D")

func _on_polygon_2d_pressed() -> void:
	create_node_with_undo("Polygon2D")
func _on_line_2d_pressed() -> void:
	create_node_with_undo("Line2D")
func _on_mesh_instance_2d_pressed() -> void:
	create_node_with_undo("MeshInstance2D")
func _on_multi_mesh_instance_2d_pressed() -> void:
	create_node_with_undo("MultiMeshInstance2D")

func _on_physical_bone_2d_pressed() -> void:
	create_node_with_undo("PhysicalBone2D")
func _on_skeleton_2d_pressed() -> void:
	create_node_with_undo("Skeleton2D")
func _on_bone_2d_pressed() -> void:
	create_node_with_undo("Bone2D")

#物理
func _on_area_2d_pressed() -> void:
	create_node_with_undo("Area2D")
func _on_shape_cast_2d_pressed() -> void:
	create_node_with_undo("ShapeCast2D")
func _on_ray_cast_2d_pressed() -> void:
	create_node_with_undo("RayCast2D")

func _on_collision_shape_2d_pressed() -> void:
	create_node_with_undo("CollisionShape2D")
func _on_collision_polygon_2d_pressed() -> void:
	create_node_with_undo("CollisionPolygon2D")

func _on_navigation_region_2d_pressed() -> void:
	create_node_with_undo("NavigationRegion2D")
func _on_navigation_link_2d_pressed() -> void:
	create_node_with_undo("NavigationLink2D")
func _on_navigation_obstacle_2d_pressed() -> void:
	create_node_with_undo("NavigationObstacle2D")
func _on_navigation_agent_2d_pressed() -> void:
	create_node_with_undo("NavigationAgent2D")

func _on_path_2d_pressed() -> void:
	create_node_with_undo("Path2D")
func _on_path_follow_2d_pressed() -> void:
	create_node_with_undo("PathFollow2D")

func _on_cpu_particles_2d_pressed() -> void:
	create_node_with_undo("CPUParticles2D")
func _on_gpu_particles_2d_pressed() -> void:
	create_node_with_undo("GPUParticles2D")

#音频
func _on_audio_stream_player_2d_pressed() -> void:
	create_node_with_undo("AudioStreamPlayer2D")
func _on_audio_listener_2d_pressed() -> void:
	create_node_with_undo("AudioListener2D")

#辅助
func _on_marker_2d_pressed() -> void:
	create_node_with_undo("Marker2D")
func _on_remote_transform_2d_pressed() -> void:
	create_node_with_undo("RemoteTransform2D")
func _on_back_buffer_copy_pressed() -> void:
	create_node_with_undo("BackBufferCopy")
func _on_touch_screen_button_pressed() -> void:
	create_node_with_undo("TouchScreenButton")

func _on_canvas_group_pressed() -> void:
	create_node_with_undo("CanvasGroup")
func _on_canvas_modulate_pressed() -> void:
	create_node_with_undo("CanvasModulate")

func _on_visible_on_screen_notifier_2d_pressed() -> void:
	create_node_with_undo("VisibleOnScreenNotifier2D")
func _on_visible_on_screen_enabler_2d_pressed() -> void:
	create_node_with_undo("VisibleOnScreenEnabler2D")
# endregion


# region 3D
#根节点
func _on_node_3d_pressed() -> void:
	create_node_with_undo("Node3D")
func _on_static_body_3d_pressed() -> void:
	create_node_with_undo("StaticBody3D")
func _on_rigid_body_3d_pressed() -> void:
	create_node_with_undo("RigidBody3D")	
func _on_animatable_body_3d_pressed() -> void:
	create_node_with_undo("AnimatableBody3D")
func _on_character_body_3d_pressed() -> void:
	create_node_with_undo("CharacterBody3D")
func _on_vehicle_body_3d_pressed() -> void:
	create_node_with_undo("VehicleBody3D")

#环境
func _on_camera_3d_pressed() -> void:
	create_node_with_undo("Camera3D")
func _on_spring_arm_3d_pressed() -> void:
	create_node_with_undo("SpringArm3D")
func _on_omni_light_3d_pressed() -> void:
	create_node_with_undo("OmniLight3D")
func _on_directional_light_3d_pressed() -> void:
	create_node_with_undo("DirectionalLight3D")
func _on_spot_light_3d_pressed() -> void:
	create_node_with_undo("SpotLight3D")
func _on_grid_map_pressed() -> void:
	create_node_with_undo("GridMap")
func _on_world_environment_pressed() -> void:
	create_node_with_undo("WorldEnvironment")
func _on_lightmap_gi_pressed() -> void:
	create_node_with_undo("LightmapGI")
func _on_lightmap_probe_pressed() -> void: 
	create_node_with_undo("LightmapProbe")
func _on_voxel_gi_pressed() -> void:
	create_node_with_undo("VoxelGI")
func _on_reflection_probe_pressed() -> void:
	create_node_with_undo("ReflectionProbe")

#对象
func _on_label_3d_pressed() -> void:
	create_node_with_undo("Label3D")

func _on_sprite_3d_pressed() -> void:
	create_node_with_undo("Sprite3D")
func _on_animated_sprite_3d_pressed() -> void:
	create_node_with_undo("AnimatedSprite3D")
func _on_decal_pressed() -> void:
	create_node_with_undo("Decal")

func _on_csg_box_3d_pressed() -> void:
	create_node_with_undo("CSGBox3D")
func _on_csg_cylinder_3d_pressed() -> void:
	create_node_with_undo("CSGCylinder3D")
func _on_csg_sphere_3d_pressed() -> void:
	create_node_with_undo("CSGSphere3D")	
func _on_csg_torus_3d_pressed() -> void:
	create_node_with_undo("CSGTorus3D")
func _on_csg_mesh_3d_pressed() -> void:
	create_node_with_undo("CSGMesh3D")
func _on_csg_polygon_3d_pressed() -> void:
	create_node_with_undo("CSGPolygon3D")
func _on_csg_combiner_3d_pressed() -> void:
	create_node_with_undo("CSGCombiner3D")

func _on_soft_body_3d_pressed() -> void:
	create_node_with_undo("SoftBody3D")
func _on_importer_mesh_instance_3d_pressed() -> void:
	create_node_with_undo("ImporterMeshInstance3D")
func _on_mesh_instance_3d_pressed() -> void:
	create_node_with_undo("MeshInstance3D")
func _on_multi_mesh_instance_3d_pressed() -> void:
	create_node_with_undo("MultiMeshInstance3D")

func _on_pin_joint_3d_pressed() -> void:
	create_node_with_undo("PinJoint3D")
func _on_slider_joint_3d_pressed() -> void:
	create_node_with_undo("SliderJoint3D")
func _on_hinge_joint_3d_pressed() -> void:
	create_node_with_undo("HingeJoint3D")
func _on_cone_twist_joint_3d_pressed() -> void:
	create_node_with_undo("ConeTwistJoint3D")
func _on_generic_6dof_joint_3d_pressed() -> void:
	create_node_with_undo("Generic6DOFJoint3D")

func _on_root_motion_view_pressed() -> void:
	create_node_with_undo("RootMotionView")
func _on_physical_bone_simulator_3d_pressed() -> void:
	create_node_with_undo("PhysicalBoneSimulator3D")
func _on_physical_bone_3d_pressed() -> void:
	create_node_with_undo("PhysicalBone3D")
func _on_bone_attachment_3d_pressed() -> void:
	create_node_with_undo("BoneAttachment3D")
func _on_skeleton_3d_pressed() -> void:
	create_node_with_undo("Skeleton3D")
func _on_copy_transform_modifier_3d_pressed() -> void:
	create_node_with_undo("CopyTransformModifier3D")
func _on_look_at_modifier_3d_pressed() -> void:
	create_node_with_undo("LookAtModifier3D")
func _on_aim_modifier_3d_pressed() -> void:
	create_node_with_undo("AimModifier3D")
func _on_modifier_bone_target_3d_pressed() -> void:
	create_node_with_undo("ModifierBoneTarget3D")
func _on_skeleton_ik_3d_pressed() -> void:
	create_node_with_undo("SkeletonIK3D")
func _on_spring_bone_simulator_3d_pressed() -> void:
	create_node_with_undo("SpringBoneSimulator3D")
func _on_retarget_modifier_3d_pressed() -> void:
	create_node_with_undo("RetargetModifier3D")
func _on_convert_transform_modifier_3d_pressed() -> void:
	create_node_with_undo("ConvertTransformModifier3D")

#物理
func _on_area_3d_pressed() -> void:
	create_node_with_undo("Area3D")
func _on_shape_cast_3d_pressed() -> void:
	create_node_with_undo("ShapeCast3D")
func _on_ray_cast_3d_pressed() -> void:
	create_node_with_undo("RayCast3D")
func _on_spring_bone_collision_3d_pressed() -> void:
	create_node_with_undo("SpringBoneCollision3D")

func _on_collision_shape_3d_pressed() -> void:
	create_node_with_undo("CollisionShape3D")
func _on_collision_polygon_3d_pressed() -> void:
	create_node_with_undo("CollisionPolygon3D")
func _on_vehicle_wheel_3d_pressed() -> void:
	create_node_with_undo("VehicleWheel3D")

func _on_navigation_region_3d_pressed() -> void:
	create_node_with_undo("NavigationRegion3D")
func _on_navigation_link_3d_pressed() -> void:
	create_node_with_undo("NavigationLink3D")
func _on_navigation_obstacle_3d_pressed() -> void:
	create_node_with_undo("NavigationObstacle3D")
func _on_navigation_agent_3d_pressed() -> void:
	create_node_with_undo("NavigationAgent3D")

func _on_path_3d_pressed() -> void:
	create_node_with_undo("Path3D")
func _on_path_follow_3d_pressed() -> void:
	create_node_with_undo("PathFollow3D")

func _on_fog_volume_pressed() -> void:
	create_node_with_undo("FogVolume")
func _on_cpu_particles_3d_pressed() -> void:
	create_node_with_undo("CPUParticles3D")
func _on_gpu_particles_3d_pressed() -> void:
	create_node_with_undo("GPUParticles3D")
func _on_gpu_particles_attractor_box_3d_pressed() -> void:
	create_node_with_undo("GPUParticlesAttractorBox3D")
func _on_gpu_particles_attractor_sphere_3d_pressed() -> void:
	create_node_with_undo("GPUParticlesAttractorSphere3D")
func _on_gpu_particles_attractor_vector_field_3d_pressed() -> void:
	create_node_with_undo("GPUParticlesAttractorVectorField3D")

#音频
func _on_audio_stream_player_3d_pressed() -> void:
	create_node_with_undo("AudioStreamPlayer3D")
func _on_audio_listener_3d_pressed() -> void:
	create_node_with_undo("AudioListener3D")

#辅助
func _on_marker_3d_pressed() -> void:
	create_node_with_undo("Marker3D")
func _on_remote_transform_3d_pressed() -> void:
	create_node_with_undo("RemoteTransform3D")

func _on_occluder_instance_3d_pressed() -> void:
	create_node_with_undo("OccluderInstance3D")
func _on_visible_on_screen_enabler_3d_pressed() -> void:
	create_node_with_undo("VisibleOnScreenEnabler3D")
func _on_visible_on_screen_notifier_3d_pressed() -> void:
	create_node_with_undo("VisibleOnScreenNotifier3D")

#XR
func _on_xr_node_3d_pressed() -> void:
	create_node_with_undo("XRNode3D")
func _on_xr_camera_3d_pressed() -> void:
	create_node_with_undo("XRCamera3D")
func _on_xr_origin_3d_pressed() -> void:
	create_node_with_undo("XROrigin3D")


func _on_open_xr_composition_layer_equirect_pressed() -> void:
	create_node_with_undo("OpenXRCompositionLayerEquirect")
func _on_open_xr_composition_layer_quad_pressed() -> void:
	create_node_with_undo("OpenXRCompositionLayerQuad")
func _on_open_xr_hand_pressed() -> void:
	create_node_with_undo("OpenXRHand")
func _on_open_xr_render_model_pressed() -> void:
	create_node_with_undo("OpenXRRenderModel")
func _on_open_xr_render_model_manager_pressed() -> void:
	create_node_with_undo("OpenXRRenderModelManager")
func _on_open_xr_visibility_mask_pressed() -> void:
	create_node_with_undo("OpenXRVisibilityMask")

func _on_xr_face_modifier_3d_pressed() -> void:
	create_node_with_undo("XRFaceModifier3D")
func _on_xr_body_modifier_3d_pressed() -> void:
	create_node_with_undo("XRBodyModifier3D")
func _on_xr_hand_modifier_3d_pressed() -> void:
	create_node_with_undo("XRHandModifier3D")
# endregion
