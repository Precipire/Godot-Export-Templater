@tool
extends ConfirmationDialog

signal build_requested(build_config: Dictionary)

# get all of the inputs
@onready var tabs: TabContainer = $Tabs

# lists for valid options.
# Godot versions based on github tags
var godot_versions_list := ["4.4.1-stable", "4.4-stable"]
var platforms_list := ["android", "ios", "linuxbsd", "macos", "web", "windows"]
# Not sure if these need to be filtered based on platform yet (I assume they do)
var arch_list := ["auto", "x86_32", "x86_64", "arm32", "arm64", "rv64", "ppc32", "ppc64", "wasm32"]
var target_list := ["editor", "template_debug", "template_release"]

var build_config = {
	"platform": "",
	"target": "",
	"godot_version":"",
	"encryption_key": "",
	"platform_settings": {}
}

var controls := {
	"web": {},
	"windows": {},
}

func _ready() -> void:
	gather_UI()

func gather_UI() -> void:
	#Web choices (encryption, threads, Godot version,  
	controls["web"]["encryption_input"] = $Tabs/Web/VCon/Encryption/LineEdit
	controls["web"]["godot_version"] = $Tabs/Web/VCon/GodotVersion/OptionButton
	controls["web"]["target"] = $Tabs/Web/VCon/Target/OptionButton
	controls["web"]["threads"] = $Tabs/Web/VCon/Threads/CheckButton
	
	controls["windows"]["encryption_input"] = $Tabs/Windows/VCon/Encryption/LineEdit
	print(controls["windows"]["encryption_input"] )
	controls["windows"]["godot_version"] = $Tabs/Windows/VCon/GodotVersion/OptionButton
	controls["windows"]["target"] = $Tabs/Windows/VCon/Target/OptionButton
	controls["windows"]["architecture"] = $Tabs/Windows/VCon/Architecture/OptionButton
	

func get_selected_option(option_button):
	return option_button.get_item_text(option_button.get_selected_id())

## Gathers the inputs, verifies, then sends it to be compiled
func start_build():
	
	build_config = {"platform_settings": {}}
	var platform: String = tabs.get_current_tab_control().name.to_lower()
	match platform:
		"web":
			build_config["platform"] = "web"
			build_config["encryption_key"] = is_valid_encryption_key(controls["web"]["encryption_input"].text)
			build_config["godot_version"] = get_selected_option(controls["web"]["godot_version"])
			build_config["target"] = get_selected_option(controls["web"]["target"])
			build_config["platform_settings"]["threads"] = "yes" if controls["web"]["threads"].button_pressed else "no"
			build_config["platform_settings"]["arch"] = "wasm32"
		"windows":
			build_config["platform"] = "windows"
			build_config["encryption_key"] = is_valid_encryption_key(controls["windows"]["encryption_input"].text)
			build_config["godot_version"] = get_selected_option(controls["windows"]["godot_version"])
			build_config["target"] = get_selected_option(controls["windows"]["target"])
			build_config["platform_settings"]["arch"] = get_selected_option(controls["windows"]["architecture"])
			build_config["platform_settings"]["use_mingw"] = "yes"
			build_config["platform_settings"]["use_llvm"] = "yes"
	
	print(build_config)
	build_requested.emit(build_config)
	
## We need to make sure the key works or we get errors in docker
func is_valid_encryption_key(key: String) -> String:
	var hex_key_regex = RegEx.new()
	hex_key_regex.compile("^[0-9a-fA-F]{64}$")
	return key if hex_key_regex.search(key) != null else ""
