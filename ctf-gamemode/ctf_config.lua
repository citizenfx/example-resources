--[[
    File: ctf_config.lua
    Description:
        This file contains configurations for the Team Deathmatch (TDM) game mode,
        including properties for each team such as team ID, base position, and player model.

    Configuration Format:
        Each team configuration is represented as a table with the following properties:
        - id: The ID of the team.
        - basePosition: The base position of the team.
        - playerModel: The player model associated with the team.
        - playerHeading: The desired player heading on spawn.
]]

ctfConfig = {}

ctfConfig.teams = {
    {
        id = TeamType.TEAM_RED,
        flagColor = {255, 0, 0},
        basePosition = vector3(2555.1860, -333.1058, 92.9928),
        playerModel = 'a_m_y_beachvesp_01',
        playerHeading = 90.0
    },
    {
        id = TeamType.TEAM_BLUE,
        flagColor = {0, 0, 255},
        basePosition = vector3(2574.9807, -342.9044, 92.9928),
        playerModel = 's_m_m_armoured_02',
        playerHeading = 90.0
    },
    {
        id = TeamType.TEAM_SPECTATOR,
        flagColor = {255, 255, 255},
        basePosition = vector3(2574.9807, -342.9044, 92.9928),
        playerModel = 's_m_m_armoured_02',
        playerHeading = 90.0
    },
    -- Add more team configurations as needed
}

-- Flags
ctfConfig.flags = {
    {
        teamID = TeamType.TEAM_RED,
        model = "w_am_case",
        position = vector3(2555.1860, -333.1058, 92.9928)
    },
    {
        teamID = TeamType.TEAM_BLUE,
        model = "w_am_case",
        position = vector3(2574.9807, -342.9044, 92.9928)
    }
}

ctfConfig.UI = {
    btnCaptions = {
        Spawn = "Spawn",
        NextTeam = "Next Team",
        PreviousTeam = "Previous Team"
    },
    teamTxtProperties = {
        x = 1.0,            -- Screen X coordinate
        y = 0.9,            -- Screen Y coordinate
        width = 0.4,        -- Width of the text
        height = 0.070,     -- Height of the text
        scale = 1.0,        -- Text scaling
        text = "",          -- Text content
        color = {           -- Color components
            r = 255,        -- Red color component
            g = 255,        -- Green color component
            b = 255,        -- Blue color component
            a = 255         -- Alpha (transparency) value
        }
    },
    screenCaptions = {
        DefendAndGrabThePackage = "Defend and grab the ~y~package~w~.",
        TeamFlagAction = "The %s team's flag has been %s."
    }
}
