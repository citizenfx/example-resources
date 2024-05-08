--[[
    File: ctf_client.lua
    Description:
        This is the main client file and its main purpose is:
            - To handle the following client related logic executed via our main thread: (see Citizen.CreateThread).
                - To perform team selection and camera manipulation if the user is in camera selection: (see boolean bInTeamSelection).
            
            - To handle certain client-side flag logic:
                - processFlagLogic: Used to update the state of a flag from the client, i.e.
                    - If the client dies (their health is below 1) the flagStatus is set to EFlagStatuses.CARRIER_DIED.
                        - The server then takes note of this and updates everyone telling them the flag was dropped.

            - To receive team data from the server via events: (see receiveTeamData).
    
    Event handlers:
        - playerSpawned: Dispatched by FiveM resource spawnManager when the player spawns (https://docs.fivem.net/docs/resources/spawnmanager/events/playerSpawned/)
            We use this event to set the player's position to the base position on first spawn (or respawn after death).

    Variables used by this script:
        - bInTeamSelection: Stores whether the user is in camera selection or not, set by method: setIntoTeamSelection.
        - bShouldShowTeamScreen: Boolean that stores whether the team screen used to pick a team should be shown. 
            It is set to true on script initialization and false once a team is picked.

        - receivedServerTeams: A table assigned by receiveTeamData, holding data sent from the server.
            It contains information about the teams the user may pick (Red and Blue).

        - lastTeamSelKeyPress: Used to introduce a cooldown period 'on left/right click' when cycling through team selection.
            Without this cooldown, rapid clicks could lead to unintended and fast team cycling.

        - localTeamSelection: Stores the local team, mainly used to decide if the client should go into team/camera selection.
            It is also used to spawn the client at their respective base (see 'playerSpawned' event).
            
        - activeCameraHandle: Stores the created camera handle (set by CreateCam in setIntoTeamSelection) for later use.
]]

-- Declare the variables this script will use
local bInTeamSelection = false
local bIsAttemptingToSwitchTeams = false
local bShouldShowTeamScreen = true -- Show it on first spawn
local receivedServerTeams = nil
local lastTeamSelKeyPress = -1
local localTeamSelection = 0
local activeCameraHandle = -1
local entityBlipHandles = {} -- Keeps handles of any blips (just two, one for each flag)
local spawnPoints = {}

--[[ 
    Define controller variables
    These controller IDs are gathered from: https://docs.fivem.net/docs/game-references/controls/#controls
]]

local CONTROL_LMB = 329 -- Left mouse button
local CONTROL_RMB = 330 -- Right mouse button
local CONTROL_LSHIFT = 209 -- Left shift

local BLIP_COLOR_BLUE = 4
local BLIP_COLOR_RED = 1

-- Set the teamID to spectator on script initialization
LocalPlayer.state:set('teamID', TeamType.TEAM_SPECTATOR, true)

-- This event is first called when the resource starts
AddEventHandler('onClientResourceStart', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then
        return
    end
    -- Let's request team data from the server when we join.
    TriggerServerEvent("requestTeamData")
    -- Send a console message showing that the resource has been started
    print('The resource ' .. resourceName .. ' has been started.')
end)

RegisterNetEvent("SetObjectiveVisible")
-- The event handler function follows after registering the event first.
AddEventHandler("SetObjectiveVisible", function(flagEntityNetID, bVisible)
    if NetworkDoesNetworkIdExist(flagEntityNetID) then
        -- Call NetToEnt to get the entity handle from our net handle (flagEntityNetID), which is sent by the server.
        local flagEntity = NetToEnt(flagEntityNetID)

        print("SetObjectiveVisible: " .. GetEntityArchetypeName(flagEntity) .. " to our player, owner is: " .. GetPlayerName(NetworkGetEntityOwner(flagEntity)))

        SetEntityVisible(flagEntity, bVisible, 0)
    else
        print("AttachFlagToPlayer: Something terrible happened, where's our flag?")
    end
end)

RegisterNetEvent("PlaySoundFrontEnd")
-- The event handler function follows after registering the event first.
AddEventHandler("PlaySoundFrontEnd", function(soundName, soundSetName)
    PlaySoundFrontend(-1, soundName, soundSetName, false)
end)

-- This event gets called every time the player spawns.
-- We use it to decide whether or not they should should go into team selection during first spawn
AddEventHandler('playerSpawned', function()
    if shouldGoIntoTeamSelection() then
        setIntoTeamSelection(TeamType.TEAM_BLUE, true)
    end
end)

-- Register the event handler to receive team data
RegisterNetEvent("receiveTeamData")
AddEventHandler("receiveTeamData", function(teamsData)
    receivedServerTeams = teamsData

    for _, team in ipairs(receivedServerTeams) do
        spawnPoints[team.id] = exports.spawnmanager:addSpawnPoint({
            x = team.basePosition.x,
            y = team.basePosition.y,
            z = team.basePosition.z,
            heading = team.playerHeading,
            model = team.playerModel,
            skipFade = false
        })
    end
end)

---------------------------------------------- Commands ----------------------------------------------

--- A command to go into camera selection (was mainly used for test purposes during development).
-- Additional documentation about RegisterCommand can be found by following the URL provided down below.
-- https://docs.fivem.net/docs/scripting-manual/migrating-from-deprecated/creating-commands/
RegisterCommand("switchteam", function(source, args, rawCommand)
    TriggerServerEvent("sendTeamDataToClient", GetPlayerServerId(PlayerId()))
    bIsAttemptingToSwitchTeams = true
    LocalPlayer.state:set('teamID', TeamType.TEAM_SPECTATOR, true)
    SetEntityHealth(PlayerPedId(), 0)
end)

RegisterCommand("kill", function(source, args, rawCommand)
    SetEntityHealth(PlayerPedId(), 0)
end, false)

---------------------------------------------- Functions ----------------------------------------------

--- Handles player input for team selection.
-- This function allows players to navigate through available teams using mouse clicks and to confirm their selection by pressing the left shift key.
-- Mouse click on the left button (LMB) decreases the team selection index by one, while a click on the right button (RMB) increases it by one.
-- The left shift key confirms the selected team and spawns the player character at the designated spawn point.
function handleTeamSelectionControl()
    local teamSelDirection = 0
    local bPressedSpawnKey = false

    -- Determine the direction of team selection based on mouse clicks
    if IsControlPressed(0, CONTROL_LMB) then 
        teamSelDirection = -1 -- Previous team
    elseif IsControlPressed(0, CONTROL_RMB) then
        teamSelDirection = 1 -- Next team
    elseif IsControlPressed(0, CONTROL_LSHIFT) then -- Left Shift
        -- Let's spawn!
        bInTeamSelection = false -- We're no longer in team/camera selection
        bIsAttemptingToSwitchTeams = false -- We're no longer trying to switch teams
        bPressedSpawnKey = true

        -- Spawn the player
        exports.spawnmanager:spawnPlayer(
            spawnPoints[LocalPlayer.state.teamID], 
            onPlayerSpawnCallback
        )
    end

    -- Determine the direction of team selection based on mouse clicks
    if teamSelDirection ~= 0 or bPressedSpawnKey then
        local newTeamID = LocalPlayer.state.teamID + teamSelDirection
        if newTeamID >= 1 and newTeamID <= #receivedServerTeams then
            LocalPlayer.state:set('teamID', newTeamID, true)
            lastTeamSelKeyPress = GetGameTimer() + 500
        end
        setIntoTeamSelection(LocalPlayer.state.teamID, bInTeamSelection)
    end
end

--- Our callback method for the autoSpawnCallback down below, we give ourselves guns here.
function onPlayerSpawnCallback()
    -- Cache the player ped
    local ped = PlayerPedId()

    -- Spawn the player via an export at the player team's spawn point.
    exports.spawnmanager:spawnPlayer(
        spawnPoints[LocalPlayer.state.teamID]
    )

    -- Let's use compile-time jenkins hashes to give ourselves an assault rifle.
    GiveWeaponToPed(ped, `weapon_assaultrifle`, 300, false, true)

    -- Disable friendly fire.
    NetworkSetFriendlyFireOption(false)

    -- Clear any previous blood damage
    ClearPedBloodDamage(ped)

    -- Make us visible again
    SetEntityVisible(ped, true)

    local TEAM_BLUE_REL_GROUP, TEAM_RED_REL_GROUP = nil, nil

    -- Add any relationship groups
    TEAM_BLUE_REL_GROUP = AddRelationshipGroup('TEAM_BLUE')
    TEAM_RED_REL_GROUP = AddRelationshipGroup('TEAM_RED')

    -- Set the relationship to hate
    -- This is done so we can allow players to shoot each other if they are in different teams.
    SetRelationshipBetweenGroups(5, `TEAM_BLUE`, `TEAM_RED`)
    SetRelationshipBetweenGroups(5, `TEAM_RED`, `TEAM_BLUE`)

    if LocalPlayer.state.teamID == TeamType.TEAM_BLUE then
        SetPedRelationshipGroupHash(ped, `TEAM_BLUE`)
    else
        SetPedRelationshipGroupHash(ped, `TEAM_RED`)
    end
end

-- Define a function to format the team name
function formatTeamName(receivedServerTeams, teamID)
    -- Check if receivedServerTeams is valid and contains the teamID
    if receivedServerTeams and receivedServerTeams[teamID] then
        -- Concatenate the team name with " Team" suffix
        return receivedServerTeams[teamID].name .. " Team"
    else
        -- Return a default message if the team name cannot be formatted
        return "Unknown Team"
    end
end

function shouldGoIntoTeamSelection()
    -- If we're on spectator team and we're not in team selection, then we should.
    return LocalPlayer.state.teamID == TeamType.TEAM_SPECTATOR and not bInTeamSelection
end

function setIntoTeamSelection(team, bIsInTeamSelection)
    -- Sets the player into camera selection
    -- Main camera handle only gets created once in order to manipulate it later
    local ped = PlayerPedId() -- Let's cache the Player Ped ID so we're not constantly calling PlayerPedId()

    LocalPlayer.state:set('teamID', team, true)
    bInTeamSelection = bIsInTeamSelection
    local origCamCoords = receivedServerTeams[team].basePosition
    local camFromCoords = vector3(origCamCoords.x, origCamCoords.y + 2.0, origCamCoords.z + 2.0)
    if activeCameraHandle == -1 then
        activeCameraHandle = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    end

    -- Set the ped where the camera should be at to allow streaming.
    SetEntityCoords(ped, origCamCoords.x, origCamCoords.y, origCamCoords.z, false, false, false, true)

    -- Set the camera coordinates
    SetCamCoord(activeCameraHandle, camFromCoords)
    PointCamAtCoord(activeCameraHandle, origCamCoords)

    -- Let the game know whether we should enable or disable rendering of scripted cameras.
    -- Our scripted camera is the one created by CreateCam, we keep a reference to that camera
    -- see: activeCameraHandle
    RenderScriptCams(bInTeamSelection)

    -- Set the ped entity visible if they are not in team selection, invisible otherwise.
    SetEntityVisible(ped, not bIsInTeamSelection)
end

function tryCreateBlipForEntity(teamID, entity, spriteId)
    local blipHandle = entityBlipHandles[teamID]
    if DoesBlipExist(blipHandle) then
        RemoveBlip(blipHandle)
    end
    local newBlipHandle = AddBlipForEntity(entity)
    SetBlipSprite(newBlipHandle, spriteId)
    SetBlipColour(newBlipHandle, teamID == TeamType.TEAM_RED and BLIP_COLOR_RED or BLIP_COLOR_BLUE)
    return newBlipHandle
end

--- Process logic related to the flag state
-- This method is used to process client-side logic related to any of the flags.
-- It will also inform the server if the carrier died to take proper action on the server.
function processFlagLogic(flagEntityNetID)
    -- Check if it exists before processing.
    -- It may not exist if we're far away from the entity
    if not NetworkDoesNetworkIdExist(flagEntityNetID) then return end

    -- Cast/convert the network ID to an entity
    local ent = NetToEnt(flagEntityNetID)

    -- Don't process any logic until we have our object
    if not DoesEntityExist(ent) then return end

    -- Code to lerp the intensity https://en.wikipedia.org/wiki/Linear_interpolation
    -- This line gets the current time in the game and converts it to seconds
    local time = GetGameTimer() / 1000

    -- This line calculates the intensity using a mathematical function
    -- It involves a sine wave, which creates a smooth up-and-down motion over time
    -- The "math.sin(time)" part calculates the sine of the time, which creates a wave pattern
    -- The "* 3" part makes the wave's peaks and valleys higher, increasing the intensity
    local intensity = 3 * (1 + math.sin(time))

    -- This line ensures that the intensity stays within a specific range (0 to 6)
    -- If the intensity is below 0, it sets it to 0
    -- If the intensity is above 6, it sets it to 6
    intensity = math.max(0, math.min(6, intensity))

    local bFreezeInPosition = false

    -- Get the entity state data for this entity
    local es = Entity(ent)

    if es.state.flagStatus == EFlagStatuses.DROPPED then
        local coords = GetEntityCoords(ent)
        Draw3DText(coords.x, coords.y, coords.z, 0.5, screenCaptions.DefendAndGrabThePackage)
    
        DrawLightWithRangeAndShadow(
            coords.x, coords.y, coords.z,
            es.state.flagColor[1], 
            es.state.flagColor[2], 
            es.state.flagColor[3], 
            5.0, 
            intensity,
            1.0
        )

        -- Add a blip for the entity
        entityBlipHandles[es.state.teamID] = tryCreateBlipForEntity(
            es.state.teamID,
            ent,
            309
        )

    elseif es.state.flagStatus == EFlagStatuses.TAKEN then
        -- Draw a light around the player carrying the flag
        local carrierPed = GetPlayerPed(GetPlayerFromServerId(es.state.carrierId))
        local carrierCoords = GetEntityCoords(carrierPed)
        DrawLightWithRangeAndShadow(
            carrierCoords.x, carrierCoords.y, carrierCoords.z,
            es.state.flagColor[1], 
            es.state.flagColor[2], 
            es.state.flagColor[3], 
            4.0, 
            intensity,
            1.0
        )

        -- Add a blip for the ped carrying the flag
        entityBlipHandles[es.state.teamID] = tryCreateBlipForEntity(
            es.state.teamID,
            carrierPed,
            309
        )
    
        -- If the carrier dies, update the status and send a request to the server to let it know
        if IsEntityDead(carrierPed) then
            es.state:set('flagStatus', EFlagStatuses.CARRIER_DIED, true)
            TriggerServerEvent("requestFlagUpdate")
            return
        end
    end
    
    if es.state.flagStatus ~= EFlagStatuses.TAKEN then
        if not IsEntityAttachedToAnyPed(ent) then
            local playerPed = PlayerPedId()
            if entityHasEntityInRadius(ent, playerPed) and not IsEntityDead(playerPed) then
                TriggerServerEvent("requestFlagUpdate")
                Citizen.Wait(500)
            end
        end
    end  
    
    if es.state.flagStatus == EFlagStatuses.AT_BASE then
        if DoesBlipExist(entityBlipHandles[es.state.teamID]) then
            RemoveBlip(entityBlipHandles[es.state.teamID])
        end

        -- Freeze when the flag is at base
        bFreezeInPosition = true
    end

    -- Actually freeze the entity by calling the native
    FreezeEntityPosition(ent, bFreezeInPosition)
end

function processBasesForTeams()
    --- Processes the bases for teams by drawing lights and freezing their positions.
    -- @usage This function should be called per tick in a thread after receiving server teams.
    for _, team in ipairs(receivedServerTeams) do
        DrawLightWithRangeAndShadow(
            team.basePosition.x, team.basePosition.y, team.basePosition.z,
            team.flagColor[1] --[[ integer ]],
            team.flagColor[2] --[[ integer ]],
            team.flagColor[3] --[[ integer ]],
            10.0 --[[ number ]],
            2.0 --[[intensity]],
            1.0
        )

        if NetworkDoesNetworkIdExist(team.baseNetworkId) then
            -- Cast/convert the network ID to an entity
            local ent = NetToEnt(team.baseNetworkId)
            if not IsEntityPositionFrozen(ent) then
                -- Freezes the entity position to keep the base in place.
                FreezeEntityPosition(ent, true)
            end
        end
    end
end

-- Define a function to get the received teams from other files
function getReceivedServerTeams()
    return receivedServerTeams
end

-- Getter to determine whether the player is in team selection or not
function isInTeamSelection()
    return bInTeamSelection
end

---------------------------------------------- Callbacks ----------------------------------------------

--- This handles player auto spawning after death.
-- See spawnmanager's documentation for more: https://docs.fivem.net/docs/resources/spawnmanager/
exports.spawnmanager:setAutoSpawnCallback(onPlayerSpawnCallback)
exports.spawnmanager:setAutoSpawn(true)

----------------------------------------------- Threads -----------------------------------------------

-- Process the client flag logic for each flag every tick
Citizen.CreateThread(function()
    while true do
        if not bInTeamSelection then
            if receivedServerTeams and #receivedServerTeams > 0 then
                for _, team in ipairs(receivedServerTeams) do
                    -- Run flag logic if they are not in camera/team selection
                    if team.id ~= TeamType.TEAM_SPECTATOR then
                        processFlagLogic(team.flagNetworkedID)
                    end
                end
            end
        end
        Citizen.Wait(0)
    end
end)

--- Our main thread.
-- We use this thread to handle team selection and to process any flag related logic.
Citizen.CreateThread(function()
    while true do
        if receivedServerTeams and #receivedServerTeams > 0 then
            if shouldGoIntoTeamSelection() and not bIsAttemptingToSwitchTeams then
                setIntoTeamSelection(TeamType.TEAM_BLUE, true)
            end

            if bInTeamSelection then
                if GetGameTimer() > lastTeamSelKeyPress then
                    -- Determine if the user pressed one of the mouse buttons or SHIFT
                    -- Sets LocalPlayer.state.teamID if so
                    handleTeamSelectionControl()
                end
            end
            -- Render base lights for teams and freezes them each frame.
            processBasesForTeams()
        end
        -- No wanted level
        ClearPlayerWantedLevel(PlayerId())

        -- Make it night time so we can see our lights
        NetworkOverrideClockTime(23, 0, 0)

        -- Process all rendering logic for this frame
        ctfRenderingRenderThisFrame()

        Citizen.Wait(0)
    end
end)
