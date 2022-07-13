if _G.CoreEx.ObjectManager.Player.CharName ~= "Tristana" then
    return
end

module("PewPewTristana", package.seeall, log.setup)
clean.module("PewPewTristana", clean.seeall, log.setup)

_G.CoreEx.AutoUpdate("https://raw.githubusercontent.com/hagbardlol/nosupport/main/PewPewTristana.lua", "1.0.6")

local API = {
    Game = _G.CoreEx.Game,
    Input = _G.CoreEx.Input,
    Vector = _G.CoreEx.Geometry.Vector,
    Polygon = _G.CoreEx.Geometry.Polygon,
    Player = _G.Player,
    Circle = _G.CoreEx.Geometry.Circle,
    Cone = _G.CoreEx.Geometry.Cone,
    EventManager = _G.CoreEx.EventManager,
    Enums = _G.CoreEx.Enums,
    Libs = _G.Libs,
    GetCurrentMillis = _G.getCurrentMillis,
    Renderer = _G.CoreEx.Renderer,
    ObjectManager = _G.CoreEx.ObjectManager,
    Nav = _G.CoreEx.Nav,
    SpellLib = _G.Libs.Spell,
    Orbwalker = _G.Libs.Orbwalker,
    TargetSelector = _G.Libs.TargetSelector,
    CollisionLib = _G.Libs.CollisionLib,
    HealthPred = _G.Libs.HealthPred,
    Evade = _G.CoreEx.EvadeAPI
}

local Menu = API.Libs.NewMenu
local TS = API.TargetSelector()
local Tristana = {
    Q = API.SpellLib.Active({
        Slot = API.Enums.SpellSlots.Q,
        Key = "Q"
    }),
    W = API.SpellLib.Skillshot({
        Slot = API.Enums.SpellSlots.W,
        Key = "W",
        Range = 900
    }),
    E = API.SpellLib.Targeted({
        Slot = API.Enums.SpellSlots.E,
        Key = "E"
    }),
    R = API.SpellLib.Targeted({
        Slot = API.Enums.SpellSlots.R,
        Key = "R"
    })
}


    for eventName, eventId in pairs(API.Enums.Events) do
        if Tristana[eventName] then
            API.EventManager.RegisterCallback(eventId, Tristana[eventName])
        end
    end

    return true
end
