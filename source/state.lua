-- source/state.lua
local State = {
    scriptRunning = true,
    lastShotTime = 0,
    SHOT_DEBOUNCE = 0.5,
    autoShootActive = false,
    CachedMurderer = nil,
    CachedSheriff = nil,
    CachedGunDrop = nil,
    CachedTraps = {},
    visitedCoins = {}
}

return State