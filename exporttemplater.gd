@tool
class_name ExportTemplater extends EditorPlugin

const DOCKER_IMAGE_VERSION = "v0.1.0"
var image_tag = "godot-templater:"+DOCKER_IMAGE_VERSION

const EXPORT_TEMPLATER_POPUP = preload("res://addons/exporttemplater/ExportTemplaterPopup.tscn")

var active_pipe: FileAccess
var stderr: FileAccess
var pid: int
var thread: Thread

var build_context

func _enter_tree() -> void:
	# Create the menu item
	add_tool_menu_item("Build Export Template", show_options)
	# Test if docker is available
	if !is_docker_available():
		return

func _exit_tree() -> void:
	# Remove the menu item to prevent errors
	remove_tool_menu_item("Build Export Template")

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

## Creates the docker image from the Dockerfile (takes a while if there is no cache)
func create_docker_build(version):
	
	# This section gets the correct path based on where this script is
	var res_path = get_script().resource_path
	var dockerfile_abs_path = ProjectSettings.globalize_path(res_path)
	build_context = dockerfile_abs_path.get_base_dir()
	
	var bin = "docker"
	var args = ["build", "--progress=plain", "-t", image_tag, build_context]
	print("BUILDING DOCKER IMAGE")
	print("THIS WILL TAKE TIME ON FIRST RUN!")
	var image_pipe := OS.execute_with_pipe(bin, args)
	get_window().close_requested.connect(clean_thread)
	if image_pipe.size() > 0: # we have successfully executed
		active_pipe = image_pipe["stdio"]
		stderr = image_pipe["stderr"]
		pid = image_pipe["pid"]
		
		thread = Thread.new()
		thread.start(_thread_func)
		
		var line=""
		while true:
			line = await pipe_in_progress
			if line == null:
				print("Finished!")
				break
			print(line)

func show_options():
	var popup = EXPORT_TEMPLATER_POPUP.instantiate()
	get_editor_interface().get_base_control().add_child(popup)
	popup.popup_centered()
	popup.connect("build_requested", create_godot_template)

func create_godot_template(version, encryption_key, platform, target, arch, profile):
	#First we build the image which we need to switch to a pipe
	create_docker_build(image_tag)
	
	# docker run --rm -v /abs/path/to/project:/project -v /abs/path/to/out:/out godot-templater:v0.1.0 /project/scripts/build_template.sh
	var abs_project = ProjectSettings.globalize_path("res://")
	var abs_out = ProjectSettings.globalize_path("res://build_output")
	var script_path = "/workspace/scripts/build_templates.sh"
	var bin = "docker"
	var args = [
		"run", "--rm",
		"-v", build_context + "/output:/out",
		"-v", build_context + "/build_profiles:/profiles",
		image_tag,
		script_path,
		"-b", version,
		"-k", encryption_key,
		"-c", profile,
		"-r", target,
		"-p", platform,
		"-a", arch
	]
	
	var image_pipe := OS.execute_with_pipe(bin, args)
	get_window().close_requested.connect(clean_thread)
	if image_pipe.size() > 0: # we have successfully executed
		active_pipe = image_pipe["stdio"]
		stderr = image_pipe["stderr"]
		pid = image_pipe["pid"]
		
		thread = Thread.new()
		thread.start(_thread_func)
		
		var line=""
		while true:
			line = await pipe_in_progress
			if line == null:
				print("Finished!")
				break
			print(line)
	
	return

func _process(delta: float) -> void:
	pass

signal pipe_in_progress
func _thread_func():
	var line = ""
	var pipe_err
	var err_output
	while active_pipe.is_open():
		pipe_err = active_pipe.get_error() 
		err_output = active_pipe.get_error()
		if pipe_err == OK:
			line = active_pipe.get_line()
			pipe_in_progress.emit.call_deferred(line)
			pass
		else:
			line=stderr.get_line()
			if line!="":
				pipe_in_progress.emit.call_deferred(line)
			else:
				break
	pipe_in_progress.emit.call_deferred(null)
	call_deferred("clean_thread")
	
func clean_thread():
	active_pipe.close()
	stderr.close()
	thread.wait_to_finish()
	OS.kill(pid)
