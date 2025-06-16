@tool
class_name ExportTemplater extends EditorPlugin

# To be incremented when the dockerfile itself changes
const DOCKER_IMAGE_VERSION = "v0.2.1"
var image_tag = "godot-templater:"+DOCKER_IMAGE_VERSION

const EXPORT_TEMPLATER_POPUP = preload("res://addons/exporttemplater/ExportTemplaterPopup.tscn")

var active_pipe: FileAccess
var stderr: FileAccess
var pid: int
var thread: Thread
var build_context: String

signal pipe_line(line)
signal pipe_done

func _enter_tree() -> void:
	# Create the menu item
	add_tool_menu_item("Build Export Template", show_options)
	# Test if docker is available
	is_docker_available()

func _exit_tree() -> void:
	# Remove the menu item to prevent errors
	remove_tool_menu_item("Build Export Template")
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
	popup.connect("build_requested", create_godot_template) 

## The real part of this script
func create_godot_template(version, encryption_key, platform, target, arch, profile):
	#First we build the image which we need to switch to a pipe
	await create_docker_build(image_tag)
	await run_docker_script(version, encryption_key, platform, target, arch, profile)
	print("Complete! Check output folder for templates")


## Creates the docker image from the Dockerfile (takes a while if there is no cache)
signal docker_build_complete
func create_docker_build(version):
	print("Building Docker image")
	print("This may take a while...")
	
	# Get the correct path based on where this script is
	var res_path = get_script().resource_path
	var dockerfile_abs_path = ProjectSettings.globalize_path(res_path)
	build_context = dockerfile_abs_path.get_base_dir()
	
	var bin = "docker"
	var args = ["build", "--progress=plain", "-t", image_tag, build_context]
	
	var pipe := OS.execute_with_pipe(bin, args)
	get_window().close_requested.connect(clean_thread)
	if pipe.size() == 0:
		# Something went wrong
		print("Docker Image Build Failed")
		return
	await start_pipe_thread(pipe)
	print("Image Built")

func run_docker_script(version, encryption_key, platform, target, arch, profile: String):
	print("Running Docker container")
	print("This will take an eternity... (go drink some water)")
	# Won't print from the command until the end for some reason so this will do for now
	print("Cloning Godot repo")
	# docker run --rm -v /abs/path/to/project:/project -v /abs/path/to/out:/out godot-templater:v0.1.0 /project/scripts/build_template.sh
	# Set up the command here
	var script_path = "/workspace/scripts/build_templates.sh"
	var bin = "docker"
	var args = [
		"run", "--rm",
		"-v", build_context + "/output:/workspace/output",
		"-v", build_context + "/build_profiles:/workspace/profiles",
		image_tag,
		script_path,
		"-b", version,
		"-k", encryption_key,
		"-r", target,
		"-p", platform,
		"-a", arch,
	]
	print("GDSFDS "+profile)
	if profile != "":
		args.append("-c")
		args.append("/workspace/profiles/"+profile)
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
