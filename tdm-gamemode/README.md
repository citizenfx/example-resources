# Team Deathmatch (TDM) Game Mode

Welcome! 

This repository contains the source code and resources for implementing a TDM game mode in your game project. 

Whether you're building a multiplayer game, experimenting with game mechanics, or enhancing an existing project, this TDM game mode provides a starting point to get you started.

## Server/Client Logic

- **client.lua:** Handles drawing on the client as well as team selection.
- **server.lua:** Handles most of the TDM logic.
- **shared.lua:** Has some structs (and lua tables) and a single function that is shared by the server and the client. Documentation about the `shared_script` directive can be found [here](https://docs.fivem.net/docs/scripting-reference/resource-manifest/resource-manifest/#shared_script).

### Multiple classes are present

For the server logic and teams 'classes' are used, Lua supports such in the form of metatables under [chapter 16.1](https://www.lua.org/pil/16.1.html). 

Classes used in this game-mode are detailed down below:

- **TDMGame:** The main class used to interact with teams, its `constructor` (to initialize teams) and a `TDMGame:shutDown` method that is used to 'dispose' of any team instances once `onResourceStop` gets called.
- **Team:** An instance of `Team` stores the base position and each team color, teams (referred by `TDMGame` as `self.teams`) are **Blue**, **Red** and **Spectator** (where **Spectator** is simply a placeholder at the moment).

## Features

This game mode utilizes the following FiveM features:

- [**State Bags**](https://docs.fivem.net/docs/scripting-manual/networking/state-bags): To keep track of any entity states between client and server.
