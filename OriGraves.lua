if Player.CharName ~= "Graves" then return end

local SCRIPT_NAME = "Ori Graves"
local SCRIPT_VERSION_UPDATER = "1.0.6"
local SCRIPT_VERSION = SCRIPT_VERSION_UPDATER
local SCRIPT_LAST_UPDATED = "08/18/2022"
local SCRIPT_AUTHOR = "Orietto"
local SCRIPT_IS_BETA = false

if SCRIPT_IS_BETA then
    SCRIPT_VERSION = SCRIPT_VERSION .. " Beta"
else
    SCRIPT_VERSION = SCRIPT_VERSION .. " Release"
end

local SCRIPT_COLOR = 0xF02222FF

module(SCRIPT_NAME, package.seeall, log.setup)
clean.module(SCRIPT_NAME, clean.seeall, log.setup)

local insert, sort = table.insert, table.sort
local huge, pow, min, max = math.huge, math.pow, math.min, math.max

local SDK = _G.CoreEx

SDK.AutoUpdate("https://raw.githubusercontent.com/hagbardlol/nosupport/main/OriGraves.lua", SCRIPT_VERSION_UPDATER)

local ObjManager = SDK.ObjectManager
local EventManager = SDK.EventManager
local Geometry = SDK.Geometry
local Renderer = SDK.Renderer
local Enums = SDK.Enums
local Game = SDK.Game
local Input = SDK.Input

local Vector = Geometry.Vector

local Libs = _G.Libs

local Menu = Libs.NewMenu
local Orbwalker = Libs.Orbwalker
local Collision = Libs.CollisionLib
local Prediction = Libs.Prediction
local Spell = Libs.Spell
local DmgLib = Libs.DamageLib
local TS = Libs.TargetSelector()

local Profiler = Libs.Profiler

local slots = {
    Q = Enums.SpellSlots.Q,
    W = Enums.SpellSlots.W,
    E = Enums.SpellSlots.E,
    R = Enums.SpellSlots.R
}

local dmgTypes = Enums.DamageTypes

local spells = {
    Q = Spell.Skillshot({
        Slot = slots.Q,
        Delay = 0.25,
        Speed = 3000,
        Range = 900,
        Radius = 80 / 2,
        Type = "Linear",
        Collisions = {Heroes = false, Minions = false, WindWall = true, Wall = true}
    }),
    W = Spell.Skillshot({
        Slot = slots.W,
        Delay = 0.25,
        Speed = 1500,
        Range = 950,
        Radius = 220,
        Type = "Circular"
    }),
    E = Spell.Skillshot({
        Slot = slots.E,
        Range = 420
    }),
    R = Spell.Skillshot({
        Slot = slots.R,
        Delay = 0.25,
        Speed = 2100,
        Range = 1000,
        Radius = 200 / 2,
        Type = "Linear"
    }),
    RCone = {
        Range = 700,
        AngleDegrees = 60
    },
    Ignite = {
        Slot = nil,
        LastCastT = 0,
        LastCheckT = 0,
        Range = 600
    },
    Flash = {
        Slot = nil,
        LastCastT = 0,
        LastCheckT = 0,
        Range = 400
    }
}

local lastCastT = {
    [slots.Q] = 0,
    [slots.W] = 0,
    [slots.E] = 0,
    [slots.R] = 0
}

local events = {}
local fightModes = {}

local OriUtils = {}

OriUtils.MiscData = {}

OriUtils.MiscData.Champions = {}

OriUtils.MiscData.Champions.NoProjectileRanged = {
    ["Azir"] = true,
    ["Lillia"] = true,
    ["Rakan"] = true,
    ["Senna"] = true,
    ["Thresh"] = true,
    ["Velkoz"] = true
}

local cacheName = Player.CharName

---@param unit AIBaseClient
---@param radius number|nil
---@param fromPos Vector|nil
function OriUtils.IsValidTarget(unit, radius, fromPos)
    fromPos = fromPos or Player.ServerPos
    radius = radius or huge

    return unit and unit.MaxHealth > 6 and fromPos:DistanceSqr(unit.ServerPos) < pow(radius, 2) and TS:IsValidTarget(unit)
end

function OriUtils.CastSpell(slot, pos_unit)
    return Input.Cast(slot, pos_unit)
end

function OriUtils.CastIgnite(unit)
    if not spells.Ignite.Slot then return false end

    local curTime = Game.GetTime()
    if curTime < spells.Ignite.LastCastT + 0.25 then return false end

    return OriUtils.CastSpell(spells.Ignite.Slot, unit)
end

function OriUtils.CastFlash(pos)
    if not spells.Flash.Slot then return false end

    local curTime = Game.GetTime()
    if curTime < spells.Flash.LastCastT + 0.25 then return false end

    return OriUtils.CastSpell(spells.Flash.Slot, pos)
end

function OriUtils.CheckCastTimers(data)
    local curTime = Game.GetTime()

    for slot, threshold in pairs(data) do
        if curTime < lastCastT[slot] + threshold then
            return false
        end
    end

    return true
end

---@param unit AIBaseClient
function OriUtils.IsDashing(unit)
    unit = unit or Player

    return unit.Pathing.IsDashing
end

---@param unit AIBaseClient
---@return Vector
function OriUtils.GetDashEndPos(unit)
    unit = unit or Player

    --return OriUtils.IsDashing(unit) and unit.Pathing.EndPos
    return unit.Pathing.EndPos
end

function OriUtils.IsSpellReady(slot)
    return Player:GetSpellState(slot) == Enums.SpellStates.Ready
end

function OriUtils.ShouldRunLogic()
    return not (Game.IsChatOpen() or Game.IsMinimized() or Player.IsDead or Player.IsRecalling)
end

function OriUtils.MGet(menuId, nothrow)
    return Menu.Get(cacheName .. "." .. menuId, nothrow)
end

local summSlots = {Enums.SpellSlots.Summoner1, Enums.SpellSlots.Summoner2}
function OriUtils.CheckFlashSlot()
    local curTime = Game.GetTime()

    if curTime < spells.Flash.LastCheckT + 1 then return end

    spells.Flash.LastCheckT = curTime

    local function IsFlash(slot)
        return Player:GetSpell(slot).Name == "SummonerFlash"
    end

    for _, slot in ipairs(summSlots) do
        if IsFlash(slot) then
            if spells.Flash.Slot ~= slot then
                INFO("Flash was found on %d", slot)
                
                spells.Flash.Slot = slot
            end

            return
        end
    end

    if spells.Flash.Slot ~= nil then
        INFO("Flash was lost")

        spells.Flash.Slot = nil
    end
end

function OriUtils.CanCastSpell(slot, menuId)
    return OriUtils.IsSpellReady(slot) and OriUtils.MGet(menuId)
end

---@return AIMinionClient[]
function OriUtils.GetEnemyAndJungleMinions(radius, fromPos)
    fromPos = fromPos or Player.ServerPos

    local result = {}

    ---@param group GameObject[]
    local function AddIfValid(group)
        for _, unit in ipairs(group) do
            local minion = unit.AsMinion

            if OriUtils.IsValidTarget(minion, radius, fromPos) then
                result[#result+1] = minion
            end
        end
    end

    local enemyMinions = ObjManager.GetNearby("enemy", "minions")
    local jungleMinions = ObjManager.GetNearby("neutral", "minions")

    AddIfValid(enemyMinions)
    AddIfValid(jungleMinions)

    return result
end

--It's like a sort only that it gets the first element instead of ordering them all
function OriUtils.GetFirstElementSort(tbl, compareFunc)
    local first = nil

    for i, v in ipairs(tbl) do
        if first == nil then
            first = v
        else
            if compareFunc(v, first) then
                first = v
            end
        end
    end

    return first
end

function OriUtils.AddDrawMenu(data)
    for _, element in ipairs(data) do
        local id = element.id
        local displayText = element.displayText

        Menu.Checkbox(cacheName .. ".draw." .. id, "Draw " .. displayText .. " range", true)
        Menu.Indent(function()
            Menu.ColorPicker(cacheName .. ".draw." .. id .. ".color", "Color", SCRIPT_COLOR)
        end)
    end

    Menu.Separator()

    Menu.Checkbox(cacheName .. ".draw." .. "comboDamage", "Draw combo damage on healthbar", true)
end

---@param forcedTarget AIHeroClient
---@param ranges number[]
---@return AIHeroClient|nil
function OriUtils.ChooseTarget(forcedTarget, ranges)
    if forcedTarget and OriUtils.IsValidTarget(forcedTarget) then
        return forcedTarget
    elseif not forcedTarget then
        for _, range in ipairs(ranges) do
            local target = TS:GetTarget(range)

            if target then
                return target
            end
        end
    end

    return nil
end

---@param pos Vector
---@return boolean
function OriUtils.IsPosUnderTurret(pos)
    local enemyTurrets = ObjManager.GetNearby("enemy", "turrets")

    local boundingRadius = Player.BoundingRadius

    for _, obj in ipairs(enemyTurrets) do
        local turret = obj.AsTurret

        if turret and turret.IsValid and not turret.IsDead and pos:DistanceSqr(turret) <= pow(900 + boundingRadius, 2) then
            return true
        end
    end

    return false
end


local Graves = {}

local qCastTimers = { [slots.Q] = 0.25 }
function Graves.CastQ(pos)
    if not OriUtils.CheckCastTimers(qCastTimers) then return false end

    if Orbwalker.IsWindingUp() then return false end

    return OriUtils.CastSpell(slots.Q, pos)
end

local wCastTimers = { [slots.W] = 0.25 }
function Graves.CastW(pos)
    if not OriUtils.CheckCastTimers(wCastTimers) then return false end

    if Orbwalker.IsWindingUp() then return false end

    return OriUtils.CastSpell(slots.W, pos)
end

local eCastTimers = { [slots.E] = 0.25 }
function Graves.CastE(pos)
    if not OriUtils.CheckCastTimers(eCastTimers) then return false end

    --if Orbwalker.IsWindingUp() then return false end

    return OriUtils.CastSpell(slots.E, pos)
end

local rCastTimers = { [slots.R] = 0.25 }
function Graves.CastR(pos)
    if not OriUtils.CheckCastTimers(rCastTimers) then return false end

    --if Orbwalker.IsWindingUp() then return false end

    return OriUtils.CastSpell(slots.R, pos)
end

function Graves.GetHitchance(slot)
    local hc = 0.5

    if slot == slots.Q then
        hc = OriUtils.MGet("hc.Q") * 0.01
    elseif slot == slots.W then
        hc = OriUtils.MGet("hc.W") * 0.01
    elseif slot == slots.R then
        hc = OriUtils.MGet("hc.R") * 0.01
    end

    return hc
end

---@param target AIBaseClient
function Graves.GetDamage(target, slot)
    return DmgLib.GetSpellDamage(Player, target, slot)
end

function fightModes.Killsteal(lagFree)
    local me = Player
    local mePos = me.ServerPos

    local qRange = spells.Q.Range

    local wRange = spells.W.Range

    local rRange = spells.R.Range
    local rWidth = spells.R.Radius * 2
    local rDelay = spells.R.Delay
    local rSpeed = spells.R.Speed

    local rConeRange = spells.RCone.Range

    local enemyHeroes = ObjManager.Get("enemy", "heroes")

    for _, obj in pairs(enemyHeroes) do
        local hero = obj.AsHero
        local heroName = hero.CharName
        local heroPos = hero.ServerPos
        local heroHandle = hero.Handle
        local dist = hero:Distance(me)
        --local heroHealth = hero.Health + hero.ShieldAll
        
        if OriUtils.IsValidTarget(hero) then
            if (lagFree == 1 or lagFree == 2) and OriUtils.CanCastSpell(slots.R, "ks.useR") then
                local rComboCheck = Orbwalker.GetMode() == "Combo" or not OriUtils.MGet("ks.useR.comboOnly")

                if rComboCheck and OriUtils.MGet("ks.useR." .. heroName, true) and dist < rRange then
                    local pred = spells.R:GetPrediction(hero)
                    
                    if pred and pred.CastPosition then
                        if pred.HitChance >= Graves.GetHitchance(slots.R) then
                            local col = Collision.SearchHeroes(mePos, pred.CastPosition, rWidth, rSpeed, rDelay, 6, "enemy", {[heroHandle] = true})
                            
                            if col then
                                local heroHealth = spells.R:GetKillstealHealth(hero)
                                local rDamage = Graves.GetDamage(hero, slots.R)
                            
                                if heroHealth > 0 then     
                                    if col.Result then
                                        ---@param elemA AIHeroClient
                                        ---@param elemB AIHeroClient
                                        local closest = OriUtils.GetFirstElementSort(col.Objects, function(elemA, elemB)
                                            return elemA:Distance(me) < elemB:Distance(me)
                                        end)
                                    
                                        if closest and hero:Distance(closest) < rConeRange then
                                            if heroHealth < rDamage * 0.8 then
                                                if Graves.CastR(pred.CastPosition) then
                                                    return true
                                                end
                                            end
                                        end
                                    else
                                        if heroHealth < rDamage then
                                            if Graves.CastR(pred.CastPosition) then
                                                return true
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            elseif lagFree == 3 and OriUtils.CanCastSpell(slots.W, "ks.useW") then
                if dist < wRange then
                    local heroHealth = spells.W:GetKillstealHealth(hero)
                    local wDamage = Graves.GetDamage(hero, slots.W)
    
                    if heroHealth > 0 and heroHealth < wDamage then
                        local pred = spells.W:GetPrediction(hero)
    
                        if pred and pred.CastPosition then
                            if pred.HitChance >= Graves.GetHitchance(slots.W) then
                                if Graves.CastW(pred.CastPosition) then
                                    return true
                                end
                            end
                        end
                    end
                end
            elseif lagFree == 4 and OriUtils.CanCastSpell(slots.Q, "ks.useQ") then
                if dist < qRange then
                    local heroHealth = spells.Q:GetKillstealHealth(hero)
                    local qDamage = Graves.GetDamage(hero, slots.Q)
    
                    if heroHealth > 0 and heroHealth < qDamage then
                        local pred = spells.Q:GetPrediction(hero)
    
                        if pred and pred.CastPosition then
                            if pred.HitChance >= Graves.GetHitchance(slots.Q) then
                                if Graves.CastQ(pred.CastPosition) then
                                    return true
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

function fightModes.ExtraModes(lagFree)
    local me = Player
    local mePos = me.ServerPos

    if lagFree == 1 and OriUtils.CanCastSpell(slots.R, "misc.forceR") then
        local forcedTarget = TS:GetForcedTarget()

        local target = OriUtils.ChooseTarget(forcedTarget, {spells.R.Range})

        if target and target:Distance(Player) < spells.R.Range then
            local pred = spells.R:GetPrediction(target)

            if pred and pred.CastPosition then
                if pred.HitChance >= Graves.GetHitchance(slots.R) then
                    local rSpell = spells.R

                    local col = Collision.SearchHeroes(mePos, pred.CastPosition, rSpell.Radius * 2, rSpell.Speed, rSpell.Delay, 6, "enemy", {[target.Handle] = true})

                    if col then
                        if col.Result then
                            ---@param elemA AIHeroClient
                            ---@param elemB AIHeroClient
                            local closest = OriUtils.GetFirstElementSort(col.Objects, function(elemA, elemB)
                                return elemA:Distance(me) < elemB:Distance(me)
                            end)

                            if closest and closest:Distance(target) < spells.RCone.Range then
                                if Graves.CastR(pred.CastPosition) then
                                    return true
                                end
                            end
                        else
                            if Graves.CastR(pred.CastPosition) then
                                return true
                            end
                        end
                    end
                end
            end
        end
    end
end

function fightModes.Combo(lagFree)
    local forcedTarget = TS:GetForcedTarget()

    local me = Player

    if lagFree == 1 and OriUtils.CanCastSpell(slots.Q, "combo.useQ") then
        local spell = spells.Q

        local target = OriUtils.ChooseTarget(forcedTarget, {spell.Range})

        if target then
            local pred = spell:GetPrediction(target)

            if pred and pred.CastPosition then
                if pred.HitChance >= Graves.GetHitchance(slots.Q) then
                    if Graves.CastQ(pred.CastPosition) then
                        return true
                    end
                end
            end
        end
    elseif lagFree == 2 and OriUtils.CanCastSpell(slots.W, "combo.useW") then
        local spell = spells.W

        local target = OriUtils.ChooseTarget(forcedTarget, {spell.Range})

        if target then
            local pred = spell:GetPrediction(target)

            if pred and pred.CastPosition then
                if pred.HitChance >= Graves.GetHitchance(slots.W) then
                    if Graves.CastW(pred.CastPosition) then
                        return true
                    end
                end
            end
        end
    elseif (lagFree == 3 or lagFree == 4) and OriUtils.CanCastSpell(slots.R, "combo.useR") then
        local spell = spells.R

        local myHP = me.HealthPercent * 100

        if myHP < OriUtils.MGet("combo.useR.minHealth") then
            local target = OriUtils.ChooseTarget(forcedTarget, {spell.Range})

            if target then
                local pred = spell:GetPrediction(target)

                if pred and pred.CastPosition then
                    if pred.HitChanceEnum >= Enums.HitChance.Low then
                        if Graves.CastR(pred.CastPosition) then
                            return true
                        end
                    end
                end
            end
        end
    end
end

function fightModes.Harass(lagFree)
    local me = Player
    
    local manaPercent = me.ManaPercent * 100

    if manaPercent <= OriUtils.MGet("harass.minMana") then
        return false
    end

    local forcedTarget = TS:GetForcedTarget()

    if lagFree == 1 and OriUtils.CanCastSpell(slots.Q, "harass.useQ") then
        local spell = spells.Q

        local target = OriUtils.ChooseTarget(forcedTarget, {spell.Range})

        if target then
            local pred = spell:GetPrediction(target)

            if pred and pred.CastPosition then
                if pred.HitChance >= Graves.GetHitchance(slots.Q) then
                    if Graves.CastQ(pred.CastPosition) then
                        return true
                    end
                end
            end
        end
    elseif lagFree == 2 and OriUtils.CanCastSpell(slots.W, "harass.useW") then
        local spell = spells.W

        local target = OriUtils.ChooseTarget(forcedTarget, {spell.Range})

        if target then
            local pred = spell:GetPrediction(target)

            if pred and pred.CastPosition then
                if pred.HitChance >= Graves.GetHitchance(slots.W) then
                    if Graves.CastW(pred.CastPosition) then
                        return true
                    end
                end
            end
        end
    end
end

function fightModes.Waveclear(lagFree)
    local me = Player
    local mePos = me.ServerPos

    local manaPercent = me.ManaPercent * 100

    if manaPercent <= OriUtils.MGet("clear.minMana") then
        return false
    end

    if lagFree == 1 and OriUtils.CanCastSpell(slots.Q, "clear.useQ") then
        local minions = OriUtils.GetEnemyAndJungleMinions(spells.Q.Range)
        local minionsPos = {}

        local qWidth = spells.Q.Radius * 2
        
        for _, minion in ipairs(minions) do
            minionsPos[#minionsPos+1] = minion.ServerPos
        end

        local bestPos, hits = Geometry.BestCoveringRectangle(minionsPos, mePos, qWidth)

        if hits >= OriUtils.MGet("clear.useQ.minHit") and bestPos then
            if Graves.CastQ(bestPos) then
                return true
            end
        end
    elseif lagFree == 2 and OriUtils.CanCastSpell(slots.W, "clear.useW") then
        local minions = OriUtils.GetEnemyAndJungleMinions(spells.W.Range)
        local minionsPos = {}

        local wRadius = spells.W.Radius

        for _, minion in ipairs(minions) do
            minionsPos[#minionsPos+1] = minion.ServerPos
        end

        local bestPos, hits = Geometry.BestCoveringCircle(minionsPos, wRadius)

        if hits >= OriUtils.MGet("clear.useW.minHit") and bestPos then
            if Graves.CastW(bestPos) then
                return true
            end
        end
    end
end

function fightModes.Lasthit(lagFree)
    local me = Player
    local mePos = me.ServerPos

    local manaPercent = me.ManaPercent * 100

    if manaPercent <= OriUtils.MGet("lh.minMana") then
        return false
    end

    if lagFree == 1 and OriUtils.CanCastSpell(slots.Q, "lh.useQ") then
        local minions = OriUtils.GetEnemyAndJungleMinions(spells.Q.Range)
        local minionsPos = {}

        local qWidth = spells.Q.Radius * 2

        for _, minion in ipairs(minions) do
            if spells.Q:GetHealthPred(minion) < Graves.GetDamage(minion, slots.Q) then
                minionsPos[#minionsPos+1] = minion.ServerPos
            end
        end

        local bestPos, hits = Geometry.BestCoveringRectangle(minionsPos, mePos, qWidth)

        if hits >= OriUtils.MGet("lh.useQ.minHit") and bestPos then
            if Graves.CastQ(bestPos) then
                return true
            end
        end
    elseif lagFree == 2 and OriUtils.CanCastSpell(slots.W, "lh.useW") then
        local minions = OriUtils.GetEnemyAndJungleMinions(spells.W.Range)
        local minionsPos = {}

        local wRadius = spells.W.Radius

        for _, minion in ipairs(minions) do
            if spells.W:GetHealthPred(minion) < Graves.GetDamage(minion, slots.W) then
                minionsPos[#minionsPos+1] = minion.ServerPos
            end
        end

        local bestPos, hits = Geometry.BestCoveringCircle(minionsPos, mePos, wRadius)

        if hits >= OriUtils.MGet("lh.useW.minHit") and bestPos then
            if Graves.CastW(bestPos) then
                return true
            end
        end
    end
end

function events.OnTick(lagFree)
    if not OriUtils.ShouldRunLogic() then return end
    
    if fightModes.Killsteal and fightModes.Killsteal(lagFree) then
        return
    end
    
    if fightModes.ExtraModes and fightModes.ExtraModes(lagFree) then
        return
    end
    
    local modeToExecute = fightModes[Orbwalker.GetMode()]
    if modeToExecute and modeToExecute(lagFree) then
        return
    end
end

local afterAAData = {
    ["Combo"] = {
        conditions = function(target) return target.IsHero and OriUtils.MGet("combo.useE") end,
        mode = function() return OriUtils.MGet("combo.useE.mode") end
    },
    ["Waveclear"] = {
        conditions = function(target) return target.IsMinion and OriUtils.MGet("clear.useE") and OriUtils.MGet("clear.minMana") < Player.ManaPercent * 100 end,
        mode = function() return OriUtils.MGet("clear.useE.mode") end
    }
}
---@param obj GameObject
---@param spellCast SpellCast
function events.OnSpellCast(obj, spellCast)
    if obj and obj.IsMe and spellCast and spellCast.IsBasicAttack and spellCast.Target then
        local target = spellCast.Target

        if not target.IsAI or not OriUtils.IsValidTarget(target) then
            return
        end

        if OriUtils.IsSpellReady(slots.E) then
            local orbMode = Orbwalker.GetMode()
            local aaData = afterAAData[orbMode]
    
            if aaData then
                local modeConditions = aaData.conditions
                local eMode = aaData.mode
                
                if modeConditions and modeConditions(target) then
                    if eMode then
                        eMode = eMode()
                    end
    
                    local castPos = nil
    
                    if eMode == 0 then
                        castPos = Renderer.GetMousePos()
                    elseif eMode == 1 then
                        castPos = target.AsAI.ServerPos
                    end
    
                    if castPos then
                        if Graves.CastE(castPos) then
                            return
                        end
                    end
                end
            end
        end
    end
end

---@param target AttackableUnit
function events.OnPostAttackDisabled(target)
    if not OriUtils.IsValidTarget(target) then
        return
    end

    if OriUtils.IsSpellReady(slots.E) then
        local orbMode = Orbwalker.GetMode()
        local aaData = afterAAData[orbMode]

        if aaData then
            local modeConditions = aaData.conditions
            local eMode = aaData.mode
            
            if modeConditions and modeConditions(target) then
                if eMode then
                    eMode = eMode()
                end

                local castPos = nil

                if eMode == 0 then
                    castPos = Renderer.GetMousePos()
                elseif eMode == 1 then
                    castPos = target.AsAI.ServerPos
                end

                if castPos then
                    if Graves.CastE(castPos) then
                        return
                    end
                end
            end
        end
    end
end

local drawData = {
    {slot = slots.Q, id = "Q", displayText = "Q [End of the Line]", range = spells.Q.Range},
    {slot = slots.W, id = "W", displayText = "W [Smoke Screen]", range = spells.W.Range},
    {slot = slots.E, id = "E", displayText = "E [Quickdraw]", range = spells.E.Range},
    {slot = slots.R, id = "R", displayText = "R [Collateral Damage]", range = spells.R.Range}
}
function events.OnDraw()
    if Player.IsDead then
        return
    end

    local myPos = Player.Position

    for _, drawInfo in ipairs(drawData) do
        local slot = drawInfo.slot
        local id = drawInfo.id
        local range = drawInfo.range

        if type(range) == "function" then
            range = range()
        end

        if OriUtils.CanCastSpell(slot, "draw." .. id) then
            Renderer.DrawCircle3D(myPos, range, 30, 2, OriUtils.MGet("draw." .. id .. ".color"))
        end
    end
end

---@param target AIHeroClient
function events.OnDrawDamage(target, dmgList)
    if not OriUtils.MGet("draw.comboDamage") then
        return
    end

    local damageToDeal = 0

    damageToDeal = damageToDeal + DmgLib.GetAutoAttackDamage(Player, target, true)

    if OriUtils.CanCastSpell(slots.Q, "combo.useQ") then
        damageToDeal = damageToDeal + Graves.GetDamage(target, slots.Q)
    end

    if OriUtils.CanCastSpell(slots.W, "combo.useW") then
        damageToDeal = damageToDeal + Graves.GetDamage(target, slots.W)
    end

    if OriUtils.CanCastSpell(slots.R, "combo.useR") then
        local hasCollision = false

        local col = Collision.SearchHeroes(Player.ServerPos, target.ServerPos, spells.R.Radius * 2, spells.R.Speed, spells.R.Delay, 6, "enemy", {[target.Handle] = true})

        if col then
            hasCollision = col.Result
        end

        damageToDeal = damageToDeal + (Graves.GetDamage(target, slots.R) * (hasCollision and 0.8 or 1.0))
    end

    insert(dmgList, damageToDeal)
end

function events.OnCastSpell(data)
    if data then
        local slot = data.Slot

        if lastCastT[slot] then
            lastCastT[slot] = Game.GetTime()
        elseif spells.Flash.Slot and spells.Flash.Slot == slot then
            spells.Flash.LastCastT = Game.GetTime()
        end
    end
end

function Graves.RegisterEvents()
    for eventName, eventId in pairs(Enums.Events) do
        if events[eventName] then
            EventManager.RegisterCallback(eventId, events[eventName])
        end
    end
end

function Graves.InitMenu()
    local function QHeader()
        Menu.Separator("Q [End of the Line]", SCRIPT_COLOR, true)
    end

    local function WHeader()
        Menu.Separator("W [Smoke Screen]", SCRIPT_COLOR, true)
    end

    local function EHeader()
        Menu.Separator("E [Quickdraw]", SCRIPT_COLOR, true)
    end

    local function RHeader()
        Menu.Separator("R [Collateral Damage]", SCRIPT_COLOR, true)
    end

    local function GravesMenu()
        Menu.NewTree("Graves.comboMenu", "Combo Settings", function()
            Menu.ColumnLayout("Graves.comboMenu.QW", "Graves.comboMenu.QW", 2, true, function()
                QHeader()

                Menu.Checkbox("Graves.combo.useQ", "Enable Q", true)

                Menu.NextColumn()

                WHeader()

                Menu.Checkbox("Graves.combo.useW", "Enable W", true)
            end)

            Menu.ColumnLayout("Graves.comboMenu.ER", "Graves.comboMenu.ER", 2, true, function()
                EHeader()

                Menu.Checkbox("Graves.combo.useE", "Enable E after AA", true)
                Menu.Indent(function()
                    Menu.Dropdown("Graves.combo.useE.mode", "Mode", 0, {"To Mouse", "To Target"})
                end)

                Menu.NextColumn()

                RHeader()

                Menu.Checkbox("Graves.combo.useR", "Enable R", true)
                Menu.Indent(function()
                    Menu.Slider("Graves.combo.useR.minHealth", "Use if my HP% is under X", 15, 0, 100, 1)
                end)
            end)
        end)

        Menu.NewTree("Graves.drawMenu", "Draw Settings", function()
            Menu.Separator("Draw Settings")
            OriUtils.AddDrawMenu(drawData)
        end)

        Menu.NewTree("Graves.harassMenu", "Harass Settings", function()
            QHeader()

            Menu.Checkbox("Graves.harass.useQ", "Enable Q", true)

            WHeader()
            
            Menu.Checkbox("Graves.harass.useW", "Enable W", false)

            Menu.Slider("Graves.harass.minMana", "Harass minimum mana", 30, 0, 100, 1)
        end)

        Menu.NewTree("Graves.clearMenu", "Clear Settings", function()
            QHeader()

            Menu.Checkbox("Graves.clear.useQ", "Enable Q", true)
            Menu.Indent(function()
                Menu.Slider("Graves.clear.useQ.minHit", "If it will hit X minions", 2, 1, 5, 1)
            end)

            WHeader()

            Menu.Checkbox("Graves.clear.useW", "Enable W", false)
            Menu.Indent(function()
                Menu.Slider("Graves.clear.useW.minHit", "If it will hit X minions", 3, 1, 5, 1)
            end)

            EHeader()

            Menu.Checkbox("Graves.clear.useE", "Enable E after AA", false)
            Menu.Indent(function()
                Menu.Dropdown("Graves.clear.useE.mode", "Mode", 0, {"To Mouse", "To Target"})
            end)

            Menu.Slider("Graves.clear.minMana", "Clear minimum mana", 30, 0, 100, 1)
        end)

        Menu.NewTree("Graves.lasthitMenu", "Last hit Settings", function()
            QHeader()

            Menu.Checkbox("Graves.lh.useQ", "Enable Q", false)
            Menu.Indent(function()
                Menu.Slider("Graves.lh.useQ.minHit", "If it will kill X minions", 2, 1, 5, 1)
            end)

            WHeader()

            Menu.Checkbox("Graves.lh.useW", "Enable W", false)
            Menu.Indent(function()
                Menu.Slider("Graves.lh.useW.minHit", "If it will kill X minions", 2, 1, 5, 1)
            end)

            Menu.Slider("Graves.lh.minMana", "Last hit minimum mana", 30, 0, 100, 1)
        end)

        Menu.NewTree("Graves.ksMenu", "Killsteal Settings", function()
            Menu.Separator("Killsteal Settings")
            Menu.Checkbox("Graves.ks.useQ", "Killsteal with Q", true)
            Menu.Checkbox("Graves.ks.useW", "Killsteal with W", true)
            Menu.Checkbox("Graves.ks.useR", "Killsteal with R", true)

            Menu.Indent(function()
                Menu.Checkbox("Graves.ks.useR.comboOnly", "Only KS R when combo key is pressed", false)
                Menu.NewTree("Graves.ksMenu.rWhitelist", "KS R Whitelist", function()
                    local enemyHeroes = ObjManager.Get("enemy", "heroes")

                    local addedWL = {}

                    for _, obj in pairs(enemyHeroes) do
                        local hero = obj.AsHero
                        local heroName = hero.CharName

                        if hero and not addedWL[heroName] then
                            Menu.Checkbox("Graves.ks.useR." .. heroName, "Use R on " .. heroName, true)

                            addedWL[heroName] = true
                        end
                    end
                end)
            end)
        end)

        Menu.NewTree("Graves.miscMenu", "Misc Settings", function()
            Menu.Separator("Misc Settings")
            Menu.Keybind("Graves.misc.forceR", "Force R", string.byte("T"))
        end)

        Menu.NewTree("Graves.hcMenu", "Hitchance Settings", function()
            Menu.Separator("Hitchance Settings")
            Menu.Slider("Graves.hc.Q", "Q Hitchance", 15, 0, 100, 1)
            Menu.Slider("Graves.hc.W", "W Hitchance", 35, 0, 100, 1)
            Menu.Slider("Graves.hc.R", "R Hitchance", 35, 0, 100, 1)
        end)

        Menu.Separator("Author: Orietto")
    end

    Menu.RegisterMenu(SCRIPT_NAME, SCRIPT_NAME, GravesMenu)
end

function OnLoad()
    Graves.InitMenu()

    Graves.RegisterEvents()

    return true
end
