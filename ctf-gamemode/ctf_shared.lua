TeamType = {
    TEAM_BLUE = 1,
    TEAM_RED = 2,
    TEAM_SPECTATOR = 3,
}

EFlagStatuses = {
    AT_BASE = 1,
    BACK_TO_BASE = 2,
    DROPPED = 3,
    TAKEN = 4,
    CAPTURED = 5,
    CARRIER_DIED = 6
}

FlagStatuses = {
    { status = AT_BASE, description = "At Base" },
    { status = BACK_TO_BASE, description = "Warping Back" },
    { status = DROPPED, description = "Dropped" },
    { status = TAKEN, description = "Taken" },
    { status = CAPTURED, description = "Captured" },
    { status = CARRIER_DIED, description = "Carrier Died" }
}

function getDescriptionForFlagStatus(statusID)
    return FlagStatuses[statusID] and FlagStatuses[statusID].description or "Unknown Status"
end

function entityHasEntityInRadius(entity, targetEntity, radius)
    radius = radius or 2.5  -- Default radius is 2.5 if not provided
    local flagPosition = GetEntityCoords(entity)
    local targetEntityPos = GetEntityCoords(targetEntity)
    local distance = #(flagPosition - targetEntityPos)
    return distance < radius  -- Adjust the distance as needed
end