@tool
class_name ExportTemplater extends EditorPlugin

# To be incremented when the dockerfile itself changes
var DOCKER_IMAGE_VERSION = "v1.3.6"
var image_tag = "godot-templater-"

const EXPORT_TEMPLATER_POPUP = preload("uid://dap8b6avxtgnd")

var active_pipe: FileAccess
var stderr: FileAccess
var pid: int
var thread: Thread
var build_context: String

var core_count

signal pipe_line(line)
signal pipe_done

func _enter_tree() -> void:
	# Create the menu item
	add_tool_menu_item("Build Export Template", show_options)
	# Test if docker is available
	is_docker_available()
	var res_path = get_script().resource_path
	var abs_path = ProjectSettings.globalize_path(res_path)
	build_context = abs_path.get_base_dir()
	
	test_environment(build_context)
	
	# get core count
	core_count = OS.get_processor_count()

func _exit_tree() -> void:
	# Remove the menu item to prevent errors
	remove_tool_menu_item("Build Export Template")
	# I still don't fully get threads
	if thread and thread.is_alive():
		clean_thread()

## Returns true/false depending if docker is running using "docker info"
func is_docker_available() -> bool:
	var output := []
	var exit_code := OS.execute("docker", ["info"], output, true)
	if exit_code != 0:
		print("Docker is not available or not installed. Make sure it is in your PATH")
		print("Remember to start the docker engine!")
		return false
	print("Docker is alive and ready!")
	return true

func show_options():
	var popup = EXPORT_TEMPLATER_POPUP.instantiate()
	get_editor_interface().get_base_control().add_child(popup)
	popup.popup_centered()
	popup.build_requested.connect(create_godot_template)

func download_godot_source() -> bool:
	var godot_path = build_context + "/godot_source/godot"
	if DirAccess.dir_exists_absolute(godot_path + "/.git"):
		print("Godot source already present, skipping clone")
		return true
	print("Cloning Godot source (this will take a while)...")
	var pipe := OS.execute_with_pipe("git", ["clone", "https://github.com/godotengine/godot.git", godot_path])
	if pipe.size() == 0:
		print("Failed to start git clone")
		return false
	await start_pipe_thread(pipe)
	if !DirAccess.dir_exists_absolute(godot_path + "/.git"):
		print("Cloning failed")
		return false
	print("Godot Cloned!")
	return true

## The real part of this script
func create_godot_template(build_info):

	if !await download_godot_source():
		return

	# Turn build info into a JSON file inside the config folder
	var json = JSON.stringify(build_info)
	var config_file = FileAccess.open(build_context + "/config/data.json", FileAccess.WRITE)
	config_file.store_line(json)
	config_file.close()

	var dockerfile_name := ""
	var setup_name := ""
	match build_info["platform"]:
		"web":
			dockerfile_name = "Dockerfile-Web"
			setup_name = "web_setup.sh"
		"windows":
			dockerfile_name = "Dockerfile-Windows"
			setup_name = "windows_setup.sh"
		"linuxbsd":
			dockerfile_name = "Dockerfile-Linuxbsd"
			setup_name = "linuxbsd_setup.sh"
		_:
			push_error("ExportTemplater: Unsupported platform: " + build_info["platform"])
			return

	if !await create_docker_build(image_tag, dockerfile_name, build_info):
		return
	await run_docker_script(build_info, setup_name)
	print("Complete! Check output folder for templates")


## Creates the docker image from the Dockerfile (takes a while if there is no cache)
func create_docker_build(version, dockerfile_name: String, build_info) -> bool:
	print("Building Docker image")
	print("This may take a while for first time runs...")

	print(build_context + "/Dockerfiles/"+ dockerfile_name)
	var bin = "docker"
	var args = ["buildx", "build",
				"--progress=plain",
				"-t",
				image_tag+build_info["platform"]+DOCKER_IMAGE_VERSION,
				"--file",
				build_context + "/Dockerfiles/"+dockerfile_name,
				build_context + "/Dockerfiles"]

	var pipe := OS.execute_with_pipe(bin, args)
	if !get_window().is_connected("close_requested",clean_thread):
		get_window().close_requested.connect(clean_thread)
	if pipe.size() == 0:
		print("Docker Image Build Failed")
		return false
	await start_pipe_thread(pipe)

	var tag = image_tag + build_info["platform"] + DOCKER_IMAGE_VERSION
	if OS.execute("docker", ["image", "inspect", tag], [], true) != 0:
		push_error("ExportTemplater: Docker image was not created: " + tag)
		return false

	print("Image Built")
	return true

func run_docker_script(build_info, setup_name):
	print("Running Docker container")
	print("This will take an eternity... (go drink some water)")
	# Won't print from the command until the end for some reason so this will do for now
	# docker run --rm -v /abs/path/to/project:/project -v /abs/path/to/out:/out godot-templater:v0.1.0 /project/scripts/build_template.sh
	# Set up the command here
	var script_path = "/workspace/scripts/" + setup_name
	var bin = "docker"
	var args = [
		"run", "--rm",
		"--cpus", str(core_count-2),
		"-v", build_context + "/scripts:/workspace/scripts",
		"-v", build_context + "/output:/workspace/output",
		"-v", build_context + "/build_profiles:/workspace/profiles",
		"-v", build_context + "/config:/workspace/config",
		"-v", build_context + "/godot_source/godot:/workspace/godot",
		image_tag+build_info["platform"]+DOCKER_IMAGE_VERSION,
		script_path,
	]

	var pipe := OS.execute_with_pipe(bin, args)
	if pipe.size() == 0:
		print("Docker Container Failed")
		return
	
	await start_pipe_thread(pipe)
	print("Container Completed")

func start_pipe_thread(pipe: Dictionary):
	active_pipe = pipe["stdio"]
	stderr = pipe["stderr"]
	pid = pipe["pid"]
	
	var finished := false
	if !pipe_line.is_connected(_on_pipe_line):
		pipe_line.connect(_on_pipe_line)
	
	thread = Thread.new()
	thread.start(_thread_func)
	await pipe_done
	
	clean_thread()

# This code is a slightly modified version of wyattbikers code here:
# https://forum.godotengine.org/t/os-execute-with-pipe-does-not-create-process-when-return-value-is-assigned-to-a-variable-until-application-is-closed/79109/5
signal pipe_in_progress
func _thread_func():
	while active_pipe.is_open() or stderr.is_open():
		if active_pipe and active_pipe.is_open():
			var err = active_pipe.get_error()
			if err == OK:
				var line = active_pipe.get_line()
				if line != "":
					pipe_line.emit.call_deferred(line)
			else:
				active_pipe.close()
		if stderr and stderr.is_open():
			var err = stderr.get_error()
			if err == OK:
				var line = stderr.get_line()
				if line != "":
					pipe_line.emit.call_deferred(line)
			else:
				stderr.close()
		OS.delay_msec(10)
	# Pipes can close before the process fully exits; wait for the process itself
	while OS.is_process_running(pid):
		OS.delay_msec(100)
	pipe_done.emit.call_deferred()

func _on_pipe_line(line):
	print(line)

# Theoretically does thread stuff when process is finished
func clean_thread():
	if active_pipe and active_pipe.is_open():
		active_pipe.close()
	if stderr and stderr.is_open():
		stderr.close()
	if thread:
		thread.wait_to_finish()
		thread = null
	if pid > 0:
		OS.kill(pid)
	pid = 0

func test_environment(build_context):
	print("Export-Templater: Running env tests")
	print("Export-Templater: Build Path: " + build_context)
	# Tests to run. Are folders visible, are files visible, is docker running
	# Do our scripts exist
	assert(DirAccess.dir_exists_absolute(build_context+"/scripts"), 
	"Export-Templater: Could not find the scripts folder. Should be at " + build_context + "/scripts")
	assert(FileAccess.file_exists(build_context+"/scripts/env_setup.sh"), 
	"Export-Templater: Could not find env_setup.sh")
	assert(FileAccess.file_exists(build_context+"/scripts/build_templates.py"), 
	"Export-Templater: Could not find build_templates.py")
	
	# Does output folder exist?
	if(!DirAccess.dir_exists_absolute(build_context+"/output")):
		print("Output Folder Missing. Attempting to create...")
		DirAccess.make_dir_absolute(build_context+"/output")
	assert(DirAccess.dir_exists_absolute(build_context+"/output"), 
	"Export-Templater: Could not find the Output Folder. Should be at " + build_context + "/output")
	
	# Does our config folder exist
	if(!DirAccess.dir_exists_absolute(build_context+"/config")):
		print("Config Folder Missing. Attempting to create...")
		DirAccess.make_dir_absolute(build_context+"/config")
	assert(DirAccess.dir_exists_absolute(build_context+"/config"), 
	"Export-Templater: Could not find the Config Folder. Should be at " + build_context + "/config")
	
	print("Export-Templater: Testing complete!")
