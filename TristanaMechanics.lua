if _G.CoreEx.ObjectManager.Player.CharName ~= "Tristana" then
    return
end
local ScriptName, Version = "TristanaMechanics", "1.0.6"
_G.CoreEx.AutoUpdate("https://raw.githubusercontent.com/hagbardlol/nosupport/main/" .. ScriptName ..".lua", Version)

local SDK = _G.CoreEx
local Lib = _G.Libs
local Obj = SDK.ObjectManager
local Player = Obj.Player
local Event = SDK.EventManager
local Enums = SDK.Enums
local Renderer = SDK.Renderer
local Input = SDK.Input
local HealthPred = Lib.HealthPred

local TS = Lib.TargetSelector()
local HitChanceEnum = SDK.Enums.HitChance
local Menu = Lib.NewMenu
local Orb = Lib.Orbwalker
local Pred = Lib.Prediction
local DmgLib = Lib.DamageLib
local Spell = Lib.Spell
local Geometry = SDK.Geometry
local Path = Geometry.Path
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
    Q = Spell.Active({
        Slot = Enums.SpellSlots.Q,
        Key = "Q"
    }),
    W = Spell.Skillshot({
        Slot = Enums.SpellSlots.W,
        Range = 900,
        Delay = 0.25,
        Speed = 1100,
        Radius = 350,
        Type = "Circular",
        Key = "W"
    }),
    E = Spell.Targeted({
        Slot = Enums.SpellSlots.E,
        Range = 517 + 8 * Player.Level,
        Delay = 0.226,
        Radius = 300,
        Key = "E"
    }),
    R = Spell.Targeted({
        Slot = Enums.SpellSlots.R,
        Range = 517 + 8 * Player.Level,
        Delay = 0.25,
        Speed = 2000,
        Radius = 200,
        Key = "R"
    })
}

function IsValidTW(value)
    local isValid = true
    local tw = value.AsTurret
    if not value.IsOnScreen or value.IsDead or string.find(value.Name, "Shrine_A") or value.IsInhibitor or value.IsNexus then
        isValid = false
    end

    return isValid
end

function IsUnderTurret(position)
    for k, turret in pairs(Obj.GetNearby("enemy", "turrets")) do
        if IsValidTW(turret) and turret.Position:Distance(position) < 875 then
            return true
        end
    end
    return position:Distance(basePosition) < 700
end

function HasItem(itemId)
    for itemSlot, item in pairs(Player.Items) do
        if item and item.ItemId == itemId then
            return itemSlot, item
        end
    end

    return nil, nil
end

function IsInAARange(Target)
    return Player:Distance(Target) <= Orb.GetTrueAutoAttackRange(Player, Target)
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

function GetWardItem()
    local hasWard = GetItemSlot(UsableItems.Wards.WardsItemIds)
    return hasWard
end

function GetActiveItem()
    local hasProwler, hasGaleForce, hasGoredrinker, hasStridebreaker = GetItemSlot(UsableItems.Prowler.ProwlerItemIds),
        GetItemSlot(UsableItems.GaleForce.GaleForceItemIds), GetItemSlot(UsableItems.Goredrinker.GoredrinkerItemIds),
        GetItemSlot(UsableItems.Stridebreaker.StridebreakerItemIds)
    return hasProwler or hasGaleForce or hasGoredrinker or hasStridebreaker
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

BaseStrucutre = {}

function BaseStrucutre:new(dat)
    dat = dat or {}
    setmetatable(dat, self)
    self.__index = self
    return dat
end

function BaseStrucutre:GetQDmg()
    return 0
end

function BaseStrucutre:GetWDmg()
    return 45 + spells.W:GetLevel() * 50 + (0.5 * Player.TotalAP)
end

function BaseStrucutre:GetEDmg()
    return 132 + spells.E:GetLevel() * 22 + (((55 + spells.E:GetLevel() * 55) / 100) * Player.TotalAD) +
               (0.5 * Player.TotalAP)
end

function BaseStrucutre:GetRDmg()
    return (200 + spells.R:GetLevel() * 100 + (1 * Player.TotalAP)) * 0.7
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

function BaseStrucutre:TotalDmg(Target, countSS)
    local Damage = DmgLib.CalculatePhysicalDamage(Player, Target, Player.TotalAD)
    if spells.Q:IsReady() then
        Damage = Damage + DmgLib.CalculatePhysicalDamage(Player, Target, self:GetQDmg())
    end
    if spells.W:IsReady() then
        Damage = Damage + DmgLib.CalculateMagicalDamage(Player, Target, self:GetWDmg())
    end
    if UsableSS.Ignite.Slot ~= nil and Player:GetSpellState(UsableSS.Ignite.Slot) == Enums.SpellStates.Ready and countSS and
        Player:Distance(Target) < UsableSS.Ignite.Range then
        Damage = Damage + DmgLib.CalculatePhysicalDamage(Player, Target, self:GetIgniteDmg(Target))
    end
    if spells.E:IsReady() then
        Damage = Damage + DmgLib.CalculatePhysicalDamage(Player, Target, self:GetEDmg())
    end
    if spells.R:IsReady() then
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

function BaseStrucutre:IsSafePos(pos)
    local enemiesInRange = self:CountHeroes(pos, 600, "enemy")
    local alliesInRange = self:CountHeroes(pos, 600, "ally")

    if enemiesInRange > alliesInRange + 1 or IsUnderTurret(pos) then
        return false
    end
    return true
end

function BaseStrucutre:GetHeroes(pos, range, team)
    local arr = {}
    for k, v in pairs(Obj.Get(team, "heroes")) do
        local hero = v.AsHero
        if hero.IsValid and not hero.IsDead and hero.IsTargetable and hero:Distance(pos) < range then
            table.insert(arr, hero)
        end
    end
    return arr
end

function BaseStrucutre:GetChargedEnemy()
    for k, v in pairs(Obj.GetNearby("enemy", "heroes")) do
        local hero = v.AsHero
        if IsInAARange(hero) and hero.IsValid and not hero.IsDead and hero.IsTargetable and
            hero:GetBuff("tristanaecharge") then
            return hero
        end
    end
    return nil
end

function BaseStrucutre:GetExplosiveChargeCount(target)
    local buff = target:GetBuff("tristanaecharge")
    if buff ~= nil and buff.Count > 0 then
        return buff.Count
    end
    return 0
end

function BaseStrucutre:GetChargedMinion()
    for k, v in pairs(Obj.GetNearby("all", "minions")) do
        local minion = v.AsMinion
        if IsInAARange(minion) and minion.IsValid and not minion.IsDead and minion.IsTargetable and not minion.IsAlly and
            minion:GetBuff("tristanaecharge") then
            return minion
        end
    end
    return nil
end

function BaseStrucutre:Menu()
    Menu.RegisterMenu(ScriptName, ScriptName .. " V" .. Version, function()
        Menu.NewTree("Combo", "Combo Options", function()
            Menu.Checkbox("Combo.CastQ", "Use Q", true)
            Menu.Checkbox("Combo.CastW", "Use W On Reset (Safe)", true)
            Menu.Checkbox("Combo.CastE", "Use E", true)
            Menu.Checkbox("Combo.ForceFocus", "Force Focus E Target", true)
            Menu.NewTree("Combo.CastE.Champions", "Champions", function()
                for k, enemy in pairs(Obj.Get("enemy", "heroes")) do
                    local hero = enemy.AsHero
                    Menu.Checkbox("Combo.CastE." .. hero.CharName, "Use E on " .. hero.CharName, true)
                end
            end)
            Menu.Checkbox("Combo.CastR", "Use R", true)
            Menu.Checkbox("Combo.UseItem", "Use Offensive Items (If Available)", true)
            Menu.Checkbox("Combo.CastIgnite", "Use Ignite", true)
        end)
        Menu.NewTree("Harass", "Harass Options", function()
            Menu.ColoredText("Mana Percent limit", 0xFFD700FF, false)
            Menu.Slider("Harass.ManaSlider", "", 70, 0, 100)
            Menu.Checkbox("Harass.CastQ", "Use Q", true)
            Menu.Checkbox("Harass.CastW", "Use W", false)
            Menu.Checkbox("Harass.CastE", "Use E", true)
            Menu.Checkbox("Harass.ForceFocus", "Force Focus E Target", true)
            Menu.NewTree("Harass.CastE.Champions", "Champions", function()
                for k, enemy in pairs(Obj.Get("enemy", "heroes")) do
                    local hero = enemy.AsHero
                    Menu.Checkbox("Harass.CastE." .. hero.CharName, "Use E on " .. hero.CharName, true)
                end
            end)
        end)
        Menu.NewTree("Waveclear", "Waveclear Options", function()
            Menu.Slider("Waveclear.ManaSlider", "Lane Mana Slider", 70, 0, 100)
            Menu.NewTree("Lane", "Lane Options", function()
                Menu.Slider("Lane.MinLevel", "Only wave clear after X lvl", 3, 1, 18, 1)
                Menu.Checkbox("Lane.Q", "Use Q", true)
                Menu.Checkbox("Lane.W", "Use W", false)
                Menu.Slider("Lane.WMinHit", "Use W", 3, 1, 6, 1)
                Menu.Checkbox("Lane.E", "Use E", true)
                Menu.Checkbox("Lane.ECannon", "Use E Only on Cannon", true)
                Menu.Checkbox("Lane.ETurret", "Use E on Turret", true)
            end)
            Menu.NewTree("Jungle", "Jungle Options", function()
                Menu.Checkbox("Jungle.Q", "Use Q", true)
                Menu.Checkbox("Jungle.W", "Use W", false)
                Menu.Slider("Jungle.WMinHit", "Use W", 1, 1, 6, 1)
                Menu.Checkbox("Jungle.E", "Use E", true)
                Menu.Checkbox("Jungle.EBigMonster", "Use E only on big monster", true)
            end)
        end)
        Menu.NewTree("Misc", "Misc Options", function()
            Menu.Checkbox("Misc.AutoWardOnLostVision", "Ward on lost vision", true)
            Menu.Checkbox("Misc.InterruptSpellsWithR", "Interrupt spells with R", true)
            Menu.ColoredText("Auto KS R", 0xFFD700FF, false)
            Menu.NewTree("KSR", "Champions", function()
                for k, enemy in pairs(Obj.Get("enemy", "heroes")) do
                    local hero = enemy.AsHero
                    Menu.Checkbox("Misc.KSR." .. hero.CharName, "Use R if " .. hero.CharName .. " is killable", true)
                end
            end)
            Menu.Checkbox("Misc.AntiGapCloserR", "Use R on GapCloser", true)
            Menu.ColoredText("Ult Dangerous enemies in melee range", 0xFFD700FF, false)
            Menu.NewTree("DangerousChampionsInCloseRange", "Champions", function()
                for k, enemy in pairs(Obj.Get("enemy", "heroes")) do
                    local hero = enemy.AsHero
                    Menu.Checkbox("Misc.AutoUltDangerous." .. hero.CharName,
                        "Use R if " .. hero.CharName .. " is too close", false)
                end
            end)
        end)
        Menu.NewTree("Draw", "Drawing Options", function()
            Menu.Checkbox("Drawing.Damage", "Draw Possible DMG", false)
            Menu.Checkbox("Drawing.W.Enabled", "Draw W Range", false)
            Menu.Checkbox("Drawing.R.Enabled", "Draw R Range", false)
        end)
    end)
end

function BaseStrucutre:OnDraw()
    if Menu.Get("Drawing.W.Enabled") then
        Renderer.DrawCircle3D(Player.Position, spells.W.Range, 30, 4, 0x118AB2FF)
    end
    if Menu.Get("Drawing.R.Enabled") then
        Renderer.DrawCircle3D(Player.Position, spells.R.Range, 30, 4, 0x118AB2FF)
    end
end

function BaseStrucutre:AutoCast()
end

function BaseStrucutre:Combo(postAttack)
    if Orb.IsWindingUp() then
        return
    end

    local CastQ, CastW, CastE, CastR, CastIgnite = Menu.Get("Combo.CastQ"), Menu.Get("Combo.CastW"), Menu.Get("Combo.CastE"), Menu.Get("Combo.CastR"),
        Menu.Get("Combo.CastIgnite")

    local Target = TS:GetTarget(1000, true)
    local hasActiveItem = GetActiveItem()
    local chargedEnemy = self:GetChargedEnemy()

    if not Target or Player.IsDead then
        return
    end

    if CastIgnite and UsableSS.Ignite.Slot ~= nil and Player:GetSpellState(UsableSS.Ignite.Slot) ==
        Enums.SpellStates.Ready and self:GetIgniteDmg(Target) > Target.Health and Player:Distance(Target) <
        UsableSS.Ignite.Range then
        Input.Cast(UsableSS.Ignite.Slot, Target)
    end

    if hasActiveItem then
        if not IsInAARange(Target) and Player:IsFacing(Target, 30) and not Target:IsFacing(Player, 30) and
            Player:GetSpellState(hasActiveItem) == Enums.SpellStates.Ready then
            Input.Cast(hasActiveItem, Target:FastPrediction(0.15))
            return
        end
    end

    if CastE and (IsInAARange(Target) or postAttack) and spells.E:IsReady() then
        spells.E:Cast(Target)
    end

    if CastW and spells.W:IsReady() then
        local possibleWDmg = DmgLib.CalculateMagicalDamage(Player, Target, self:GetWDmg())
        if chargedEnemy ~= nil and (self:GetExplosiveChargeCount(chargedEnemy) >= 2 or
            (possibleWDmg >
                HealthPred.GetHealthPrediction(Target, 0.015, true)) and not IsInAARange(Target)) then
            local wPred = Pred.GetPredictedPosition(chargedEnemy, spells.W, Player.Position)
            if wPred and self:IsSafePos(wPred.CastPosition) and wPred.HitChanceEnum >= HitChanceEnum.Medium then
                spells.W:Cast(wPred.CastPosition)
                return
            end
        end
    end

    if CastQ and spells.Q:IsReady() then
        spells.Q:Cast()
        return
    end

    if CastR and spells.R:IsReady() then
        if chargedEnemy ~= nil and IsInAARange(chargedEnemy) and self:GetExplosiveChargeCount(Target) >= 3 then
            local predictHealth = HealthPred.GetHealthPrediction(chargedEnemy, 1, true)
            local possibleRDmg = DmgLib.CalculateMagicalDamage(Player, chargedEnemy, self:GetRDmg())
            local possibleEDmg = DmgLib.CalculatePhysicalDamage(Player, chargedEnemy, self:GetEDmg())
            if possibleEDmg > predictHealth then
                return
            elseif possibleEDmg + possibleRDmg > predictHealth then
                spells.R:Cast(chargedEnemy)
            end
        elseif IsInAARange(Target) then
            local possibleRDmg = DmgLib.CalculateMagicalDamage(Target, chargedEnemy, self:GetRDmg())
            if possibleRDmg > HealthPred.GetHealthPrediction(Target, 0.015, true) then
                spells.R:Cast(Target)
            end
        end
    end
end

function BaseStrucutre:Harass(postAttack)
    if Orb.IsWindingUp() then
        return
    end

    local CastQ, CastW = Menu.Get("Harass.CastQ"), Menu.Get("Harass.CastW")
    local Target = TS:GetTarget(spells.Q.Range, true)
    if not Target or Player.IsDead then
        return
    end
    local chargedEnemy = self:GetChargedEnemy()

    if CastQ and spells.Q:IsReady() and (IsInAARange(Target) or Orb.GetTarget() ~= nil) and not spells.E:IsReady() then
        spells.Q:Cast()
        return
    end

    if CastW and spells.W:IsReady() then
        if chargedEnemy ~= nil and self:GetExplosiveChargeCount(chargedEnemy) >= 3 then
            local wPred = Pred.GetPredictedPosition(chargedEnemy, spells.W, Player.Position)
            if wPred and self:IsSafePos(wPred.CastPosition) and wPred.HitChanceEnum >= HitChanceEnum.Medium then
                spells.W:Cast(wPred.CastPosition)
                return
            end
        end
    end
end

function BaseStrucutre:Lasthit(postAttack)
end

function BaseStrucutre:Waveclear(postAttack)
    local ManaSlider, MinLevel, CastQLane, CastWLane, WMinHitLane, CastQJungle, CastWJungle, WMinHitJungle =
        Menu.Get("Waveclear.ManaSlider"), Menu.Get("Lane.MinLevel"), Menu.Get("Lane.Q"), Menu.Get("Lane.W"),
        Menu.Get("Lane.WMinHit"), Menu.Get("Jungle.Q"), Menu.Get("Jungle.W"), Menu.Get("Jungle.WMinHit")
    local minions = self:CountMinionsInRange(Player.AttackRange, "enemy")
    local monsters = self:CountMinionsInRange(Player.AttackRange, "neutral")
    if (minions == 0 and monsters == 0) or Player.ManaPercent <= ManaSlider / 100 then
        return
    end

    if minions > monsters then
        if Player.Level >= MinLevel then
            local minionFocus = self:GetPriorityMinion(Player.Position, "enemy", Player.AttackRange)

            if minionFocus == nil then
                return
            end
            if CastWLane and spells.W:IsReady() and spells.W:CastIfWillHit(WMinHitLane, "minions") then
                return
            end
            if CastQLane and spells.Q:IsReady() and not spells.E:IsReady() then
                spells.Q:Cast()
                return
            end
        end
    else
        local minionFocus = self:GetPriorityMinion(Player.Position, "neutral", Player.AttackRange)

        if minionFocus == nil then
            return
        end
        if CastWJungle and spells.W:IsReady() and spells.W:CastIfWillHit(WMinHitJungle, "minions") then
            spells.W:Cast(minionFocus.Position)
            return
        end
        if CastQJungle and spells.Q:IsReady() and not spells.E:IsReady() then
            spells.Q:Cast()
            return
        end
    end
end

function BaseStrucutre:OnLowPriority()
    CheckIgniteSlot()
    if spells.R:IsReady() then
        for k, enemy in pairs(Obj.GetNearby("enemy", "heroes")) do
            local Target = enemy.AsHero
            if Target.CharName ~= "PracticeTool_TargetDummy" then
                if Menu.Get("Misc.KSR." .. Target.CharName) and IsInAARange(Target) then
                    local possibleRDmg = DmgLib.CalculateMagicalDamage(Player, Target, self:GetRDmg())
                    local possibleAADmg = DmgLib.GetAutoAttackDamage(Player, Target, true)
                    local predictHealth = HealthPred.GetHealthPrediction(Target, 0.015, true)
                    if predictHealth > possibleAADmg and possibleRDmg > predictHealth then
                        spells.R:Cast(Target)
                    end
                elseif Menu.Get("Misc.AutoUltDangerous." .. Target.CharName) and Player:Distance(Target) <= 150 then
                    spells.R:Cast(Target)
                end
            end
        end
    end

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

function BaseStrucutre:OnGapClose(source, dash)
    if not source.IsEnemy or source.Invulnerable and not source:IsFacing(Player.Position, 30) then
        return
    end

    local GapR = Menu.Get("Misc.AntiGapCloserR")
    if spells.R:IsReady() and spells.R:IsInRange(source) and GapR then
        spells.R:Cast(source)
    end

end

function BaseStrucutre:OnInterruptibleSpell(Source, SpellCast, Danger, EndTime, CanMoveDuringChannel)
    if not Source.IsEnemy or Source.Invulnerable then
        return
    end
    local InterruptSpellsWithR = Menu.Get("Misc.InterruptSpellsWithR")
    if InterruptSpellsWithR and spells.R:IsReady() and spells.R:IsInRange(Source) then
        spells.R:Cast(Source)
    end
end

function BaseStrucutre:OnDrawDamage(target, dmgList)
    if Menu.Get("Drawing.Damage") then
        table.insert(dmgList, self:TotalDmg(target, true))
    end
end

function BaseStrucutre:OnPreAttack(args)
    local orbMode = Orb.GetMode()
    if orbMode == "Combo" then
        local enemyWithCharge = self:GetChargedEnemy()

        if Menu.Get("Combo.ForceFocus") and enemyWithCharge ~= nil then
            args.Target = enemyWithCharge
            return
        end
        local CastE = Menu.Get("Combo.CastE")
        local Target = TS:GetTarget(Player.AttackRange, true)

        if not Target or Player.IsDead then
            return
        end

        if CastE and spells.E:IsReady() and IsInAARange(Target) and Menu.Get("Combo.CastE." .. Target.CharName) then
            spells.E:Cast(Target)
            return
        end
    elseif orbMode == "Harass" then
        local enemyWithCharge = self:GetChargedEnemy()

        if Menu.Get("Harass.ForceFocus") and enemyWithCharge ~= nil then
            if enemyWithCharge.Ptr ~= args.Target.Ptr then
                args.Target = enemyWithCharge
                return
            end
        end

        local CastE = Menu.Get("Harass.CastE")
        local Target = TS:GetTarget(Player.AttackRange, true)

        if not Target or Player.IsDead then
            return
        end

        if CastE and spells.E:IsReady() and IsInAARange(Target) and Menu.Get("Harass.CastE." .. Target.CharName) then
            spells.E:Cast(Target)
            return
        end
    elseif orbMode == "Waveclear" then
        local MinLevel = Menu.Get("Lane.MinLevel")
        if not spells.E:IsReady() or not IsInAARange(args.Target) then
            return
        end

        local enemyWithCharge = self:GetChargedMinion()

        if enemyWithCharge ~= nil then
            args.Target = enemyWithCharge
        end

        if args.Target.IsNeutral and Menu.Get("Jungle.E") then
            local minion = args.Target.AsMinion
            if minion and (minion.IsEpicMinion or minion.IsEliteMinion) and Menu.Get("Jungle.EBigMonster") then
                spells.E:Cast(args.Target)
                return
            elseif not Menu.Get("Jungle.EBigMonster") and minion then
                spells.E:Cast(args.Target)
                return
            end
        elseif args.Target.IsTurret and args.Target.IsEnemy and Menu.Get("Lane.ETurret") then
            spells.E:Cast(args.Target)
            return
        elseif args.Target.IsEnemy and Menu.Get("Lane.E") then
            if Player.Level >= MinLevel then
                local minion = args.Target.AsMinion
                if minion and (minion.IsSiegeMinion or minion.IsSuperMinion) and Menu.Get("Lane.ECannon") then
                    spells.E:Cast(args.Target)
                    return
                elseif minion then
                    spells.E:Cast(args.Target)
                    return
                end
            end
        end
    end
end

TristanaMechanics = BaseStrucutre:new()

TristanaMechanics:Menu()

-- Loading Components --

-- Events --
local OnNormalPriority = function()
    TristanaMechanics:OnLoop()
end

local OnGapClose = function(source, dash)
    TristanaMechanics:OnGapClose(source, dash)
end

local OnInterruptibleSpell = function(Source, SpellCast, Danger, EndTime, CanMoveDuringChannel)
    TristanaMechanics:OnInterruptibleSpell(Source, SpellCast, Danger, EndTime, CanMoveDuringChannel)
end

local OnLowPriority = function()
    TristanaMechanics:OnLowPriority()
end

local OnPostAttack = function()
    TristanaMechanics:OnPostAttack()
end

local OnDraw = function()
    TristanaMechanics:OnDraw()
end

local OnVisionLost = function(obj)
    TristanaMechanics:OnVisionLost(obj)
end

local OnCreateObject = function(obj)
    TristanaMechanics:OnCreateObject(obj)
end

local OnPreAttack = function(args)
    TristanaMechanics:OnPreAttack(args)
end

local OnDrawDamage = function(target, dmgList)
    TristanaMechanics:OnDrawDamage(target, dmgList)
end

function OnLoad()
    Event.RegisterCallback(Enums.Events.OnLowPriority, OnLowPriority)
    Event.RegisterCallback(Enums.Events.OnTick, OnNormalPriority)
    Event.RegisterCallback(Enums.Events.OnGapclose, OnGapClose)
    Event.RegisterCallback(Enums.Events.OnInterruptibleSpell, OnInterruptibleSpell)
    Event.RegisterCallback(Enums.Events.OnPostAttack, OnPostAttack)
    Event.RegisterCallback(Enums.Events.OnVisionLost, OnVisionLost)
    Event.RegisterCallback(Enums.Events.OnPreAttack, OnPreAttack)
    Event.RegisterCallback(Enums.Events.OnDraw, OnDraw)
    Event.RegisterCallback(Enums.Events.OnDrawDamage, OnDrawDamage)
    CheckIgniteSlot()

    return true
end
