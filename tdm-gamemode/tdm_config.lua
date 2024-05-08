--[[
    File: tdm_config.lua
    Description:
        This file contains configurations for the Team Deathmatch (TDM) game mode,
        including properties for each team such as team ID, base position, player model and UI.

    Configuration Format:
        Each team configuration is represented as a table with the following properties:
        - id: The ID of the team.
        - basePosition: The base position of the team.
        - playerModel: The player model associated with the team.
        - playerHeading: The desired player heading on spawn.
]]

tdmConfig = {}

tdmConfig.teams = {
    {
        id = TeamType.TEAM_RED,
        basePosition = vector3(2555.1860, -333.1058, 92.9928),
        playerModel = 'a_m_y_beachvesp_01',
        playerHeading = 90.0
    },
    {
        id = TeamType.TEAM_BLUE,
        basePosition = vector3(2574.9807, -342.9044, 92.9928),
        playerModel = 's_m_m_armoured_02',
        playerHeading = 90.0
    },
    {
        id = TeamType.TEAM_SPECTATOR,
        basePosition = vector3(2574.9807, -342.9044, 92.9928),
        playerModel = 's_m_m_armoured_02',
        playerHeading = 90.0
    },
    -- Add more team configurations as needed
}

tdmConfig.UI = {
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
    }
}
