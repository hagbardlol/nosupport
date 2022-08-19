if Player.CharName ~= "Akali" then return end

local SCRIPT_NAME = "Ori Akali"
local SCRIPT_VERSION_UPDATER = "1.0.7"
local SCRIPT_VERSION = SCRIPT_VERSION_UPDATER
local SCRIPT_LAST_UPDATED = "08/18/2022"
local SCRIPT_AUTHOR = "Orietto"
local SCRIPT_IS_BETA = false

if SCRIPT_IS_BETA then
    SCRIPT_VERSION = SCRIPT_VERSION .. " Beta"
else
    SCRIPT_VERSION = SCRIPT_VERSION .. " Release"
end

local SCRIPT_COLOR = 0x1ED44EFF

module(SCRIPT_NAME, package.seeall, log.setup)
clean.module(SCRIPT_NAME, clean.seeall, log.setup)

local insert, sort = table.insert, table.sort
local huge, pow, min, max, pi, ceil, floor, sin, cos = math.huge, math.pow, math.min, math.max, math.pi, math.ceil, math.floor, math.sin, math.cos

local SDK = _G.CoreEx

SDK.AutoUpdate("https://raw.githubusercontent.com/hagbardlol/nosupport/main/OriAkali.lua", SCRIPT_VERSION_UPDATER)

local ObjManager = SDK.ObjectManager
local EventManager = SDK.EventManager
local Geometry = SDK.Geometry
local Renderer = SDK.Renderer
local Enums = SDK.Enums
local Game = SDK.Game
local Input = SDK.Input
local Nav = SDK.Nav

local Vector = Geometry.Vector

local Libs = _G.Libs

local Menu = Libs.NewMenu
local Orbwalker = Libs.Orbwalker
local Collision = Libs.CollisionLib
local Prediction = Libs.Prediction
local Spell = Libs.Spell
local DmgLib = Libs.DamageLib
local HealthPred = Libs.HealthPred
local TS = Libs.TargetSelector()

local Profiler = Libs.Profiler

local slots = {
    Q = Enums.SpellSlots.Q,
    W = Enums.SpellSlots.W,
    E = Enums.SpellSlots.E,
    R = Enums.SpellSlots.R
}

local dmgTypes = {
    Physical = Enums.DamageTypes.Physical,
    Magical = Enums.DamageTypes.Magical,
    True = Enums.DamageTypes.True
}

local damages = {
    Passive = {
        Base = {29, 32, 35, 38, 41, 44, 47, 50, 59, 68, 77, 86, 95, 110, 125, 140, 155, 170},
        BonusAD = 0.6,
        TotalAP = 0.4,
        Type = dmgTypes.Magical
    },
    Q = {
        Base = {30, 55, 80, 105, 130},
        TotalAD = 0.65,
        TotalAP = 0.6,
        Type = dmgTypes.Magical
    },
    E1 = {
        Base = {30, 56.25, 82.5, 108.75, 135},
        TotalAD = 0.255,
        TotalAP = 0.36,
        Type = dmgTypes.Magical
    },
    E2 = {
        Base = {70, 131.25, 192.5, 253.75, 315},
        TotalAD = 0.595,
        TotalAP = 0.84,
        Type = dmgTypes.Magical
    },
    R1 = {
        Base = {80, 220, 360},
        BonusAD = 0.5,
        TotalAP = 0.3,
        Type = dmgTypes.Magical
    },
    R2 = {
        Base = {60, 130, 200},
        TotalAP = 0.3,
        ---@param baseDamage number
        ---@param target AIBaseClient
        ---@param simulatedHealth number|nil
        MissingHealth = function(baseDamage, target, simulatedHealth)
            local curHP = simulatedHealth or target.Health
            local missingHealthPercent = 1 - (curHP / target.MaxHealth)

            local increasePercent = min(2, missingHealthPercent * 2.86)

            return baseDamage * increasePercent
        end,
        Type = dmgTypes.Magical
    }
}

local spells = {
    Q = Spell.Skillshot({
        Slot = slots.Q,
        Delay = 0.25,
        Speed = huge,
        Range = 520,
        Radius = 100 / 2,
        Type = "Linear",
        AngleRad = 35 * (pi/180)
    }),
    W = Spell.Skillshot({
        Slot = slots.W,
        Delay = 0.25,
        Speed = huge,
        Range = 300,
        Radius = 350,
        Type = "Circular"
    }),
    E1 = Spell.Skillshot({
        Slot = slots.E,
        Delay = 0.25,
        Speed = 1800,
        Range = 750,
        Radius = 80 / 2,
        Type = "Linear",
        Collisions = {Heroes = true, Minions = true, WindWall = true}
    }),
    E2 = Spell.Active({
        Slot = slots.E,
        Range = huge
    }),
    R1 = Spell.Targeted({
        Slot = slots.R,
        Range = 670,
    }),
    R2 = Spell.Skillshot({
        Slot = slots.R,
        Delay = 0,
        Speed = 3000,
        Range = 730,
        Radius = 180 / 2,
        Type = "Linear"
    }),
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

OriUtils.MiscData.Map = {}

OriUtils.MiscData.Map.River = {
    Top = {
        {3048, -25.488565444946, 11904},
        {3430, -63.276065826416, 11726},
        {3736, -60.225284576416, 11522},
        {3784, -70.918266296387, 10944},
        {3850, -78.907920837402, 10552},
        {4346, -71.240600585938, 10128},
        {4514, -71.240600585938, 10142},
        {4574, -71.240600585938, 10284},
        {4484, -71.240600585938, 10536},
        {4654, -71.240600585938, 10750},
        {5052, -78.487075805664, 10862},
        {5356, -71.240600585938, 10646},
        {5362, -71.240600585938, 10238},
        {5182, -71.240600585938, 10016},
        {4924, -71.240600585938, 9996},
        {4840, -70.387908935547, 9820},
        {5096, -69.851135253906, 9668},
        {5516, -71.181427001953, 9474},
        {6072, -68.877799987793, 9326},
        {6288, -71.240600585938, 9062},
        {6326, -71.240600585938, 8938},
        {7016, -71.240600585938, 8364},
        {6448, -49.922626495361, 7896},
        {5866, -70.283508300781, 8328},
        {5298, -65.726959228516, 8572},
        {4790, -44.610748291016, 8716},
        {4768, -69.819557189941, 8890},
        {4274, -66.105194091797, 9116},
        {3900, -67.920196533203, 9442},
        {3770, -1.6699202060699, 9204},
        {3522, -65.373352050781, 9790},
        {3358, -65.332664489746, 10254},
        {3160, -67.455421447754, 10710},
        {2738, -43.222412109375, 11498},
        {2666, -7.1835269927979, 11688},
        {2866, 7.1607427597046, 11910}
    },
    Bottom = {
        {7920, -68.054618835449, 6308},
        {8450, -71.240600585938, 6844},
        {9364, -71.240600585938, 6308},
        {10016, -16.135112762451, 6238},
        {10046, -71.240600585938, 5996},
        {10746, -62.810199737549, 5482},
        {11034, -70.854095458984, 5402},
        {11446, -71.240600585938, 4810},
        {11806, -71.240600585938, 4302},
        {11950, -66.245162963867, 3518},
        {11356, -68.348770141602, 3152},
        {10992, -46.506671905518, 3430},
        {11070, -71.240600585938, 4044},
        {10914, -71.240600585938, 4338},
        {10392, -69.378196716309, 4818},
        {10238, -71.240600585938, 4672},
        {10284, -71.240600585938, 4282},
        {10074, -71.240600585938, 3958},
        {9680, -70.833366394043, 3964},
        {9364, -71.240600585938, 4408},
        {9500, -71.240600585938, 4676},
        {10014, -71.240600585938, 4878},
        {10090, -68.042984008789, 5070},
        {9954, -66.324920654297, 5226},
        {9798, -70.990257263184, 5190},
        {9354, -71.240600585938, 5450},
        {8824, -71.240600585938, 5622},
        {8590, -71.240600585938, 5970},
        {8336, -71.240600585938, 6054}
    },
    ---@type Polygon
    TopPoly = nil,
    ---@type Polygon
    BottomPoly = nil
}

OriUtils.Items = {}

OriUtils.Items.Prowler = {}

OriUtils.Items.Prowler.ItemIDs = {6693, 7000}
OriUtils.Items.Prowler.Range = 500

OriUtils.Perks = {}

OriUtils.Perks.Electrocute = {}

OriUtils.Perks.Electrocute.HasBuff = false
OriUtils.Perks.Electrocute.BuffName = "ASSETS/Perks/Styles/Domination/Electrocute/Electrocute.lua"

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

function OriUtils.LoadRiverPolygons()
    local tempTop, tempBottom = {}, {}

    for i, point in ipairs(OriUtils.MiscData.Map.River.Top) do
        tempTop[i] = Vector(point[1], point[2], point[3])
    end

    for i, point in ipairs(OriUtils.MiscData.Map.River.Bottom) do
        tempBottom[i] = Vector(point[1], point[2], point[3])
    end

    OriUtils.MiscData.Map.River.TopPoly = Geometry.Polygon(tempTop)
    OriUtils.MiscData.Map.River.BottomPoly = Geometry.Polygon(tempBottom)
end

---@param point Vector
function OriUtils.IsRiver(point)
    local river = OriUtils.MiscData.Map.River

    return river.TopPoly:Contains(point) or river.BottomPoly:Contains(point)
end

---@param point Vector
---@return '"Terrain"'|'"Brush"'|'"River"'|'"None"'
function OriUtils.GetPointType(point)
    if Nav.IsWall(point) then
        return "Terrain"
    elseif Nav.IsGrass(point) then
        return "Brush"
    elseif OriUtils.IsRiver(point) then
        return "River"
    else
        return "None"
    end
end

function OriUtils.HasItem(itemId)
    ---@param item Item
    for itemSlot, item in pairs(Player.Items) do
        if item and item.ItemId == itemId then
            return itemSlot, item
        end
    end

    return nil, nil
end

function OriUtils.GetProwlerSlot()
    for _, itemId in ipairs(OriUtils.Items.Prowler.ItemIDs) do
        local slot, item = OriUtils.HasItem(itemId)

        if slot then
            slot = slot + 6

            if OriUtils.IsSpellReady(slot) then
                return slot
            end
        end
    end

    return nil
end

function OriUtils.InitElectrocute()
    if Player:GetBuff(OriUtils.Perks.Electrocute.BuffName) then
        OriUtils.Perks.Electrocute.HasBuff = true
    end
end

function OriUtils.GetElectrocuteDamage(target)
    local me = Player

    local bonusAD = me.BonusAD
    local bonusAP = me.BonusAP

    local dmgType = dmgTypes.Physical
    if bonusAP > bonusAD then
        dmgType = dmgTypes.Magical
    end

    local rawDamage = (30 + 150 / 17 * (min(18, me.Level))) + (0.4 * bonusAD) + (0.25 * me.TotalAP)

    return dmgType == dmgTypes.Physical and DmgLib.CalculatePhysicalDamage(me, target, rawDamage) or DmgLib.CalculateMagicalDamage(me, target, rawDamage)
end


local Akali = {}

Akali.MiscData = {}

Akali.MiscData.HasPassive = false

Akali.MiscData.HasSmokeStealth = false

Akali.MiscData.R2BuffExpireTime = nil

Akali.MiscData.EnemyEDebuffs = {}

local qCastTimers = { [slots.Q] = 0.25, [slots.E] = 0.15, [slots.R] = 0.15 }
function Akali.CastQ(pos)
    if not OriUtils.CheckCastTimers(qCastTimers) then return false end

    return OriUtils.CastSpell(slots.Q, pos)
end

local wCastTimers = { [slots.W] = 0.25 }
function Akali.CastW(pos)
    if not OriUtils.CheckCastTimers(wCastTimers) then return false end

    return OriUtils.CastSpell(slots.W, pos)
end

local eCastTimers = { [slots.E] = 0.25, [slots.Q] = 0.15 }
function Akali.CastE(pos, isE2)
    if not OriUtils.CheckCastTimers(eCastTimers) then return false end

    if isE2 then
        return OriUtils.CastSpell(slots.E, Player)
    else
        return OriUtils.CastSpell(slots.E, pos)
    end
end

local rCastTimers = { [slots.R] = 0.25 }
function Akali.CastR(target_pos)
    if not OriUtils.CheckCastTimers(rCastTimers) then return false end

    return OriUtils.CastSpell(slots.R, target_pos)
end

function Akali.HasE2()
    return Player:GetSpell(slots.E).Name == "AkaliEb"
end

function Akali.HasR2()
    return Player:GetSpell(slots.R).Name == "AkaliRb"
end

local slotToDamageTable = {
    [slots.Q] = function(isPartTwo) return damages.Q end,
    [slots.E] = function(isPartTwo) if isPartTwo then return damages.E2 else return damages.E1 end end,
    [slots.R] = function(isPartTwo) if isPartTwo then return damages.R2 else return damages.R1 end end,
}

function Akali.GetPassiveDamage(target)
    local me = Player

    local passive = damages.Passive

    local rawDamage = passive.Base[min(18, me.Level)] + (passive.BonusAD * me.BonusAD) + (passive.TotalAP * me.TotalAP)

    return DmgLib.CalculateMagicalDamage(me, target, rawDamage)
end

function Akali.GetSpellDamage(target, slot, isPartTwo, simulatedHealth)
    local me = Player

    local rawDamage = 0
    local dmgType = nil

    local spellLevel = me:GetSpell(slot).Level

    local data = slotToDamageTable[slot]
    if data then
        data = data(isPartTwo)

        dmgType = data.Type
        rawDamage = data.Base[spellLevel]

        if data.BonusAD then
            rawDamage = rawDamage + (data.BonusAD * me.BonusAD)
        end

        if data.TotalAD then
            rawDamage = rawDamage + (data.TotalAD * me.TotalAD)
        end

        if data.TotalAP then
            rawDamage = rawDamage + (data.TotalAP * me.TotalAP)
        end

        if data.MissingHealth then
            rawDamage = rawDamage + data.MissingHealth(rawDamage, target, simulatedHealth)
        end

        if dmgType == dmgTypes.Physical then
            return DmgLib.CalculatePhysicalDamage(me, target, rawDamage)
        elseif dmgType == dmgTypes.Magical then
            return DmgLib.CalculateMagicalDamage(me, target, rawDamage)
        else
            return rawDamage
        end
    end

    return 0
end

---@param target AIHeroClient
---@param drawingMode boolean
function Akali.GetBestCombo(target, drawingMode)
    local result = {
        CanKill = false,
        Damage = 0,
        Mana = 0,
        SpellStatus = {
            Q = false,
            E1 = false,
            E2 = false,
            R1 = false,
            R2 = false
        }
    }

    local me = Player

    local isEReady = OriUtils.IsSpellReady(slots.E)
    local isRReady = OriUtils.IsSpellReady(slots.R)

    local QCondition = OriUtils.CanCastSpell(slots.Q, "combo.useQ") and (drawingMode or spells.Q:IsInRange(target))
    local E1Condition = isEReady and OriUtils.MGet("combo.useE1") and (drawingMode or spells.E1:IsInRange(target))
    local E2Condition = isEReady and OriUtils.MGet("combo.useE2")
    local R1Condition = isRReady and OriUtils.MGet("combo.useR1") and (drawingMode or spells.R1:IsInRange(target))
    local R2Condition = isRReady and OriUtils.MGet("combo.useR2") and (drawingMode or spells.R2:IsInRange(target))

    local fullHealth = target.Health + target.ShieldAll

    local hasE2 = Akali.HasE2()
    local hasR2 = Akali.HasR2()

    local ECondition = nil
    if hasE2 then
        ECondition = E2Condition
    else
        ECondition = E1Condition
    end

    local RCondition = nil
    if hasR2 then
        RCondition = R2Condition
    else
        RCondition = R1Condition
    end

    local check = {false, true}
    local dontCheck = {false}

    for _, QVal in ipairs(QCondition and check or dontCheck) do
        local tempDamage = 0
        local tempMana = 0
        local tempStatus = {
            Q = false,
            E1 = false,
            E2 = false,
            R1 = false,
            R2 = false
        }

        if QVal then
            tempDamage = tempDamage + Akali.GetSpellDamage(target, slots.Q)
            tempMana = tempMana + spells.Q:GetManaCost()
            tempStatus.Q = true
        end

        for __, EVal in ipairs(ECondition and check or dontCheck) do
            if EVal then
                if hasE2 then
                    tempDamage = tempDamage + Akali.GetSpellDamage(target, slots.E, true)
                    tempStatus.E2 = true
                else
                    tempDamage = tempDamage + Akali.GetSpellDamage(target, slots.E, false)
                    tempMana = tempMana + spells.E1:GetManaCost()
                    tempStatus.E1 = true

                    if E2Condition then
                        tempDamage = tempDamage + Akali.GetSpellDamage(target, slots.E, true)
                        tempStatus.E2 = true
                    end
                end
            end

            for ___, RVal in ipairs(RCondition and check or dontCheck) do
                if RVal then
                    if hasR2 then
                        local tempHealth = max(0, fullHealth - tempDamage)

                        tempDamage = tempDamage + Akali.GetSpellDamage(target, slots.R, true, tempHealth)
                        tempStatus.R2 = true
                    else
                        tempDamage = tempDamage + Akali.GetSpellDamage(target, slots.R, false)
                        tempStatus.R1 = true

                        if R2Condition then
                            local tempHealth = max(0, fullHealth - tempDamage)

                            tempDamage = tempDamage + Akali.GetSpellDamage(target, slots.R, true, tempHealth)
                            tempStatus.R2 = true
                        end
                    end
                end

                if tempMana <= me.Mana then
                    local bReplaceValues = false

                    local tempCanKill = tempDamage > fullHealth

                    if result.Damage == 0 then
                        if tempDamage > 0 then
                            bReplaceValues = true
                        end
                    else
                        if result.CanKill and tempCanKill then
                            if tempDamage < result.Damage then
                                bReplaceValues = true
                            end
                        elseif tempCanKill then
                            bReplaceValues = true
                        end
                    end

                    if bReplaceValues then
                        result.Damage = tempDamage
                        result.Mana = tempMana
                        result.SpellStatus = tempStatus
                        result.CanKill = tempCanKill
                    end
                end
            end
        end
    end

    return result
end

--[[
    function Akali.EnemyHasEDebuff()
        local enemyHeroes = ObjManager.Get("enemy", "heroes")

        for _, obj in pairs(enemyHeroes) do
            local hero = obj.AsHero
            
            if OriUtils.IsValidTarget(hero) then
                local buffs = hero.Buffs
                
                for buffName in pairs(buffs) do
                    if buffName == "akaliemis" then
                        return true
                    end
                end
            end
        end
        
        return false
    end
]]

function Akali.EnemyHasEDebuff()
    for _, hasBuff in pairs(Akali.MiscData.EnemyEDebuffs) do
        if hasBuff then
            return true
        end
    end

    return false
end

function Akali.GetHitchance(slot)
    local hc = 0.5

    if slot == slots.Q then
        hc = OriUtils.MGet("hc.Q") * 0.01
    elseif slot == slots.E then
        hc = OriUtils.MGet("hc.E1") * 0.01
    elseif slot == slots.R then
        hc = OriUtils.MGet("hc.R2") * 0.01
    end

    return hc
end

---@param initialPos Vector
---@param castPos Vector
function Akali.ExtraECheck(initialPos, castPos, targetHandle)
    local e1Width = spells.E1.Radius * 2
    local e1Speed = spells.E1.Speed
    local e1Delay = spells.E1.Delay

    local misStartPos = initialPos:Extended(castPos, -400)

    local heroCol = Collision.SearchHeroes(misStartPos, initialPos, e1Width, e1Speed, e1Delay, 1, "enemy", {[targetHandle] = true})
    if heroCol and heroCol.Result then
        return false
    end

    local minionCol = Collision.SearchMinions(misStartPos, initialPos, e1Width, e1Speed, e1Delay, 1, "enemy")
    if minionCol and minionCol.Result then
        return false
    end

    return true
end

function Akali.IsR2BuffExpiring()
    if Akali.MiscData.R2BuffExpireTime then
        local curTime = Game.GetTime()

        if curTime > Akali.MiscData.R2BuffExpireTime - 1 then
            return true
        end
    end

    return false
end

function fightModes.Killsteal(lagFree)
    local checkQ = OriUtils.CanCastSpell(slots.Q, "ks.useQ")

    local isDashing = OriUtils.IsDashing()

    local enemyHeroes = ObjManager.GetNearby("enemy", "heroes")
    for _, obj in ipairs(enemyHeroes) do
        local hero = obj.AsHero

        if OriUtils.IsValidTarget(hero) and not isDashing then 
            if checkQ and spells.Q:IsInRange(hero) then
                local ksHealth = spells.Q:GetKillstealHealth(hero)
                local qDmg = Akali.GetSpellDamage(hero, slots.Q)

                if qDmg > ksHealth then
                    local pred = spells.Q:GetPrediction(hero)

                    if pred and pred.HitChance > Akali.GetHitchance(slots.Q) then
                        if Akali.CastQ(pred.CastPosition) then
                            return true
                        end
                    end
                end
            end
        end
    end
end

function fightModes.ExtraModes(lagFree)
    local me = Player

    local forcedTarget = TS:GetForcedTarget()

    if (lagFree == 1 or lagFree == 2) and OriUtils.CanCastSpell(slots.R, "misc.forceR") then
        if Akali.HasR2() then
            local r2Range = spells.R2.Range

            local target = OriUtils.ChooseTarget(forcedTarget, {r2Range})
            if target and target:Distance(me) < r2Range then
                local pred = spells.R2:GetPrediction(target)

                if pred and pred.HitChanceEnum >= Enums.HitChance.Low then
                    if Akali.CastR(pred.CastPosition) then
                        return true
                    end
                end
            end
        else
            local r1Range = spells.R1.Range

            local target = OriUtils.ChooseTarget(forcedTarget, {r1Range})
            if target and target:Distance(me) < r1Range then
                if Akali.CastR(target) then
                    return true
                end
            end
        end
    end
end

function fightModes.Flee(lagFree)
    local me = Player

    if --[[lagFree == 1 and]] OriUtils.CanCastSpell(slots.E, "flee.useE") and not Akali.HasE2() then
        local myPos = me.ServerPos
        local mousePos = Renderer.GetMousePos()

        local castPos = myPos:Extended(mousePos, -200)

        if Akali.CastE(castPos, false) then
            return true
        end
    end
end

function fightModes.Combo(lagFree)
    local me = Player
    local myPos = me.ServerPos

    local forcedTarget = TS:GetForcedTarget()

    local hideInCombo = OriUtils.MGet("combo.smokePassive")
    local hasStealth = Akali.MiscData.HasSmokeStealth
    local smokePassive = hideInCombo and hasStealth

    local waitForPassive = OriUtils.MGet("combo.useQ.waitForPassive")
    local wfpCheck = waitForPassive and not Akali.MiscData.HasPassive or not waitForPassive

    local hasE2 = Akali.HasE2()
    local hasR2 = Akali.HasR2()

    local isDashing = OriUtils.IsDashing()

    local e2ChampionsOnly = OriUtils.MGet("combo.useE2.championHit")

    local enemyHasEDebuff = Akali.EnemyHasEDebuff()

    local enemies = ObjManager.GetNearby("enemy", "heroes")
    local enemiesAsHeroes = {}

    for _, obj in ipairs(enemies) do
        enemiesAsHeroes[#enemiesAsHeroes+1] = obj.AsHero
    end

    local sortedEnemies = TS:SortTargetsForMode(enemiesAsHeroes, "Lowest HP")
    
    --SmartKillCombo first
    for _, hero in ipairs(sortedEnemies) do
        local heroHealth = hero.Health + hero.ShieldAll

        if OriUtils.IsValidTarget(hero) and OriUtils.MGet("combo.useR.wl." .. hero.CharName, true) then
            local bestCombo = Akali.GetBestCombo(hero, false)

            if bestCombo.CanKill then
                if lagFree ~= 0 then 
                    if hasR2 then
                        if bestCombo.SpellStatus.R2 then
                            local killedByR2 = Akali.GetSpellDamage(hero, slots.R, true) > heroHealth

                            if killedByR2 then
                                local pred = spells.R2:GetPrediction(hero)

                                if pred and pred.HitChance >= Akali.GetHitchance(slots.R) then
                                    if Akali.CastR(pred.CastPosition) then
                                        return true
                                    end
                                end
                            end
                        end
                    else
                        if bestCombo.SpellStatus.R1 and not isDashing and not smokePassive then
                            if Akali.CastR(hero) then
                                return true
                            end
                        end
                    end
                end

                if lagFree == 2 and not isDashing and not smokePassive then
                    if bestCombo.SpellStatus.Q then
                        local pred = spells.Q:GetPrediction(hero)

                        if pred and pred.HitChance >= Akali.GetHitchance(slots.Q) then
                            if Akali.CastQ(pred.CastPosition) then
                                return true
                            end
                        end
                    end
                elseif lagFree == 3 and not isDashing and not smokePassive then
                    if hasE2 then
                        if bestCombo.SpellStatus.E2 then
                            if e2ChampionsOnly and enemyHasEDebuff or not e2ChampionsOnly then
                                if Akali.CastE(nil, true) then
                                    return true
                                end
                            end
                        end
                    else
                        if bestCombo.SpellStatus.E1 then
                            local pred = spells.E1:GetPrediction(hero)

                            if pred and pred.HitChance >= Akali.GetHitchance(slots.E) then
                                if Akali.ExtraECheck(myPos, pred.CastPosition, hero.Handle) then
                                    if Akali.CastE(pred.CastPosition, false) then
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

    --Normal combo second
    if lagFree ~= 0 and OriUtils.IsSpellReady(slots.R) then
        if hasR2 and OriUtils.MGet("combo.useR2") then
            local forceR2 = false

            if me.HealthPercent * 100 < OriUtils.MGet("combo.useR2.minHealth") then
                forceR2 = true
            end

            if Akali.IsR2BuffExpiring() then
                forceR2 = true
            end

            if forceR2 then
                local r2Range = spells.R2.Range

                local target = OriUtils.ChooseTarget(forcedTarget, {r2Range})
                if target and target:Distance(me) < r2Range then
                    local pred = spells.R2:GetPrediction(target)

                    if pred and pred.HitChanceEnum >= Enums.HitChance.Low then
                        if Akali.CastR(pred.CastPosition) then
                            return true
                        end
                    end
                end
            end
        end
    end

    if lagFree == 2 and OriUtils.CanCastSpell(slots.Q, "combo.useQ") and not isDashing and wfpCheck and not smokePassive then
        local qRange = spells.Q.Range

        local target = OriUtils.ChooseTarget(forcedTarget, {qRange})
        if target and target:Distance(me) < qRange then
            local pred = spells.Q:GetPrediction(target)

            if pred and pred.HitChance >= Akali.GetHitchance(slots.Q) then
                if Akali.CastQ(pred.CastPosition) then
                    return true
                end
            end
        end
    elseif lagFree == 3 and OriUtils.IsSpellReady(slots.E) and not isDashing and not smokePassive then
        if hasE2 then
            if OriUtils.MGet("combo.useE2") then
                if e2ChampionsOnly and enemyHasEDebuff or not e2ChampionsOnly then
                    if Akali.CastE(nil, true) then
                        return true
                    end
                end
            end
        else
            if OriUtils.MGet("combo.useE1") then
                local e1Range = spells.E1.Range

                local target = OriUtils.ChooseTarget(forcedTarget, {e1Range})
                if target and target:Distance(me) < e1Range then
                    local pred = spells.E1:GetPrediction(target)

                    if pred and pred.HitChance >= Akali.GetHitchance(slots.E) then
                        if Akali.CastE(pred.CastPosition, false) then
                            return true
                        end
                    end
                end
            end
        end
    elseif lagFree == 4 and OriUtils.CanCastSpell(slots.W, "combo.useW") and not isDashing then
        local dir = OriUtils.MGet("combo.useW.dir")

        if me.Mana < OriUtils.MGet("combo.useW.minEnergy") then
            local towards = Renderer.GetMousePos()

            local wRange = spells.W.Range
            local target = OriUtils.ChooseTarget(nil, {wRange})

            if dir == 1 and target then
                towards = target.ServerPos
            end

            if Akali.CastW(towards) then
                return true
            end
        end
    end
end

function fightModes.Harass(lagFree)
    local me = Player

    if me.ManaPercent * 100 < OriUtils.MGet("harass.minMana") then
        return false
    end

    local hideInHarass = OriUtils.MGet("harass.smokePassive")
    local hasStealth = Akali.MiscData.HasSmokeStealth
    local smokePassive = hideInHarass and hasStealth

    local forcedTarget = TS:GetForcedTarget()

    if lagFree == 1 and OriUtils.CanCastSpell(slots.Q, "harass.useQ") and not smokePassive then 
        local qRange = spells.Q.Range
        
        local target = OriUtils.ChooseTarget(forcedTarget, {qRange})
        if target and target:Distance(me) < qRange then
            local pred = spells.Q:GetPrediction(target)

            if pred and pred.HitChance >= Akali.GetHitchance(slots.Q) then
                if Akali.CastQ(pred.CastPosition) then
                    return true
                end
            end
        end
    end
end

function fightModes.Waveclear(lagFree)
    local me = Player

    if me.ManaPercent * 100 < OriUtils.MGet("clear.minMana") then
        return false
    end

    if not (OriUtils.MGet("clear.enemyAround") or not TS:GetTarget(1000)) then
        return false
    end

    if lagFree == 1 and OriUtils.CanCastSpell(slots.Q, "clear.useQ") then
        local qMinions = OriUtils.GetEnemyAndJungleMinions(spells.Q.Range)
        local qMinionsPos = {}

        for _, minion in ipairs(qMinions) do
            qMinionsPos[#qMinionsPos+1] = minion.ServerPos
        end

        if #qMinionsPos > 0 then
            local bestPos, hits = Geometry.BestCoveringCone(qMinionsPos, me.ServerPos, spells.Q.AngleRad)

            if bestPos and hits >= OriUtils.MGet("clear.useQ.minHit") then
                if Akali.CastQ(bestPos) then
                    return true
                end
            end
        end
    end
end

function fightModes.Lasthit(lagFree)
    local me = Player

    if me.ManaPercent * 100 < OriUtils.MGet("lh.minMana") then
        return false
    end

    if lagFree == 1 and OriUtils.CanCastSpell(slots.Q, "lh.useQ") then
        local qMinions = OriUtils.GetEnemyAndJungleMinions(spells.Q.Range)
        local qMinionsPos = {}

        for _, minion in ipairs(qMinions) do
            local ksHealth = spells.Q:GetHealthPred(minion)
            local qDmg = Akali.GetSpellDamage(minion, slots.Q)

            if qDmg > ksHealth then
                qMinionsPos[#qMinionsPos+1] = minion.ServerPos
            end
        end

        if #qMinionsPos > 0 then
            local bestPos, hits = Geometry.BestCoveringCone(qMinionsPos, me.ServerPos, spells.Q.AngleRad)

            if bestPos and hits >= OriUtils.MGet("lh.useQ.minHit") then
                if Akali.CastQ(bestPos) then
                    return true
                end
            end
        end
    end
end

function events.OnTick(lagFree)
    OriUtils.CheckFlashSlot()

    if not OriUtils.ShouldRunLogic() then
        return
    end

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

local drawData = {
    {slot = slots.Q, id = "Q", displayText = "Q [Five Point Strike]", range = spells.Q.Range},
    {slot = slots.W, id = "W", displayText = "W [Twilight Shroud]", range = spells.W.Range},
    {slot = slots.E, id = "E", displayText = "E1/E2 [Shuriken Flip]", range = function() if Akali.HasE2() then return 0 else return spells.E1.Range end end},
    {slot = slots.R, id = "R", displayText = "R1/R2 [Perfect Execution]", range = function() if Akali.HasR2() then return spells.R2.Range else return spells.R1.Range end end}
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

    if OriUtils.MGet("draw.killCombo") then
        local enemyHeroes = ObjManager.Get("enemy", "heroes")

        for _, obj in pairs(enemyHeroes) do
            local hero = obj.AsHero

            if OriUtils.IsValidTarget(hero) then
                local bestCombo = Akali.GetBestCombo(hero, true)

                if bestCombo.CanKill then
                    local orderedCombo = {}

                    if bestCombo.SpellStatus.Q then
                        orderedCombo[#orderedCombo+1] = "Q"
                    end

                    if bestCombo.SpellStatus.E1 then
                        orderedCombo[#orderedCombo+1] = "E1"
                    end

                    if bestCombo.SpellStatus.E2 then
                        orderedCombo[#orderedCombo+1] = "E2"
                    end

                    if bestCombo.SpellStatus.R1 then
                        orderedCombo[#orderedCombo+1] = "R1"
                    end

                    if bestCombo.SpellStatus.R2 then
                        orderedCombo[#orderedCombo+1] = "R2"
                    end

                    local killStr = nil

                    for i, spellStr in ipairs(orderedCombo) do
                        if i == 1 then
                            killStr = spellStr
                        else
                            killStr = killStr .. ", " .. spellStr
                        end
                    end

                    local targetPos = hero.Position:ToScreen()

                    Renderer.DrawText(targetPos, Vector(0, 0), killStr, 0xFFFF00FF)
                end
            end
        end
    end
end

---@param target AIHeroClient
---@param dmgList table
function events.OnDrawDamage(target, dmgList)
    if not OriUtils.MGet("draw.comboDamage") then
        return
    end

    local me = Player

    local damageToDeal = 0

    local isEReady = OriUtils.IsSpellReady(slots.E)
    local isRReady = OriUtils.IsSpellReady(slots.R)

    local useElectrocute = OriUtils.Perks.Electrocute.HasBuff
    local useQ = OriUtils.CanCastSpell(slots.Q, "combo.useQ")
    local useE1 = isEReady and OriUtils.MGet("combo.useE1")
    local useE2 = isEReady and OriUtils.MGet("combo.useE2")
    local useR1 = isRReady and OriUtils.MGet("combo.useR1")
    local useR2 = isRReady and OriUtils.MGet("combo.useR2")

    damageToDeal = damageToDeal + DmgLib.GetAutoAttackDamage(me, target, true)

    if useElectrocute then
        damageToDeal = damageToDeal + OriUtils.GetElectrocuteDamage(target)
    end

    if useQ then
        damageToDeal = damageToDeal + Akali.GetSpellDamage(target, slots.Q)
    end

    if useE1 then
        damageToDeal = damageToDeal + Akali.GetSpellDamage(target, slots.E, false)
    end

    if useE2 then
        damageToDeal = damageToDeal + Akali.GetSpellDamage(target, slots.E, true)
    end

    if useR1 then
        damageToDeal = damageToDeal + Akali.GetSpellDamage(target, slots.R, false)
    end

    if useR2 then
        local fullHealth = target.Health + target.ShieldAll
        local tempHealth = max(0, fullHealth - damageToDeal)

        damageToDeal = damageToDeal + Akali.GetSpellDamage(target, slots.R, true, tempHealth)
    end

    insert(dmgList, damageToDeal)
end

---@param obj GameObject
---@param buffInst BuffInst
function events.OnBuffGain(obj, buffInst)
    if obj and obj.IsMe and buffInst then
        --INFO("Akali gained buff: " .. buffInst.Name)
    end

    if obj and buffInst then
        if obj.IsMe then 
            if buffInst.Name == "akaliwstealth" then
                Akali.MiscData.HasSmokeStealth = true
            end

            if buffInst.Name == "AkaliR" then
                Akali.MiscData.R2BuffExpireTime = buffInst.EndTime
            end

            if buffInst.Name == "AkaliPWeapon" then
                Akali.MiscData.HasPassive = true
            end

            if buffInst.Name == OriUtils.Perks.Electrocute.BuffName then
                OriUtils.Perks.Electrocute.HasBuff = true
            end
        elseif obj.IsHero and obj.IsEnemy then
            if buffInst.Name == "AkaliEMis" then
                Akali.MiscData.EnemyEDebuffs[obj.Handle] = true
            end
        end
    end
end

---@param obj GameObject
---@param buffInst BuffInst
function events.OnBuffLost(obj, buffInst)
    if obj and obj.IsMe and buffInst then
        --INFO("Akali lost buff: " .. buffInst.Name)
    end

    if obj and buffInst then
        if obj.IsMe then 
            if buffInst.Name == "akaliwstealth" then
                Akali.MiscData.HasSmokeStealth = false
            end

            if buffInst.Name == "AkaliR" then
                Akali.MiscData.R2BuffExpireTime = nil
            end

            if buffInst.Name == "AkaliPWeapon" then
                Akali.MiscData.HasPassive = false
            end

            if buffInst.Name == OriUtils.Perks.Electrocute.BuffName then
                OriUtils.Perks.Electrocute.HasBuff = true
            end
        elseif obj.IsHero and obj.IsEnemy then
            if buffInst.Name == "AkaliEMis" then
                Akali.MiscData.EnemyEDebuffs[obj.Handle] = false
            end
        end
    end
end

local preAttackData = {
    ["Combo"] = function() return OriUtils.MGet("combo.smokePassive") end,
    ["Harass"] = function() return OriUtils.MGet("harass.smokePassive") end
}
function events.OnPreAttack(args)
    local data = preAttackData[Orbwalker.GetMode()]

    if data and data() and Akali.MiscData.HasSmokeStealth then
        args.Process = false
    end
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

function Akali.RegisterEvents()
    for eventName, eventId in pairs(Enums.Events) do
        if events[eventName] then
            EventManager.RegisterCallback(eventId, events[eventName])
        end
    end
end

function Akali.InitMenu()
    local function QHeader()
        Menu.Separator(drawData[1].displayText, SCRIPT_COLOR, true)
    end

    local function WHeader()
        Menu.Separator(drawData[2].displayText, SCRIPT_COLOR, true)
    end

    local function EHeader()
        Menu.Separator(drawData[3].displayText, SCRIPT_COLOR, true)
    end

    local function RHeader()
        Menu.Separator(drawData[4].displayText, SCRIPT_COLOR, true)
    end

    local function AkaliMenu()
        Menu.NewTree("Akali.comboMenu", "Combo Settings", function()
            Menu.Checkbox("Akali.combo.smokePassive", "Don't AA or Cast (except R2) while stealthed", false)
            
            Menu.ColumnLayout("Akali.comboMenu.QW", "Akali.comboMenu.QW", 2, true, function()
                QHeader()
                
                Menu.Checkbox("Akali.combo.useQ", "Enable Q", true)
                Menu.Indent(function()
                    Menu.Checkbox("Akali.combo.useQ.waitForPassive", "Use Passive before casting", false) 
                end)

                Menu.NextColumn()

                WHeader()

                Menu.Checkbox("Akali.combo.useW", "Enable W", true)
                Menu.Indent(function()
                    Menu.Slider("Akali.combo.useW.minEnergy", "If my energy is below X", 120, 0, 200, 1)
                    Menu.Dropdown("Akali.combo.useW.dir", "Use towards", 1, {"Mouse", "Target"})
                end)
            end)

            Menu.ColumnLayout("Akali.comboMenu.ER", "Akali.comboMenu.ER", 2, true, function()
                EHeader()

                Menu.Checkbox("Akali.combo.useE1", "Enable E1", true)
                --[[
                Menu.Indent(function()
                    Menu.Slider("Akali.combo.useE1.minDist", "Min dist before use", 700, 100, spells.E1.Range, 10)
                end)
                --]]

                Menu.Checkbox("Akali.combo.useE2", "Enable E2", true)
                Menu.Indent(function()
                    Menu.Checkbox("Akali.combo.useE2.championHit", "Only if it will hit a champion", true)
                end)

                Menu.NextColumn()

                RHeader()

                Menu.Checkbox("Akali.combo.useR1", "Enable R1 if Killable with Combo", true)

                Menu.Checkbox("Akali.combo.useR2", "Enable R2", true)
                Menu.Indent(function()
                    Menu.Checkbox("Akali.combo.useR2.comboKillable", "If Killable with Combo", true)
                    Menu.Checkbox("Akali.combo.useR2.expire", "Force if it's about to expire", true)
                    Menu.Slider("Akali.combo.useR2.minHealth", "Force if my health is below X %", 15, 0, 100, 1)
                end)

                Menu.NewTree("Akali.comboMenu.R.wl", "R1/R2 Killable with Combo whitelist", function()
                    Menu.ColoredText("NOTE: R2 Expire option ignores this whitelist", 0xFFFF00FF, false)
                    local enemyHeroes = ObjManager.Get("enemy", "heroes")

                    local addedWL = {}

                    for _, obj in pairs(enemyHeroes) do
                        local hero = obj.AsHero
                        local heroName = hero.CharName

                        if hero and not addedWL[heroName] then
                            Menu.Checkbox("Akali.combo.useR.wl." .. heroName, "Use R1/R2 on " .. heroName, true)

                            addedWL[heroName] = true
                        end
                    end
                end)
            end)
        end)

        Menu.NewTree("Akali.drawMenu", "Draw Settings", function()
            Menu.Separator("Draw Settings")
            OriUtils.AddDrawMenu(drawData)

            Menu.Checkbox("Akali.draw.killCombo", "Print kill combo on enemies", false)
        end)

        Menu.NewTree("Akali.harassMenu", "Harass Settings", function()
            Menu.Checkbox("Akali.harass.smokePassive", "Don't AA or Cast while stealthed", false)

            QHeader()

            Menu.Checkbox("Akali.harass.useQ", "Enable Q", true)

            Menu.Slider("Akali.harass.minMana", "Harass Minimum Energy %", 25, 0, 100, 1)
        end)

        Menu.NewTree("Akali.clearMenu", "Clear Settings", function()
            QHeader()

            Menu.Checkbox("Akali.clear.useQ", "Enable Q", true)
            Menu.Indent(function()
                Menu.Slider("Akali.clear.useQ.minHit", "If it will hit X minions", 1, 1, 5, 1)
            end)

            Menu.Checkbox("Akali.clear.enemyAround", "Clear even if enemy is around", true)
            Menu.Slider("Akali.clear.minMana", "Clear minimum Energy %", 25, 0, 100, 1)
        end)

        Menu.NewTree("Akali.lhMenu", "Last hit Settings", function()
            QHeader()

            Menu.Checkbox("Akali.lh.useQ", "Enable Q", true)
            Menu.Indent(function()
                Menu.Slider("Akali.lh.useQ.minHit", "If it will kill X minions", 2, 1, 5, 1)
            end)

            Menu.Slider("Akali.lh.minMana", "Last hit minimum Energy %", 25, 0, 100, 1)
        end)

        Menu.NewTree("Akali.fleeMenu", "Flee Settings", function()
            EHeader()

            Menu.Checkbox("Akali.flee.useE", "Enable E1 to mouse", true)
        end)

        Menu.NewTree("Akali.miscMenu", "Misc Settings", function()
            Menu.Separator("Misc Settings")
            Menu.Keybind("Akali.misc.forceR", "Force R1/R2", string.byte("T"))
        end)

        Menu.NewTree("Akali.ksMenu", "Killsteal Settings", function()
            Menu.Separator("Killsteal Settings")
            Menu.Checkbox("Akali.ks.useQ", "Enable Q to KS", true)
        end)

        Menu.NewTree("Akali.hcMenu", "Hitchance Settings", function()
            Menu.Separator("Hitchance Settings")
            Menu.Slider("Akali.hc.Q", "Q Hitchance", 15, 0, 100, 1)
            Menu.Slider("Akali.hc.E1", "E1 Hitchance", 15, 0, 100, 1)
            Menu.Slider("Akali.hc.R2", "R2 Hitchance", 15, 0, 100, 1)
        end)

        Menu.Separator("Author: Orietto")
    end

    Menu.RegisterMenu(SCRIPT_NAME, SCRIPT_NAME, AkaliMenu)
end

function OnLoad()
    Akali.InitMenu()

    Akali.RegisterEvents()

    OriUtils.InitElectrocute()

    return true
end
