--[[

  /$$$$$$            /$$                           /$$      /$$                     /$$                           /$$                    
 /$$__  $$          | $$                          | $$$    /$$$                    | $$                          |__/                    
| $$  \__/ /$$   /$$| $$  /$$$$$$   /$$$$$$$      | $$$$  /$$$$  /$$$$$$   /$$$$$$$| $$$$$$$   /$$$$$$  /$$$$$$$  /$$  /$$$$$$$  /$$$$$$$
|  $$$$$$ | $$  | $$| $$ |____  $$ /$$_____/      | $$ $$/$$ $$ /$$__  $$ /$$_____/| $$__  $$ |____  $$| $$__  $$| $$ /$$_____/ /$$_____/
 \____  $$| $$  | $$| $$  /$$$$$$$|  $$$$$$       | $$  $$$| $$| $$$$$$$$| $$      | $$  \ $$  /$$$$$$$| $$  \ $$| $$| $$      |  $$$$$$ 
 /$$  \ $$| $$  | $$| $$ /$$__  $$ \____  $$      | $$\  $ | $$| $$_____/| $$      | $$  | $$ /$$__  $$| $$  | $$| $$| $$       \____  $$
|  $$$$$$/|  $$$$$$$| $$|  $$$$$$$ /$$$$$$$/      | $$ \/  | $$|  $$$$$$$|  $$$$$$$| $$  | $$|  $$$$$$$| $$  | $$| $$|  $$$$$$$ /$$$$$$$/
 \______/  \____  $$|__/ \_______/|_______/       |__/     |__/ \_______/ \_______/|__/  |__/ \_______/|__/  |__/|__/ \_______/|_______/ 
           /$$  | $$                                                                                                                     
          |  $$$$$$/                                                                                                                     
           \______/                                                                                                                      

]]
if _G.CoreEx.ObjectManager.Player.CharName ~= "Sylas" then
    return
end
local ScriptName, Version = "SylasMechanics", "1.0.3"
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

local UsableItems = {
    HextechRocketbelt = {
        HextechRocketbeltIds = {3152},
        Range = 275
    },
    Everfrost = {
        EverfrostIds = {6656},
        Range = 275
    },Wards = {
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
    }
}

local spells = {
    Q = Spell.Skillshot({
        Slot = Enums.SpellSlots.Q,
        Range = 775,
        Delay = 0.4,
        Speed = 1550,
        Radius = 180,
        Type = "Circular",
        Key = "Q"
    }),
    W = Spell.Targeted({
        Slot = Enums.SpellSlots.W,
        Range = 400,
        Key = "W"
    }),
    E = Spell.Skillshot({
        Slot = Enums.SpellSlots.E,
        Range = 400,
        Delay = 0,
        Key = "E"
    }),
    E2 = Spell.Skillshot({
        Slot = Enums.SpellSlots.E,
        Range = 800,
        Delay = 0.25,
        Speed = 1600,
        Collisions = {
            Heroes = true,
            Minions = true,
            WindWall = true,
            Wall = false
        },
        Key = "E"
    }),
    R = Spell.Targeted({
        Slot = Enums.SpellSlots.R,
        Range = 950,
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

function IsE2()
    return spells.E:GetName() == "SylasE2"
end

function IsR1()
    return spells.R:GetName() == "SylasR"
end

function IsInAARange(Target)
    return Player:Distance(Target) <= Player.AttackRange
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
    local hasEverfrost, hasProtobelt = GetItemSlot(UsableItems.Everfrost.EverfrostIds),
        GetItemSlot(UsableItems.HextechRocketbelt.HextechRocketbeltIds)
    return hasEverfrost or hasProtobelt
end

function GetWardItem()
    local hasWard = GetItemSlot(UsableItems.Wards.WardsItemIds)
    return hasWard
end

function HasPassive(target)
    local hasPassive = false
    for k, v in pairs(target.Buffs) do
        if v.Name == "SylasR" then
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

function BaseStrucutre:GetWDmg()
    return 70 + spells.W:GetLevel() * 65 + (0.9 * Player.TotalAP)
end

function BaseStrucutre:GetEDmg()
    return 80 + spells.E:GetLevel() * 50 + (1 * Player.TotalAP)
end

function BaseStrucutre:GetQDmg()
    return 100 + spells.Q:GetLevel() * 75 + (1.2 * Player.TotalAP)
end

function BaseStrucutre:GetIgniteDmg(target)
    return 50 + 20 * Player.Level - target.HealthRegen * 2.5
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
    local Damage = DmgLib.CalculateMagicalDamage(Player, Target, Player.TotalAD)
    if spells.Q:IsReady() then
        Damage = Damage + DmgLib.CalculateMagicalDamage(Player, Target, self:GetQDmg())
    end
    if spells.W:IsReady() then
        Damage = Damage + DmgLib.CalculateMagicalDamage(Player, Target, self:GetWDmg())
    end
    if UsableSS.Ignite.Slot ~= nil and Player:GetSpellState(UsableSS.Ignite.Slot) == Enums.SpellStates.Ready and countSS then
        Damage = Damage + DmgLib.CalculateMagicalDamage(Player, Target, self:GetIgniteDmg(Target))
    end
    if spells.E:IsReady() then
        Damage = Damage + DmgLib.CalculateMagicalDamage(Player, Target, self:GetEDmg())
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
    if Menu.Get("Drawing.W.Enabled") then
        Renderer.DrawCircle3D(Player.Position, spells.W.Range, 30, 4, 0x118AB2FF)
    end
    if Menu.Get("Drawing.E.Enabled") then
        Renderer.DrawCircle3D(Player.Position, spells.E2.Range, 30, 4, 0x118AB2FF)
    end
    if Menu.Get("Drawing.R.Enabled") then
        Renderer.DrawCircle3D(Player.Position, spells.R.Range, 30, 4, 0x118AB2FF)
    end
end

function BaseStrucutre:AutoCast()
    if spells.R:IsReady() and IsR1() then
        for _, value in pairs(Obj.Get("enemy", "heroes")) do
            local target = value.AsHero
            local StealUlt = Menu.Get("Misc.StealUlt." .. target.CharName)
            if StealUlt and target.IsValid and not target.IsDead and target.IsTargetable and spells.R:IsInRange(target) and
                not HasPassive(target) then
                spells.R:Cast(target)
                return
            end
        end
    end
end

function BaseStrucutre:Combo(postAttack)
    local CastQ, CastW, CastE1, CastE2, CastIgnite, CastSmite = Menu.Get("Combo.CastQ"), Menu.Get("Combo.CastW"),
        Menu.Get("Combo.CastE1"), Menu.Get("Combo.CastE2"), Menu.Get("Combo.CastIgnite"), Menu.Get("Combo.CastSmite")
    local Target = TS:GetTarget(spells.E2.Range + spells.E.Range, true)
    local hasActiveItem = GetActiveItem()
    if not Target then
        return
    end

    if CastIgnite and UsableSS.Ignite.Slot ~= nil and Player:GetSpellState(UsableSS.Ignite.Slot) ==
        Enums.SpellStates.Ready and self:GetIgniteDmg(Target) > Target.Health and Player:Distance(Target) <
        UsableSS.Ignite.Range then
        Input.Cast(UsableSS.Ignite.Slot, Target)
    end

    if CastSmite and UsableSS.Smite.Slot ~= nil and Player:GetSpellState(UsableSS.Smite.Slot) == Enums.SpellStates.Ready and
        (self:GetSmiteDmg() > Target.Health or Player:Distance(Target) > Player.AttackRange + 100) and
        Player:Distance(Target) < UsableSS.Smite.Range then
        Input.Cast(UsableSS.Smite.Slot, Target)
        return
    end

    if hasActiveItem then
        if not IsE2() and spells.E:IsReady() and CastE1 and not IsInAARange(Target) then
            spells.E:Cast(Target.Position)
            return
        end
        if spells.W:IsReady() and spells.W:IsInRange(Target) and CastW and (not IsInAARange(Target) or postAttack) then
            spells.W:Cast(Target)
            return
        end
        if IsE2() and spells.E2:IsReady() and spells.E2:IsInRange(Target) and CastE2 and
            spells.E2:CastOnHitChance(Target, HitChanceEnum.VeryLow) then
            return
        end
        if (IsE2() or not spells.E2:IsReady()) and CastQ and spells.Q:IsReady() and
            spells.Q:CastOnHitChance(Target, HitChanceEnum.Medium) then
            return
        end
        if ((IsE2() or not spells.E2:IsReady()) or Target.IsImmovable) and Player:GetSpellState(hasActiveItem) ==
            Enums.SpellStates.Ready then
            Input.Cast(hasActiveItem, Target.Position)
            return
        end
    else
        if not IsE2() and spells.E:IsReady() and CastE1 and not IsInAARange(Target) then
            spells.E:Cast(Target.Position)
            return
        end
        if spells.W:IsReady() and spells.W:IsInRange(Target) and CastW and (not IsInAARange(Target) or postAttack) then
            spells.W:Cast(Target)
            return
        end
        if IsE2() and spells.E2:IsReady() and spells.E2:IsInRange(Target) and CastE2 and
            spells.E2:CastOnHitChance(Target, HitChanceEnum.VeryLow) then
            return
        end
        if (IsE2() or not spells.E2:IsReady()) and CastQ and spells.Q:IsReady() and
            spells.Q:CastOnHitChance(Target, HitChanceEnum.Medium) then
            return
        end
    end
end

function BaseStrucutre:Harass(postAttack)
    local CastQ, CastW, CastE1, CastE2 = Menu.Get("Harass.CastQ"), Menu.Get("Harass.CastW"), Menu.Get("Harass.CastE1"),
        Menu.Get("Harass.CastE2")
    local Target = TS:GetTarget(IsE2() and spells.E.Range or spells.Q.Range, true)
    if not Target then
        return
    end
    if not IsE2() and spells.E:IsReady() and spells.E:IsInRange(Target) and CastE1 and not IsInAARange(Target) then
        spells.E:Cast(Target.Position)
        return
    end
    if spells.W:IsReady() and spells.W:IsInRange(Target) and CastW and (not IsInAARange(Target) or postAttack) then
        spells.W:Cast(Target)
    end
    if IsE2() and spells.E2:IsReady() and spells.E2:IsInRange(Target) and CastE2 and
        spells.E2:CastOnHitChance(Target, HitChanceEnum.Medium) then
        if CastQ and spells.Q:IsReady() then
            spells.Q:Cast(Target.Position)
        end
        return
    end
    if CastQ and spells.Q:IsReady() and spells.Q:CastOnHitChance(Target, HitChanceEnum.Medium) and
        not spells.E:IsReady() then
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
    if CastW and spells.W:IsReady() then
        local lastHitMinion = self:GetLastHitMinion(Player.Position, spells.W.Range, self:GetWDmg(), false, true)
        if lastHitMinion == nil then
            return
        else
            spells.W:Cast(lastHitMinion)
        end
    end
    if CastQ and spells.Q:IsReady() then
        local lastHitMinion = self:GetLastHitMinion(Player.Position, spells.Q.Range, self:GetQDmg(), false, true)
        if lastHitMinion == nil then
            return
        else
            spells.Q:Cast(lastHitMinion.Position)
        end
    end
end

function BaseStrucutre:Waveclear(postAttack)
    local ManaSlider, CastQLane, CastWLane, CastQJungle, CastWJungle, CastE1Jungle, CastE2Jungle =
        Menu.Get("Lane.ManaSlider"), Menu.Get("Lane.Q"), Menu.Get("Lane.W"), Menu.Get("Jungle.Q"), Menu.Get("Jungle.W"),
        Menu.Get("Jungle.E1"), Menu.Get("Jungle.E2")
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
        if CastWLane and spells.W:IsReady() then
            spells.W:Cast(minionFocus)
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
        if minionFocus.IsEpicMinion then
            if (minionFocus.Health < 1300 and UsableSS.Smite.Slot ~= nil) and self:TotalDmg(minionFocus, false) <
                minionFocus.Health then
                return
            end
            if CastQJungle and spells.Q:IsReady() and spells.Q:IsInRange(minionFocus) then
                spells.Q:Cast(minionFocus.Position)
                return
            end
            if CastWJungle and spells.W:IsReady() and Player.HealthPercent < 1 and spells.W:IsInRange(minionFocus) then
                spells.W:Cast(minionFocus)
                return
            end
            if not IsE2() and CastE1Jungle and spells.E:IsReady() and spells.E:IsInRange(minionFocus) then
                spells.E:Cast(minionFocus.Position)
                return
            end
            if IsE2() and CastE2Jungle and spells.E2:IsReady() and spells.E2:IsInRange(minionFocus) then
                spells.E2:Cast(minionFocus.Position)
                return
            end
        else
            if CastQJungle and spells.Q:IsReady() and spells.Q:IsInRange(minionFocus) then
                spells.Q:Cast(minionFocus.Position)
                return
            end
            if CastWJungle and spells.W:IsReady() and Player.HealthPercent < 1 and spells.W:IsInRange(minionFocus) then
                spells.W:Cast(minionFocus)
                return
            end
            if not IsE2() and CastE1Jungle and spells.E:IsReady() and spells.E:IsInRange(minionFocus) then
                spells.E:Cast(minionFocus.Position)
                return
            end
            if IsE2() and CastE2Jungle and spells.E:IsReady() and spells.E2:IsInRange(minionFocus) then
                spells.E2:Cast(minionFocus.Position)
                return
            end
        end
    end

end

function BaseStrucutre:OnLowPriority()
    CheckSmiteSlot()
    CheckIgniteSlot()
    self:AutoCast()
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

function BaseStrucutre:OnGapClose(source, dash)
end

function BaseStrucutre:OnDrawDamage(target, dmgList)
    if Menu.Get("Drawing.Damage") then
        table.insert(dmgList, self:TotalDmg(target, true))
    end
end

function BaseStrucutre:Menu()
    Menu.RegisterMenu("SylasMechanics", "Sylas Mechanics", function()
        Menu.NewTree("Combo", "Combo Options", function()
            Menu.Checkbox("Combo.CastQ", "Use Q", true)
            Menu.Checkbox("Combo.CastW", "Use W", true)
            Menu.Checkbox("Combo.CastE1", "Use E1", true)
            Menu.Checkbox("Combo.CastE2", "Use E2", true)
            Menu.Checkbox("Combo.CastIgnite", "Use Ignite", true)
            Menu.Checkbox("Combo.CastSmite", "Use Smite", true)
        end)
        Menu.NewTree("Harass", "Harass Options", function()
            Menu.ColoredText("Mana Percent limit", 0xFFD700FF, true)
            Menu.Slider("Harass.ManaSlider", "", 70, 0, 100)
            Menu.Checkbox("Harass.CastQ", "Use Q", true)
            Menu.Checkbox("Harass.CastW", "Use W", true)
            Menu.Checkbox("Harass.CastE1", "Use E1", true)
            Menu.Checkbox("Harass.CastE2", "Use E2", true)
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
                Menu.Checkbox("Lane.W", "Use W", false)
            end)
            Menu.NewTree("Jungle", "Jungle Options", function()
                Menu.Checkbox("Jungle.Q", "Use Q", true)
                Menu.Checkbox("Jungle.W", "Use W", true)
                Menu.Checkbox("Jungle.E1", "Use E1", true)
                Menu.Checkbox("Jungle.E2", "Use E2", true)
            end)
        end)
        Menu.NewTree("Misc", "Misc Options", function()
            Menu.Checkbox("Misc.AutoWardOnLostVision", "Ward on lost vision", true)
            for _, value in pairs(Obj.Get("enemy", "heroes")) do
                local hero = value.AsHero
                Menu.Checkbox("Misc.StealUlt." .. hero.CharName, "Take Ult from " .. hero.CharName, false)
            end
        end)
        Menu.NewTree("Draw", "Drawing Options", function()
            Menu.Checkbox("Drawing.Damage", "Draw Possible DMG", false)
            Menu.Checkbox("Drawing.Q.Enabled", "Draw Q Range", false)
            Menu.Checkbox("Drawing.W.Enabled", "Draw W Range", false)
            Menu.Checkbox("Drawing.E.Enabled", "Draw E Range", false)
            Menu.Checkbox("Drawing.R.Enabled", "Draw R Range", false)
        end)
    end)
end

SylasMechanics = BaseStrucutre:new()

SylasMechanics:Menu()

-- Loading Components --

-- Events --
local OnNormalPriority = function()
    SylasMechanics:OnLoop()
end

local OnGapClose = function(source, dash)
    SylasMechanics:OnGapClose(source, dash)
end

local OnLowPriority = function()
    SylasMechanics:OnLowPriority()
end

local OnPostAttack = function()
    SylasMechanics:OnPostAttack()
end

local OnDraw = function()
    SylasMechanics:OnDraw()
end

local OnVisionLost = function(obj)
    SylasMechanics:OnVisionLost(obj)
end

local OnDrawDamage = function(target, dmgList)
    SylasMechanics:OnDrawDamage(target, dmgList)
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
    CheckSmiteSlot()

    return true
end
