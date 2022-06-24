if _G.CoreEx.ObjectManager.Player.CharName ~= "Illaoi" then
    return
end
local ScriptName, Version = "IllaoiMechanics", "1.0.3"
_G.CoreEx.AutoUpdate("https://raw.githubusercontent.com/hagbardlol/nosupport/main/" .. ScriptName .. ".lua", Version)

local OsClock = os.clock

local SDK = _G.CoreEx
local Lib = _G.Libs
local Obj = SDK.ObjectManager
local Player = Obj.Player
local Event = SDK.EventManager
local Enums = SDK.Enums
local Renderer = SDK.Renderer
local Input = SDK.Input

local TS = Lib.TargetSelector()
local Menu = Lib.NewMenu
local Orb = Lib.Orbwalker
local DmgLib = Lib.DamageLib
local Spell = Lib.Spell
local Geometry = SDK.Geometry
local Vector = Geometry.Vector

local spells = {
    Q = Spell.Skillshot({
        Slot = Enums.SpellSlots.Q,
        Range = 800,
        Delay = 0.75,
        Radius = 200,
        Speed = 20000,
        Collisions = {
            Minions = false,
            WindWall = false,
            Heroes = false,
            Wall = false
        },
        Type = "Linear",
        Key = "Q"
    }),
    W = Spell.Active({
        Slot = Enums.SpellSlots.W,
        Range = 125 + 225,
        Key = "W"
    }),
    E = Spell.Skillshot({
        Slot = Enums.SpellSlots.E,
        Range = 950,
        Delay = 0.25,
        Speed = 1900,
        Radius = 90,
        Collisions = {
            Minions = true,
            WindWall = true,
            Heroes = true,
            Wall = false
        },
        Type = "Linear",
        Key = "E"
    }),
    R = Spell.Skillshot({
        Slot = Enums.SpellSlots.R,
        Range = 1,
        Speed = 20000,
        Radius = 500,
        Delay = 0.5,
        Collisions = {
            Minions = false,
            WindWall = false,
            Heroes = false,
            Wall = false
        },
        Type = "Circular",
        Key = "R"
    })
}

BaseStructure = {}

function BaseStructure:new(dat)
    dat = dat or {}
    setmetatable(dat, self)
    self.__index = self
    return dat
end

function BaseStructure:GetQDmg()
    return 10 + Player.Level + (12 * Player.TotalAD) + (0.4 * Player.TotalAP)
end

function BaseStructure:GetWDmg(target)
    return (2.5 + spells.W:GetLevel() * 0.5) * target.MaxHealth
end

function BaseStructure:GetEDmg()
    return 0
end

function BaseStructure:GetRDmg()
    return 100 + spells.R:GetLevel() * 150 + (0.5 * Player.TotalAD)
end

function BaseStructure:IsInAARange(Target)
    return Player:Distance(Target) <= Orb.GetTrueAutoAttackRange(Player, Target)
end

function BaseStructure:GetLastHitMinion(minions, pos, range, possibleDmg, time)
    local lastHitMinion = nil
    local lastHitHealth = 0
    for k, v in pairs(minions) do
        local minion = v.AsAttackableUnit
        local health = minion.Health
        if time then
            health = _G.Libs.HealthPred.GetHealthPrediction(minion, time)
        end
        if possibleDmg == 0 then
            possibleDmg = Orb.GetAutoAttackDamage(minion)
        end
        if minion.IsValid and not minion.IsDead and minion.IsTargetable and minion:Distance(pos) < range then
            if health < possibleDmg then
                if lastHitMinion == nil or health < lastHitHealth then
                    lastHitMinion = minion
                    lastHitHealth = health
                end
            end
        end
    end
    return lastHitMinion
end

function BaseStructure:GetNerbyMinions(pos, type, maxRange)
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

function BaseStructure:TotalDmg(Target)
    local Damage = DmgLib.CalculatePhysicalDamage(Player, Target, Player.TotalAD)
    if spells.Q:IsReady() and spells.Q:IsInRange(Target) then
        Damage = Damage + DmgLib.CalculatePhysicalDamage(Player, Target, self:GetQDmg())
    end
    if spells.W:IsReady() and spells.W:IsInRange(Target) then
        Damage = Damage + DmgLib.CalculatePhysicalDamage(Player, Target, self:GetWDmg(Target))
    end
    if spells.E:IsReady() and spells.E:IsInRange(Target) then
        Damage = Damage + DmgLib.CalculatePhysicalDamage(Player, Target, self:GetEDmg())
    end
    if spells.R:IsReady() and spells.R:IsInRange(Target) then
        Damage = Damage + DmgLib.CalculatePhysicalDamage(Player, Target, self:GetRDmg())
    end
    return Damage
end

function BaseStructure:CountHeroes(pos, range, team)
    local num = 0
    for k, v in pairs(Obj.Get(team, "heroes")) do
        local hero = v.AsHero
        if hero.IsValid and not hero.IsDead and hero.IsTargetable and hero:Distance(pos) < range then
            num = num + 1
        end
    end
    return num
end

function BaseStructure:GetHeroes(pos, range, team)
    local arr = {}
    for k, v in pairs(Obj.Get(team, "heroes")) do
        local hero = v.AsHero
        if hero.IsValid and not hero.IsDead and hero.IsTargetable and hero:Distance(pos) < range then
            table.insert(arr, hero)
        end
    end
    return arr
end

function BaseStructure:Menu()
    Menu.RegisterMenu(ScriptName, ScriptName .. " V" .. Version, function()
        Menu.NewTree("Combo", "Combo Options", function()
            Menu.Checkbox("Combo.CastQ", "Use Q", true)
            Menu.Checkbox("Combo.CastW", "Use W", true)
            Menu.Checkbox("Combo.CastE", "Use E", true)
            Menu.Checkbox("Combo.CastR", "Use R", true)
            Menu.Dropdown("Combo.R.Usage", "Use R When", 3, {"Hard Kill", "Easy Kill", "Burst", "Always"})
            Menu.Slider("Combo.R.MinHit", "Min Hit Heroes for Cast R", 2, 1, 5, 1)

        end)
        Menu.NewTree("Harass", "Harass Options", function()
            Menu.ColoredText("Mana Percent limit", 0xFFD700FF, true)
            Menu.Slider("Harass.ManaSlider", "", 40, 0, 100)
            Menu.Checkbox("Harass.CastQ", "Use Q", true)
            Menu.Slider("Harass.Q.MinHit", "Min Hit Heroes for Cast Q", 1, 1, 5, 1)
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
                Menu.Checkbox("Lane.CastQ", "Use Q", true)
                Menu.Slider("Lane.Q.MinHit", "Min Hit Minions for Cast Q", 3, 1, 6, 1)
                Menu.Checkbox("Lane.CastW", "Use W", true)
            end)
            Menu.NewTree("Jungle", "Jungle Options", function()
                Menu.Checkbox("Jungle.CastQ", "Use Q", true)
                Menu.Checkbox("Jungle.CastW", "Use W", true)
            end)
        end)
        Menu.NewTree("HitChance", "Hit chance Options", function()
            Menu.Dropdown("HitChance.Q.Combo", "Q Combo Hitchance", 4, {"Collision", "OutOfRange", "VeryLow", "Low",
                                                                        "Medium", "High", "VeryHigh", "Dashing",
                                                                        "Immobile"})
            Menu.Dropdown("HitChance.E.Combo", "E Combo Hitchance", 4, {"Collision", "OutOfRange", "VeryLow", "Low",
                                                                        "Medium", "High", "VeryHigh", "Dashing",
                                                                        "Immobile"})
            Menu.Dropdown("HitChance.Q.Harass", "Q Harass Hitchance", 5, {"Collision", "OutOfRange", "VeryLow", "Low",
                                                                          "Medium", "High", "VeryHigh", "Dashing",
                                                                          "Immobile"})
            Menu.Dropdown("HitChance.E.Harass", "E Harass Hitchance", 5, {"Collision", "OutOfRange", "VeryLow", "Low",
                                                                          "Medium", "High", "VeryHigh", "Dashing",
                                                                          "Immobile"})
        end)
        Menu.NewTree("KS", "Ks Options", function()
            Menu.Checkbox("KS.UseQ", "Use Q for KS", false)
            Menu.Checkbox("KS.UseW", "Use W for KS", false)
            Menu.Checkbox("KS.UseR", "Use R for KS", false)
        end)
        Menu.NewTree("Misc", "Misc Options", function()
            Menu.Checkbox("Misc.AntiGapCloserQ", "Use Q on GapCloser", true)
        end)
        Menu.NewTree("Draw", "Drawing Options", function()
            Menu.Checkbox("Drawing.KillCombo", "Draw Kill Combo", true)
            Menu.Checkbox("Drawing.Damage", "Draw Possible DMG", true)
            Menu.Checkbox("Drawing.Q.Enabled", "Draw Q Range", false)
            Menu.Checkbox("Drawing.W.Enabled", "Draw W Range", false)
            Menu.Checkbox("Drawing.E.Enabled", "Draw E Range", false)
            Menu.Checkbox("Drawing.R.Enabled", "Draw R Range", false)
        end)
    end)
end

function BaseStructure:OnDraw()
    if Menu.Get("Drawing.KillCombo") then
        local enemies = self:GetHeroes(Player.Position, 2000, "enemy")
        for k, enemy in pairs(enemies) do
            if enemy ~= nil and enemy.IsValid and enemy.IsVisible and enemy.IsTargetable and not enemy.IsDead and
                enemy.Position.IsOnScreen then
                local comboDamage, comboType = self:GetComboDamage(enemy)
                Renderer.DrawText(Renderer.WorldToScreen(Vector(enemy.Position.x + 100, enemy.Position.y + 105,
                    enemy.Position.z)), Vector(200, 100), comboType, 0xFFFFFFFF)
            end
        end
    end

    if Menu.Get("Drawing.Q.Enabled") then
        Renderer.DrawCircle3D(Player.Position, spells.Q.Range, 30, 4, 0x118AB2FF)
    end
    if Menu.Get("Drawing.W.Enabled") then
        Renderer.DrawCircle3D(Player.Position, spells.W.Range, 30, 4, 0x118AB2FF)
    end
    if Menu.Get("Drawing.E.Enabled") then
        Renderer.DrawCircle3D(Player.Position, spells.E.Range, 30, 4, 0x118AB2FF)
    end
    if Menu.Get("Drawing.R.Enabled") then
        Renderer.DrawCircle3D(Player.Position, 500, 30, 4, 0x118AB2FF)
    end

end

function BaseStructure:AutoCast()
    for k, Enemy in pairs(self:GetHeroes(Player.Position, spells.Q.Range, "enemy")) do
        if Enemy ~= nil and Enemy.IsValid and Enemy.IsVisible and Enemy.IsTargetable and not Enemy.IsDead then
            if Menu.Get("KS.UseQ") and spells.Q:IsReady() then
                local QDamage = DmgLib.CalculatePhysicalDamage(Player, Enemy, self:GetQDmg())
                if QDamage > Enemy.Health then
                    spells.Q:Cast(Enemy)
                    return
                end
            end
            if Menu.Get("KS.UseW") and spells.W:IsReady() and spells.W:IsInRange(Enemy) then
                local WDamage = DmgLib.CalculatePhysicalDamage(Player, Enemy, self:GetWDmg(Enemy))
                if WDamage > Enemy.Health then
                    spells.W:Cast()
                    Input.Attack(Enemy)
                    return
                end
            end
            if Menu.Get("KS.UseR") and spells.R:IsReady() and spells.R:IsInRange(Enemy) then
                local RDamage = DmgLib.CalculatePhysicalDamage(Player, Enemy, self:GetRDmg())
                if RDamage > Enemy.Health then
                    spells.R.Cast(Player.Position)
                    return
                end
            end
        end
    end
end

function BaseStructure:GetComboDamage(target)
    local damage = 0
    local killType = ""
    if spells.Q:IsReady() and spells.Q:IsInRange(target) then
        damage = damage + DmgLib.CalculatePhysicalDamage(Player, target, self:GetQDmg())
        if damage > target.Health then
            killType = "Burst"
            return damage, killType
        end
    end
    if spells.W:IsReady() and spells.W:IsInRange(target) then
        damage = damage + DmgLib.CalculatePhysicalDamage(Player, target, self:GetWDmg(target))
        if damage > target.Health then
            killType = "Burst"
            return damage, killType
        end
    end
    if spells.R:IsReady() and spells.R:IsInRange(target) then
        damage = damage + DmgLib.CalculatePhysicalDamage(Player, target, self:GetRDmg())
        if damage > target.Health then
            killType = "Easy Kill"
            return damage, killType
        end
    end

    if damage * 2 < target.Health then
        killType = "Impossible"
        return damage, killType
    end

    if damage * 1.25 < target.Health then
        killType = "Hard Kill"
        return damage, killType
    end

    return damage, killType
end

function BaseStructure:Combo()
    if Player.IsDead then
        return
    end

    local Target = TS:GetTarget(1000, true)
    if not Target or not Target.IsValid or Target.IsDead or not Target.IsVisible or not Target.IsTargetable then
        return
    end

    if Menu.Get("Combo.CastE") and spells.E:IsReady() and spells.E:IsInRange(Target) and
        spells.E:CastOnHitChance(Target, Menu.Get("HitChance.E.Combo")) then
        return
    end

    local rUsage = Menu.Get("Combo.R.Usage")

    local comboDamage, comboType = self:GetComboDamage(Target)

    if self:CountHeroes(Player.Position, 500, "enemy") >= Menu.Get("Combo.R.MinHit") and spells.R:IsReady() and
        Menu.Get("Combo.CastR") and (not spells.E:IsReady() or Player.HealthPercent < 0.5   ) then
        if rUsage == 0 and comboType == "Hard Kill" then
            spells.R:Cast(Target.Position)
            return
        elseif rUsage == 1 and comboType == "Easy Kill" and spells.Q:IsReady() and not spells.E:IsReady() and not spells.W:IsReady() and
            comboDamage >= Target.Health then
            spells.R:Cast(Target.Position)
            return
        elseif rUsage == 2 and comboType == "Burst" and not spells.Q:IsReady() and not spells.E:IsReady() and not spells.W:IsReady() and
            comboDamage >= Target.Health then
            spells.R:Cast(Target.Position)
            return
        elseif rUsage == 3 then
            spells.R:Cast(Target.Position)
            return
        end
    end

    if Menu.Get("Combo.CastQ") and spells.Q:IsReady() and spells.Q:IsInRange(Target) and
        spells.Q:CastOnHitChance(Target, Menu.Get("HitChance.Q.Combo")) then
        return
    end

    if Menu.Get("Combo.CastW") and spells.W:IsReady() and spells.W:IsInRange(Target) and
        not self:IsInAARange(Target) then
        spells.W:Cast()
        Input.Attack(Target)
        return
    end

end

function BaseStructure:Harass()
    if Player.IsDead then
        return
    end

    local Target = TS:GetTarget(1050, true)
    if not Target or not Target.IsValid or Target.IsDead or not Target.IsVisible or not Target.IsTargetable or
        Player.ManaPercent <= Menu.Get("Harass.ManaSlider") / 100 then
        return
    end

    if Menu.Get("Harass.CastQ") and spells.Q:IsReady() and spells.Q:IsInRange(Target) and
        spells.Q:CastOnHitChance(Target, Menu.Get("HitChance.Q.Harass")) then
        return
    end

    if Menu.Get("Harass.CastW") and spells.W:IsReady() and spells.W:IsInRange(Target) and
        (not Orb.IsAttackReady() or not Orb.GetTrueAutoAttackRange(Player, Target)) then
        spells.W:Cast()
        Input.Attack(Target)
        return
    end

    if Menu.Get("Harass.CastE") and spells.E:IsReady() and spells.E:IsInRange(Target) and
        spells.E:CastOnHitChance(Target, Menu.Get("HitChance.E.Harass")) then
        return
    end

end

function BaseStructure:Lasthit()
    local minions = Obj.GetNearby("enemy", "minions")

    if #minions == 0 or Player.ManaPercent <= Menu.Get("Lasthit.ManaSlider") / 100 or not Orb.IsAttackReady() then
        return
    end

    local TargetQ = self:GetLastHitMinion(minions, Player.Position, spells.Q.Range, self:GetQDmg(), 0.75)

    if TargetQ and TargetQ.Health > 15 and Menu.Get("Lasthit.CastQ") and spells.Q:IsReady() and
        spells.Q:IsInRange(TargetQ) then
        spells.Q:Cast(TargetQ)
        return
    end

    local TargetW = self:GetLastHitMinion(minions, Player.Position, spells.W.Range, 0, 0.25)

    if TargetW and TargetW.Health > 15 and Menu.Get("Lasthit.CastW") and spells.E:IsReady() and
        spells.W:IsInRange(TargetW) then
        spells.W:Cast()
        Input.Attack(TargetW)
        return
    end
end

function BaseStructure:Waveclear()
    local orbTarget = Orb.GetLastTarget()

    if orbTarget == nil then
        return
    end

    if not orbTarget.IsMonster then
        if Player.ManaPercent <= Menu.Get("Lane.ManaSlider") / 100 and not Orb.IsFastClearEnabled() then
            return
        end

        if Menu.Get("Lane.CastQ") and spells.Q:IsReady() and spells.Q:IsInRange(orbTarget) then
            local castPos, hitCount = spells.Q:GetBestLinearCastPos(
                self:GetNerbyMinions(Player.Position, "enemy", spells.Q.Range))

            if (hitCount >= Menu.Get("Lane.Q.MinHit") or Orb.IsFastClearEnabled()) and castPos then
                spells.Q:Cast(castPos)
                return
            end
        end

        if Menu.Get("Lane.CastW") and spells.W:IsInRange(orbTarget) and spells.W:IsReady() and not Orb.IsAttackReady() then
            spells.W:Cast()
            Input.Attack(orbTarget)
            return
        end

    else
        if Menu.Get("Jungle.CastQ") and spells.Q:IsReady() and spells.Q:IsInRange(orbTarget) and Orb.IsAttackReady() then
            local castPos, hitCount = spells.Q:GetBestLinearCastPos(
                self:GetNerbyMinions(Player.Position, "neutral", spells.Q.Range))

            if hitCount > 0 and castPos then
                spells.Q:Cast(castPos)
                return
            end

        end
    end
end

function BaseStructure:OnLoop()
    if Player.IsDead then
        return
    end
    self:AutoCast()
    local orbMode = Orb.GetMode()
    if orbMode == "Combo" then
        self:Combo()
    elseif orbMode == "Harass" then
        self:Harass()
    elseif orbMode == "Waveclear" then
        self:Waveclear()
    elseif orbMode == "Lasthit" then
        self:Lasthit()
    end
end

function BaseStructure:OnGapClose(source, dash)
    if not source.IsEnemy or source.Invulnerable and not source:IsFacing(Player.Position, 30) then
        return
    end

    local paths = dash:GetPaths()
    local endPos = paths[#paths].EndPos

    local GapQ = Menu.Get("Misc.AntiGapCloserQ")

    if spells.Q:IsReady() and spells.Q:IsInRange(endPos) and GapQ then
        spells.Q:Cast(source)
    end

end

function BaseStructure:OnDrawDamage(target, dmgList)
    if Menu.Get("Drawing.Damage") then
        table.insert(dmgList, self:TotalDmg(target))
    end
end

function BaseStructure:OnCreateObject(obj)
    if obj.IsValid and obj.IsEnemy then
        if obj.Type == "obj_AI_Minion" then
            if obj.Name == "Seed" then
                print("Seed")
            end
        end
        print(obj.Name .. " enemy")
    end
    print(obj.Name .. " enemy")
end

function BaseStructure:OnPostAttack()
    local orbMode = Orb.GetMode()
    local Target = Orb.GetLastTarget()
    if orbMode == "Combo" then
        if Target ~= nil and Target.Health > 15 and Menu.Get("Combo.CastW") and spells.W:IsReady() and spells.W:IsInRange(Target) then
            spells.W:Cast()
            Input.Attack(Target)
            return
        end
    elseif orbMode == "Harass" then
        if Target ~= nil and Target.Health > 15 and Menu.Get("Harass.CastW") and spells.W:IsReady() and spells.W:IsInRange(Target) then
            spells.W:Cast()
            Input.Attack(Target)
            return
        end
    end
end

IllaoiMechanics = BaseStructure:new()

IllaoiMechanics:Menu()

-- Loading Components --

-- Events --
local OnNormalPriority = function()
    IllaoiMechanics:OnLoop()
end

local OnGapClose = function(source, dash)
    IllaoiMechanics:OnGapClose(source, dash)
end

local OnPostAttack = function()
    IllaoiMechanics:OnPostAttack()
end

local OnDraw = function()
    IllaoiMechanics:OnDraw()
end

local OnDrawDamage = function(target, dmgList)
    IllaoiMechanics:OnDrawDamage(target, dmgList)
end

function OnLoad()
    Event.RegisterCallback(Enums.Events.OnTick, OnNormalPriority)
    Event.RegisterCallback(Enums.Events.OnGapclose, OnGapClose)
    Event.RegisterCallback(Enums.Events.OnDraw, OnDraw)
    Event.RegisterCallback(Enums.Events.OnDrawDamage, OnDrawDamage)
    Event.RegisterCallback(Enums.Events.OnPostAttack, OnPostAttack)

    return true
end
