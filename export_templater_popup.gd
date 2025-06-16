@tool
extends ConfirmationDialog

signal build_requested(version, encryption_key, platform, target, arch, profile)
@onready var encryption: LineEdit = $VBoxContainer/Encryption/LineEdit
@onready var godot_version: OptionButton = $VBoxContainer/GodotVersion/OptionButton
@onready var platform: OptionButton = $VBoxContainer/Platform/OptionButton
@onready var architecture: OptionButton = $VBoxContainer/Architecture/OptionButton
@onready var scons_display: Label = $VBoxContainer/sconsDisplay
@onready var build_profile: LineEdit = $VBoxContainer/BuildProfile/LineEdit
@onready var target_options: OptionButton = $VBoxContainer/Target/OptionButton

var godot_versions_list := ["4.4.1-stable", "4.4-stable", "4.3-stable"]
var platforms_list := ["android", "ios", "linuxbsd", "macos", "web", "windows"]
var arch_list := ["auto", "x86_32", "x86_64", "arm32", "arm64", "rv64", "ppc32", "ppc64", "wasm32"]
var target_list := ["editor", "template_debug", "template_release"]

var args := []

func _ready() -> void:
	#populate
	godot_version.clear()
	platform.clear()
	architecture.clear()
	scons_display.text = ""
	for version in godot_versions_list:
		godot_version.add_item(version)
	for p in platforms_list:
		platform.add_item(p)
	for arch in arch_list:
		architecture.add_item(arch)
	for t in target_list:
		target_options.add_item(t)

func start_build():
	var sel_version: String = godot_versions_list[godot_version.get_selected_id()]
	var sel_key: String
	if is_valid_encryption_key(encryption.text):
		sel_key = encryption.text
	else:
		print("Entered Key is not a valid AES256 encryption key")
		
	var sel_platform: String = platforms_list[platform.get_selected_id()]
	var sel_target: String = target_list[target_options.get_selected_id()]
	var sel_arch: String = arch_list[architecture.get_selected_id()]
	var sel_profile: String = ""
	# Verify file exists
	if ("res://addons/exporttemplater/build_profiles/"+build_profile.text).get_file() != "":
		sel_platform = build_profile.text
	build_requested.emit(sel_version, sel_key, sel_platform, sel_target, sel_arch, sel_profile)

func verify_build():
	var sel_version: String = godot_versions_list[godot_version.get_selected_id()]
	var sel_key: String
	if is_valid_encryption_key(encryption.text):
		sel_key = encryption.text
	else:
		print("Entered Key is not a valid AES256 encryption key")
		
	var sel_platform: String = platforms_list[platform.get_selected_id()]
	var sel_target: String = target_list[target_options.get_selected_id()]
	var sel_arch: String = arch_list[architecture.get_selected_id()]
	var sel_profile: String = ""
	# Verify file exists
	if ("res://addons/exporttemplater/build_profiles/"+build_profile.text).get_file() != "":
		sel_platform = build_profile.text
	
	
	
func is_valid_encryption_key(key: String) -> bool:
	var hex_key_regex = RegEx.new()
	hex_key_regex.compile("^[0-9a-fA-F]{64}$")
	return hex_key_regex.search(key) != null

func variable_updated(data):
	pass
