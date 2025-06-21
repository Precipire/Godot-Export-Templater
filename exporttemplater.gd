@tool
class_name ExportTemplater extends EditorPlugin

# To be incremented when the dockerfile itself changes
var DOCKER_IMAGE_VERSION = "v0.3.5"
var image_tag = "godot-templater:"+DOCKER_IMAGE_VERSION

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
	
	# get core count
	core_count = OS.get_processor_count()
	print(core_count)

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
	if !popup.is_connected("build_requested", create_godot_template):
		popup.build_requested.connect(create_godot_template) 

## The real part of this script
func create_godot_template(build_info):
	# Turn build info into a JSON file inside the config folder
	var res_path = get_script().resource_path
	var abs_path = ProjectSettings.globalize_path(res_path)
	build_context = abs_path.get_base_dir()
	var json = JSON.stringify(build_info)
	var config_file = FileAccess.open(build_context + "/config/data.json", FileAccess.WRITE)
	config_file.store_line(json)
	#First we build the image which we need to switch to a pipe
	await create_docker_build(image_tag)

	await run_docker_script(build_info)
	print("Complete! Check output folder for templates")


## Creates the docker image from the Dockerfile (takes a while if there is no cache)
signal docker_build_complete
func create_docker_build(version):
	print("Building Docker image")
	print("This may take a while...")
	
	# Get the correct path based on where this script is

	
	var bin = "docker"
	var args = ["build", "--progress=plain", "-t", image_tag, build_context]
	
	var pipe := OS.execute_with_pipe(bin, args)
	if !get_window().is_connected("close_requested",clean_thread):
		get_window().close_requested.connect(clean_thread)
	if pipe.size() == 0:
		# Something went wrong
		print("Docker Image Build Failed")
		return
	await start_pipe_thread(pipe)
	print("Image Built")

func run_docker_script(build_info):
	print("Running Docker container")
	print("This will take an eternity... (go drink some water)")
	# Won't print from the command until the end for some reason so this will do for now
	# docker run --rm -v /abs/path/to/project:/project -v /abs/path/to/out:/out godot-templater:v0.1.0 /project/scripts/build_template.sh
	# Set up the command here
	var script_path = "/workspace/scripts/env_setup.sh"
	var bin = "docker"
	var args = [
		"run", "--rm",
		"--cpus", str(core_count-2),
		"-v", build_context + "/scripts:/workspace/scripts",
		"-v", build_context + "/output:/workspace/output",
		"-v", build_context + "/build_profiles:/workspace/profiles",
		"-v", build_context + "/config:/workspace/config",
		image_tag,
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
