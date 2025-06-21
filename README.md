# Godot Export Templater
Create encrypted export templates right inside of Godot!

Requires Docker to be installed and running (https://docs.docker.com/get-started/get-docker/)

## Usage
1. Download and install Docker
2. Make sure Docker Engine is running
3. Download this project
4. Place it in addons folder of a godot project
5. Active the plugin in **Project -> Project Settings -> Plugins**
6. Open the tool in **Project -> Tools -> Build Export Template**
7. Fill out the fields
8. Press Start Build. Text will appear in the console and it will start building the docker image. 
Once built it will start making the templates. 
There is a current bug with getting the stdio and stderr from the container so only part of the console prints. 
Check the actual container logs for a more live view
9. Get comfy this is a slooow process (depending on your specs)
10. If all goes well there should be files placed in the output folder of the plugin

## Features
- Hassle-free creation of export templates for Godot (Current)
- In-Editor interface for selecting and building
- Docker-based containerization of tools for cross-platform compatability
- Add encryption to your exports!

## TO-DO
- Add in remaining platforms (Android, C# support)
- Test Linux functionality
- Add build profile support
- Add option for engine string stripping (to make finding the encryption key more difficult)
- Add in more niche options for platforms
- Build profile support

## Known Bugs
- Console won't print the whole output
- Godot has some *seemingly* random crashes
- Godot sometimes won't start the container if building the docker image for the first time
