if _G.CoreEx.ObjectManager.Player.CharName ~= "Tristana" then
    return
end

module("PewPewTristana", package.seeall, log.setup)
clean.module("PewPewTristana", clean.seeall, log.setup)

_G.CoreEx.AutoUpdate("https://raw.githubusercontent.com/hagbardlol/nosupport/main/PewPewTristana.lua", "1.0.5")

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

function Tristana.InRange(target)
    return target.Position:Distance(API.Player) <= API.Orbwalker.GetTrueAutoAttackRange(API.Player, target)
end

local lastAttackedEnemy = nil
local lastAttackedTick = 0

function Tristana.OnPostAttack(target)
    if Menu.Get("ComboQ") and target.IsHero and target.IsEnemy and API.Orbwalker.GetMode() == "Combo" and Tristana.Q:IsReady() then
        Tristana.Q:Cast()
    end
end

function Tristana.OnPreAttack(args)
    if args.Target.IsHero and args.Target.IsEnemy then
        lastAttackedEnemy = args.Target
        lastAttackedTick = API.Game.GetTime() * 1000
        
        local forced = TS:GetForcedTarget()
        if forced == nil or forced ~= args.Target then
            for _, enemy in pairs(API.ObjectManager.GetNearby("enemy", "heroes")) do
                if enemy.IsAlive and enemy.IsTargetable and Tristana.InRange(enemy) and enemy:GetBuff("tristanaechargesound") ~= nil then
                    args.Target = enemy
                    lastAttackedEnemy = enemy
                    return
                end
            end
        end
    end
end

function Tristana.OnDraw()

    if Menu.Get("DrawW") and Tristana.W:IsReady() then
        API.Renderer.DrawCircle3D(API.Player.Position, Tristana.W.Range, 30, 2, Menu.Get("DrawWColor"))
    end

end

function Tristana.OnGapclose(source, dashInstance)
    if not source.IsEnemy or dashInstance.Invulnerable and not source:IsFacing(API.Player.Position, 30) then
        return
    end

    if Menu.Get("RGap" .. source.CharName, true) and Tristana.R:IsReady() and Tristana.InRange(source) then
        print("Anti GapCloser " .. source.CharName)
        Tristana.R:Cast(source)
        return
    end
end


function Tristana.OnInterruptibleSpell(Source, SpellCast, Danger, EndTime, CanMoveDuringChannel)
    if not Source.IsEnemy or Source.Invulnerable then
        return
    end

    local slot = "UK"
    if SpellCast.Slot == API.Enums.SpellSlots.Q then
        slot = "Q"
    elseif SpellCast.Slot == API.Enums.SpellSlots.W then
        slot = "W"
    elseif SpellCast.Slot == API.Enums.SpellSlots.E then
        slot = "E"
    elseif SpellCast.Slot == API.Enums.SpellSlots.R then
        slot = "R"
    end

    if Menu.Get("InterruptR" .. Source.CharName .. slot, true) and Tristana.R:IsReady() and Tristana.R:IsInRange(Source) then
        print("Interrupt " .. Source.CharName .. " slot " .. slot)
        Tristana.R:Cast(Source)
        return
    end
end

function Tristana.OnTick()

    local forced = TS:GetForcedTarget()
    local tick = API.Game.GetTime() * 1000

    if Menu.Get("RKey") and Tristana.R:IsReady() then
        -- #1 last AA target (within 500 ms)
        if lastAttackedEnemy ~= nil and tick - lastAttackedTick < 500 and lastAttackedEnemy.IsAlive and lastAttackedEnemy.IsTargetable and Tristana.InRange(lastAttackedEnemy) then
            --print("R last AA target")
            Tristana.R:Cast(lastAttackedEnemy)
            return
        end
        -- #2 closest
        local min = math.huge
        local best = nil
        for _, enemy in pairs(API.ObjectManager.GetNearby("enemy", "heroes")) do
            if Tristana.InRange(enemy) and enemy.IsAlive and enemy.IsTargetable then
                local dist = enemy.Position:DistanceSqr(API.Player.Position)
                if dist < min then
                    best = enemy
                    min = dist
                end
            end
        end
        if best ~= nil then
            Tristana.R:Cast(best)
            return
        end
    end

    if Menu.Get("ComboE") and API.Orbwalker.GetMode() == "Combo" and Tristana.E:IsReady() and (API.Player.Pathing.IsDashing or API.Orbwalker.CanMove()) then
        if forced ~= nil and forced.IsAlive then
            if Tristana.InRange(forced) then
                Tristana.E:Cast(forced)
                return
            end
        else
            local list = {}
            for _, enemy in pairs(API.ObjectManager.GetNearby("enemy", "heroes")) do
                if Menu.Get("UseE" .. enemy.CharName, true) and Tristana.InRange(enemy) and enemy.IsAlive and enemy.IsTargetable then
                    table.insert(list, enemy)
                end
            end

            local target = TS:GetTargetFromList(list, true, nil, 1500)
            if target ~= nil then
                Tristana.E:Cast(target)
                return
            end
        end
    end


end

function OnLoad()

    Menu.RegisterMenu("PewPewTristana", "PewPewTristana", function()
        
        Menu.Keybind("RKey", "R Key", 82)
        Menu.Checkbox("ComboQ", "Use Q in combo", true)
        Menu.Checkbox("ComboE", "Use E in combo", true)

        local hash = {}
        Menu.NewTree("EWhitelist", "Combo E Whitelist", function()
            for _, enemy in pairs(API.ObjectManager.Get("enemy", "heroes")) do
                if hash[enemy.CharName] == nil then
                    Menu.Checkbox("UseE" .. enemy.CharName, enemy.CharName, true)
                    hash[enemy.CharName] = true
                end
            end
        end)

        hash = {}
        Menu.NewTree("RAntiGap", "Anti Gapcloser R Whitelist", function()
            for _, enemy in pairs(API.ObjectManager.Get("enemy", "heroes")) do
                if hash[enemy.CharName] == nil then
                    Menu.Checkbox("RGap" .. enemy.CharName, enemy.CharName, false)
                    hash[enemy.CharName] = true
                end
            end
        end)

        hash = {}
        Menu.NewTree("RInterrupt", "Interrupt R Whitelist", function()
            for _, enemy in pairs(API.ObjectManager.Get("enemy", "heroes")) do
                if hash[enemy.CharName] == nil then
                    Menu.NewTree("InterruptR" .. enemy.CharName, enemy.CharName, function()
                        Menu.Checkbox("InterruptR" .. enemy.CharName .. "Q", "Q", false)
                        Menu.Checkbox("InterruptR" .. enemy.CharName .. "W", "W", false)
                        Menu.Checkbox("InterruptR" .. enemy.CharName .. "E", "E", false)
                        Menu.Checkbox("InterruptR" .. enemy.CharName .. "R", "R", false)
                    end)
                    hash[enemy.CharName] = true
                end
            end
        end)

        Menu.Checkbox("DrawW", "Draw W Range", true)
        Menu.SameLine()
        Menu.ColorPicker("DrawWColor", "", 0xFFFFFFFFF)
        
    end)

    for eventName, eventId in pairs(API.Enums.Events) do
        if Tristana[eventName] then
            API.EventManager.RegisterCallback(eventId, Tristana[eventName])
        end
    end

    return true
end
