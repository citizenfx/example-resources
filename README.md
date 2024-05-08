# Gamemode Examples

Welcome to the Gamemode Examples Repository. Here, you'll find resources for a variety of gamemodes. Our primary goal is to provide documented official methods for creating gamemodes, thoroughly reviewed by our team. Please note that these resources may evolve to incorporate technological advancements and community feedback. 

Additionally, we may introduce new gamemodes in the future. 

Explore, learn, and stay tuned for updates as we continue to expand our repository!

### These resources cover the following topics

- Usage of natives
- Use of events
- Use of spawn manager
- State bags


## Resources

In FiveM, a 'resource' is essentially a structured folder containing various files that contribute to modifying or enhancing gameplay on a FiveM server. 

These resources can include scripts for gameplay mechanics, assets like models and textures for new objects or vehicles, and other files that enhance the overall gaming experience on a FiveM server. 

Server owners and developers can use these resources to customize and tailor their server to their preferences and the desires of their community.

- [TDM Gamemode](./tdm-gamemode): A simple team death match game mode where players are put in teams and are allowed to compete against each other.
- [CTF Gamemode](./ctf-gamemode): A game mode that involves capturing an objective by taking it from point A to B.

## Getting Started

We recommend checking out this [guide](https://docs.fivem.net/docs/scripting-manual/introduction/creating-your-first-script/) *(Creating your first script in Lua)*, as a starting point to set up the game modes. This guide assumes you already have a server set up, if not, you may follow one of [these guides](https://docs.fivem.net/docs/server-manual/setting-up-a-server/) *(Setting up a server)*.

### The Resource Manifest

The manifest file (`fxmanifest.lua`) is used to define what files/scripts are used by the resource. More about it can be found in [Introduction to resources](https://docs.fivem.net/docs/scripting-manual/introduction/introduction-to-resources/).

### Natives

It's important to note that when you browse the files mentioned above, you will see many function calls that don't seem to be declared anywhere; those are most likely natives, i.e., [`SetEntityCoords`](https://docs.fivem.net/natives/?_0xDF70B41B).

Natives are used to call in-game function methods that execute larger chunks of game logic within the game. It's how the game mode communicates with the game-client (when called via client scripts such as `client.lua` or `shared.lua`).

If called on the server side, it may call server-related natives and not client natives, but client natives can still be called by the server via RPC (Remote Procedure Call).

The full list of natives and their corresponding documentation can be found [here](https://docs.fivem.net/natives/).

### Events

The game mode makes use of events (server and client) to communicate data back and forth. Documentation regarding events can be found [here](https://docs.fivem.net/docs/scripting-manual/working-with-events/triggering-events/).
