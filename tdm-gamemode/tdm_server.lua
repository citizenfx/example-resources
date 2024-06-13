--[[
    File: tdm_server.lua
    Description:
        This file handles server-side logic for the Team Deathmatch (TDM) game mode. 
        It includes functions for team management, player kills tracking, team data updates, and game state maintenance.

    Functions:
        - Team.new: Constructs a new Team object representing a team in the TDM game mode.
        - Team:destroy: Destroys the Team object, resetting its properties.
        - Team:getName: Retrieves the name of the team.
        - Team:incrementKills: Increments the kill count for the team.

        - TDMGame.new: Initializes a new instance of the TDMGame class.
        - TDMGame:shutDown: Cleans up resources and stops the TDM game.
        - TDMGame:getPlayerTeam: Retrieves the team instance for a player.
        - TDMGame:getLeadingTeam: Determines the leading team based on kills count.

    Event Handlers:
        - tdm:onPlayerKilled: https://docs.fivem.net/docs/resources/example-resources/events/tdm-gamemode/onPlayerKilled/

    Variables:
        - teamAssignments: Stores player assignments to different teams for balancing purposes.
        - g_PlayerTeams: Maps player IDs to their assigned team IDs.
    
    Classes:
        - Team: Represents a team in the TDM game mode.
        - TDMGame: Manages the overall game state and logic for the TDM game mode.
]]


-- Define the Team class
Team = {}
Team.__index = Team

--- Constructs a new Team object.
-- @param teamID The ID of the team.
-- @param basePosition The base position of the team.
-- @param playerModel The player model associated with the team.
-- @param playerHeading The desired player heading on spawn.
-- @return Team The newly created Team object.
function Team.new(teamID, basePosition, playerModel, playerHeading)
    local self = setmetatable({}, Team)
    self.id = teamID             -- The ID of the team.
    self.kills = 0               -- The number of kills for the team.
    self.basePosition = basePosition  -- The base position of the team.
    self.playerModel = playerModel    -- The player model associated with the team.
    self.playerHeading = playerHeading -- The desired player heading on spawn.
    return self
end

--- Destroy the Team's instanced object.
-- It will first destroy the team's entity (the base object), it will also reset certain properties of the class.
-- Finally, it will set the metatable to nil, TDMGame:shutDown provides an example of this using iteration.
-- 
-- Example:
-- ```lua
-- local blueTeam = Team.new(tdmConfig.type.TEAM_RED, vector3(2555.1860, -333.1058, 92.9928), 'a_m_y_beachvesp_01')
-- blueTeam:destroy()
-- ```
function Team:destroy()
    self.id = -1
    self.kills = 0
    self.basePosition = nil
    self.playerModel = ''

    setmetatable(self, nil)
end

--- Retrieves the name of the team.
--
-- Example:
-- ```lua
-- local blueTeam = Team.new(1, {0, 0, 255}, vector3(100.0, 0.0, 50.0), 'a_m_y_beachvesp_01')
-- blueTeam:getName()
-- ```
function Team:getName()
    if self.id == tdmConfig.type.TEAM_BLUE then
        return "Blue"
    end
    if self.id == tdmConfig.type.TEAM_RED then
        return "Red"
    end
    return "Spectator"
end

--- Increments the kill count for the created team instance
function Team:incrementKills(byNum)
    self.kills = self.kills + byNum
end

-- Define the TDMGame class
TDMGame = {}
TDMGame.__index = TDMGame

--- Creates a new instance of the TDMGame class.
-- This function initializes a new TDMGame object with default values.
-- It sets up the teams for the Team Deathmatch (TDM) game mode, including the team locations and player models.
-- The leading team is initialized as nil.
-- @return table A new instance of the TDMGame class.
function TDMGame.new()
    local self = setmetatable({}, TDMGame)
    self.teams = {}  -- Initialize teams as an empty table
    -- Initialize each team with their respective position, player model and heading
    -- These are loaded from tdm_config.lua
    for _, teamConfig in ipairs(tdmConfig.teams) do
        self.teams[teamConfig.id] = Team.new(
            teamConfig.id,
            teamConfig.basePosition,
            teamConfig.playerModel,
            teamConfig.playerHeading
        )
    end
    self.leadingTeam = nil
    return self
end

--- Call this method to end the game mode
-- Will destroy all team instances.
function TDMGame:shutDown()
    -- 'Dispose' on shutdown
    for _, team in ipairs(self.teams) do
        team:destroy()
    end
end

-- Define a method to get the team instance for a player
function TDMGame:getPlayerTeam(playerID)
    local playerState = Player(playerID).state
    local teamID = playerState.teamID
    if teamID then
        return self.teams[teamID]
    else
        return nil
    end
end

-- Define the TDMGame method to get the leading team
function TDMGame:getLeadingTeam()
    for _, team in pairs(self.teams) do
        if not self.leadingTeam or team.kills > self.leadingTeam.kills then
            self.leadingTeam = team
        end
    end
    return self.leadingTeam
end

-- Creating a TDM game
local tdmGame = TDMGame.new()

-------------------------------------- Event Handlers --------------------------------------

-- Event handler for player kills
RegisterNetEvent("tdm:onPlayerKilled")
AddEventHandler("tdm:onPlayerKilled", function(killerID, victimID)
    -- The player wasn't killed by another player.
    if killerID == 0 or victimID == 0 then return end

    -- We cannot trust the client, clients can lie to us and fabricate information.
    -- We're the server and we have state-awareness over what's happening.
    -- Let's do a simple check to verify that they died by who they said they did.
    local victimDeathSource = GetPedSourceOfDeath(GetPlayerPed(victimID))
    if victimDeathSource ~= GetPlayerPed(killerID) then
        -- They lied to us, so we give them nothing.
        print(string.format("%s is possibly sending fake events.", GetPlayerName(killerID)))
        return
    end

    -- Looks good, let's continue by retrieving the killer's team instance
    local killerTeam = tdmGame:getPlayerTeam(killerID)
    local victimTeam = tdmGame:getPlayerTeam(victimID)

    if killerTeam.id == victimTeam.id then
        TriggerClientEvent("killPlayer", killerID)
        -- Color coding can also be added to strings (~r~), for more check: https://docs.fivem.net/docs/game-references/text-formatting/
        TriggerClientEvent("SendClientHudNotification", killerID, "~r~Friendly fire won't be tolerated!")
        return
    end

    if killerTeam then
        -- Increment the team kills
        killerTeam:incrementKills(1)
        
        -- Notify clients about the leading team
        local leadingTeam = tdmGame:getLeadingTeam()
        if leadingTeam then
            local message = string.format("Team %s is leading with %s kill(s)", leadingTeam:getName(), leadingTeam.kills)
            -- Send a notification to every client, indicating by sending -1 as the source parameter
            TriggerClientEvent("SendClientHudNotification", -1, message)
        end
    else
        print("Player killed. Killer's team not found (error).")
    end
end)

--- A server-side event that is triggered when a player has a finally-assigned NetID.
-- See the following link for more:
-- https://docs.fivem.net/docs/scripting-reference/events/server-events/
RegisterServerEvent('playerJoining')
AddEventHandler('playerJoining', function(source, oldID)
    Player(source).state.teamID = tdmConfig.type.TEAM_RED -- Initialize to team red
    TriggerEvent("sendTeamDataToClient", source) -- Trigger the event locally (on the server)
end)

-- Register a server event to send team data to clients
RegisterServerEvent("sendTeamDataToClient")

-- Event handler for sending team data to clients
AddEventHandler("sendTeamDataToClient", function(source)
    -- Create an array to store team data
    local teamsDataArray = {}
    -- Iterate through each team in tdmGame.teams
    for _, team in ipairs(tdmGame.teams) do
        -- Exclude TEAM_SPECTATOR from the data
        if team.id ~= tdmConfig.type.TEAM_SPECTATOR then
            -- Create a table containing team information
            local teamData = {
                id = team.id,
                name = team:getName(),
                basePosition = team.basePosition,
                playerModel = team.playerModel,
                playerHeading = team.playerHeading
            }
            -- Insert the team data table into teamsDataArray
            teamsDataArray[#teamsDataArray+1] = teamData
        end
    end
    -- Trigger the "receiveTeamData" event on the client with the team data array
    TriggerClientEvent("receiveTeamData", source, teamsDataArray)
end)

--- The requestTeamData event.
-- This is triggered by the client via TriggerServerEvent.
-- This event is used to call another event that sends the team data to the client.
-- We trigger a local event (registered on the server) named 'sendTeamDataToClient'.
--
-- @param source (number) The player's NetID (a number in Lua/JS).
RegisterServerEvent('requestTeamData')
AddEventHandler('requestTeamData', function()
    TriggerEvent("sendTeamDataToClient", source)
end)

--- Triggered when the resource is stopping.
-- This event can be triggered by the client via TriggerServerEvent.
--
-- @param resourceName (string) The resource name, i.e. tdm_server.
AddEventHandler('onResourceStop', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then
        return
    end
    -- The gamemode is over, call our shutdown method which will remove the flags
    tdmGame:shutDown()
    print('The resource ' .. resourceName .. ' was stopped.')
end)

-------------------------------------- Commands --------------------------------------

--- Shutdown command used to clean-up the game mode (removes teams)
-- For more information on RegisterCommand, see the following link:
-- https://docs.fivem.net/natives/?_0x5FA79B0F
RegisterCommand("shutdown", function(source, args, rawCommand)
    tdmGame:shutDown()
end, true)
