# Capture The Flag (CTF) Game Mode

Welcome! 

This directory contains the source code and resources for implementing a CTF game mode in your game project. 

Whether you're building a multiplayer game, experimenting with game mechanics, or enhancing an existing project, this CTF game mode provides a starting point to get you started.

## Server/Client Logic

- **ctf_client.lua:** Handles flag logic and team selection.
- **ctf_rendering.lua:** Handles drawing on the client.
- **ctf_server.lua:** Handles most of the CTF logic (this involves capturing, dropping and taking the flag).
- **ctf_shared.lua:** Has some structs (and lua tables) and a single function that is shared by the server and the client. Documentation about the `shared_script` directive can be found [here](https://docs.fivem.net/docs/scripting-reference/resource-manifest/resource-manifest/#shared_script).

### Multiple classes are present

For the server logic, team and flag objects 'classes' are used, Lua supports such in the form of metatables under [chapter 16.1](https://www.lua.org/pil/16.1.html). 

Classes used in this game-mode are detailed down below:

- **CTFGame:** The main class that simply holds a `CTFGame:Update` method, its `constructor` (to initialize flags and teams) and a `CTFGame:shutDown` method that is used to 'dispose' of any flag or team instances once `onResourceStop` gets called.
- **Flag:** Used for each `Flag` instance, each `Flag` can have different states and they're tied to a team.
- **Team:** An instance of `Team` stores the base position and each team color, teams (referred by `CTFGame` as `self.teams`) are **Blue**, **Red** and **Spectator** (where **Spectator** is simply a placeholder at the moment).

## Features

This game mode utilizes the following FiveM features:

- [**State Bags**](https://docs.fivem.net/docs/scripting-manual/networking/state-bags): To keep track of any entity states between client and server.

## Small Todos

- Put the bases farther away from each other, mainly close for testing.
