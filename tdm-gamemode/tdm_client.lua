--[[
    File: tdm_client.lua
    Description:
        This is the main client file and its main purpose is:
            - To handle the following client related logic executed via our main thread: (see CreateThread).
                - To draw any instructional UI on the screen: (see drawScaleFormUI).
                - To perform team selection and camera manipulation if the user is in camera selection: (see boolean bInTeamSelection).

            - To receive team data from the server via events: (see receiveTeamData).
    
    Event handlers:
        - SendClientHudNotification: Dispatched by the server to display simple 'toast' UI notifications on the client.
        - playerSpawned: Dispatched by FiveM resource spawnManager when the player spawns (https://docs.fivem.net/docs/resources/spawnmanager/events/playerSpawned/)
            We use this event to set the player's position to the base position on first spawn (or respawn after death).
        - gameEventTriggered: Used in conjunction with CEventNetworkEntityDamage to check if the player was killed.
            Information is then relayed to the server via an event (tdm:onPlayerKilled).

    Variables used by this script:
        - bInTeamSelection: Stores whether the user is in camera selection or not, set by method: setIntoTeamSelection.
            It is set to true on script initialization and false once a team is picked.

        - receivedServerTeams: A table assigned by receiveTeamData, holding data sent from the server.
            It contains information about the teams the user may pick (Red and Blue).

        - lastTeamSelKeyPress: Used to introduce a cooldown period 'on left/right click' when cycling through team selection.
            Without this cooldown, rapid clicks could lead to unintended and fast team cycling.

        - teamID: Stores the local team, mainly used to decide if the client should go into team/camera selection.
            It is also used to spawn the client at their respective base (see 'playerSpawned' event).
            This is a state bag and it's shared with the server
            
        - activeCameraHandle: Stores the created camera handle (set by CreateCam in setIntoTeamSelection) for later use.
]]

-- Declare the variables this script will use
local bInTeamSelection = false
local receivedServerTeams = nil
local lastTeamSelKeyPress = -1
local activeCameraHandle = -1
local spawnPoints = {}
local enemyBlips = {}

-- Define controller variables
local CONTROL_LMB = 329 -- Left mouse button
local CONTROL_RMB = 330 -- Right mouse button
local CONTROL_LSHIFT = 209 -- Left shift

-- UI related variables.
-- Create a local reference to tdmConfig.UI
local UIConfig = tdmConfig.UI

-- Access 'teamTxtProperties' from the 'tdmConfig.UI' table referenced by 'UIConfig'.
local UITeamTxtProps = UIConfig.teamTxtProperties

-- Access 'btnCaptions' properties from the 'tdmConfig.UI' table referenced by 'UIConfig'.
local btnCaptions = UIConfig.btnCaptions

-- Set the teamID to spectator on script initialization
-- Learn more about state bags to https://docs.fivem.net/docs/scripting-manual/networking/state-bags/#player-state
LocalPlayer.state:set('teamID', tdmConfig.type.TEAM_SPECTATOR, true)

-- Caching the spawnmanager export
local spawnmanager = exports.spawnmanager

---------------------------------------------- Functions ----------------------------------------------

--- Our callback method for the autoSpawnCallback down below, we give ourselves guns here.
local onPlayerSpawnCallback = function()
    local ped = PlayerPedId() -- 'Cache' our ped so we're not invoking the native multiple times.

    -- Spawn the player via an export at the player team's spawn point.
    spawnmanager:spawnPlayer(
        spawnPoints[LocalPlayer.state.teamID]
    )

    -- Let's use compile-time jenkins hashes to give ourselves an assault rifle.
    GiveWeaponToPed(ped, `weapon_assaultrifle`, 300, false, true)

    -- Enable player vs player so players can target and shoot each other
    NetworkSetFriendlyFireOption(true)
    SetCanAttackFriendly(ped, true, true)

    -- Clear any previous blood damage
    ClearPedBloodDamage(ped)

    -- Make us visible again
    SetEntityVisible(ped, true)
end

local setIntoTeamSelection = function(team, bIsInTeamSelection)
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

    SetEntityCoords(ped, origCamCoords.x, origCamCoords.y, origCamCoords.z, false, false, false, true)
    SetCamCoord(activeCameraHandle, camFromCoords)
    PointCamAtCoord(activeCameraHandle, origCamCoords)
    RenderScriptCams(bInTeamSelection)
    SetEntityVisible(ped, not bIsInTeamSelection)
end

local buttonMessage = function(text)
    BeginTextCommandScaleformString("STRING")
    AddTextComponentScaleform(Locales[tostring(GetCurrentLanguage())][text] or text) -- Calling native every time so if player change game language, it will update automatically
    EndTextCommandScaleformString()
end

--- Draws the scaleform UI displaying controller buttons and associated messages for player instructions.
--
-- @param buttonsHandle (number) The handle for the scaleform movie.
local drawScaleFormUI = function(buttonsHandle)
    while not HasScaleformMovieLoaded(buttonsHandle) do -- Wait for the scaleform to be fully loaded
        Wait(0)
    end

    CallScaleformMovieMethod(buttonsHandle, 'CLEAR_ALL') -- Clear previous buttons

    PushScaleformMovieFunction(buttonsHandle, "SET_DATA_SLOT")
    PushScaleformMovieFunctionParameterInt(2)
    ScaleformMovieMethodAddParamPlayerNameString("~INPUT_SPRINT~")
    buttonMessage('spawn')
    PopScaleformMovieFunctionVoid()

    PushScaleformMovieFunction(buttonsHandle, "SET_DATA_SLOT")
    PushScaleformMovieFunctionParameterInt(1)
    ScaleformMovieMethodAddParamPlayerNameString("~INPUT_ATTACK~")
    buttonMessage('previous_team')
    PopScaleformMovieFunctionVoid()

    PushScaleformMovieFunction(buttonsHandle, "SET_DATA_SLOT")
    PushScaleformMovieFunctionParameterInt(0)
    ScaleformMovieMethodAddParamPlayerNameString("~INPUT_AIM~") -- The button to display
    buttonMessage('next_team') -- the message to display next to it
    PopScaleformMovieFunctionVoid()
    
    CallScaleformMovieMethod(buttonsHandle, 'DRAW_INSTRUCTIONAL_BUTTONS') -- Sets buttons ready to be drawn
end

local removePlayerBlips = function()
    for blipTableIdx, blipHandle in ipairs(enemyBlips) do
        local blipOwningEntity = GetBlipInfoIdEntityIndex(blipHandle)
        local playerId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(blipOwningEntity))
        if not DoesEntityExist(blipOwningEntity) or Player(playerId).state.teamID == LocalPlayer.state.teamID then
            Citizen.Trace("Removed orphan blip (" .. GetPlayerName(NetworkGetPlayerIndexFromPed(blipOwningEntity)) .. ")")
            RemoveBlip(blipHandle) 
            table.remove(enemyBlips, blipTableIdx)
        end
    end
end

function tryCreateBlips()
    for _, player in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(player)
        if GetBlipFromEntity(ped) == 0 then
            if Player(GetPlayerServerId(player)).state.teamID ~= LocalPlayer.state.teamID then
                Citizen.Trace('Added ' .. GetPlayerName(player))
                enemyBlips[#enemyBlips+1] = AddBlipForEntity(ped) -- Store the blip handle in the table
            end
        end
    end
end

--- Used to draw text on the screen.
-- Multiple natives are called for drawing.
-- Documentation for those natives can be found at http://docs.fivem.net/natives
--
-- @param x (number) Where on the screen to draw text (horizontal axis).
-- @param y (number) Where on the screen to draw text (vertical axis).
-- @param width (number) The width for the text.
-- @param height (number) The height for the text.
-- @param scale (number) The scale for the text.
-- @param text (string) The actual text value to display.
-- @param r (number) The value for red (0-255).
-- @param g (number) The value for green (0-255).
-- @param b (number) The value for blue (0-255).
-- @param alpha (number) The value for alpha/opacity (0-255).
local drawTxt = function(x, y, width, height, scale, text, r, g, b, a)
    SetTextFont(2)
    SetTextProportional(0)
    SetTextScale(scale, scale)
    SetTextColour(r, g, b, a)
    SetTextDropShadow(0, 0, 0, 0,255)
    SetTextEdge(1, 0, 0, 0, 255)
    SetTextDropShadow()
    SetTextOutline()
    -- Let's use our previously created text entry 'textRenderingEntry'
    SetTextEntry("textRenderingEntry")
    AddTextComponentString(text)
    DrawText(x - width/2, y - height/2 + 0.005)    
end

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

-- Define a function to format the team name
local formatTeamName = function(receivedServerTeams, teamID)
    -- Check player language and save in cache
    local currentLanguage = tostring(GetCurrentLanguage())
    local teamData = receivedServerTeams[teamID]
    local localizedTeamName

    -- Check if receivedServerTeams is valid and contains the teamID
    if teamData and teamData.name then
        -- Concatenate the team name with " Team" suffix
        localizedTeamName = Locales[currentLanguage][teamData.name] or (teamData.name .. " " .. (Locales[currentLanguage]['team'] or "Team"))
    else
        -- Return a default message if the team name cannot be formatted
        localizedTeamName = "Unknown Team"
    end

    return localizedTeamName
end

function shouldGoIntoCameraSelection()
    return LocalPlayer.state.teamID == tdmConfig.type.TEAM_SPECTATOR and not bInTeamSelection
end


---------------------------------------------- Event handlers ----------------------------------------------

RegisterNetEvent("SendClientHudNotification")
AddEventHandler("SendClientHudNotification", function(message)
    BeginTextCommandThefeedPost("STRING")
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandThefeedPostTicker(true, true)
end)

-- Register the event handler to receive team data
RegisterNetEvent("receiveTeamData")
AddEventHandler("receiveTeamData", function(teamsData)
    receivedServerTeams = teamsData

    for _, team in ipairs(receivedServerTeams) do
        spawnPoints[team.id] = spawnmanager:addSpawnPoint({
            x = team.basePosition.x,
            y = team.basePosition.y,
            z = team.basePosition.z,
            heading = team.playerHeading,
            model = team.playerModel,
            skipFade = false
        })
    end
end)

--- Sets the player health to 0 (kills the player)
RegisterNetEvent("killPlayer")
AddEventHandler("killPlayer", function()
    -- Over here 'ped' isn't cached since it's only called once
    SetEntityHealth(PlayerPedId(), 0)
end)

--- Here we handle the CEventNetworkEntityDamage event.
-- Documentation on gameEventTriggered can be found here: https://docs.fivem.net/docs/scripting-reference/events/list/gameEventTriggered/
-- The full list of events can be found linked on the forementioned URL as well.
AddEventHandler("gameEventTriggered", function(name, args)
    if not (name == "CEventNetworkEntityDamage") then return end

    local victimID = GetPlayerServerId(NetworkGetPlayerIndexFromPed(args[1]))
    local killerID = GetPlayerServerId(NetworkGetPlayerIndexFromPed(args[2]))

    if IsEntityDead(args[1]) then
        if GetPlayerServerId(PlayerId()) == killerID then
            TriggerServerEvent("tdm:onPlayerKilled", killerID, victimID)
        end
    end
end)

---
-- Event handler triggered when a resource starts.
-- Requests team data from the server when the resource starts.
-- For more information regarding onClientResourceStart, visit the following link:
-- https://docs.fivem.net/docs/scripting-reference/events/list/onClientResourceStart/
-- @param resourceName The name of the resource that started.
AddEventHandler('onClientResourceStart', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then
        return
    end
    -- Let's create our entry for text rendering.
    -- '~a~' is a placeholder for a substring 'text component', such as ADD_TEXT_COMPONENT_SUBSTRING_TEXT_LABEL.
    -- More here:
    -- https://docs.fivem.net/docs/game-references/text-formatting/#content-formatting-codes
    AddTextEntry("textRenderingEntry", "~a~")
    -- Let's request team data from the server when we join.
    TriggerServerEvent("requestTeamData")
    -- Send a console message showing that the resource has been started
    print('The resource ' .. resourceName .. ' has been started.')
end)

--- This event is dispatched by spawnmanager once the player spawns (URL at the top of the file).
AddEventHandler('playerSpawned', function()
    if shouldGoIntoCameraSelection() then
        setIntoTeamSelection(tdmConfig.type.TEAM_BLUE, true)
    end
end)

--- Used to switch teams
-- For more information on RegisterCommand, see the following link:
-- https://docs.fivem.net/natives/?_0x5FA79B0F
RegisterCommand("switchteam", function(source, args, rawCommand)
    setIntoTeamSelection(tdmConfig.type.TEAM_BLUE, true)
end)

---------------------------------------------- Callbacks ----------------------------------------------

--- This handles player auto spawning after death.
-- See spawnmanager's documentation for more: https://docs.fivem.net/docs/resources/spawnmanager/
spawnmanager:setAutoSpawnCallback(onPlayerSpawnCallback)
spawnmanager:setAutoSpawn(true)

---------------------------------------------- Threads ----------------------------------------------

-- Threads are used to perform tasks asynchronously.
-- They are based on lua's coroutines
-- Lua's coroutines basics can be found here: https://www.lua.org/pil/9.1.html

-- Refresh blips every two seconds in case new players join in
CreateThread(function()
    while true do
        -- Cleanup any old blips
        removePlayerBlips()

        -- Recreate blips
        tryCreateBlips()
        Wait(2000)
    end
end)

--- Our main thread.
-- We use this thread to perform Text/Sprite Rendering, handling drawing of instructional UI, team selection and camera manipulation.
CreateThread(function()
    local buttonsHandle = RequestScaleformMovie('INSTRUCTIONAL_BUTTONS') -- Request the scaleform to be loaded
    drawScaleFormUI(buttonsHandle)

    while true do
        if receivedServerTeams ~= nil and #receivedServerTeams > 0 then
            -- Our spectator team is not in use, it's only there for team selection purposes.
            -- So if we're in that team and we're not in camera selection, we initiate the team selection process.
            if shouldGoIntoCameraSelection() then
                setIntoTeamSelection(tdmConfig.type.TEAM_BLUE, true)
            end

            -- Run the logic for picking a team
            if bInTeamSelection then
                DisableRadarThisFrame()
                HideHudAndRadarThisFrame()

                -- Draw the instructional buttons this frame
                DrawScaleformMovieFullscreen(buttonsHandle, 255, 255, 255, 255, 1)
                
                if GetGameTimer() > lastTeamSelKeyPress then
                    -- Determine if the user pressed one of the mouse buttons or SHIFT
                    -- Sets LocalPlayer.state.teamID if so
                    handleTeamSelectionControl()

                    if LocalPlayer.state.teamID and LocalPlayer.state.teamID <= #receivedServerTeams then
                        -- Draw the text on the screen for this specific team
                        -- This will use the properties from our tdm_config.lua file
                        drawTxt(
                            UITeamTxtProps.x,
                            UITeamTxtProps.y,
                            UITeamTxtProps.width,
                            UITeamTxtProps.height,
                            UITeamTxtProps.scale,
                            formatTeamName(receivedServerTeams, LocalPlayer.state.teamID),
                            UITeamTxtProps.color.r,
                            UITeamTxtProps.color.g,
                            UITeamTxtProps.color.b,
                            UITeamTxtProps.color.a
                        )
                    end
                end
            end
        end
        -- No wanted level
        ClearPlayerWantedLevel(PlayerId())

        Wait(0)
    end
end)
