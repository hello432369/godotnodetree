@tool
extends Control
## 节点速览 V2 - UI 主脚本
## 核心特性：动态节点生成、搜索、最近使用、文档快捷查看、配置持久化

# ============================================================
# 外部引用（由 plugin.gd 注入）
# ============================================================
var editor_plugin: EditorPlugin = null
var sound_manager: Node = null

@export var button_theme: Theme

# ============================================================
# 配置
# ============================================================
const CONFIG_PATH := "res://addons/nodetree_v2/config.cfg"
const MAX_RECENT := 10

# ============================================================
# 运行时状态
# ============================================================
var font_size: int = 15
var sound_enabled: bool = true
var recent_nodes: Array[String] = []
var fold_states: Dictionary = {}

# ============================================================
# 节点分类定义 - 三级结构
# 格式: { "标签页": { "大分类": { "小分类": [ {"cn": "中文", "cls": "ClassName"}, ... ] } } }
# ============================================================
const CATEGORIES := {
	"通用": {
		"窗口": {
			"动画": [
				{"cn": "播放", "cls": "AnimationPlayer"},
				{"cn": "控制", "cls": "AnimationTree"},
			],
			"音频": [
				{"cn": "播放", "cls": "AudioStreamPlayer"},
			],
			"计时": [
				{"cn": "计时", "cls": "Timer"},
			],
			"预载": [
				{"cn": "提前_加载", "cls": "ResourcePreloader"},
			],
			"特殊": [
				{"cn": "着色_全局", "cls": "ShaderGlobalsOverride"},
				{"cn": "网络_请求", "cls": "HTTPRequest"},
				{"cn": "多人_管理", "cls": "MultiplayerSpawner"},
				{"cn": "多人_状态", "cls": "MultiplayerSynchronizer"},
			],
			"其他": [
				{"cn": "系统_通知", "cls": "StatusIndicator"},
				{"cn": "插件_基础", "cls": "EditorPlugin"},
			],
			"外部": [
				{"cn": "外部_窗口", "cls": "Window"},
				{"cn": "对话_接受", "cls": "AcceptDialog"},
				{"cn": "对话_确认", "cls": "ConfirmationDialog"},
				{"cn": "对话_文件", "cls": "FileDialog"},
				{"cn": "弹窗_基础", "cls": "Popup"},
				{"cn": "弹窗_菜单", "cls": "PopupMenu"},
				{"cn": "弹窗_面板", "cls": "PopupPanel"},
			],
			"内部": [
				{"cn": "内部_窗口", "cls": "SubViewport"},
			],
		},
	},
	"UI": {
		"根节点": {
			"图层": [
				{"cn": "图层", "cls": "CanvasLayer"},
				{"cn": "控件", "cls": "Control"},
			],
		},
		"输入": {
			"布尔": [
				{"cn": "基础", "cls": "Button"},
				{"cn": "纹理", "cls": "TextureButton"},
				{"cn": "复选", "cls": "CheckBox"},
				{"cn": "开关", "cls": "CheckButton"},
				{"cn": "下拉", "cls": "OptionButton"},
				{"cn": "菜单", "cls": "MenuButton"},
				{"cn": "链接", "cls": "LinkButton"},
				{"cn": "取色", "cls": "ColorPickerButton"},
			],
			"数字": [
				{"cn": "滑块_左右", "cls": "HSlider"},
				{"cn": "滑块_上下", "cls": "VSlider"},
				{"cn": "滚动条_左右", "cls": "HScrollBar"},
				{"cn": "滚动条_上下", "cls": "VScrollBar"},
				{"cn": "进度条_百分比", "cls": "ProgressBar"},
				{"cn": "进度条_纹理", "cls": "TextureProgressBar"},
				{"cn": "点框_数字", "cls": "SpinBox"},
			],
			"字符": [
				{"cn": "单行", "cls": "LineEdit"},
				{"cn": "多行", "cls": "TextEdit"},
				{"cn": "代码", "cls": "CodeEdit"},
			],
			"文件": [
				{"cn": "文件列表", "cls": "ItemList"},
				{"cn": "视频播放", "cls": "VideoStreamPlayer"},
				{"cn": "树形_结构", "cls": "Tree"},
			],
		},
		"输出": {
			"文本": [
				{"cn": "基础", "cls": "Label"},
				{"cn": "丰富", "cls": "RichTextLabel"},
			],
			"图形": [
				{"cn": "ui纯色背景", "cls": "ColorRect"},
				{"cn": "ui图片背景", "cls": "TextureRect"},
				{"cn": "ui九宫背景", "cls": "NinePatchRect"},
			],
		},
		"容器": {
			"分列": [
				{"cn": "排列_左右", "cls": "HBoxContainer"},
				{"cn": "排列_上下", "cls": "VBoxContainer"},
				{"cn": "流式_左右", "cls": "HFlowContainer"},
				{"cn": "流式_上下", "cls": "VFlowContainer"},
				{"cn": "分隔_左右", "cls": "HSplitContainer"},
				{"cn": "分隔_上下", "cls": "VSplitContainer"},
				{"cn": "排列_网格", "cls": "GridContainer"},
			],
			"分区": [
				{"cn": "比例", "cls": "AspectRatioContainer"},
				{"cn": "面板", "cls": "PanelContainer"},
				{"cn": "视窗", "cls": "SubViewportContainer"},
				{"cn": "选项", "cls": "TabContainer"},
				{"cn": "滚动", "cls": "ScrollContainer"},
				{"cn": "边距", "cls": "MarginContainer"},
				{"cn": "居中", "cls": "CenterContainer"},
				{"cn": "折叠", "cls": "FoldableContainer"},
				{"cn": "取色", "cls": "ColorPicker"},
			],
			"独立": [
				{"cn": "面板背景", "cls": "Panel"},
				{"cn": "顶部菜单栏", "cls": "MenuBar"},
				{"cn": "选项标题栏", "cls": "TabBar"},
			],
			"可视化": [
				{"cn": "根", "cls": "GraphEdit"},
				{"cn": "组", "cls": "GraphFrame"},
				{"cn": "点", "cls": "GraphNode"},
			],
		},
		"辅助": {
			"分割线": [
				{"cn": "分割线_上下", "cls": "HSeparator"},
				{"cn": "分割线_左右", "cls": "VSeparator"},
				{"cn": "参考框线", "cls": "ReferenceRect"},
			],
		},
	},
	"2D": {
		"根节点": {
			"节点": [
				{"cn": "空", "cls": "Node"},
				{"cn": "2d", "cls": "Node2D"},
			],
			"刚体": [
				{"cn": "静态", "cls": "StaticBody2D"},
				{"cn": "动态", "cls": "RigidBody2D"},
				{"cn": "动画", "cls": "AnimatableBody2D"},
				{"cn": "人物", "cls": "CharacterBody2D"},
			],
		},
		"主体": {
			"图片": [
				{"cn": "单张", "cls": "Sprite2D"},
				{"cn": "序列", "cls": "AnimatedSprite2D"},
			],
			"图形": [
				{"cn": "形状_单边", "cls": "Line2D"},
				{"cn": "形状_多边", "cls": "Polygon2D"},
				{"cn": "网格_单重", "cls": "MeshInstance2D"},
				{"cn": "网格_多重", "cls": "MultiMeshInstance2D"},
			],
			"骨骼": [
				{"cn": "根骨", "cls": "Skeleton2D"},
				{"cn": "子骨", "cls": "Bone2D"},
				{"cn": "子骨_物理", "cls": "PhysicalBone2D"},
			],
		},
		"物理": {
			"检测": [
				{"cn": "简形", "cls": "Area2D"},
				{"cn": "杂形", "cls": "ShapeCast2D"},
				{"cn": "射线", "cls": "RayCast2D"},
			],
			"碰撞": [
				{"cn": "形状", "cls": "CollisionShape2D"},
				{"cn": "多边", "cls": "CollisionPolygon2D"},
			],
			"导航": [
				{"cn": "区域", "cls": "NavigationRegion2D"},
				{"cn": "链接", "cls": "NavigationLink2D"},
				{"cn": "障碍", "cls": "NavigationObstacle2D"},
				{"cn": "代理", "cls": "NavigationAgent2D"},
			],
			"路径": [
				{"cn": "绘制", "cls": "Path2D"},
				{"cn": "跟随", "cls": "PathFollow2D"},
			],
			"粒子": [
				{"cn": "CPU", "cls": "CPUParticles2D"},
				{"cn": "GPU", "cls": "GPUParticles2D"},
			],
		},
		"音频": {
			"音频": [
				{"cn": "播放", "cls": "AudioStreamPlayer2D"},
				{"cn": "监听", "cls": "AudioListener2D"},
			],
		},
		"背景": {
			"相机": [
				{"cn": "相机", "cls": "Camera2D"},
			],
			"光照": [
				{"cn": "点光", "cls": "PointLight2D"},
				{"cn": "平光", "cls": "DirectionalLight2D"},
				{"cn": "遮光", "cls": "LightOccluder2D"},
			],
			"地形": [
				{"cn": "瓦片", "cls": "TileMapLayer"},
			],
			"视差": [
				{"cn": "视差", "cls": "Parallax2D"},
				{"cn": "图层", "cls": "ParallaxLayer"},
			],
		},
		"辅助": {
			"其他": [
				{"cn": "标记坐标", "cls": "Marker2D"},
				{"cn": "远程跟随", "cls": "RemoteTransform2D"},
				{"cn": "延迟处理", "cls": "BackBufferCopy"},
				{"cn": "触控按钮", "cls": "TouchScreenButton"},
			],
			"图层": [
				{"cn": "组合", "cls": "CanvasGroup"},
				{"cn": "调节", "cls": "CanvasModulate"},
			],
			"可见": [
				{"cn": "区域可控", "cls": "VisibleOnScreenEnabler2D"},
				{"cn": "区域可见", "cls": "VisibleOnScreenNotifier2D"},
			],
		},
	},
	"3D": {
		"根节点": {
			"节点": [
				{"cn": "3D节点", "cls": "Node3D"},
			],
			"刚体": [
				{"cn": "静态体", "cls": "StaticBody3D"},
				{"cn": "动态体", "cls": "RigidBody3D"},
				{"cn": "动画体", "cls": "AnimatableBody3D"},
				{"cn": "人物体", "cls": "CharacterBody3D"},
				{"cn": "汽车体", "cls": "VehicleBody3D"},
			],
		},
		"主体": {
			"文字": [
				{"cn": "文字标签", "cls": "Label3D"},
			],
			"图片": [
				{"cn": "单张精灵", "cls": "Sprite3D"},
				{"cn": "序列精灵", "cls": "AnimatedSprite3D"},
				{"cn": "贴纸", "cls": "Decal"},
			],
			"几何": [
				{"cn": "立方体", "cls": "CSGBox3D"},
				{"cn": "圆柱体", "cls": "CSGCylinder3D"},
				{"cn": "球体", "cls": "CSGSphere3D"},
				{"cn": "圆环体", "cls": "CSGTorus3D"},
				{"cn": "网格体", "cls": "CSGMesh3D"},
				{"cn": "多边体", "cls": "CSGPolygon3D"},
				{"cn": "组合体", "cls": "CSGCombiner3D"},
			],
			"网格": [
				{"cn": "软体网格", "cls": "SoftBody3D"},
				{"cn": "导入网格", "cls": "ImporterMeshInstance3D"},
				{"cn": "网格实例", "cls": "MeshInstance3D"},
				{"cn": "多重网格", "cls": "MultiMeshInstance3D"},
			],
			"关节": [
				{"cn": "固定关节", "cls": "PinJoint3D"},
				{"cn": "滑动关节", "cls": "SliderJoint3D"},
				{"cn": "单轴关节", "cls": "HingeJoint3D"},
				{"cn": "三轴关节", "cls": "ConeTwistJoint3D"},
				{"cn": "六轴关节", "cls": "Generic6DOFJoint3D"},
			],
			"骨骼": [
				{"cn": "根骨运动", "cls": "RootMotionView"},
				{"cn": "物理根骨骼", "cls": "PhysicalBoneSimulator3D"},
				{"cn": "物理子骨骼", "cls": "PhysicalBone3D"},
				{"cn": "骨骼装备", "cls": "BoneAttachment3D"},
				{"cn": "人形骨骼", "cls": "Skeleton3D"},
				{"cn": "复制变换", "cls": "CopyTransformModifier3D"},
				{"cn": "朝向头部", "cls": "LookAtModifier3D"},
				{"cn": "朝向手臂", "cls": "AimModifier3D"},
				{"cn": "朝向新目标", "cls": "ModifierBoneTarget3D"},
				{"cn": "反向运动", "cls": "SkeletonIK3D"},
				{"cn": "弹簧骨骼", "cls": "SpringBoneSimulator3D"},
				{"cn": "动画重定向", "cls": "RetargetModifier3D"},
				{"cn": "变换转换", "cls": "ConvertTransformModifier3D"},
			],
		},
		"物理": {
			"检测": [
				{"cn": "区域检测", "cls": "Area3D"},
				{"cn": "形状投射", "cls": "ShapeCast3D"},
				{"cn": "射线投射", "cls": "RayCast3D"},
				{"cn": "弹簧骨骼碰撞", "cls": "SpringBoneCollision3D"},
			],
			"碰撞": [
				{"cn": "碰撞形状", "cls": "CollisionShape3D"},
				{"cn": "碰撞多边形", "cls": "CollisionPolygon3D"},
				{"cn": "车辆轮子", "cls": "VehicleWheel3D"},
			],
			"导航": [
				{"cn": "导航区域", "cls": "NavigationRegion3D"},
				{"cn": "导航链接", "cls": "NavigationLink3D"},
				{"cn": "导航障碍", "cls": "NavigationObstacle3D"},
				{"cn": "导航代理", "cls": "NavigationAgent3D"},
			],
			"路径": [
				{"cn": "绘制路径", "cls": "Path3D"},
				{"cn": "路径跟随", "cls": "PathFollow3D"},
			],
			"粒子": [
				{"cn": "迷雾体积", "cls": "FogVolume"},
				{"cn": "CPU粒子", "cls": "CPUParticles3D"},
				{"cn": "GPU粒子", "cls": "GPUParticles3D"},
				{"cn": "GPU盒子", "cls": "GPUParticlesAttractorBox3D"},
				{"cn": "GPU球体", "cls": "GPUParticlesAttractorSphere3D"},
				{"cn": "GPU向量场", "cls": "GPUParticlesAttractorVectorField3D"},
			],
		},
		"音频": {
			"音频": [
				{"cn": "3D音频播放器", "cls": "AudioStreamPlayer3D"},
				{"cn": "3D音频监听器", "cls": "AudioListener3D"},
			],
		},
		"背景": {
			"相机": [
				{"cn": "3D相机", "cls": "Camera3D"},
				{"cn": "3D相机机械臂", "cls": "SpringArm3D"},
			],
			"光照": [
				{"cn": "点光源", "cls": "OmniLight3D"},
				{"cn": "平行光源", "cls": "DirectionalLight3D"},
				{"cn": "聚光灯源", "cls": "SpotLight3D"},
			],
			"地形": [
				{"cn": "网格地图", "cls": "GridMap"},
			],
			"氛围": [
				{"cn": "世界环境", "cls": "WorldEnvironment"},
				{"cn": "光照贴图GI", "cls": "LightmapGI"},
				{"cn": "光照探针", "cls": "LightmapProbe"},
				{"cn": "体素GI", "cls": "VoxelGI"},
				{"cn": "反射探针", "cls": "ReflectionProbe"},
			],
		},
		"辅助": {
			"其他": [
				{"cn": "3D标记", "cls": "Marker3D"},
				{"cn": "远程变换3D", "cls": "RemoteTransform3D"},
				{"cn": "遮挡器实例3D", "cls": "OccluderInstance3D"},
			],
			"可见": [
				{"cn": "可见启动", "cls": "VisibleOnScreenEnabler3D"},
				{"cn": "可见通知", "cls": "VisibleOnScreenNotifier3D"},
			],
		},
		"XR": {
			"树根": [
				{"cn": "XR节点3D", "cls": "XRNode3D"},
				{"cn": "XR相机3D", "cls": "XRCamera3D"},
				{"cn": "XR原点3D", "cls": "XROrigin3D"},
			],
			"开源": [
				{"cn": "矩形合成", "cls": "OpenXRCompositionLayerEquirect"},
				{"cn": "四边形合成", "cls": "OpenXRCompositionLayerQuad"},
				{"cn": "手部", "cls": "OpenXRHand"},
				{"cn": "渲染模型", "cls": "OpenXRRenderModel"},
				{"cn": "模型管理", "cls": "OpenXRRenderModelManager"},
				{"cn": "可见遮罩", "cls": "OpenXRVisibilityMask"},
			],
			"修改": [
				{"cn": "XR面部修改器3D", "cls": "XRFaceModifier3D"},
				{"cn": "XR身体修改器3D", "cls": "XRBodyModifier3D"},
				{"cn": "XR手部修改器3D", "cls": "XRHandModifier3D"},
			],
		},
	},
}

# ============================================================
# 资源链接定义
# ============================================================
const RESOURCES := {
	"教程": {
		"目录": [
			{"text": "导航地图", "uri": "https://xk3gvpbkxh.feishu.cn/wiki/Ob5WwTrmlihPbqkufilckXDUnye?fromScene=spaceOverview"},
			{"text": "官网推荐", "uri": "https://docs.godotengine.org/zh-cn/4.x/community/tutorials.html#resources"},
			{"text": "官网论坛教程", "uri": "https://forum.godotengine.org/c/resources/tutorials/20"},
		],
		"实战": [
			{"text": "视频教程", "uri": "https://space.bilibili.com/9004724/favlist?fid=3363751324&ftype=create"},
			{"text": "开源项目", "uri": "https://github.com/godotengine/awesome-godot"},
		],
		"节点": [
			{"text": "节点集合", "uri": "https://space.bilibili.com/9004724/favlist?fid=3519792524&ftype=create"},
		],
		"功能": [
			{"text": "功能集合", "uri": "https://space.bilibili.com/9004724/favlist?fid=3411700524&ftype=create"},
			{"text": "进阶教程", "uri": "https://kidscancode.org/godot_recipes/4.x/2d/enter_exit_screen/index.html"},
		],
	},
	"美术": {
		"2D": [
			{"text": "opengameart.org", "uri": "https://opengameart.org/"},
			{"text": "itch.io", "uri": "https://itch.io/game-assets/free"},
			{"text": "ai_混元2D", "uri": "https://hunyuan.tencent.com/game/home?from=/creation_tool"},
			{"text": "ai_即梦", "uri": "https://jimeng.jianying.com/ai-tool/home"},
		],
		"3D": [
			{"text": "ai_混元 3D", "uri": "https://3d.hunyuan.tencent.com/"},
		],
		"特效": [
			{"text": "shader", "uri": "https://godotshaders.com/shader/"},
		],
	},
	"字体": {
		"": [
			{"text": "免费商用字体", "uri": "https://fonts.zeoseven.com/"},
			{"text": "itch.io", "uri": "https://itch.io/game-assets/free/tag-fonts"},
		],
	},
	"音频": {
		"音效": [
			{"text": "ai_音效", "uri": "https://app.klingai.com/cn/text-to-audio/new"},
			{"text": "itch.io", "uri": "https://itch.io/game-assets/free/tag-sound-effects"},
		],
		"音乐": [
			{"text": "itch.io", "uri": "https://itch.io/game-assets/free/tag-music"},
		],
	},
	"UI": {
		"": [
			{"text": "itch.io", "uri": "https://itch.io/game-assets/free/tag-gui"},
		],
	},
}

# ============================================================
# 需要排除的类
# ============================================================
const EXCLUDE_PREFIXES: PackedStringArray = [
	"@", "Editor", "Resource", "RefCounted", "_",
	# 服务器/内部类（非场景节点）
	"RenderDataServer", "RenderingServer", "PhysicsServer",
	"PhysicsServer2D", "PhysicsServer3D", "NavigationServer",
	"NavigationServer2D", "NavigationServer3D",
	"TextServer", "TranslationServer", "CameraServer",
	"JavaClassWrapper", "JavaScriptBridge",
	# XR 内部
	"XRInterface", "XRPositionalTracker", "XRController3D",
]
# 无法直接实例化或不应出现在节点列表中的类
const EXCLUDE_CLASSES: PackedStringArray = [
	# === 场景树基类 ===
	"Node", "Control", "CanvasItem", "Node2D", "Node3D",
	# === 抽象按钮 ===
	"BaseButton",
	# === 抽象容器 ===
	"Container", "BoxContainer", "SplitContainer",
	# === 抽象范围控件 ===
	"Range", "Slider",
	# === 抽象物理 ===
	"PhysicsBody2D", "PhysicsBody3D",
	"CollisionObject2D", "CollisionObject3D",
	"CollisionShape", "CollisionPolygon2D", "CollisionPolygon3D",
	"Shape2D", "Shape3D",
	"Joint2D", "Joint3D",
	# === 抽象相机/光照 ===
	"Camera", "Camera2D", "Camera3D",
	"Light", "Light2D", "Light3D",
	# === 抽象骨骼 ===
	"Bone2D", "Bone3D",
	# === 抽象图形 ===
	"MeshInstance2D",  # 抽象基类，具体是 MeshInstance2D
	"GraphElement",
	# === 抽象播放器 ===
	"StreamPlayer",
	# === 抽象/内部资源类（不应作为场景节点） ===
	"Material", "ShaderMaterial",
	"AudioStream", "AudioStreamPlayback", "AudioEffect", "AudioEffectInstance",
	"AudioBusLayout",
	"Texture", "Texture2D", "Texture3D", "TextureLayered",
	"Mesh", "Mesh2D", "Mesh3D", "ArrayMesh",
	"StyleBox", "Theme", "Font",
	"InputEvent", "InputEventAction", "InputEventGesture", "InputEventMouse",
	"InputEventMIDI", "InputEventPanGesture", "InputEventScreenDrag",
	"InputEventScreenTouch", "InputEventShortcut", "InputEventMagnifyGesture",
	"Resource", "RefCounted", "Object",
	# === 占位符/无效节点 ===
	"MissingNode", "MissingResource",
	# === 已废弃类 ===
	"TileMap", "TileSet",  # 被 TileMapLayer 替代
	"AnimatedSprite",  # 被 AnimatedSprite2D/3D 替代
	"YSort",  # 被节点排序替代
	"Position2D",  # 被 Marker2D 替代
	# === 网络/通信抽象 ===
	"MultiplayerAPI", "MultiplayerPeer",
	"PacketPeer", "PacketPeerExtension",
	"StreamPeer", "StreamPeerExtension",
	# === 编辑器专用 ===
	"EditorPlugin", "EditorScript", "EditorSelection",
	"EditorExportPlugin", "EditorImportPlugin", "EditorInspectorPlugin",
	# === 其他不可用 ===
	"SubViewport",  # 通过 SubViewportContainer 使用
	"World2D", "World3D",  # 内部世界对象
	"Viewport", "ViewportTexture",
	"Environment",  # 资源类
	"Sky", "Compositor", "CompositorEffect",  # 渲染资源
	"CameraFeed",  # 内部类
	"Thread", "Mutex", "Semaphore",  # 非节点
	"JSON", "JSONParseResult",  # 工具类
	"DirAccess", "FileAccess",  # IO 类
	"HTTPClient", "TCPClient", "UDPServer", "UDPSocket",  # 网络底层
	"StreamPeerTCP", "StreamPeerUDP",
	"PacketPeerUDP", "PacketPeerDTLS",
]

# ============================================================
# 内部缓存
# ============================================================
var _tab_inner_containers: Dictionary = {}
var _all_node_buttons: Array[Button] = []
var _undo_redo: EditorUndoRedoManager = null

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_load_config()
	_cache_tab_containers()
	_build_all_categories()
	_build_resources_tab()
	_load_recent_nodes()
	_update_recent_ui()
	_apply_font_size()
	_apply_sound_state()


func on_editor_ready() -> void:
	if editor_plugin:
		_undo_redo = editor_plugin.get_undo_redo()


# ============================================================
# 配置持久化
# ============================================================

func _load_config() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	font_size = cfg.get_value("settings", "font_size", 15)
	sound_enabled = cfg.get_value("settings", "sound_enabled", true)
	var keys = cfg.get_section_keys("fold_states")
	for k in keys:
		fold_states[k] = cfg.get_value("fold_states", k, false)


func _save_config() -> void:
	var cfg := ConfigFile.new()
	if FileAccess.file_exists(CONFIG_PATH):
		cfg.load(CONFIG_PATH)
	cfg.set_value("settings", "font_size", font_size)
	cfg.set_value("settings", "sound_enabled", sound_enabled)
	for k in fold_states:
		cfg.set_value("fold_states", k, fold_states[k])
	cfg.save(CONFIG_PATH)


# ============================================================
# Tab 容器缓存
# ============================================================

func _cache_tab_containers() -> void:
	var tc: TabContainer = $VBox/TabContainer
	for i in tc.get_tab_count():
		var tab_name = tc.get_tab_title(i)
		var scroll = tc.get_tab_control(i)
		var inner = scroll.find_child("Inner", true, false)
		if inner:
			_tab_inner_containers[tab_name] = inner


# ============================================================
# 动态节点按钮生成
# ============================================================

func _build_all_categories() -> void:
	_all_node_buttons.clear()
	# 先构建"新增"标签页
	_build_new_tab()
	# 再构建原始标签页（保持原始内容，不添加任何新节点）
	for tab_name in CATEGORIES:
		var inner = _tab_inner_containers.get(tab_name)
		if not inner:
			continue
		for child in inner.get_children():
			child.queue_free()
		var major_cats = CATEGORIES[tab_name]
		for major_name in major_cats:
			var sub_cats = major_cats[major_name]
			_build_major_category(inner, tab_name, major_name, sub_cats)


## 构建一个大分类的 FoldableContainer，内含多个小分类
func _build_major_category(parent: VBoxContainer, tab_name: String, major_name: String, sub_cats: Dictionary) -> void:
	var foldable = FoldableContainer.new()
	foldable.name = major_name
	foldable.title = major_name
	parent.add_child(foldable)

	var outer_vbox = VBoxContainer.new()
	outer_vbox.name = "Content"
	outer_vbox.add_theme_constant_override("separation", 4)
	foldable.add_child(outer_vbox)

	var fid = foldable.get_path()
	if fid in fold_states:
		foldable.folded = fold_states[fid]
	else:
		fold_states[fid] = false
	foldable.folding_changed.connect(_on_foldable_changed.bind(foldable))

	var sub_names := sub_cats.keys()
	for sub_idx in range(sub_names.size()):
		var sub_name: String = sub_names[sub_idx]
		var items: Array = sub_cats[sub_name]

		# 小分类行: HBoxContainer [Label | VBoxContainer[Button...]]
		var hbox = HBoxContainer.new()
		hbox.name = sub_name
		hbox.add_theme_constant_override("separation", 8)
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		outer_vbox.add_child(hbox)

		# 左侧标签
		var label = Label.new()
		label.text = sub_name
		if button_theme:
			label.theme = button_theme
		label.add_theme_font_size_override("font_size", font_size)
		label.custom_minimum_size = Vector2(48, 0)
		hbox.add_child(label)

		# 右侧按钮列表（纵向排列）
		var btn_vbox = VBoxContainer.new()
		btn_vbox.name = "Buttons"
		btn_vbox.add_theme_constant_override("separation", 4)
		btn_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(btn_vbox)

		for item in items:
			var cn_name: String = item.get("cn", item.get("cls", ""))
			var cls_name: String = item.get("cls", "")
			if cls_name.is_empty():
				continue
			var row = _create_node_row(cn_name, cls_name)
			btn_vbox.add_child(row)

		# 小分类之间加分隔线
		if sub_idx < sub_names.size() - 1:
			var sep = HSeparator.new()
			sep.name = "Sep_" + sub_name
			outer_vbox.add_child(sep)


## 构建"新增"标签页 - 包含通用/UI/2D/3D四个折叠，直接平铺按钮
func _build_new_tab() -> void:
	var inner = _tab_inner_containers.get("新增")
	if not inner:
		return
	for child in inner.get_children():
		child.queue_free()

	# 收集所有已分类的类名
	var classified: Dictionary = {}
	for tab_name in CATEGORIES:
		var major_cats = CATEGORIES[tab_name]
		for major_name in major_cats:
			var sub_cats = major_cats[major_name]
			for sub_name in sub_cats:
				for item in sub_cats[sub_name]:
					var cls_name: String = item.get("cls", "")
					if not cls_name.is_empty():
						classified[cls_name] = true

	# 按标签页分类发现新增节点
	# 顺序很重要：先检查具体父类，再检查 Node（因为 Control 也是 Node 子类）
	var tab_bases: Array = [
		{"tab": "UI", "base": "Control"},
		{"tab": "2D", "base": "Node2D"},
		{"tab": "3D", "base": "Node3D"},
		{"tab": "通用", "base": "Node"},
	]
	var all_classes: PackedStringArray = ClassDB.get_class_list()

	for entry in tab_bases:
		var tab_name: String = entry["tab"]
		var base_class: String = entry["base"]
		var new_nodes: Array[Dictionary] = []
		for cls in all_classes:
			if cls in classified:
				continue
			if not ClassDB.can_instantiate(cls):
				continue
			if not ClassDB.is_parent_class(cls, base_class):
				continue
			if _should_exclude(cls):
				continue
			new_nodes.append({"cn": cls, "cls": cls})
			classified[cls] = true  # 标记已分配，避免重复归入"通用"
		if new_nodes.is_empty():
			continue
		new_nodes.sort()
		# 直接构建折叠 + 按钮列表，不要小分类
		_build_simple_foldable(inner, tab_name, new_nodes)


func _get_base_class_for_tab(tab_name: String) -> String:
	match tab_name:
		"UI": return "Control"
		"2D": return "Node2D"
		"3D": return "Node3D"
		"通用": return "Node"
		_: return ""


func _should_exclude(cls: String) -> bool:
	for prefix in EXCLUDE_PREFIXES:
		if cls.begins_with(prefix):
			return true
	return cls in EXCLUDE_CLASSES


## 新增标签页专用：简单折叠 + 直接平铺按钮（无小分类）
func _build_simple_foldable(parent: VBoxContainer, title: String, items: Array) -> void:
	var foldable = FoldableContainer.new()
	foldable.name = title
	foldable.title = title
	parent.add_child(foldable)

	var vbox = VBoxContainer.new()
	vbox.name = "Buttons"
	vbox.add_theme_constant_override("separation", 4)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foldable.add_child(vbox)

	var fid = foldable.get_path()
	if fid in fold_states:
		foldable.folded = fold_states[fid]
	else:
		fold_states[fid] = false
	foldable.folding_changed.connect(_on_foldable_changed.bind(foldable))

	for item in items:
		var cn_name: String = item.get("cn", item.get("cls", ""))
		var cls_name: String = item.get("cls", "")
		if cls_name.is_empty():
			continue
		var row = _create_node_row(cn_name, cls_name)
		vbox.add_child(row)


## 创建一行：[节点按钮(拉伸)] [文档按钮(固定宽)]
func _create_node_row(cn_name: String, cls_name: String) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.name = cls_name
	row.add_theme_constant_override("separation", 6)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# 节点创建按钮 - 拉伸填充
	var btn = Button.new()
	btn.name = cls_name
	btn.text = cn_name + "\n" + cls_name
	btn.tooltip_text = cn_name + " (" + cls_name + ")"
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 36)
	if button_theme:
		btn.theme = button_theme
	btn.add_theme_font_size_override("font_size", font_size)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var icon = get_theme_icon(cls_name, "EditorIcons")
	if icon:
		btn.icon = icon
	btn.pressed.connect(_on_node_button_pressed.bind(cls_name))
	_all_node_buttons.append(btn)
	row.add_child(btn)

	# 文档按钮 - 固定宽度，不拉伸
	var doc_btn = Button.new()
	doc_btn.name = "Doc_" + cls_name
	doc_btn.text = "?"
	doc_btn.tooltip_text = "查看 " + cls_name + " 内置文档"
	doc_btn.custom_minimum_size = Vector2(28, 0)
	doc_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if button_theme:
		doc_btn.theme = button_theme
	doc_btn.add_theme_font_size_override("font_size", max(font_size - 4, 10))
	doc_btn.pressed.connect(_on_doc_button_pressed.bind(cls_name))
	row.add_child(doc_btn)

	return row


# ============================================================
# 资源标签页构建
# ============================================================

func _build_resources_tab() -> void:
	var inner = _tab_inner_containers.get("资源")
	if not inner:
		return
	for child in inner.get_children():
		child.queue_free()
	for section_name in RESOURCES:
		_build_resource_section(inner, section_name, RESOURCES[section_name])


func _build_resource_section(parent: VBoxContainer, section_title: String, sub_sections: Dictionary) -> void:
	var foldable = FoldableContainer.new()
	foldable.name = section_title
	foldable.title = section_title
	parent.add_child(foldable)

	var vbox = VBoxContainer.new()
	vbox.name = "Content"
	vbox.add_theme_constant_override("separation", 12)
	foldable.add_child(vbox)

	var fid = foldable.get_path()
	if fid in fold_states:
		foldable.folded = fold_states[fid]
	else:
		fold_states[fid] = false
	foldable.folding_changed.connect(_on_foldable_changed.bind(foldable))

	for sub_name in sub_sections:
		var links = sub_sections[sub_name]
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)
		vbox.add_child(hbox)

		if sub_name != "":
			var label = Label.new()
			label.text = sub_name
			if button_theme:
				label.theme = button_theme
			label.add_theme_font_size_override("font_size", font_size)
			hbox.add_child(label)

		var grid = GridContainer.new()
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 12)
		grid.columns = mini(links.size(), 3)
		hbox.add_child(grid)

		for link_data in links:
			var lb = _create_link_button(link_data["text"], link_data["uri"])
			grid.add_child(lb)


func _create_link_button(text: String, uri: String) -> LinkButton:
	var lb = LinkButton.new()
	lb.text = text
	lb.uri = uri
	lb.tooltip_text = uri
	if button_theme:
		lb.theme = button_theme
	lb.add_theme_font_size_override("font_size", font_size)
	lb.underline = LinkButton.UnderlineMode.UNDERLINE_MODE_ON_HOVER
	return lb


# ============================================================
# 节点创建（带撤销）
# ============================================================

func _on_node_button_pressed(cls_name: String) -> void:
	_play_click_sound()
	_create_node(cls_name)
	_add_recent(cls_name)


func _create_node(node_class: String) -> void:
	if not editor_plugin:
		push_warning("插件未初始化")
		return

	var editor_interface = editor_plugin.get_editor_interface()
	var selection = editor_interface.get_selection()
	var selected = selection.get_selected_nodes()

	if selected.is_empty():
		push_warning("请先选择一个父节点")
		return

	var parent_node = selected[0]
	if not _undo_redo:
		_undo_redo = editor_plugin.get_undo_redo()

	_undo_redo.create_action("创建节点: " + node_class)
	var new_node = ClassDB.instantiate(node_class)
	if not new_node:
		push_warning("无法实例化: " + node_class)
		_undo_redo.commit_action(false)
		return
	new_node.name = node_class

	if node_class == "Bone2D":
		new_node.set_length(20.0)
		new_node.set_bone_angle(0.0)
		new_node.auto_calculate_length_and_angle = false
		new_node.transform = Transform2D.IDENTITY
		if parent_node.get_class() == "Bone2D":
			new_node.position = Vector2(parent_node.get_length(), 0)

	_undo_redo.add_do_method(parent_node, "add_child", new_node)
	_undo_redo.add_do_method(new_node, "set_owner", editor_interface.get_edited_scene_root())
	_undo_redo.add_undo_method(parent_node, "remove_child", new_node)
	_undo_redo.commit_action(true)


# ============================================================
# 文档按钮
# ============================================================

func _on_doc_button_pressed(cls_name: String) -> void:
	_play_click_sound()
	if not editor_plugin:
		return
	var se = editor_plugin.get_editor_interface().get_script_editor()
	if se:
		se.goto_help("class_name:" + cls_name)


# ============================================================
# 最近使用节点
# ============================================================

func _add_recent(cls_name: String) -> void:
	var idx = recent_nodes.find(cls_name)
	if idx != -1:
		recent_nodes.remove_at(idx)
	recent_nodes.insert(0, cls_name)
	if recent_nodes.size() > MAX_RECENT:
		recent_nodes.resize(MAX_RECENT)
	_save_recent()
	_update_recent_ui()


func _save_recent() -> void:
	var cfg := ConfigFile.new()
	if FileAccess.file_exists(CONFIG_PATH):
		cfg.load(CONFIG_PATH)
	for i in recent_nodes.size():
		cfg.set_value("recent", "n%d" % i, recent_nodes[i])
	cfg.save(CONFIG_PATH)


func _load_recent_nodes() -> void:
	recent_nodes.clear()
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	var keys = cfg.get_section_keys("recent")
	for k in keys:
		var v = cfg.get_value("recent", k, "")
		if v != "" and v not in recent_nodes:
			recent_nodes.append(v)


func _update_recent_ui() -> void:
	var grid: GridContainer = $VBox/RecentBar/RecentGrid
	for child in grid.get_children():
		child.queue_free()
	for cls_name in recent_nodes:
		var btn = Button.new()
		btn.text = cls_name
		btn.tooltip_text = "创建 " + cls_name
		if button_theme:
			btn.theme = button_theme
		btn.add_theme_font_size_override("font_size", font_size)
		var icon = get_theme_icon(cls_name, "EditorIcons")
		if icon:
			btn.icon = icon
		btn.pressed.connect(_on_node_button_pressed.bind(cls_name))
		grid.add_child(btn)


# ============================================================
# 搜索
# ============================================================

func _on_search_changed(text: String) -> void:
	if text.is_empty():
		_show_all_buttons()
		return
	var lower = text.to_lower()
	for btn in _all_node_buttons:
		var is_match: bool = btn.text.to_lower().find(lower) != -1
		btn.visible = is_match
		if btn.get_parent():
			btn.get_parent().visible = is_match


func _show_all_buttons() -> void:
	for btn in _all_node_buttons:
		btn.visible = true
		if btn.get_parent():
			btn.get_parent().visible = true


# ============================================================
# 折叠状态
# ============================================================

func _on_foldable_changed(is_folded: bool, foldable: FoldableContainer) -> void:
	var fid = foldable.get_path()
	var current = foldable.folded
	if fid not in fold_states or fold_states[fid] != current:
		fold_states[fid] = current
		_save_config()


# ============================================================
# 工具栏回调
# ============================================================

func _on_refresh_pressed() -> void:
	_play_click_sound()
	_save_config()
	if editor_plugin and editor_plugin.has_method("refresh_panel"):
		editor_plugin.refresh_panel()


func _on_sound_toggled(on: bool) -> void:
	sound_enabled = on
	if sound_manager and sound_manager.has_method("set_enabled"):
		sound_manager.set_enabled(on)
	_save_config()


func _on_font_slider_changed(value: float) -> void:
	font_size = int(value)
	_apply_font_size()
	_save_config()


# ============================================================
# 样式应用
# ============================================================

func _apply_font_size() -> void:
	var doc_font_size := max(font_size - 4, 10)
	for btn in _all_node_buttons:
		if btn.has_method("add_theme_font_size_override"):
			btn.add_theme_font_size_override("font_size", font_size)
			btn.queue_redraw()
		var parent = btn.get_parent()
		if parent and parent is HBoxContainer:
			for child in parent.get_children():
				if child.name.begins_with("Doc_") and child.has_method("add_theme_font_size_override"):
					child.add_theme_font_size_override("font_size", doc_font_size)
	_update_recent_ui()


func _apply_sound_state() -> void:
	var btn: CheckButton = $VBox/Toolbar/BtnSound
	if btn:
		btn.button_pressed = sound_enabled
	if sound_manager and sound_manager.has_method("set_enabled"):
		sound_manager.set_enabled(sound_enabled)


# ============================================================
# 音效
# ============================================================

func _play_click_sound() -> void:
	if sound_manager and sound_manager.has_method("play"):
		sound_manager.play()
