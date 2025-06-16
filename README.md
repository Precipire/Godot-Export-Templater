# Godot Export Templater
Create encrypted export templates right inside of Godot!

Requires Docker to be installed and running (https://docs.docker.com/get-started/get-docker/)

## Usage
1. Download and install Docker
2. Make sure Docker Engine is running
3. Download this project
4. Place it in a godot project
5. Active the plugin in **Project -> Project Settings -> Plugins**
6. Open the tool in **Project -> Tools -> Build Export Template**
7. Enter an encryption key (AES-256-cbc)
8. Choose the Godot Version 
9. Choose the Platform for the build
10. Choose the Target. This is whether you are building an editor, a debug build, or a release build
11. Choose the Architecture. Auto should just choose your systems architecure but you can change it if needed
12. Ignore build profile for now
14. Press Start Build. Text will appear in the console and it will start building the docker image. Once built it will start making the templates. There is a current bug with getting the stdio and stderr from the container so only part of the console prints. Check the actual container logs for a more live view
15. Get comfy this is a slooow process
16. If all goes well there should be files places in the output folder of the plugin


## Features
- Hassle-free creation of export templates for Godot
- In-Editor interface for selecting and building
- Docker-based containerization of tools for cross-platform compatability
- Add encryption for your exports!

## TO-DO
- Verify all export templates are functional
- Add build profile support
- Add option for engine string stripping (to make finding the encryption key more difficult)

## Known Bugs
- Console won't print the whole output
- build profiles DO NOT WORK 
- Godot will crash if the docker process doesn't exit cleanly