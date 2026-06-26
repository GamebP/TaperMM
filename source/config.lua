-- source/config.lua
local ConfigModule = {
    Config = {
        ESP = true,
        GunESP = false,
        TrapESP = false,
        AutoShoot = true,
        AutoShootBind = "V", 
        AutoShootMode = "Hold",
        AutoCoin = false,
        CoinMethod = "Smooth Fly", -- Options: "Teleport", "Smooth Fly"
        AutoGrabGun = false,
        XPFarm = false,
        AntiAFK = false,
        AutoReset = false,
        AutoDodge = false,
        DodgeDistance = 30,
        SilentAim = false,
        KillAura = false,
        KillAuraRange = 18,
        KillAuraTeleport = false,
        KillAuraTeleportRange = 150,
        WalkSpeed = 16,
        Fly = false,
        Noclip = false,
        FlySpeed = 50,
    },
    KNIFE_NAMES = { "Knife", "RealKnife" },
    GUN_NAMES = { "Gun", "Revolver" },
    MAP_NAMES = {
        "MilBase", "Office3", "PoliceStation", "ResearchFacility", 
        "Workplace", "Factory", "BioLab", "Bank2", "Hospital3", 
        "House2", "Mansion2", "Hotel", "Hotel2", "Mineshaft", 
        "Barn", "nSOffice", "VampireCastle", "Farmhouse", "Manor"
    }
}

return ConfigModule