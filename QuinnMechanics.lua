--[[
________        .__                   _____                .__                  .__               
\_____  \  __ __|__| ____   ____     /     \   ____   ____ |  |__ _____    ____ |__| ____   ______
 /  / \  \|  |  \  |/    \ /    \   /  \ /  \_/ __ \_/ ___\|  |  \\__  \  /    \|  |/ ___\ /  ___/
/   \_/.  \  |  /  |   |  \   |  \ /    Y    \  ___/\  \___|   Y  \/ __ \|   |  \  \  \___ \___ \ 
\_____\ \_/____/|__|___|  /___|  / \____|__  /\___  >\___  >___|  (____  /___|  /__|\___  >____  >
       \__>             \/     \/          \/     \/     \/     \/     \/     \/        \/     \/ 
]]
local ScriptName, Version = "QuinnMechanics", "1.0.2"
_G.CoreEx.AutoUpdate("https://github.com/hagbardlol/nosupport/raw/main/" .. ScriptName ..".lua", Version)

local SDK = _G.CoreEx
local Lib = _G.Libs
local Obj = SDK.ObjectManager
local Player = Obj.Player
if _G.CoreEx.ObjectManager.Player.CharName ~= "Quinn" then
    return
end
local Event = SDK.EventManager
local Enums = SDK.Enums
local Renderer = SDK.Renderer
local Input = SDK.Input

local TS = Lib.TargetSelector()
local HitChanceEnum = SDK.Enums.HitChance
local Menu = Lib.NewMenu
local Orb = Lib.Orbwalker
local Pred = Lib.Prediction
local DmgLib = Lib.DamageLib
local Spell = Lib.Spell
local Geometry = SDK.Geometry
local Vector = Geometry.Vector

local basePosition = Player.TeamId == 100 and Vector(14302, 172, 14387) or Vector(415, 182, 415)

local UsableItems = {
    Prowler = {
        ProwlerItemIds = {7000, 6693},
        Range = 500
    },
    Youmuus = {
        YoumuusItemIds = {3388, 3142},
        Range = 0
    },
    GaleForce = {
        GaleForceItemIds = {6671},
        Range = 425
    },
    Goredrinker = {
        GoredrinkerItemIds = {6630},
        Range = 450
    },
    Stridebreaker = {
        StridebreakerItemIds = {6631},
        Range = 450
    },
    Wards = {
        WardsItemIds = {3340, 2055, 2056, 2057, 2050},
        Range = 600
    }
}

local UsableSS = {
    Ignite = {
        Slot = nil,
        Range = 600
    }
}
local spells = {
    Q = Spell.Skillshot({
        Slot = Enums.SpellSlots.Q,
        Range = 1050,
        Delay = 0.25,
        Speed = 1550,
        Radius = 120,
        Type = "Linear",
        Collisions = { Minions = true, WindWall = true, Heroes = true },
        Key = "Q"
    }),
    W = Spell.Active({
        Slot = Enums.SpellSlots.W,
        Range = 900,
        Delay = 0,
        Key = "W"
    }),
    E = Spell.Targeted({
        Slot = Enums.SpellSlots.E,
        Range = 600,
        Delay = 0,
        Key = "E"
    }),
    R = Spell.Active({
        Slot = Enums.SpellSlots.R,
        Range = 700,
        Key = "R"
    })
}

function IsInFountain()
    return Player:Distance(basePosition) < 300
end

function HasItem(itemId)
    for itemSlot, item in pairs(Player.Items) do
        if item and item.ItemId == itemId then
            return itemSlot, item
        end
    end

    return nil, nil
end

function HasUltUp()
    local ultCasted = false
    for k, v in pairs(Player.Buffs) do
        if v.Name == "QuinnR" then
            return true
        end
    end
    return ultCasted
end

function GetItemSlot(Arr)
    for _, itemId in ipairs(Arr) do
        local slot, item = HasItem(itemId)

        if slot then
            slot = slot + 6

            if Player:GetSpellState(slot) == Enums.SpellStates.Ready then
                return slot
            end
        end
    end

    return nil
end

function GetActiveItem()
    local hasProwler, hasGaleForce, hasGoredrinker, hasStridebreaker = GetItemSlot(UsableItems.Prowler.ProwlerItemIds),
        GetItemSlot(UsableItems.GaleForce.GaleForceItemIds), GetItemSlot(UsableItems.Goredrinker.GoredrinkerItemIds),
        GetItemSlot(UsableItems.Stridebreaker.StridebreakerItemIds)
    return hasProwler or hasGaleForce or hasGoredrinker or hasStridebreaker
end

function HasPassive(target)
    local hasPassive = false
    for k, v in pairs(target.Buffs) do
        if v.Name == "QuinnW" then
            return true
        end
    end
    return hasPassive
end

function CheckIgniteSlot()

    local slots = {Enums.SpellSlots.Summoner1, Enums.SpellSlots.Summoner2}

    local function IsIgnite(slot)
        return Player:GetSpell(slot).Name == "SummonerDot"
    end

    for _, slot in ipairs(slots) do
        if IsIgnite(slot) then
            if UsableSS.Ignite.Slot ~= slot then
                UsableSS.Ignite.Slot = slot
            end

            return
        end
    end

    if UsableSS.Ignite.Slot ~= nil then
        UsableSS.Ignite.Slot = nil
    end
end

function GetWardItem()
    local hasWard = GetItemSlot(UsableItems.Wards.WardsItemIds)
    return hasWard
end

BaseStrucutre = {}

function BaseStrucutre:new(dat)
    dat = dat or {}
    setmetatable(dat, self)
    self.__index = self
    return dat
end

function BaseStrucutre:GetLastHitMinion(pos, range, possibleDmg, collision, onlyKillable)
    local lastHitMinion = nil
    for k, v in pairs(Obj.GetNearby("enemy", "minions")) do
        local minion = v.AsAttackableUnit
        if minion.IsValid and not minion.IsDead and minion.IsTargetable and minion:Distance(pos) < range then
            if minion.Health < possibleDmg or not onlyKillable then
                if collision then
                    local qPred = Pred.GetPredictedPosition(minion, spells.Q, Player.Position)
                    if qPred and qPred.HitChanceEnum >= HitChanceEnum.VeryLow then
                        return minion
                    end
                elseif lastHitMinion == nil or minion.Health < lastHitMinion.Health then
                    lastHitMinion = minion
                end
            end
        end
    end
    return lastHitMinion
end

function BaseStrucutre:GetLastHitMonster(pos, range, possibleDmg, collision, onlyKillable)
    local lastHitMinion = nil
    for k, v in pairs(Obj.GetNearby("neutral", "minions")) do
        local minion = v.AsMinion
        if not minion.IsJunglePlant and minion.IsValid and not minion.IsDead and minion.IsTargetable and
            minion:Distance(pos) < range then
            if minion.Health < possibleDmg or not onlyKillable then
                if collision then
                    local qPred = Pred.GetPredictedPosition(minion, spells.Q, Player.Position)
                    if qPred and qPred.HitChanceEnum >= HitChanceEnum.VeryLow then
                        return minion
                    end
                elseif lastHitMinion == nil or minion.Health < lastHitMinion.Health then
                    lastHitMinion = minion
                end
            end
        end
    end
    return lastHitMinion
end

function BaseStrucutre:CountMinionsInRange(range, type)
    local amount = 0
    for k, v in pairs(Obj.GetNearby(type, "minions")) do
        local minion = v.AsMinion
        if not minion.IsJunglePlant and minion.IsValid and not minion.IsDead and minion.IsTargetable then
            amount = amount + 1
        end
    end
    return amount
end

function BaseStrucutre:GetPriorityMinion(pos, type, maxRange)
    local minionFocus = nil
    for k, v in pairs(Obj.GetNearby(type, "minions")) do
        local minion = v.AsMinion
        if not minion.IsJunglePlant and minion.IsValid and not minion.IsDead and minion.IsTargetable and minion:Distance(pos) < maxRange then
            if minionFocus == nil then
                minionFocus = minion
            elseif minionFocus.IsEpicMinion then
                minionFocus = minion
            elseif not minionFocus.IsEpicMinion and minionFocus.IsEliteMinion then
                minionFocus = minion
            elseif not minionFocus.IsEpicMinion and not minionFocus.IsEliteMinion then
                if minion.Health < minionFocus.Health or minionFocus:Distance(pos) > minion:Distance(pos) then
                    minionFocus = minion
                end
            end
        end
    end
    return minionFocus
end

function BaseStrucutre:GetEDmg()
    return 40 + spells.E:GetLevel() * 30 + (0.2 * Player.TotalAD)
end

function BaseStrucutre:GetRDmg()
    return 0.4 * Player.TotalAD
end

function BaseStrucutre:GetQDmg()
    return 15 + spells.Q:GetLevel() * 5 + (0.2 * Player.TotalAP) +
               (((80 + spells.Q:GetLevel() * 5) / 100) * Player.TotalAD)
end

function BaseStrucutre:GetIgniteDmg(target)
    return 50 + 20 * Player.Level - target.HealthRegen * 2.5
end

function BaseStrucutre:TotalDmg(Target, countSS)
    local Damage = DmgLib.CalculatePhysicalDamage(Player, Target, Player.TotalAD)
    if spells.Q:IsReady() then
        Damage = Damage + DmgLib.CalculateMagicalDamage(Player, Target, self:GetQDmg())
    end
    if UsableSS.Ignite.Slot ~= nil and Player:GetSpellState(UsableSS.Ignite.Slot) == Enums.SpellStates.Ready and countSS then
        Damage = Damage + DmgLib.CalculateMagicalDamage(Player, Target, self:GetIgniteDmg(Target))
    end
    if spells.E:IsReady() then
        Damage = Damage + DmgLib.CalculateMagicalDamage(Player, Target, self:GetEDmg(0))
    end
    if HasUltUp() then
        Damage = Damage + DmgLib.CalculateMagicalDamage(Player, Target, self:GetRDmg())
    end
    return Damage
end

function BaseStrucutre:CountHeroes(pos, range, team)
    local num = 0
    for k, v in pairs(Obj.Get(team, "heroes")) do
        local hero = v.AsHero
        if hero.IsValid and not hero.IsDead and hero.IsTargetable and hero:Distance(pos) < range then
            num = num + 1
        end
    end
    return num
end

function BaseStrucutre:Menu()
    Menu.RegisterMenu("QuinnMechanics", "Quinn Mechanics", function()
        Menu.NewTree("Combo", "Combo Options", function()
            Menu.Checkbox("Combo.CastQ", "Use Q", true)
            Menu.Checkbox("Combo.CastW", "Use W When Vision Lost", true)
            Menu.Checkbox("Combo.CastE", "Use E", true)
            Menu.Checkbox("Combo.CastIgnite", "Use Ignite", true)
        end)
        Menu.NewTree("Harass", "Harass Options", function()
            Menu.ColoredText("Mana Percent limit", 0xFFD700FF, true)
            Menu.Slider("Harass.ManaSlider", "", 70, 0, 100)
            Menu.Checkbox("Harass.CastQ", "Use Q", true)
            Menu.Checkbox("Harass.CastW", "Use W When Vision Lost", false)
            Menu.Checkbox("Harass.CastE", "Use E", true)
        end)
        Menu.NewTree("Lasthit", "LastHit Options", function()
            Menu.ColoredText("Mana Percent limit", 0xFFD700FF, true)
            Menu.Slider("Lasthit.ManaSlider", "", 50, 0, 100)
            Menu.Checkbox("Lasthit.CastQ", "Use Q", true)
            Menu.Checkbox("Lasthit.CastE", "Use E", true)
        end)
        Menu.NewTree("Waveclear", "Waveclear Options", function()
            Menu.Slider("Lane.ManaSlider", "Lane Mana Slider", 70, 0, 100)
            Menu.NewTree("Lane", "Lane Options", function()
                Menu.Checkbox("Lane.Q", "Use Q", true)
                Menu.Checkbox("Lane.E", "Use E", false)
            end)
            Menu.NewTree("Jungle", "Jungle Options", function()
                Menu.Checkbox("Jungle.Q", "Use Q", true)
                Menu.Checkbox("Jungle.E", "Use E", true)
            end)
        end)
        Menu.NewTree("Misc", "Misc Options", function()
            Menu.Checkbox("Misc.CastR", "Auto R on Base", true)
            Menu.Checkbox("Misc.GapE", "Use E on Gapcloser", true)
            Menu.Checkbox("Misc.GapQ", "Use Q on Gapcloser", true)
            Menu.Checkbox("Misc.AutoWardOnLostVision", "Ward on lost vision", true)
        end)
        Menu.NewTree("Draw", "Drawing Options", function()
            Menu.Checkbox("Drawing.Damage", "Draw Possible DMG", false)
            Menu.Checkbox("Drawing.Q.Enabled", "Draw Q Range", false)
            Menu.Checkbox("Drawing.E.Enabled", "Draw E Range", false)
            Menu.Checkbox("Drawing.R.Enabled", "Draw R Range", false)
        end)
    end)
end

function BaseStrucutre:IsInDanger(Target)
    if Target.IsEnemy or Target.IsDead then
        return false
    end
    local amountThreats = self:CountHeroes(Target.Position, spells.W.Range, "ally")
    if amountThreats >= 1 and Target.HealthPercent <= 0.2 then
        return true
    end

    return false
end

function BaseStrucutre:OnDraw()
    if Menu.Get("Drawing.Q.Enabled") then
        Renderer.DrawCircle3D(Player.Position, spells.Q.Range, 30, 4, 0x118AB2FF)
    end
    if Menu.Get("Drawing.E.Enabled") then
        Renderer.DrawCircle3D(Player.Position, spells.E.Range, 30, 4, 0x118AB2FF)
    end
    if Menu.Get("Drawing.R.Enabled") then
        Renderer.DrawCircle3D(Player.Position, spells.R.Range, 30, 4, 0x118AB2FF)
    end
end

function BaseStrucutre:AutoCast()
    local castROnBase = Menu.Get("Misc.CastR")
    if castROnBase and spells.R:IsReady() and IsInFountain() and not HasUltUp() then
        spells.R:Cast()
    end
end

function BaseStrucutre:Combo(postAttack)
    local CastQ, CastE, CastIgnite = Menu.Get("Combo.CastQ"), Menu.Get("Combo.CastE"), Menu.Get("Combo.CastIgnite")
    local Target = TS:GetTarget(HasUltUp() and spells.E.Range or spells.Q.Range, true)
    local hasActiveItem = GetActiveItem()
    local hasYoumuu = GetItemSlot(UsableItems.Youmuus.YoumuusItemIds)
    if not Target then
        return
    end

    if CastIgnite and UsableSS.Ignite.Slot ~= nil and Player:GetSpellState(UsableSS.Ignite.Slot) ==
        Enums.SpellStates.Ready and self:GetIgniteDmg(Target) > Target.Health + 10 and Player:Distance(Target) <
        UsableSS.Ignite.Range then
        Input.Cast(UsableSS.Ignite.Slot, Target)
    end

    if hasYoumuu and Player:GetSpellState(hasYoumuu) == Enums.SpellStates.Ready then
        Input.Cast(hasYoumuu)
    end

    if HasUltUp() then
        if hasActiveItem then
            if (postAttack or not HasPassive(Target)) and CastQ and spells.Q:IsReady() and spells.Q:CastOnHitChance(Target, HitChanceEnum.Medium) then
                return
            end
            if spells.E:IsReady() and spells.E:IsInRange(Target) and CastE then
                spells.E:Cast(Target)
                return
            end
            if not spells.E:IsReady() and Player:GetSpellState(hasActiveItem) == Enums.SpellStates.Ready then
                Input.Cast(hasActiveItem, Target)
                return
            end
        else
            if spells.E:IsReady() and spells.E:IsInRange(Target) and CastE then
                spells.E:Cast(Target)
                return
            end
        end
    else
        if spells.E:IsReady() and spells.E:IsInRange(Target) and CastE and (postAttack or not HasPassive(Target)) then
            spells.E:Cast(Target)
            return
        end
        if not spells.E:IsReady() and hasActiveItem and Player:GetSpellState(hasActiveItem) == Enums.SpellStates.Ready then
            Input.Cast(hasActiveItem, Target.Position)
            return
        end
        if CastQ and spells.Q:IsReady() and spells.Q:CastOnHitChance(Target, HitChanceEnum.Medium) and (not spells.E:IsReady() or postAttack or not HasPassive(Target)) then
            return
        end
    end
end

function BaseStrucutre:Harass(postAttack)
    local CastQ, CastE = Menu.Get("Harass.CastQ"), Menu.Get("Harass.CastE")
    local Target = TS:GetTarget(spells.E.Range, true)
    if not Target then
        return
    end
    if spells.E:IsReady() and spells.E:IsInRange(Target) and CastE and (postAttack or not HasPassive(Target)) then
        spells.E:Cast(Target)
    end
    if CastQ and spells.Q:IsReady() and spells.Q:CastOnHitChance(Target, HitChanceEnum.Medium) and not spells.E:IsReady() and (postAttack or not HasPassive(Target)) then
        return
    end
end

function BaseStrucutre:Lasthit(postAttack)
    local ManaSlider, CastQ, CastE = Menu.Get("Lasthit.ManaSlider"), Menu.Get("Lasthit.CastQ"),
        Menu.Get("Lasthit.CastE")
    local minions = Obj.GetNearby("enemy", "minions")
    if #minions == 0 or Player.ManaPercent <= ManaSlider / 100 then
        return
    end
    if CastE and spells.E:IsReady() then
        local lastEHitMinon = self:GetLastHitMinion(Player.Position, spells.E.Range, self:GetEDmg(), false, true)
        if lastEHitMinon == nil then
            return
        else
            spells.E:Cast(lastEHitMinon)
            return
        end
    elseif CastQ and spells.Q:IsReady() then
        local lastQHitMinon = self:GetLastHitMinion(Player.Position, spells.Q.Range, self:GetQDmg(), true, true)
        if lastQHitMinon == nil then
            return
        else
            spells.Q:Cast(lastQHitMinon.Position)
            return
        end
    end
end

function BaseStrucutre:Waveclear(postAttack)
    local ManaSlider, CastQLane, CastELane, CastQJungle, CastEJungle = Menu.Get("Lane.ManaSlider"), Menu.Get("Lane.Q"),
        Menu.Get("Lane.E"), Menu.Get("Jungle.Q"), Menu.Get("Jungle.E")
    local minions = self:CountMinionsInRange(500, "enemy")
    local monsters = self:CountMinionsInRange(500, "neutral")
    if (minions == 0 and monsters == 0) or Player.ManaPercent <= ManaSlider / 100 then
        return
    end

    if minions > monsters then
        local minionFocus = self:GetPriorityMinion(Player.Position, "enemy", 600)
        if minionFocus == nil then
            return
        end
        if CastELane and spells.E:IsReady() and postAttack and not HasPassive(minionFocus) then
            spells.E:Cast(minionFocus)
            return
        end
        if CastQLane and spells.Q:IsReady() then
            spells.Q:Cast(minionFocus.Position)
            return
        end
    else
        local minionFocus = self:GetPriorityMinion(Player.Position, "neutral", 600)
        if minionFocus == nil then
            return
        end
        if CastEJungle and spells.E:IsReady() and not HasPassive(minionFocus) then
            spells.E:Cast(minionFocus)
            return
        end
        if CastQJungle and spells.Q:IsReady() and not HasPassive(minionFocus) then
            spells.Q:Cast(minionFocus.Position)
            return
        end
    end

end

function BaseStrucutre:OnLowPriority()
    self:AutoCast()
end

function BaseStrucutre:OnVisionLost(obj)
    local orbMode = Orb.GetMode()
    if orbMode == "Combo" then
        local CastW = Menu.Get("Combo.CastW")
        if CastW and spells.W:IsReady() then
            spells.W:Cast()
        elseif Menu.Get("Misc.AutoWardOnLostVision") then
            local hasWard = GetWardItem()
            if hasWard ~= nil and Player:GetSpellState(hasWard) == Enums.SpellStates.Ready and obj.Position:IsGrass() then
                Input.Cast(hasWard, obj.Position)
            end
        end
    elseif orbMode == "Harass" then
        local CastW = Menu.Get("Harass.CastW")
        if CastW and spells.W:IsReady() then
            spells.W:Cast()
        end
    end
end

function BaseStrucutre:OnPostAttack()
    local orbMode = Orb.GetMode()
    if orbMode == "Combo" then
        self:Combo(true)
    elseif orbMode == "Harass" then
        self:Harass(true)
    elseif orbMode == "Waveclear" then
        self:Waveclear(true)
    elseif orbMode == "Lasthit" then
        self:Lasthit(true)
    end
end

function BaseStrucutre:OnLoop()
    local orbMode = Orb.GetMode()
    if orbMode == "Combo" then
        self:Combo(false)
    elseif orbMode == "Harass" then
        self:Harass(false)
    elseif orbMode == "Waveclear" then
        self:Waveclear(false)
    elseif orbMode == "Lasthit" then
        self:Lasthit(false)
    elseif orbMode == "Flee" then
    end
end

function BaseStrucutre:OnGapClose(source, dash)
    if not source.IsEnemy or dash.Invulnerable then
        return
    end
    local GapE = Menu.Get("Misc.GapE")
    local GapQ = Menu.Get("Misc.GapQ")
    if spells.E:IsReady() and GapE then
        spells.E:Cast(Player)
    elseif spells.Q:IsReady() and spells.Q:IsInRange(source) and GapQ then
        local qPred = Pred.GetPredictedPosition(source, spells.Q, Player.Position)
        if qPred and qPred.HitChanceEnum >= HitChanceEnum.VeryLow then
            spells.Q:Cast(qPred.CastPosition)
        end
    end
end

function BaseStrucutre:OnDrawDamage(target, dmgList)
    if Menu.Get("Drawing.Damage") then
        table.insert(dmgList, self:TotalDmg(target, true))
    end
end

QuinnMechanics = BaseStrucutre:new()

QuinnMechanics:Menu()

-- Loading Components --

-- Events --
local OnNormalPriority = function()
    QuinnMechanics:OnLoop()
end

local OnGapClose = function(source, dash)
    QuinnMechanics:OnGapClose(source, dash)
end

local OnLowPriority = function()
    QuinnMechanics:OnLowPriority()
end

local OnPostAttack = function()
    QuinnMechanics:OnPostAttack()
end

local OnDraw = function()
    QuinnMechanics:OnDraw()
end

local OnVisionLost = function(obj)
    QuinnMechanics:OnVisionLost(obj)
end

local OnDrawDamage = function(target, dmgList)
    QuinnMechanics:OnDrawDamage(target, dmgList)
end

function OnLoad()
    Event.RegisterCallback(Enums.Events.OnLowPriority, OnLowPriority)
    Event.RegisterCallback(Enums.Events.OnNormalPriority, OnNormalPriority)
    Event.RegisterCallback(Enums.Events.OnGapclose, OnGapClose)
    Event.RegisterCallback(Enums.Events.OnPostAttack, OnPostAttack)
    Event.RegisterCallback(Enums.Events.OnVisionLost, OnVisionLost)
    Event.RegisterCallback(Enums.Events.OnDraw, OnDraw)
    Event.RegisterCallback(Enums.Events.OnDrawDamage, OnDrawDamage)
    CheckIgniteSlot()

    return true
end