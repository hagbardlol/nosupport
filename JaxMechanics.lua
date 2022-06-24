--[[

    /$$$$$                           /$$      /$$                     /$$                           /$$                    
   |__  $$                          | $$$    /$$$                    | $$                          |__/                    
      | $$  /$$$$$$  /$$   /$$      | $$$$  /$$$$  /$$$$$$   /$$$$$$$| $$$$$$$   /$$$$$$  /$$$$$$$  /$$  /$$$$$$$  /$$$$$$$
      | $$ |____  $$|  $$ /$$/      | $$ $$/$$ $$ /$$__  $$ /$$_____/| $$__  $$ |____  $$| $$__  $$| $$ /$$_____/ /$$_____/
 /$$  | $$  /$$$$$$$ \  $$$$/       | $$  $$$| $$| $$$$$$$$| $$      | $$  \ $$  /$$$$$$$| $$  \ $$| $$| $$      |  $$$$$$ 
| $$  | $$ /$$__  $$  >$$  $$       | $$\  $ | $$| $$_____/| $$      | $$  | $$ /$$__  $$| $$  | $$| $$| $$       \____  $$
|  $$$$$$/|  $$$$$$$ /$$/\  $$      | $$ \/  | $$|  $$$$$$$|  $$$$$$$| $$  | $$|  $$$$$$$| $$  | $$| $$|  $$$$$$$ /$$$$$$$/
 \______/  \_______/|__/  \__/      |__/     |__/ \_______/ \_______/|__/  |__/ \_______/|__/  |__/|__/ \_______/|_______/ 
                                                                            
]]
if _G.CoreEx.ObjectManager.Player.CharName ~= "Jax" then
    return
end
local ScriptName, Version = "JaxMechanics", "1.0.3"
_G.CoreEx.AutoUpdate("https://raw.githubusercontent.com/hagbardlol/nosupport/main/" .. ScriptName ..".lua", Version)

local SDK = _G.CoreEx
local Lib = _G.Libs
local Obj = SDK.ObjectManager
local Player = Obj.Player
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

local shouldJump = false

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
    },
    Smite = {
        Slot = nil,
        Range = 500
    },
    Flash = {
        Slot = nil,
        Range = 400
    }
}

local spells = {
    Q = Spell.Targeted({
        Slot = Enums.SpellSlots.Q,
        Range = 700,
        Key = "Q"
    }),
    W = Spell.Active({
        Slot = Enums.SpellSlots.W,
        Range = Player.AttackRange,
        Key = "W"
    }),
    E = Spell.Active({
        Slot = Enums.SpellSlots.E,
        Range = 300,
        Key = "E"
    }),
    R = Spell.Active({
        Slot = Enums.SpellSlots.R,
        Key = "R"
    })
}

function IsInFountain()
    return Player:Distance(basePosition) < 300
end

function ISEActive()
    local hasPassive = false
    for k, v in pairs(Player.Buffs) do
        if v.Name == "JaxCounterStrike" then
            return true
        end
    end
    return hasPassive
end

function IsInAARange(Target)
    return Player:Distance(Target) <= Player.AttackRange
end

function HasItem(itemId)
    for itemSlot, item in pairs(Player.Items) do
        if item and item.ItemId == itemId then
            return itemSlot, item
        end
    end

    return nil, nil
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

function GetWardItem()
    local hasWard = GetItemSlot(UsableItems.Wards.WardsItemIds)
    return hasWard
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

function CheckFlashSlot()
    local slots = {Enums.SpellSlots.Summoner1, Enums.SpellSlots.Summoner2}

    local function IsFlash(slot)
        return Player:GetSpell(slot).Name == "SummonerFlash"
    end

    for _, slot in ipairs(slots) do
        if IsFlash(slot) then
            if UsableSS.Flash.Slot ~= slot then
                UsableSS.Flash.Slot = slot
            end

            return
        end
    end

    if UsableSS.Flash.Slot ~= nil then
        UsableSS.Flash.Slot = nil
    end
end

function CheckSmiteSlot()
    local slots = {Enums.SpellSlots.Summoner1, Enums.SpellSlots.Summoner2}

    local function IsSmite(slot)
        return Player:GetSpell(slot).Name == "S5_SummonerSmiteDuel" or Player:GetSpell(slot).Name ==
                   "S5_SummonerSmitePlayerGanker" or Player:GetSpell(slot).Name == "SummonerSmite"
    end

    for _, slot in ipairs(slots) do
        if IsSmite(slot) then
            if UsableSS.Smite.Slot ~= slot then
                UsableSS.Smite.Slot = slot
            end

            return
        end
    end

    if UsableSS.Ignite.Slot ~= nil then
        UsableSS.Ignite.Slot = nil
    end
end

BaseStrucutre = {}

function BaseStrucutre:new(dat)
    dat = dat or {}
    setmetatable(dat, self)
    self.__index = self
    return dat
end

function BaseStrucutre:Menu()
    Menu.RegisterMenu(ScriptName, ScriptName .. " V" .. Version, function()
        Menu.NewTree("Combo", "Combo Options", function()
            Menu.Checkbox("Combo.CastQ", "Use Q", true)
            Menu.Checkbox("Combo.CastW", "Use W", true)
            Menu.Checkbox("Combo.CastE", "Use E", true)
            Menu.Checkbox("Combo.CastEInsta", "Use E InstaStun", false)
            Menu.Checkbox("Combo.CastR", "Use R", true)
            Menu.Slider("Combo.MinHealthCastR", "Min Health to Use R", 80, 0, 100, 5)
            Menu.Slider("Combo.MinEnemies", "Min Enemies in Range to use R", 1, 1, 5, 1)
            Menu.Checkbox("Combo.UseItem", "Use Offensive Items (If Available)", true)
            Menu.Checkbox("Combo.CastIgnite", "Use Ignite", true)
            Menu.Checkbox("Combo.CastSmite", "Use Smite", true)
            Menu.Checkbox("Combo.Flash", "Use Flash if Killable", false)
        end)
        Menu.NewTree("Harass", "Harass Options", function()
            Menu.ColoredText("Mana Percent limit", 0xFFD700FF, true)
            Menu.Slider("Harass.ManaSlider", "", 70, 0, 100)
            Menu.Checkbox("Harass.CastQ", "Use Q", true)
            Menu.Checkbox("Harass.CastW", "Use W", true)
            Menu.Checkbox("Harass.CastE", "Use E", true)
        end)
        Menu.NewTree("Lasthit", "LastHit Options", function()
            Menu.ColoredText("Mana Percent limit", 0xFFD700FF, true)
            Menu.Slider("Lasthit.ManaSlider", "", 50, 0, 100)
            Menu.Checkbox("Lasthit.CastQ", "Use Q", true)
            Menu.Checkbox("Lasthit.CastW", "Use W", true)
        end)
        Menu.NewTree("Waveclear", "Waveclear Options", function()
            Menu.Slider("Lane.ManaSlider", "Lane Mana Slider", 70, 0, 100)
            Menu.NewTree("Lane", "Lane Options", function()
                Menu.Checkbox("Lane.Q", "Use Q", true)
                Menu.Checkbox("Lane.W", "Use W", true)
                Menu.Checkbox("Lane.E", "Use E", false)
            end)
            Menu.NewTree("Jungle", "Jungle Options", function()
                Menu.Checkbox("Jungle.Q", "Use Q", true)
                Menu.Checkbox("Jungle.W", "Use W", true)
                Menu.Checkbox("Jungle.E", "Use E", true)
            end)
        end)
        Menu.NewTree("Misc", "Misc Options", function()
            Menu.Keybind("WardJump", "Ward Jump", string.byte('T'))
            Menu.Checkbox("Misc.AutoWardOnLostVision", "Ward on lost vision", true)
        end)
        Menu.NewTree("Draw", "Drawing Options", function()
            Menu.Checkbox("Drawing.Damage", "Draw Possible DMG", false)
            Menu.Checkbox("Drawing.Q.Enabled", "Draw Q Range", false)
            Menu.Checkbox("Drawing.E.Enabled", "Draw E Range", false)
        end)
    end)
end

function BaseStrucutre:GetQDmg()
    return 25 + spells.Q:GetLevel() * 40 + (1 * Player.TotalAD) + (0.6 * Player.TotalAP)
end

function BaseStrucutre:GetWDmg()
    return 5 + spells.W:GetLevel() * 35 + (0.6 * Player.TotalAP)
end

function BaseStrucutre:GetEDmg()
    return 30 + spells.E:GetLevel() * 25 + (0.5 * Player.TotalAD)
end

function BaseStrucutre:GetRDmg()
    return 60 + spells.R:GetLevel() * 40 + (0.7 * Player.TotalAP)
end

function BaseStrucutre:GetIgniteDmg(target)
    return 50 + 20 * Player.Level - target.HealthRegen * 2.5
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
        if not minion.IsJunglePlant and minion.IsValid and not minion.IsDead and minion.IsTargetable and
            Player:Distance(minion) < range then
            amount = amount + 1
        end
    end
    return amount
end

function BaseStrucutre:GetPriorityMinion(pos, type, maxRange)
    local minionFocus = nil
    for k, v in pairs(self:GetNerbyMinions(pos, type, maxRange)) do
        local minion = v.AsMinion
        if not minion.IsJunglePlant and minion.IsValid and not minion.IsDead and minion.IsTargetable then
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

function BaseStrucutre:GetNerbyMinions(pos, type, maxRange)
    local minionTable = {}
    for k, v in pairs(Obj.Get(type, "minions")) do
        local minion = v.AsMinion
        if not minion.IsJunglePlant and minion.IsValid and not minion.IsDead and minion.IsTargetable and
            minion:Distance(pos) < maxRange then
            table.insert(minionTable, minion)
        end
    end
    return minionTable
end

function BaseStrucutre:GetNerbyTargets(target, range)
    local objTable = {}
    for k, v in pairs(Obj.GetNearby("all", "minions")) do
        local obj = v.AsAttackableUnit
        if obj.IsValid and obj.IsDead and target:Distance(obj) < range then
            table.insert(objTable, obj)
        end
    end
    for k, v in pairs(Obj.GetNearby("all", "heroes")) do
        local obj = v.AsAttackableUnit
        if obj.IsValid and obj.IsDead and not obj.IsMe and target:Distance(obj) < range then
            table.insert(objTable, obj)
        end
    end
    return objTable
end

function BaseStrucutre:GetNearstTarget(target, range)
    local obj = nil
    for k, v in pairs(self:GetNerbyTargets(target, range)) do
        if obj ~= nil and target:Distance(v) < target:Distance(obj) then
            obj = v
        else
            obj = v
        end
    end
    return obj
end

function BaseStrucutre:GetSmiteDmg()
    local smiteData = Player:GetSpell(UsableSS.Smite.Slot)
    if smiteData.Name == "S5_SummonerSmiteDuel" then
        return 41 + Player.Level * 7
    elseif smiteData.Name == "S5_SummonerSmitePlayerGanker" then
        return 11.3 + Player.Level * 8.6
    elseif smiteData.Name == "SummonerSmite" then
        return 0
    end
    return 0
end

function BaseStrucutre:TotalDmg(Target, countSS)
    local Damage = DmgLib.CalculatePhysicalDamage(Player, Target, Player.TotalAD)
    if spells.Q:IsReady() and spells.Q:IsInRange(Target) then
        Damage = Damage + DmgLib.CalculatePhysicalDamage(Player, Target, self:GetQDmg())
    end
    if spells.W:IsReady() and IsInAARange(Target) then
        Damage = Damage + DmgLib.CalculateMagicalDamage(Player, Target, self:GetWDmg())
    end
    if UsableSS.Ignite.Slot ~= nil and Player:GetSpellState(UsableSS.Ignite.Slot) == Enums.SpellStates.Ready and countSS and
        Player:Distance(Target) < UsableSS.Ignite.Range then
        Damage = Damage + DmgLib.CalculateMagicalDamage(Player, Target, self:GetIgniteDmg(Target))
    end
    if spells.E:IsReady() and spells.E:IsInRange(Target) then
        Damage = Damage + DmgLib.CalculatePhysicalDamage(Player, Target, self:GetEDmg())
    end
    if spells.R:IsReady() and IsInAARange(Target) then
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
end

function BaseStrucutre:AutoCast()
    if Menu.Get("WardJump") and spells.Q:IsReady() then
        local hasWard = GetWardItem()
        if hasWard ~= nil and Player:GetSpellState(hasWard) == Enums.SpellStates.Ready then
            shouldJump = true
            Input.Cast(hasWard, Renderer.GetMousePos())
        end
    elseif shouldJump and not spells.Q:IsReady() then
        shouldJump = false
    end
end

function BaseStrucutre:Combo(postAttack)
    local CastQ, CastW, CastE, CastEInsta, CastR, CastIgnite, CastSmite, MinHealthCastR, MinEnemies, UseItem, Flash =
        Menu.Get("Combo.CastQ"), Menu.Get("Combo.CastW"), Menu.Get("Combo.CastE"), Menu.Get("Combo.CastEInsta"),
        Menu.Get("Combo.CastR"), Menu.Get("Combo.CastIgnite"), Menu.Get("Combo.CastSmite"),
        Menu.Get("Combo.MinHealthCastR"), Menu.Get("Combo.MinEnemies"), Menu.Get("Combo.UseItem"),
        Menu.Get("Combo.Flash")
    local Target = TS:GetTarget(spells.Q.Range + 400, true)
    local hasActiveItem = GetActiveItem()
    if not Target then
        return
    end

    if CastIgnite and UsableSS.Ignite.Slot ~= nil and Player:GetSpellState(UsableSS.Ignite.Slot) ==
        Enums.SpellStates.Ready and self:GetIgniteDmg(Target) > Target.Health + 10 and Player:Distance(Target) <
        UsableSS.Ignite.Range then
        Input.Cast(UsableSS.Ignite.Slot, Target)
        return
    end

    if Flash and UsableSS.Flash.Slot ~= nil and Player:GetSpellState(UsableSS.Flash.Slot) == Enums.SpellStates.Ready then
        if CastIgnite and UsableSS.Ignite.Slot ~= nil and Player:GetSpellState(UsableSS.Ignite.Slot) ==
            Enums.SpellStates.Ready and self:GetIgniteDmg(Target) > Target.Health and Player:Distance(Target) <
            UsableSS.Ignite.Range + UsableSS.Flash.Range then
            Input.Cast(UsableSS.Flash.Slot, Target.Position)
            return
        elseif Player:Distance(Target) < spells.Q.Range + UsableSS.Flash.Range and CastQ and spells.Q:IsReady() and
            DmgLib.CalculatePhysicalDamage(Player, Target, self:GetQDmg()) > Target.Health then
            Input.Cast(UsableSS.Flash.Slot, Target.Position)
            return
        end
    end

    if CastSmite and UsableSS.Smite.Slot ~= nil and Player:GetSpellState(UsableSS.Smite.Slot) == Enums.SpellStates.Ready and
        (self:GetSmiteDmg() > Target.Health or Player:Distance(Target) > Player.AttackRange + 100) and
        Player:Distance(Target) < UsableSS.Smite.Range then
        Input.Cast(UsableSS.Smite.Slot, Target)
        return
    end

    if hasActiveItem and UseItem then
        if (IsInAARange(Target) or Target.IsImmovable) and Player:GetSpellState(hasActiveItem) ==
            Enums.SpellStates.Ready then
            Input.Cast(hasActiveItem, Target.Position)
            return
        end
    end

    if CastR and spells.R:IsReady() and
        (Player.HealthPercent < MinHealthCastR / 100 or self:CountHeroes(Player.Position, 700, "enemy") >= MinEnemies) then
        spells.R:Cast()
        return
    end

    if CastW and spells.W:IsReady() and postAttack and IsInAARange(Target) then
        spells.W:Cast()
        return
    end

    if CastQ and spells.Q:IsReady() and (postAttack or not IsInAARange(Target)) then
        if spells.Q:IsInRange(Target) then
            spells.Q:Cast(Target)
            return
        else
            local nearObj = self:GetNearstTarget(Target, Player.AttackRange)
            if nearObj ~= nil then
                spells.Q:Cast(nearObj)
                return
            end
        end
    end

    if CastE and spells.E:IsReady() and not ISEActive() and IsInAARange(Target) then
        spells.E:Cast()
        return
    end

    if CastEInsta and spells.E:IsReady() and ISEActive() and spells.E:IsInRange(Target) then
        spells.E:Cast()
        return
    end
end

function BaseStrucutre:Harass(postAttack)
    local CastQ, CastW, CastE = Menu.Get("Harass.CastQ"), Menu.Get("Harass.CastW"), Menu.Get("Harass.CastE")
    local Target = TS:GetTarget(spells.Q.Range, true)
    if not Target then
        return
    end

    if CastW and spells.W:IsReady() and postAttack and IsInAARange(Target) then
        spells.W:Cast()
        return
    end

    if CastQ and spells.Q:IsReady() and (postAttack or not IsInAARange(Target)) then
        if spells.Q:IsInRange(Target) then
            spells.Q:Cast(Target)
            return
        end
    end

    if CastE and spells.E:IsReady() and not ISEActive() then
        spells.E:Cast()
        return
    end

end

function BaseStrucutre:Lasthit(postAttack)
    local ManaSlider, CastQ, CastW = Menu.Get("Lasthit.ManaSlider"), Menu.Get("Lasthit.CastQ"),
        Menu.Get("Lasthit.CastW")
    local minions = Obj.GetNearby("enemy", "minions")
    if #minions == 0 or Player.ManaPercent <= ManaSlider / 100 then
        return
    end
    if CastW and spells.W:IsReady() and postAttack then
        local lastHitMinion = self:GetLastHitMinion(Player.Position, Player.AttackRange, self:GetWDmg(), false, true)
        if lastHitMinion == nil then
            return
        else
            spells.W:Cast()
            return
        end
    end
    if CastQ and spells.Q:IsReady() and postAttack then
        local lastHitMinion = self:GetLastHitMinion(Player.Position, spells.Q.Range, self:GetQDmg(), false, true)
        if lastHitMinion == nil then
            return
        else
            spells.Q:Cast(lastHitMinion)
            return
        end
    end
end

function BaseStrucutre:Waveclear(postAttack)
    local ManaSlider, CastQLane, CastWLane, CastQJungle, CastWJungle, CastEJungle = Menu.Get("Lane.ManaSlider"),
        Menu.Get("Lane.Q"), Menu.Get("Lane.W"), Menu.Get("Jungle.Q"), Menu.Get("Jungle.W"), Menu.Get("Jungle.E")
    local minions = self:CountMinionsInRange(500, "enemy")
    local monsters = self:CountMinionsInRange(500, "neutral")
    if (minions == 0 and monsters == 0) or Player.ManaPercent <= ManaSlider / 100 then
        return
    end

    if minions > monsters then
        local minionFocus = self:GetPriorityMinion(Player.Position, "enemy", spells.Q.Range)
        if minionFocus == nil then
            return
        end
        if CastWLane and postAttack then
            spells.W:Cast()
            return
        end
        if CastQLane and spells.Q:IsReady() then
            spells.Q:Cast(minionFocus)
            return
        end
    else
        local minionFocus = self:GetPriorityMinion(Player.Position, "neutral", spells.Q.Range)
        if minionFocus == nil then
            return
        end
        if minionFocus.IsEpicMinion then
            if (minionFocus.Health < 1300 and UsableSS.Smite.Slot ~= nil) and self:TotalDmg(minionFocus, false) <
                minionFocus.Health then
                return
            end
            if CastQJungle and spells.Q:IsReady() and spells.Q:IsInRange(minionFocus) then
                spells.Q:Cast(minionFocus)
                return
            end
            if CastWJungle and spells.W:IsReady() and postAttack and IsInAARange(minionFocus) then
                spells.W:Cast()
                return
            end
            if CastEJungle and not ISEActive() and spells.E:IsReady() and spells.E:IsInRange(minionFocus) then
                spells.E:Cast()
                return
            end
        else
            if CastQJungle and spells.Q:IsReady() and spells.Q:IsInRange(minionFocus) then
                spells.Q:Cast(minionFocus)
                return
            end
            if CastWJungle and spells.W:IsReady() and postAttack and IsInAARange(minionFocus) then
                spells.W:Cast()
                return
            end
            if CastEJungle and not ISEActive() and spells.E:IsReady() and spells.E:IsInRange(minionFocus) then
                spells.E:Cast()
                return
            end
        end
    end

end

function BaseStrucutre:OnLowPriority()
    CheckSmiteSlot()
    CheckIgniteSlot()
    CheckFlashSlot()
end

function BaseStrucutre:OnVisionLost(obj)
    local orbMode = Orb.GetMode()
    if orbMode == "Combo" then
        if Menu.Get("Misc.AutoWardOnLostVision") then
            local hasWard = GetWardItem()
            if hasWard ~= nil and Player:GetSpellState(hasWard) == Enums.SpellStates.Ready and obj.Position:IsGrass() then
                Input.Cast(hasWard, obj.Position)
            end
        end
    elseif orbMode == "Harass" then
        if Menu.Get("Misc.AutoWardOnLostVision") then
            local hasWard = GetWardItem()
            if hasWard ~= nil and Player:GetSpellState(hasWard) == Enums.SpellStates.Ready and obj.Position:IsGrass() then
                Input.Cast(hasWard, obj.Position)
            end
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
    self:AutoCast()
    local orbMode = Orb.GetMode()
    if orbMode == "Combo" then
        self:Combo(false)
    elseif orbMode == "Harass" then
        self:Harass(false)
    elseif orbMode == "Waveclear" then
        self:Waveclear(false)
    elseif orbMode == "Lasthit" then
        self:Lasthit(false)
    end
end

function BaseStrucutre:OnCreateObject(obj)
    if (Menu.Get("WardJump") or shouldJump) and obj.IsWard and obj.IsAlly and spells.Q:IsReady() and spells.Q:IsInRange(obj.Position) then
        delay(125, Input.Cast, Enums.SpellSlots.Q, obj)
    end
end

function BaseStrucutre:OnGapClose(source, dash)
end

function BaseStrucutre:OnDrawDamage(target, dmgList)
    if Menu.Get("Drawing.Damage") then
        table.insert(dmgList, self:TotalDmg(target, true))
    end
end

JaxMechanics = BaseStrucutre:new()

JaxMechanics:Menu()

-- Loading Components --

-- Events --
local OnNormalPriority = function()
    JaxMechanics:OnLoop()
end

local OnGapClose = function(source, dash)
    JaxMechanics:OnGapClose(source, dash)
end

local OnLowPriority = function()
    JaxMechanics:OnLowPriority()
end

local OnPostAttack = function()
    JaxMechanics:OnPostAttack()
end

local OnDraw = function()
    JaxMechanics:OnDraw()
end

local OnVisionLost = function(obj)
    JaxMechanics:OnVisionLost(obj)
end

local OnDrawDamage = function(target, dmgList)
    JaxMechanics:OnDrawDamage(target, dmgList)
end

local OnCreateObject = function(obj)
    JaxMechanics:OnCreateObject(obj)
end

function OnLoad()
    Event.RegisterCallback(Enums.Events.OnLowPriority, OnLowPriority)
    Event.RegisterCallback(Enums.Events.OnNormalPriority, OnNormalPriority)
    Event.RegisterCallback(Enums.Events.OnGapclose, OnGapClose)
    Event.RegisterCallback(Enums.Events.OnPostAttack, OnPostAttack)
    Event.RegisterCallback(Enums.Events.OnVisionLost, OnVisionLost)
    Event.RegisterCallback(Enums.Events.OnDraw, OnDraw)
    Event.RegisterCallback(Enums.Events.OnDrawDamage, OnDrawDamage)
    Event.RegisterCallback(Enums.Events.OnCreateObject, OnCreateObject)
    CheckIgniteSlot()
    CheckFlashSlot()
    CheckSmiteSlot()

    return true
end
