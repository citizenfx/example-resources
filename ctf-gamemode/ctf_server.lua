--[[
    File: ctf_server.lua
    Description:
        This file handles server-side logic for the Capture the Flag (CTF) game mode. 
        It includes functions for team balancing, player-team assignments, flag management, and game state updates.

    Functions:
        - GetCTFGame: Retrieves or creates an instance of the CTFGame class.
        - CTFGame.new: Constructs a new CTFGame instance.
        - CTFGame:start: Initializes the CTF game by creating teams and flags.
        - CTFGame:update: Updates the game state including flag interactions, player scores, and flag status changes.
        - CTFGame:shutDown: Handles cleanup tasks upon game shutdown, including flag and team destruction.

    Event Handlers:
        - playerJoining: https://docs.fivem.net/docs/resources/example-resources/events/cft-gamemode/playerJoining/
        - requestTeamData: https://docs.fivem.net/docs/resources/example-resources/events/cft-gamemode/requestTeamData/
        - sendTeamDataToClient: https://docs.fivem.net/docs/resources/example-resources/events/cft-gamemode/sendTeamDataToClient/
        - assignPlayerTeam: https://docs.fivem.net/docs/resources/example-resources/events/cft-gamemode/assignPlayerTeam/
    
    Classes:
        - Team: Represents a team in the CTF game mode.
            - new: Creates a new Team instance.
            - createBaseObject: Creates the base object associated with the team.
            - getName: Retrieves the name of the team.
            - updateScore: Updates the team's score.
            - goalBaseHasEntityInRadius: Checks if the base has a given entity in range.
            - destroy: Destroys the team object.

        - Flag: Represents a flag in the CTF game mode.
            - new: Creates a new Flag instance.
            - spawn: Spawns the flag in the game world.
            - getFlagStatus: Retrieves the current status of the flag.
            - getFlagNetworkedID: Retrieves the networked ID of the flag.
            - carrierDied: Checks if the carrier of the flag has died.
            - isBeingCarried: Checks if the flag is being carried by a player.
            - isTaken: Checks if the flag has been taken.
            - isCaptured: Checks if the flag has been captured.
            - isDropped: Checks if the flag has been dropped.
            - isAtBase: Checks if the flag is at its base.
            - setNextCooldown: Sets the next cooldown time for the flag.
            - isPastCooldown: Checks if the flag's cooldown has elapsed.
            - setStatus: Sets the status of the flag.
            - hasEntityInRadius: Checks if an entity is within the flag's radius.
            - setPosition: Sets the position of the flag.
            - sendBackToBase: Sends the flag back to its base.
            - destroy: Destroys the flag object.

        - CTFGame: Manages the overall game state and logic for the CTF game mode.
            - new: Creates a new CTFGame instance.
            - start: Initializes the game by creating teams and flags.
            - update: Updates the game state based on player interactions and flag status changes.
            - shutDown: Cleans up resources and stops the game.

    Notes:
        - The CTF game mode relies on consistent team assignments, flag status updates, and player interactions to function correctly.
        - Adjust game parameters and logic as needed to maintain balance and fairness.
]]

-- UI related variables.
-- Create a local reference to ctfConfig.UI
local UIConfig = ctfConfig.UI

-- Access 'screenCaptions' properties from the 'ctfConfig.UI' table referenced by 'UIConfig'.
local screenCaptions = UIConfig.screenCaptions

-- Define the Team class
Team = {}
Team.__index = Team

--- Creates a new Team instance.
-- Example:
-- @see CTFGame.new

-- @param id (number) The unique identifier for the team.
-- @param flagColor (table) The RGB color values representing the team's flag color.
-- @param basePosition (vector3) The base position where the team's flag is located.
-- @return Team A new Team instance.
--
function Team.new(id, flagColor, basePosition, playerModel, playerHeading)
    -- Set the metatable for the self table to the Team table.
    -- This allows instances of Team to inherit properties and methods.
    local self = setmetatable({}, Team)

    -- Assign values to the properties of the new Team instance.
    self.id = id
    self.flagColor = flagColor
    self.basePosition = basePosition
    self.entity = nil
    self.score = 0
    self.playerModel = playerModel
    self.playerHeading = playerHeading -- The desired player heading on spawn.

    -- Return the newly created Team instance.
    return self
end

--- Creates the base object entity associated with the team.
--
-- Example:
-- @see CTFGame:start
--
function Team:createBaseObject()
    -- Calls server setter CREATE_OBJECT_NO_OFFSET, to create an entity on the server
    -- Adjust z-coord, so its flushed to the ground.
    local baseEntity = CreateObjectNoOffset(
        `xs_propint2_stand_thin_02_ring`,
        self.basePosition.x, self.basePosition.y, self.basePosition.z - 0.85
    )

    -- wait until it has been created
    while not DoesEntityExist(baseEntity) do
        Wait(1)
    end

    -- Now that it's created we can set its state
    self.entity = Entity(baseEntity)

    -- Assign a networked ID
    self.networkedID = NetworkGetNetworkIdFromEntity(self.entity)
end

function Team:goalBaseHasEntityInRadius(targetEntity, radius)
    radius = radius or 2.5  -- Default radius is 2.5 if not provided
    local targetEntityPos = GetEntityCoords(targetEntity)
    local distance = #(self.basePosition - targetEntityPos)
    return distance < radius  -- Adjust the distance as needed
end

--- Retrieves the name of the team.
--
-- Example:
-- ```lua
-- local blueTeam = Team.new(1, {0, 0, 255}, vector3(100.0, 0.0, 50.0))
-- blueTeam:getName()
-- ```
function Team:getName()
    if self.id == TeamType.TEAM_BLUE then
        return "Blue"
    end
    if self.id == TeamType.TEAM_RED then
        return "Red"
    end
    return "Spectator"
end

--- Update's the team's score.
-- Example:
-- ```lua
-- local blueTeam = Team.new(1, {0, 0, 255}, vector3(100.0, 0.0, 50.0))
-- blueTeam:updateScore(1)
-- ```
-- @param score (number) How much to update the score by.
--
function Team:updateScore(score)
    self.score = self.score + score
end

--- Destroy the Team's instanced object.
-- It will first destroy the team's entity (the base object), it will also reset certain properties of the class.
-- Finally, it will set the metatable to nil, CTFGame:shutDown provides an example of this using iteration.
-- 
-- Example:
-- ```lua
-- local blueTeam = Team.new(1, {0, 0, 255}, vector3(100.0, 0.0, 50.0))
-- blueTeam:destroy()
-- ```
function Team:destroy()
    DeleteEntity(self.entity)

    self.id = -1
    self.flagColor = {0, 0, 0}
    self.basePosition = nil
    self.entity = nil

    setmetatable(self, nil)
end

-- Define the Flag class
Flag = {}
Flag.__index = Flag

--- Creates a new Flag instance.
-- Example:
-- ```lua
-- local blueFlag = Flag.new(1, `prop_flag_ls`, blueTeam, vector3(100.0, 0.0, 50.0))
-- ```
-- @param id (number) The unique identifier for the flag.
-- @param modelHash (number) The model hash of the flag.
-- @param team (Team) The Team instance to which the flag belongs.
-- @param spawnPosition (vector3) The initial spawn position of the flag.
-- @return Flag A new Flag instance.
--
function Flag.new(id, modelHash, team, spawnPosition)
    local self = setmetatable({}, Flag)
    self.id = id
    self.modelHash = modelHash
    self.entity = nil
    self.team = team
    self.spawnPosition = spawnPosition
    self.hasBeenCaptured = false
    self.networkedID = -1
    return self
end

--- Spawns a new flag entity.
-- This method spawns a new flag entity at the specified position. 
-- It creates an object on the server using the CreateObjectNoOffset function, 
-- waits until the entity has been created, and then sets its initial state properties.
-- You may refer to CTFGame:start to see how this method is implemented (example code).
-- @see CTFGame:start
--
-- @return (Flag) A new Flag instance.
--
-- @see CreateObjectNoOffset
-- @see DoesEntityExist
-- @see NetworkGetNetworkIdFromEntity
-- @see EFlagStatuses
function Flag:spawn()
    print('^5[INFO] ^7Spawning flag at: ' .. tostring(self.spawnPosition))
    -- Calls server setter CREATE_OBJECT_NO_OFFSET, to create an entity on the server
    local flagEntity = CreateObjectNoOffset(self.modelHash, self.spawnPosition)

    while not DoesEntityExist(flagEntity) do -- wait until it has been created
        Wait(1)
    end

    -- Make the object fall so it doesn't stay still in the air by setting the z-velocity
    SetEntityVelocity(flagEntity, 0, 0, -1.0)

    -- Now that it's created we can set its state
    self.entity = Entity(flagEntity)
    self.networkedID = NetworkGetNetworkIdFromEntity(self.entity)

    --local ent = Entity(NetworkGetEntityFromNetworkId(self.networkedID))

    self.entity.state.networkedID = self.networkedID
    self.entity.state.teamID = self.team.id
    self.entity.state.position = self.spawnPosition
    self.entity.state.flagColor = self.team.flagColor
    self.entity.state.flagStatus = EFlagStatuses.AT_BASE
    self.entity.state.carrierId = -1 -- The player that is carrying the flag
    self.entity.state.lastCooldown = GetGameTimer()
    self.entity.state.autoReturnTime = GetGameTimer()
end


--- This method returns the current status of the flag by accessing its flagStatus property from the entity state.
-- Example:
-- ```lua
-- local flagStatus = blueFlag:getFlagStatus()
-- ```
-- @return (number) The status of the flag represented by an enum value.
-- @see EFlagStatuses
function Flag:getFlagStatus()
    return self.entity.state.flagStatus
end

--- Returns the Networked ID of the flag, set by Flag:spawn
-- @return (number) The status of the flag represented by an enum value.
function Flag:getFlagNetworkedID()
    return self.networkedID
end

function Flag:carrierDied()
    return self:getFlagStatus() == EFlagStatuses.CARRIER_DIED
end

function Flag:isBeingCarried()
    return self.entity.state.carrierId ~= -1
end

function Flag:isFlagCarrier(playerId)
    return self.entity.state.carrierId == playerId
end

function Flag:isTaken()
    return self:getFlagStatus() == EFlagStatuses.TAKEN
end

function Flag:isCaptured()
    return self:getFlagStatus() == EFlagStatuses.CAPTURED
end

function Flag:isDropped()
    return self:getFlagStatus() == EFlagStatuses.DROPPED
end

-- Method to check if the flag is at its base (spawn position)
function Flag:isAtBase()
    local distance = #(GetEntityCoords(self.entity) - self.spawnPosition)
    return distance < 5.0
end


--- Sets the next cooldown time for the flag.
--
-- @param timeMs (number) The time duration in milliseconds for the cooldown.
function Flag:setNextCooldown(timeMs)
    self.entity.state.lastCooldown = GetGameTimer() + timeMs
end

--- Sets the automatic return time for the flag (if it's dropped).
--
-- @param timeMs (number) The time duration in milliseconds for the return time.
function Flag:setAutoReturnTime(timeMs)
    self.entity.state.autoReturnTime = GetGameTimer() + timeMs
end

--- Checks if the flag's cooldown period has elapsed.
-- This function evaluates whether the current time exceeds the lastCooldown time of the flag instance. 
-- It serves as a check within the Capture The Flag (CTF) game logic to determine if the flag is available for interaction after a certain cooldown period has passed. 
-- By returning true when the cooldown period is over, it indicates that the flag is ready to be captured or interacted with again.
--
-- @return (boolean) Returns true if the cooldown period has elapsed, otherwise false.
function Flag:isPastCooldown()
    -- Check if the current time (in milliseconds) is greater than the last cooldown time
    return GetGameTimer() > self.entity.state.lastCooldown
end

--- Checks if the flag's auto return time period has elapsed.
-- This function evaluates whether the current time exceeds the autoReturnTime time of the flag instance. 
-- It serves as a check within the Capture The Flag (CTF) game logic to determine if the flag should be returned to base after a certain time period has passed. 
-- By returning true when the period is over, it indicates that the flag should be returned to base.
--
-- @return (boolean) Returns true if the auto-return time period has elapsed, otherwise false.
function Flag:isPastAutoReturnTime()
    -- Check if the current time (in milliseconds) is greater than the last cooldown time
    return GetGameTimer() > self.entity.state.autoReturnTime
end

--- Sets the flag status
-- @see EFlagStatuses
function Flag:setStatus(status)
    self.entity.state.flagStatus = status
end

--- Gets the flag status
-- @see EFlagStatuses
function Flag:getStatus()
    return self.entity.state.flagStatus
end

--- Checks if an entity is in radius
-- @return (boolean) Returns true if the entity is in radius of the targetEntity
function Flag:hasEntityInRadius(targetEntity, radius)
    return entityHasEntityInRadius(self.entity, targetEntity, radius)
end

--- Sets the position of the flag entity.
-- @param position (vector3) The new position to set for the flag.
function Flag:setPosition(position)
    print("^5[INFO] ^2setPosition: ^5" .. position .. " ^2entity: ^5" .. tostring(self.entity))
    SetEntityCoords(self.entity, position.x, position.y, position.z, true, true, true, true)
end

--- Sends the flag back to its base position.
-- This function resets the flag's status to 'at base', and sets its position back to the 
-- spawn position.
-- 
-- @usage Call this function to return the flag to its base position after certain events,
-- such as when it's dropped or captured.
--
function Flag:sendBackToBase()
    self:setNextCooldown(500)
    -- self.entity.state.carrierId

    self:setPosition(self.spawnPosition)

    self:setStatus(EFlagStatuses.AT_BASE)

    -- Make the object fall so it doesn't stay still in the air by setting the z-velocity
    SetEntityVelocity(self.entity, 0, 0, -1.0)

    self.entity.state.carrierId = -1

    TriggerClientEvent("SetObjectiveVisible", -1, self:getFlagNetworkedID(), true)

    print(string.format("Sent %s flag back to %f, %f, %f\n", self.team:getName(), self.spawnPosition.x, self.spawnPosition.y, self.spawnPosition.z))
end

---
-- Sets the flag as dropped and performs necessary actions.
-- This function is used to mark the flag as dropped, resetting its status, setting its 
-- position to the carrier's current position, and triggering client events.
-- 
-- @usage Call this function when the flag needs to be dropped.
--
function Flag:setAsDropped()
    local carrierId = self.entity.state.carrierId
    self:setStatus(EFlagStatuses.DROPPED)
    self:setPosition(GetEntityCoords(GetPlayerPed(carrierId)))
    self.entity.state.carrierId = -1
    self:setNextCooldown(5000) -- Set a cooldown so we can't perform any logic once it's dropping
    self:setAutoReturnTime(30000) -- Set auto return time to 30 seconds
    TriggerClientEvent("SetObjectiveVisible", -1, self:getFlagNetworkedID(), true)
end

--- Method to destroy the flag entity.
function Flag:destroy()
    print("Flag:destroy\n")
    DeleteEntity(self.entity)

    self.id = -1
    self.modelHash = modelHash
    self.entity = nil
    self.team = team
    self.spawnPosition = spawnPosition
    self.hasBeenCaptured = false
    self.networkedID = -1

    setmetatable(self, nil)
end

-- Define the CTFGame class
CTFGame = {}
CTFGame.__index = CTFGame

--- Constructs a new instance of the Capture The Flag (CTF) game. 
--  This method initializes the game state, including teams and flags,
--  and returns the initialized CTF game object.
--
--  The CTF game consists of teams and flags, each with specific properties and positions within the game world. 
--  Teams represent player factions, while flags denote objectives to be captured by opposing teams.
--
--  @return (CTFGame) A new CTFGame instance representing a CTF game environment.
function CTFGame.new()
    local self = setmetatable({}, CTFGame)
    self.teams = {}  -- Initialize teams as an empty table
    -- Initialize each team with their respective position, player model and heading
    -- These are loaded from ctf_config.lua
    for _, teamConfig in ipairs(ctfConfig.teams) do
        self.teams[teamConfig.id] = Team.new(
            teamConfig.id,
            teamConfig.flagColor,
            teamConfig.basePosition,
            teamConfig.playerModel,
            teamConfig.playerHeading
        )
    end
    -- Create flags based on the configuration
    self.flags = {}  -- Initialize flags as an empty table
    for _, flagConfig in ipairs(ctfConfig.flags) do
        self.flags[flagConfig.teamID] = Flag.new(
            flagConfig.teamID,
            flagConfig.model,
            self.teams[flagConfig.teamID],
            flagConfig.position
        )
    end
    self.leadingTeam = nil
    return self
end

--- Method to start the CTF game.
function CTFGame:start()
    for _, team in ipairs(self.teams) do
        team:createBaseObject()
    end

    for _, flag in ipairs(self.flags) do
        print('Spawning flag owned by team: ' .. flag.team.id)
        flag:spawn()
    end
end

--- Method to create or retrieve the CTFGame instance.
-- @return (CTFGame) The CTFGame instance.
function GetCTFGame()
    if not ctfGame then
        ctfGame = CTFGame.new()
    end
    return ctfGame
end

--- Retrieves the team of a player based on their source ID.
-- If the player's team ID is not found, it defaults to the spectator team.
--
-- @param source (number) The source ID of the player.
-- @return Team The team of the player, defaults to the spectator team if not found.
--
function CTFGame:getPlayerTeam(source)
    local playerState = Player(source).state
    local teamID = playerState.teamID
    local playerTeam = self.teams[teamID] or self.teams[TeamType.TEAM_SPECTATOR]
    return playerTeam 
end

--- Retrieves the flag based on the player's source ID and a boolean (`bGetEnemyFlag`).
-- If the boolean is set to retrieve the enemy flag (`bGetEnemyFlag`), 
-- it returns the flag of the opposing team. Otherwise, it returns the flag of the player's team.
--
-- @param source (number) The source ID of the player.
-- @param bGetEnemyFlag (boolean) Indicates whether to retrieve the enemy flag (true) or the player's team flag (false).
-- @return Flag The flag object corresponding to the specified criteria, or nil if not found.
--
function CTFGame:getFlag(source, bGetEnemyFlag)
    local playerTeam = self:getPlayerTeam(source)

    if bGetEnemyFlag then
        -- Assuming there are only two teams (TEAM_BLUE and TEAM_RED)
        local enemyTeamIndex = (playerTeam.id == TeamType.TEAM_BLUE) and TeamType.TEAM_RED or TeamType.TEAM_BLUE
        return self.flags[enemyTeamIndex] or nil
    else
        return self.flags[playerTeam.id] or nil
    end
    return nil
end

--- Return an instance of a flag, based on the teamID.
-- @return Flag The flag object corresponding to the specified criteria, or nil if not found.
function CTFGame:getFlagByTeamID(teamID)
    return self.flags[teamID] or nil
end

-- Helper functions

--- Captures the flag.
function CTFGame:captureFlag(flagToCapture, ourFlag, playerId)
    local playerTeam = self:getPlayerTeam(playerId)
    playerTeam:updateScore(1)
    SendClientHudNotification(
        -1, 
        string.format(
            "The %s team's flag has been captured.~n~Scores are %d-%d",
            flagToCapture.team:getName(),
            flagToCapture.team.score, 
            ourFlag.team.score
        )
    )
    PlaySoundForEveryone("BASE_JUMP_PASSED", "HUD_AWARDS")
    flagToCapture:sendBackToBase()
    TriggerEvent("sendTeamDataToClient", -1)
end

--- Takes the flag.
function CTFGame:attemptToTakeFlag(flagToCapture, playerPed, playerId)
    flagToCapture:setStatus(EFlagStatuses.TAKEN)
    TriggerClientEvent("SetObjectiveVisible", NetworkGetEntityOwner(flagToCapture.entity), flagToCapture:getFlagNetworkedID(), false)
    --TriggerClientEvent("AttachFlagToPlayer", NetworkGetEntityOwner(flagToCapture.entity), flagToCapture:getFlagNetworkedID(), playerId)
    flagToCapture.entity.state.carrierId = playerId
    flagToCapture:setNextCooldown(2000)
    PlaySoundForEveryone("CHALLENGE_UNLOCKED", "HUD_AWARDS")
    SendClientHudNotification(
        -1,
        string.format(
            screenCaptions.TeamFlagAction,
            flagToCapture.team:getName(),
            "taken"
        )
    )
end

--- Returns the flag.
function CTFGame:returnFlag(ourFlag)
    ourFlag:sendBackToBase()
    TriggerEvent("sendTeamDataToClient", -1)
    SendClientHudNotification(
        -1,
        string.format(
            screenCaptions.TeamFlagAction,
            ourFlag.team:getName(),
            "returned"
        )
    )
end

-- Method to update the CTF game state
function CTFGame:update()
    -- Check if any flags have been dropped
    for _, flagInstance in ipairs(ctfGame.flags) do
        if flagInstance:carrierDied() then
            flagInstance:setAsDropped()
            SendClientHudNotification(
                -1,
                string.format(
                    screenCaptions.TeamFlagAction,
                    flagInstance.team:getName(),
                    "dropped"
                )
            )
        
        elseif flagInstance:isDropped() then 
            -- -- If any flags have been dropped, check if they haven't been picked up for a while
            if flagInstance:isPastAutoReturnTime() then
                self:returnFlag(flagInstance)
            end
        end
    end
end

function SendClientHudNotification(source, message)
    TriggerClientEvent("SendClientHudNotification", source, message)
    -- Update the client's team data and hud status
    TriggerEvent("sendTeamDataToClient", source)
end

--- Call this method to end the game mode
-- Will destroy all flag and team instances.
function CTFGame:shutDown()
    -- 'Dispose' on shutdown
    for _, flag in ipairs(self.flags) do
        flag:destroy()
    end
    for _, team in ipairs(self.teams) do
        team:destroy()
    end
end

-- Instantiate the CTFGame
ctfGame = CTFGame.new()

-- Start the CTF game
ctfGame:start()

function PlaySoundForEveryone(soundName, soundSetName)
    TriggerClientEvent("PlaySoundFrontEnd", -1, soundName, soundSetName)
end

--- Gets called by the client when flag data is requested.
-- See ctf_client.lua, this gets called from processFlagLogic. 
-- Most of the flag logic on the server is handled here.
RegisterServerEvent('requestFlagUpdate')
AddEventHandler('requestFlagUpdate', function()
    print("requestFlagUpdate from: " .. source .. "\n")
    local playerPed = GetPlayerPed(source)
    local playerTeam = ctfGame:getPlayerTeam(source)

    -- Check if any flags have been taken, dropped or captured.
    if playerTeam.id ~= TeamType.TEAM_SPECTATOR then
        if GetEntityHealth(playerPed) < 1 then return end
        local ourFlag = ctfGame:getFlag(source, false)
        local flagToCapture = ctfGame:getFlag(source, true)
        if flagToCapture:isPastCooldown() and ourFlag:isPastCooldown() then
            if (flagToCapture:isDropped() or flagToCapture:isAtBase()) and flagToCapture:hasEntityInRadius(playerPed) then
                ctfGame:attemptToTakeFlag(flagToCapture, playerPed, source)
            elseif flagToCapture:isFlagCarrier(source) and ourFlag:isAtBase() then
                if playerTeam:goalBaseHasEntityInRadius(playerPed) then
                    ctfGame:captureFlag(flagToCapture, ourFlag, source)
                end
            elseif ourFlag:hasEntityInRadius(playerPed) and ourFlag:isDropped() then
                ctfGame:returnFlag(ourFlag)
            end
        end
    end
end)

--- The playerJoining event.
-- This is an event provided by FiveM.
-- It's triggered when a player connects to the server and has a finally-assigned NetID.
-- We use this method to send the team data to the client.
-- We trigger a local event (registered on the server) named 'sendTeamDataToClient'.
--
-- @param source (number) The player's NetID (a number in Lua/JS).
-- @param oldID (number) The original TempID for the connecting player, as specified during playerConnecting.
RegisterServerEvent('playerJoining')
AddEventHandler('playerJoining', function(source, oldID)
    Player(source).state.teamID = TeamType.TEAM_RED -- Initialize to team red
    TriggerEvent("sendTeamDataToClient", source)
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

--- The sendTeamDataToClient event.
-- This event can be triggered by the client or the server.
-- This event is used to set up our teamsDataArray table and send it over to the client for parsing.
--
-- @param source (number) The player's NetID (a number in Lua/JS).
RegisterServerEvent("sendTeamDataToClient")
AddEventHandler("sendTeamDataToClient", function(source)
    local teamsDataArray = {}
    -- We go through the gamemode's teams and add everything, but TEAM_SPECTATOR (so TEAM_BLUE and TEAM_RED only).
    for _, team in ipairs(ctfGame.teams) do
        if team.id ~= TeamType.TEAM_SPECTATOR then
            print("flag status is " .. ctfGame:getFlagByTeamID(team.id):getFlagStatus())
            local teamData = {
                id = team.id,
                name = team:getName(),
                basePosition = team.basePosition,
                flagColor = team.flagColor,
                flagNetworkedID = ctfGame:getFlagByTeamID(team.id):getFlagNetworkedID(),
                flagStatus = ctfGame:getFlagByTeamID(team.id):getFlagStatus(),
                playerModel = team.playerModel,
                playerHeading = team.playerHeading,
                baseNetworkId = team.networkedID,
                score = team.score
            }
            teamsDataArray[#teamsDataArray+1] = teamData
        end
    end
    -- Finally trigger the client event receiveTeamData declared in ctf_client.lua
    TriggerClientEvent("receiveTeamData", source, teamsDataArray)
end)

RegisterCommand("shutdown", function(source, args, rawCommand)
    ctfGame:shutDown()
end, true)

--- Triggered when the resource is stopping.
--
-- @param resourceName (string) The resource name, i.e. ctf_server.
AddEventHandler('onResourceStop', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then
        return
    end
    -- The gamemode is over, call our shutdown method which will remove the flags
    ctfGame:shutDown()
    print('The resource ' .. resourceName .. ' was stopped.')
end)

AddEventHandler('playerDropped', function (reason)
    local flagToCapture = ctfGame:getFlag(source, true)
    if flagToCapture:isFlagCarrier(source) then
        flagToCapture:setAsDropped()
    end
end)

-- Main game loop
CreateThread(function()
    while true do
        ctfGame:update()
        Wait(500)  -- Adjust the interval as needed
    end
end)
