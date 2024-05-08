--[[
    File: ctf_client.lua
    Description:
        - Handles rendering for UI elements via ctfRenderingRenderThisFrame:
            - Text/Sprite Rendering: (see renderFlagScores).
            - Draws instructional UI on the screen: (see drawScaleFormUI).
        - Contains helper methods to draw text on the screen.
    Event handlers:
        - SendClientHudNotification: Dispatched by the server to display simple 'toast' UI notifications on the client.
]]

-- Store UI configuration from ctfConfig.UI.
local UIConfig = ctfConfig.UI

-- Store properties for team text.
local UITeamTxtProps = UIConfig.teamTxtProperties

-- Store captions for buttons.
local btnCaptions = UIConfig.btnCaptions

-- Store captions for screens.
-- Global since it's used by ctf_client.lua
screenCaptions = UIConfig.screenCaptions

-- Used for the instructional buttons in drawScaleFormUI
local buttonsHandle = nil


AddEventHandler('onClientResourceStart', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then
        return
    end
    -- Let's create our entry for text rendering.
    -- '~a~' is a placeholder for a substring 'text component', such as ADD_TEXT_COMPONENT_SUBSTRING_TEXT_LABEL.
    -- More here:
    -- https://docs.fivem.net/docs/game-references/text-formatting/#content-formatting-codes
    AddTextEntry("textRenderingEntry", "~a~")
    -- Request the texture dictionary for our instructional buttons
    RequestStreamedTextureDict("commonmenutu")
    buttonsHandle = RequestScaleformMovie('INSTRUCTIONAL_BUTTONS') -- Request the scaleform to be loaded
end)

-- Event used to draw toast notifications on the screen
RegisterNetEvent("SendClientHudNotification")
AddEventHandler("SendClientHudNotification", function(message)
    BeginTextCommandThefeedPost("STRING")
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandThefeedPostTicker(true, true)
end)

-- Our main rendering method. 
-- We use this method to perform Text/Sprite Rendering, handling drawing of instructional UI, team selection and camera manipulation.
function ctfRenderingRenderThisFrame()
    drawScaleFormUI(buttonsHandle)

    local teams = nil

    -- We need to wait for these since they arrive via an event from the server
    if not teams then
        teams = getReceivedServerTeams()
    end

    -- If we got the teams we can render
    if teams and #teams > 0 then
        if HasStreamedTextureDictLoaded("commonmenutu") then
            renderFlagScores(teams)
        end

        if isInTeamSelection() then
            DisableRadarThisFrame()
            HideHudAndRadarThisFrame()
            DrawScaleformMovieFullscreen(buttonsHandle, 255, 255, 255, 255, 1) -- Draw the instructional buttons this frame
            
            -- Draw the text on the screen for this specific team
            -- This will use the properties from our ctf_config.lua file
            if LocalPlayer.state.teamID and LocalPlayer.state.teamID <= #teams then
                drawTxt(
                    UITeamTxtProps.x,
                    UITeamTxtProps.y,
                    UITeamTxtProps.width,
                    UITeamTxtProps.height,
                    UITeamTxtProps.scale,
                    formatTeamName(teams, LocalPlayer.state.teamID),
                    UITeamTxtProps.color.r,
                    UITeamTxtProps.color.g,
                    UITeamTxtProps.color.b,
                    UITeamTxtProps.color.a
                )
            end
        end
    end
end

function renderFlagScore(flagData, screenPos, colorRgba)
    local statusID = flagData.flagStatus

    -- Draw the flag
    DrawSprite(
        "commonmenutu" --[[ string ]], 
        "race" --[[ string ]], 
        screenPos.x --[[ number ]], 
        screenPos.y --[[ number ]], 
        0.06 --[[ scale on x ]],
        0.1 --[[ scale on y ]], 
        0.0 --[[ heading ]], 
        table.unpack(colorRgba)
    )

    -- Draws the score and the flag description
    drawTxt(screenPos.x, screenPos.y, -0.08, 0.08, 1.0, tostring(flagData.score), table.unpack(colorRgba))
    drawTxt(screenPos.x, screenPos.y, 0.03, -0.04, 0.5, getDescriptionForFlagStatus(statusID), table.unpack(colorRgba))
end

function renderFlagScores(teams)
    -- If we received any news from the server after script startup, run our render
    if teams ~= nil then
        renderFlagScore(teams[TeamType.TEAM_RED], {x = 0.025, y = 0.5}, {255, 0, 0, 180})
        renderFlagScore(teams[TeamType.TEAM_BLUE], {x = 0.025, y = 0.6}, {0, 0, 255, 180})
    end
end

function buttonMessage(text)
    BeginTextCommandScaleformString("STRING")
    AddTextComponentScaleform(text)
    EndTextCommandScaleformString()
end

--- Draws the scaleform UI displaying controller buttons and associated messages for player instructions.
--
-- @param buttonsHandle (number) The handle for the scaleform movie.
function drawScaleFormUI(buttonsHandle)
    while not HasScaleformMovieLoaded(buttonsHandle) do -- Wait for the scaleform to be fully loaded
        Wait(0)
    end

    CallScaleformMovieMethod(buttonsHandle, 'CLEAR_ALL') -- Clear previous buttons

    PushScaleformMovieFunction(buttonsHandle, "SET_DATA_SLOT")
    PushScaleformMovieFunctionParameterInt(2)
    ScaleformMovieMethodAddParamPlayerNameString("~INPUT_SPRINT~")
    buttonMessage(btnCaptions.Spawn)
    PopScaleformMovieFunctionVoid()

    PushScaleformMovieFunction(buttonsHandle, "SET_DATA_SLOT")
    PushScaleformMovieFunctionParameterInt(1)
    ScaleformMovieMethodAddParamPlayerNameString("~INPUT_ATTACK~")
    buttonMessage(btnCaptions.PreviousTeam)
    PopScaleformMovieFunctionVoid()

    PushScaleformMovieFunction(buttonsHandle, "SET_DATA_SLOT")
    PushScaleformMovieFunctionParameterInt(0)
    ScaleformMovieMethodAddParamPlayerNameString("~INPUT_AIM~") -- The button to display
    buttonMessage(btnCaptions.NextTeam) -- the message to display next to it
    PopScaleformMovieFunctionVoid()
    
    CallScaleformMovieMethod(buttonsHandle, 'DRAW_INSTRUCTIONAL_BUTTONS') -- Sets buttons ready to be drawn
end

------------------------------------------ Helper methods ------------------------------------------

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
function drawTxt(x,y,width,height,scale, text, r,g,b,a)
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

---  https://forum.cfx.re/t/draw-3d-text-as-marker/2643565/2
function Draw3DText(x, y, z, scl_factor, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    local p = GetGameplayCamCoords()
    local distance = GetDistanceBetweenCoords(p.x, p.y, p.z, x, y, z, 1)
    local scale = (1 / distance) * 2
    local fov = (1 / GetGameplayCamFov()) * 100
    local scale = scale * fov * scl_factor
    if onScreen then
        SetTextScale(0.0, scale)
        SetTextFont(0)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextDropshadow(0, 0, 0, 0, 255)
        SetTextEdge(2, 0, 0, 0, 150)
        SetTextDropShadow()
        SetTextOutline()
        -- Let's use our previously created text entry 'textRenderingEntry'
        SetTextEntry("textRenderingEntry")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)
    end
end
