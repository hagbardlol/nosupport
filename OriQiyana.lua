if Player.CharName ~= "Qiyana" then return end

local SCRIPT_NAME = "Ori Qiyana"
local SCRIPT_VERSION_UPDATER = "2.0.5"
local SCRIPT_VERSION = SCRIPT_VERSION_UPDATER
local SCRIPT_LAST_UPDATED = "08/18/2022"
local SCRIPT_AUTHOR = "Orietto"
local SCRIPT_IS_BETA = false

if SCRIPT_IS_BETA then
    SCRIPT_VERSION = SCRIPT_VERSION .. " Beta"
else
    SCRIPT_VERSION = SCRIPT_VERSION .. " Release"
end

local SCRIPT_COLOR = 0xB52479FF

module(SCRIPT_NAME, package.seeall, log.setup)
clean.module(SCRIPT_NAME, clean.seeall, log.setup)

local insert, sort = table.insert, table.sort
local huge, pow, min, max, pi, ceil, floor, sin, cos = math.huge, math.pow, math.min, math.max, math.pi, math.ceil, math.floor, math.sin, math.cos

local SDK = _G.CoreEx

SDK.AutoUpdate("https://raw.githubusercontent.com/hagbardlol/nosupport/main/OriQiyana.lua", SCRIPT_VERSION_UPDATER)

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
        Base = function(heroLevel)
            return 11 + 4 * min(heroLevel, 18)
        end,
        BonusAD = 0.55,
        TotalAP = 0.3,
        Type = dmgTypes.Physical
    },
    Q = {
        Base = {60, 85, 110, 135, 160},
        BonusAD = 0.9,
        RockExtra = {
            MaxEnemyHPPercent = 0.5,
            Base = {36, 51, 66, 81, 96},
            BonusAD = 0.54
        },
        Type = dmgTypes.Physical
    },
    W = {
        Base = {8, 22, 36, 50, 64},
        BonusAD = 0.1,
        TotalAP = 0.45,
        Type = dmgTypes.Magical
    },
    E = {
        Base = {60, 90, 120, 150, 180},
        BonusAD = 0.7,
        Type = dmgTypes.Physical
    },
    R = {
        Base = {100, 200, 300},
        BonusAD = 1.7,
        TargetMaxHealth = 0.1,
        Type = dmgTypes.Physical
    }
}

local spells = {
    Q1 = Spell.Skillshot({
        Slot = slots.Q,
        Delay = 0.25,
        Speed = huge,
        Range = 400,
        Radius = 120 / 2,
        Type = "Linear"
    }),
    Q2 = Spell.Skillshot({
        Slot = slots.Q,
        Delay = 0.25,
        Speed = 1600,
        Range = 850,
        RangeSecondHalf = 350, --300,
        Radius = 165 / 2,
        Type = "Linear",
        Collisions = {WindWall = true}
    }),
    W = {
        Slot = slots.W,
        Range = 1050,
    },
    E = Spell.Targeted({
        Slot = slots.E,
        Delay = 0,
        Range = 640
    }),
    R = Spell.Skillshot({
        Slot = slots.R,
        Delay = 0.25,
        Speed = 2000,
        Range = 920, --950
        Radius = 280 / 2,
        Type = "Linear",
        PushRange = 300,
        Collisions = {Wall = true, WindWall = true}
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


local Qiyana = {}

Qiyana.MiscData = {}

Qiyana.MiscData.HasGrassStealth = false

Qiyana.MiscData.LastElement = nil

Qiyana.MiscData.WUniformData = {}
Qiyana.MiscData.WUniformData.PosRadius = spells.W.Range / 7 / 2
Qiyana.MiscData.WUniformData.AngleRad = (90 * pi) / 180

local qCastTimers = { [slots.Q] = 0.25 }
function Qiyana.CastQ(pos)
    if not OriUtils.CheckCastTimers(qCastTimers) then return false end

    if Orbwalker.IsWindingUp() then return false end

    return OriUtils.CastSpell(slots.Q, pos)
end

local wCastTimers = { [slots.W] = 0.25 }
function Qiyana.CastW(pos)
    if not OriUtils.CheckCastTimers(wCastTimers) then return false end

    if Orbwalker.IsWindingUp() then return false end

    return OriUtils.CastSpell(slots.W, pos)
end

local eCastTimers = { [slots.E] = 0.25 }
function Qiyana.CastE(target)
    if not OriUtils.CheckCastTimers(eCastTimers) then return false end

    return OriUtils.CastSpell(slots.E, target)
end

local rCastTimers = { [slots.R] = 0.25 }
function Qiyana.CastR(pos)
    if not OriUtils.CheckCastTimers(rCastTimers) then return false end

    return OriUtils.CastSpell(slots.R, pos)
end

function Qiyana.HasQ2()
    return Player:GetSpell(slots.Q).Name ~= "QiyanaQ"
end

function Qiyana.PosAfterE(target)
    return Player.ServerPos:Extended(target, spells.E.Range)
end

---@param target AIBaseClient|nil
---@return AIBaseClient|nil
function Qiyana.GetDashableObj(target, isFlee)
    local eRange = spells.E.Range
    local me = Player

    ---@type Vector
    local pos = target and target.ServerPos or Renderer.GetMousePos()

    if isFlee then
        pos = me.ServerPos:Extended(pos, 1000)
    end
    
    local distToMe = me:Distance(pos)

    local possibleDash = {}

    local function IsEndPosCloser(unit)
        local posAfterE = Qiyana.PosAfterE(unit)

        return posAfterE:Distance(pos) < distToMe
    end

    local enemyMinions = OriUtils.GetEnemyAndJungleMinions(eRange)
    for _, minion in ipairs(enemyMinions) do
        if IsEndPosCloser(minion) then
            possibleDash[#possibleDash+1] = minion
        end
    end

    local enemyHeroes = ObjManager.GetNearby("enemy", "heroes")
    for _, obj in ipairs(enemyHeroes) do
        local hero = obj.AsHero

        if OriUtils.IsValidTarget(hero, eRange) and IsEndPosCloser(hero) then
            possibleDash[#possibleDash+1] = hero
        end
    end

    if #possibleDash == 0 then
        return nil
    end

    local bestTarget = OriUtils.GetFirstElementSort(possibleDash, function(elemA, elemB)
        return Qiyana.PosAfterE(elemA):Distance(pos) < Qiyana.PosAfterE(elemB):Distance(pos)
    end)

    return bestTarget
end

---@param from Vector
---@param to Vector
---@param maxCheck number
---@return Vector[]
function Qiyana.GetWUniformPositions(from, to, maxCheck)
    maxCheck = maxCheck or 150

    local result = {}

    local posChecked, radiusIndex, posRadius = 0, 0, Qiyana.MiscData.WUniformData.PosRadius

    local cone = Geometry.Cone(from, to, Qiyana.MiscData.WUniformData.AngleRad, spells.W.Range + 10)

    while posChecked < maxCheck do
        radiusIndex = radiusIndex + 1

        local curRadius = radiusIndex * 2 * posRadius
        local curCircleChecks = ceil(pi * curRadius / posRadius)
        for i = 1, curCircleChecks-1 do
            posChecked = posChecked + 1
            local cRadians = (2 * pi / (curCircleChecks - 1)) * i

            local possiblePoint = Vector(from.x + curRadius * cos(cRadians), from.y, from.z + curRadius * sin(cRadians))

            if cone:Contains(possiblePoint) then
                result[#result + 1] = possiblePoint
            end
        end
    end

    return result
end

local prioTable = {
    [0] = "River",
    [1] = "Brush",
    [2] = "Terrain"
}
function Qiyana.GetBestWPos(isFlee, isHarassAlwaysBrush)
    local me = Player

    local wRange = spells.W.Range

    local forcedTarget = TS:GetForcedTarget()

    local target = OriUtils.ChooseTarget(forcedTarget, {wRange})

    local prioRock = false
    local prio1 = prioTable[OriUtils.MGet("combo.useW.prio1")]
    local prio2 = prioTable[OriUtils.MGet("combo.useW.prio2")]
    local prio3 = prioTable[OriUtils.MGet("combo.useW.prio3")]

    if isHarassAlwaysBrush then
        prio1 = "Brush"
        prio2 = "River"
        prio3 = "Terrain"
    end

    local different = OriUtils.MGet("combo.useW.different")
    local rockOverride = OriUtils.MGet("combo.useW.override")

    local dir = OriUtils.MGet("combo.useW.dir")

    local towards = Renderer.GetMousePos()

    if not isFlee and target and target:Distance(me) < wRange then
        if dir == 1 then 
            towards = target.ServerPos
        end

        if rockOverride and target.HealthPercent <= 0.5 then
            prioRock = true
        end
    end

    local points = Qiyana.GetWUniformPositions(me.ServerPos, towards)

    local waterPoint, grassPoint, rockPoint = nil, nil, nil

    local lastElement = Qiyana.MiscData.LastElement

    for i = #points, 1, -1 do
        local curPoint = points[i]
        local pointType = OriUtils.GetPointType(curPoint)

        --[[
            if isFlee and pointType ~= "None" then
                return curPoint
            end
        --]]

        if prioRock and pointType == "Terrain" then
            return curPoint
        end

        if pointType == "Terrain" and not rockPoint then
            rockPoint = curPoint
        elseif pointType == "Brush" and not grassPoint then
            grassPoint = curPoint
        elseif pointType == "River" and not waterPoint then
            waterPoint = curPoint
        end
    end

    local function ElementOrder(pointType)
        if pointType ~= nil then 
            if prio1 == pointType then
                return 1
            elseif prio2 == pointType then
                return 2
            elseif prio3 == pointType then
                return 3
            end
        end

        return 0
    end

    local possibleOptions = {
        [1] = "Invalid",
        [2] = "Invalid",
        [3] = "Invalid"
    }

    if waterPoint then
        possibleOptions[ElementOrder(prioTable[0])] = {Type = prioTable[0], Point = waterPoint}
    end
    
    if grassPoint then
        possibleOptions[ElementOrder(prioTable[1])] = {Type = prioTable[1], Point = grassPoint}
    end

    if rockPoint then
        possibleOptions[ElementOrder(prioTable[2])] = {Type = prioTable[2], Point = rockPoint}
    end

    local fallback1, fallback2, fallback3 = nil, nil, nil

    for i, elementData in ipairs(possibleOptions) do
        if type(elementData) == "table" then
            if different and lastElement and not isHarassAlwaysBrush then
                if i == 1 then
                    fallback1 = elementData
                elseif i == 2 then
                    fallback2 = elementData
                elseif i == 3 then
                    fallback3 = elementData
                end
            else
                return elementData.Point
            end
        end
    end

    if different and lastElement and not isHarassAlwaysBrush then
        if fallback1 and lastElement ~= fallback1.Type then
            return fallback1.Point
        elseif fallback2 and lastElement ~= fallback2.Type then
            return fallback2.Point
        elseif fallback3 and lastElement ~= fallback3.Type then
            return fallback3.Point
        elseif fallback1 then
            return fallback1.Point
        elseif fallback2 then
            return fallback2.Point
        elseif fallback3 then
            return fallback3.Point
        end
    end

    return nil
end

---@param target AIBaseClient
---@param pred PredictionResult
function Qiyana.CanQ2Hit(target, pred)    
    if pred and pred.CastPosition then
        local predPos = pred.CastPosition
        local myPos = Player.ServerPos
    
        local spell = spells.Q2
        local spellWidth = spell.Radius * 2
        local spellSpeed = spell.Speed
        local spellDelay = spell.Delay

        local targetHandle = target.Handle

        local colUnits = {}

        local heroCol = Collision.SearchHeroes(myPos, predPos, spellWidth, spellSpeed, spellDelay, 6, "enemy", {[targetHandle] = true})

        if heroCol and heroCol.Result then
            for _, unit in ipairs(heroCol.Objects) do
                colUnits[#colUnits+1] = unit.AsHero
            end
        end

        local minionCol = Collision.SearchMinions(myPos, predPos, spellWidth, spellSpeed, spellDelay, 8, "enemy", {[targetHandle] = true})

        if minionCol and minionCol.Result then
            for _, unit in ipairs(minionCol.Objects) do
                colUnits[#colUnits+1] = unit.AsMinion
            end
        end

        if #colUnits == 0 then
            return true
        end

        ---@param elemA AIBaseClient
        ---@param elemB AIBaseClient
        ---@type AIBaseClient
        local closest = OriUtils.GetFirstElementSort(colUnits, function(elemA, elemB)
            return elemA:Distance(myPos) < elemB:Distance(myPos)
        end)

        if closest then
            local dist = closest:EdgeDistance(pred.TargetPosition)

            if dist < spell.RangeSecondHalf then
                return true
            end
        end
    end

    return false
end

---@param target AIHeroClient
---@param pred PredictionResult
function Qiyana.WillRStun(target, pred, maxCheck)
    maxCheck = maxCheck or 30

    local rRange = spells.R.Range

    local myPos = Player.ServerPos

    local targetPos = pred.TargetPosition
    local boundingRadius = target.BoundingRadius

    local targetEndPos = targetPos:Extended(myPos, -(spells.R.PushRange + boundingRadius + 100))

    local interval = targetPos:Distance(targetEndPos) / maxCheck

    for i = 0, maxCheck do
        local checkPos = targetPos:Extended(targetEndPos, interval * i)

        local pointType = OriUtils.GetPointType(checkPos)

        if pointType == "Terrain" then
            if checkPos:Distance(myPos) < rRange then
                return true
            end
        elseif pointType == "Brush" or pointType == "River" then
            if targetEndPos:Distance(myPos) < rRange then
                return true
            end
        end
    end

    return false
end

function Qiyana.GetHitchance(slot, isQ2)
    local hc = 0.5

    if slot == slots.Q then
        if isQ2 then
            hc = OriUtils.MGet("hc.Q2") * 0.01
        else
            hc = OriUtils.MGet("hc.Q1") * 0.01
        end
    elseif slot == slots.R then
        hc = OriUtils.MGet("hc.R") * 0.01
    end

    return hc
end

---@param target AIBaseClient
function Qiyana.TargetHasPassiveBuff(target)
    local buffs = target.Buffs

    for buffName, buff in pairs(buffs) do
        if buffName == "qiyanapassivecd_base" or buffName == "qiyanapassivecd_grass" or buffName == "qiyanapassivecd_rock" or buffName == "qiyanapassivecd_water" then
            return true
        end
    end

    return false
end

---@param target AIHeroClient
function Qiyana.RComboDamage(target)
    local damageToDeal = 0

    local useElectrocute = OriUtils.Perks.Electrocute.HasBuff
    local useProwler = OriUtils.MGet("combo.useProwler") and OriUtils.GetProwlerSlot() or target:GetBuff("6693amp")
    local useQ = OriUtils.CanCastSpell(slots.Q, "combo.useQ")
    local useW = OriUtils.CanCastSpell(slots.W, "combo.useW")
    local useE = OriUtils.CanCastSpell(slots.E, "combo.useE")

    if not Qiyana.TargetHasPassiveBuff(target) then
        damageToDeal = damageToDeal + Qiyana.GetPassiveDamage(target)
    end

    if useElectrocute then
        damageToDeal = damageToDeal + OriUtils.GetElectrocuteDamage(target)
    end

    if useQ then
        local qDmg = Qiyana.GetSpellDamage(target, slots.Q, false)

        if useW then
            qDmg = qDmg * 2
        end

        damageToDeal = damageToDeal + qDmg
    end

    if Qiyana.HasQ2() then
        damageToDeal = damageToDeal + Qiyana.GetSpellDamage(target, slots.W)
    end

    if useE then
        damageToDeal = damageToDeal + Qiyana.GetSpellDamage(target, slots.E)
    end

    damageToDeal = damageToDeal + Qiyana.GetSpellDamage(target, slots.R)

    if useProwler then
        damageToDeal = damageToDeal + (damageToDeal * 0.15)
    end

    return damageToDeal
end

local slotToDamageTable = {
    [slots.Q] = damages.Q,
    [slots.W] = damages.W,
    [slots.E] = damages.E,
    [slots.R] = damages.R
}
function Qiyana.GetPassiveDamage(target)
    local me = Player

    local passive = damages.Passive

    local rawDamage = passive.Base(me.Level) + (passive.BonusAD * me.BonusAD) + (passive.TotalAP * me.TotalAP)

    return DmgLib.CalculatePhysicalDamage(me, target, rawDamage)
end

function Qiyana.GetSpellDamage(target, slot, isPostCollision)
    local me = Player

    local rawDamage = 0
    local dmgType = nil

    local spellLevel = me:GetSpell(slot).Level

    local data = slotToDamageTable[slot]

    if data then
        dmgType = data.Type
        rawDamage = data.Base[spellLevel]

        if data.BonusAD then
            rawDamage = rawDamage + (data.BonusAD * me.BonusAD)
        end

        if data.TotalAP then
            rawDamage = rawDamage + (data.TotalAP * me.TotalAP)
        end

        if data.TargetMaxHealth then
            rawDamage = rawDamage + (data.TargetMaxHealth * target.MaxHealth)
        end

        if data.RockExtra then
            if target.HealthPercent <= data.RockExtra.MaxEnemyHPPercent then
                rawDamage = rawDamage + (data.RockExtra.Base[spellLevel] + (data.RockExtra.BonusAD * me.BonusAD))
            end
        end

        if slot == slots.Q and isPostCollision then
            rawDamage = rawDamage * 0.75
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

---@param minion AIMinionClient
function Qiyana.Q2MinionHits(minion)
    local me = Player

    local myPos = me.ServerPos
    local endPos = myPos:Extended(minion, spells.Q2.Range)

    local spell = spells.Q2
    local secondHalfRange = spell.RangeSecondHalf

    local col = Collision.SearchMinions(myPos, endPos, spell.Radius * 2, spell.Speed, spell.Delay, 8, "enemy")

    local nHits = 0

    if col and col.Result then
        ---@param elemA GameObject
        ---@param elemB GameObject
        ---@type GameObject
        local closest = OriUtils.GetFirstElementSort(col.Objects, function(elemA, elemB)
            return elemA:Distance(me) < elemB:Distance(me)
        end)

        if closest then
            nHits = nHits + 1

            local closestHandle = closest.Handle

            for _, obj in ipairs(col.Objects) do
                if obj.Handle ~= closestHandle and closest:Distance(obj) < secondHalfRange then
                    nHits = nHits + 1
                end
            end
        end
    end

    return nHits
end

function Qiyana.HandleComboW()
    local function ExtraQCheck()
        if OriUtils.IsSpellReady(slots.Q) then
            return false
        end

        if Player:GetSpell(slots.Q).Level < 1 then
            return false
        end

        return true
    end

    local function ShouldForceW()
        local enabled = OriUtils.MGet("combo.useW.forceW")

        return enabled and not Qiyana.HasQ2() and OriUtils.IsSpellReady(slots.Q) and not TS:GetTarget(spells.Q1.Range)
    end

    local mode = OriUtils.MGet("combo.useW.mode")

    if (mode == 0 and ExtraQCheck() or mode == 1) or ShouldForceW() then
        local bestWPos = Qiyana.GetBestWPos()

        if bestWPos then
            if Qiyana.CastW(bestWPos) then
                return true
            end
        end
    end
end

local onNewQLastName = "Default"
local spellNameToElement = {
    ["QiyanaQ_Water"] = "River",
    ["QiyanaQ_Grass"] = "Brush",
    ["QiyanaQ_Rock"] = "Terrain"
}
function Qiyana.HandleOnNewQ()
    local qName = Player:GetSpell(slots.Q).Name

    if qName ~= "QiyanaQ" and qName ~= onNewQLastName then
        onNewQLastName = qName

        EventManager.FireEvent("Qiyana.OnNewQ", spellNameToElement[qName])
    end
end

function fightModes.Killsteal(lagFree)
    local me = Player

    local enemyHeroes = ObjManager.GetNearby("enemy", "heroes")

    for _, obj in ipairs(enemyHeroes) do
        local hero = obj.AsHero

        if OriUtils.IsValidTarget(hero) then
            local heroName = hero.CharName
            local dist = hero:Distance(me)
    
            if (lagFree == 1 or lagFree == 2) and OriUtils.CanCastSpell(slots.R, "ks.useR") and not OriUtils.IsDashing() then
                local comboOnlyCheck = Orbwalker.GetMode() == "Combo" or not OriUtils.MGet("ks.useR.comboOnly")

                if comboOnlyCheck and OriUtils.MGet("ks.useR.wl." .. heroName, true) and dist < spells.R.Range then
                    local rMode = OriUtils.MGet("ks.useR.mode")
                    local ksHealth = spells.R:GetKillstealHealth(hero)
                    local pred = spells.R:GetPrediction(hero)
    
                    if pred and pred.HitChance >= Qiyana.GetHitchance(slots.R) then
                        if Qiyana.WillRStun(hero, pred) then
                            if rMode == 0 then
                                if ksHealth > 0 and ksHealth < Qiyana.GetSpellDamage(hero, slots.R) then
                                    if Qiyana.CastR(pred.CastPosition) then
                                        return true
                                    end
                                end
                            elseif rMode == 1 then
                                if ksHealth > 0 and ksHealth < Qiyana.RComboDamage(hero) then
                                    if Qiyana.CastR(pred.CastPosition) then
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
end

function fightModes.ExtraModes(lagFree)
    local me = Player
    local myPos = me.ServerPos

    local forcedTarget = TS:GetForcedTarget()

    if lagFree == 1 and OriUtils.CanCastSpell(slots.R, "misc.forceR") and not OriUtils.IsDashing() then
        local rRange = spells.R.Range

        local target = OriUtils.ChooseTarget(forcedTarget, {rRange})

        if target and target:Distance(me) < rRange then
            local pred = spells.R:GetPrediction(target)

            if pred and pred.HitChance >= Qiyana.GetHitchance(slots.R) then
                if Qiyana.WillRStun(target, pred) then
                    if Qiyana.CastR(pred.CastPosition) then
                        return true
                    end
                end
            end
        end
    end
end

function fightModes.Flee(lagFree)
    if not OriUtils.IsDashing() then
        if lagFree == 1 and OriUtils.CanCastSpell(slots.E, "flee.useE") then
            local dashableObj = Qiyana.GetDashableObj(nil, true)

            if dashableObj then
                if Qiyana.CastE(dashableObj) then
                    return true
                end
            end
        elseif lagFree == 2 and OriUtils.CanCastSpell(slots.W, "flee.useW") then
            local bestWPos = Qiyana.GetBestWPos(true)

            if bestWPos then
                if Qiyana.CastW(bestWPos) then
                    return true
                end
            end
        end
    end
end

function fightModes.Combo(lagFree)
    local forcedTarget = TS:GetForcedTarget()

    local me = Player

    local prowlerSlot = OriUtils.GetProwlerSlot()
    local prowlerRange = OriUtils.Items.Prowler.Range

    local hideInCombo = OriUtils.MGet("combo.brushPassive")
    local hasStealth = Qiyana.MiscData.HasGrassStealth

    local function BrushPassiveCond()
        return hideInCombo and hasStealth
    end

    if lagFree == 1 and prowlerSlot and OriUtils.MGet("combo.useProwler") and not BrushPassiveCond() then
        local target = OriUtils.ChooseTarget(forcedTarget, {prowlerRange})

        if target then
            local dist = target:Distance(me)

            if dist < prowlerRange then
                if OriUtils.CastSpell(prowlerSlot, target) then
                    return true
                end
            end
        end
    elseif lagFree == 2 and OriUtils.CanCastSpell(slots.E, "combo.useE") and not BrushPassiveCond() then
        local eRange = spells.E.Range

        local target = OriUtils.ChooseTarget(forcedTarget, {eRange, eRange + prowlerRange - 200})

        if target then
            local dist = target:Distance(me)

            if dist < eRange then
                if dist > OriUtils.MGet("combo.useE.minDist") then
                    if Qiyana.CastE(target) then
                        return true
                    end
                end
            else
                if prowlerSlot and OriUtils.MGet("combo.useE.beforeProwler") then
                    local dashableObj = Qiyana.GetDashableObj(target)

                    if dashableObj then
                        if Qiyana.CastE(dashableObj) then
                            return true
                        end
                    end
                end
            end
        end
    elseif lagFree == 3 and OriUtils.CanCastSpell(slots.W, "combo.useW") then
        if Qiyana.HandleComboW() then
            return true
        end
    elseif lagFree == 4 and OriUtils.CanCastSpell(slots.Q, "combo.useQ") and not BrushPassiveCond() then
        local hasQ2 = Qiyana.HasQ2()

        ---@type Skillshot
        local spell = hasQ2 and spells.Q2 or spells.Q1

        local target = OriUtils.ChooseTarget(forcedTarget, {spell.Range})

        if target then
            local mode = OriUtils.MGet("combo.useQ.mode")
            
            local function ShouldForceQ()
                local fallback = OriUtils.MGet("combo.useQ.mode.fallback")
                local isInAARange = Orbwalker.GetTrueAutoAttackRange(me, target) > target:Distance(me)

                return fallback and not isInAARange and not OriUtils.IsSpellReady(slots.E)
            end

            if mode == false and ShouldForceQ() or mode == true then
                local pred = spell:GetPrediction(target)

                if pred then 
                    if hasQ2 and Qiyana.CanQ2Hit(target, pred) or not hasQ2 then
                        if pred.HitChance >= Qiyana.GetHitchance(slots.Q, hasQ2) then
                            if Qiyana.CastQ(pred.CastPosition) then
                                return true
                            end
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


    local hideInHarass = OriUtils.MGet("harass.brushPassive")
    local hasStealth = Qiyana.MiscData.HasGrassStealth

    local function BrushPassiveCond()
        return hideInHarass and hasStealth
    end

    if lagFree == 1 and OriUtils.CanCastSpell(slots.E, "harass.useE") and not BrushPassiveCond() then
        local eRange = spells.E.Range

        local target = OriUtils.ChooseTarget(forcedTarget, {eRange})

        if target then
            local dist = target:Distance(me)

            if dist < eRange then
                if Qiyana.CastE(target) then
                    return true
                end
            end
        end
    elseif lagFree == 2 and OriUtils.CanCastSpell(slots.W, "harass.useW") then
        local wMode = OriUtils.MGet("harass.useW.mode")

        if wMode == 0 then
            if Qiyana.HandleComboW() then
                return true
            end
        elseif wMode == 1 then
            local function ExtraQCheck()
                if OriUtils.IsSpellReady(slots.Q) then
                    return false
                end
        
                if Player:GetSpell(slots.Q).Level < 1 then
                    return false
                end
        
                return true
            end

            if ExtraQCheck() then 
                local bestWPos = Qiyana.GetBestWPos(false, true)
                
                if bestWPos then
                    if Qiyana.CastW(bestWPos) then
                        return true
                    end
                end
            end
        end
    elseif lagFree == 3 and OriUtils.CanCastSpell(slots.Q, "harass.useQ") and not BrushPassiveCond() then
        local hasQ2 = Qiyana.HasQ2()

        ---@type Skillshot
        local spell = hasQ2 and spells.Q2 or spells.Q1

        local target = OriUtils.ChooseTarget(forcedTarget, {spell.Range})

        if target then
            local pred = spell:GetPrediction(target)

            if pred then 
                if hasQ2 and Qiyana.CanQ2Hit(target, pred) or not hasQ2 then
                    if pred.HitChance >= Qiyana.GetHitchance(slots.Q, hasQ2) then
                        if Qiyana.CastQ(pred.CastPosition) then
                            return true
                        end
                    end
                end
            end
        end
    end
end

function fightModes.Waveclear(lagFree)
    local me = Player

    local manaPercent = me.ManaPercent * 100

    if manaPercent <= OriUtils.MGet("clear.minMana") then
        return false
    end

    if not (OriUtils.MGet("clear.enemyAround") or not TS:GetTarget(1000)) then
        return false
    end

    local qMinHit = OriUtils.MGet("clear.useQ.minHit")
    local useEUnderTurret = OriUtils.MGet("clear.useE.turret")
    
    local hasQ2 = Qiyana.HasQ2()
    
    local q1Minions = {}
    
    local minions = OriUtils.GetEnemyAndJungleMinions(spells.Q2.Range)
    
    for _, minion in ipairs(minions) do
        local dist = minion:Distance(me)

        if lagFree == 1 and OriUtils.CanCastSpell(slots.E, "clear.useE") then
            if dist < spells.E.Range then
                if useEUnderTurret or not OriUtils.IsPosUnderTurret(Qiyana.PosAfterE(minion)) then 
                    local minionKillable = minion.Health < Qiyana.GetSpellDamage(minion, slots.E)
                    local outsideAA = Orbwalker.GetTrueAutoAttackRange(me, minion) < dist
                    
                    if minionKillable and outsideAA then
                        if Qiyana.CastE(minion) then
                            return true
                        end
                    end
                end
            end
        elseif lagFree == 2 and OriUtils.CanCastSpell(slots.W, "clear.useW") then
            if Qiyana.HandleComboW() then
                return true
            end
        elseif lagFree == 3 and OriUtils.CanCastSpell(slots.Q, "clear.useQ") then
            ---@type Skillshot
            local spell = hasQ2 and spells.Q2 or spells.Q1

            if dist < spell.Range then
                if hasQ2 then
                    local hits = Qiyana.Q2MinionHits(minion)

                    if not OriUtils.IsDashing() and hits >= qMinHit then
                        if Qiyana.CastQ(minion.ServerPos) then
                            return true
                        end
                    end
                else
                    q1Minions[#q1Minions+1] = minion.ServerPos
                end
            end
        end
    end

    if #q1Minions == 0 then
        return false
    end

    local bestPos, hits = Geometry.BestCoveringRectangle(q1Minions, me.ServerPos, spells.Q1.Radius * 2)

    if bestPos and hits >= qMinHit then
        if Qiyana.CastQ(bestPos) then
            return true
        end
    end
end

function fightModes.Lasthit(lagFree)
    local me = Player

    local manaPercent = me.ManaPercent * 100

    if manaPercent <= OriUtils.MGet("lh.minMana") then
        return false
    end

    if not (OriUtils.MGet("lh.enemyAround") or not TS:GetTarget(1000)) then
        return false
    end

    local qMinHit = OriUtils.MGet("lh.useQ.minHit")
    local useEUnderTurret = OriUtils.MGet("lh.useE.turret")

    local hasQ2 = Qiyana.HasQ2()

    local q1Minions = {}

    local minions = OriUtils.GetEnemyAndJungleMinions(spells.E.Range)

    for _, minion in ipairs(minions) do
        local dist = minion:Distance(me)
        local minionHealth = minion.Health

        if lagFree == 1 and OriUtils.CanCastSpell(slots.E, "lh.useE") then
            if useEUnderTurret or not OriUtils.IsPosUnderTurret(Qiyana.PosAfterE(minion)) then
                local minionKillable = minionHealth < Qiyana.GetSpellDamage(minion, slots.E)
                local outsideAA = Orbwalker.GetTrueAutoAttackRange(me, minion) < dist

                if minionKillable and outsideAA then
                    if Qiyana.CastE(minion) then
                        return true
                    end
                end
            end
        elseif lagFree == 2 and OriUtils.CanCastSpell(slots.Q, "lh.useQ") then
            if not hasQ2 then
                if dist < spells.Q1.Range then
                    if minionHealth < Qiyana.GetSpellDamage(minion, slots.Q, true) then
                        q1Minions[#q1Minions+1] = minion.ServerPos
                    end
                end
            end
        end
    end

    if #q1Minions == 0 then
        return false
    end

    local bestPos, hits = Geometry.BestCoveringRectangle(q1Minions, me.ServerPos, spells.Q1.Radius * 2)

    if bestPos and hits >= qMinHit then
        if Qiyana.CastQ(bestPos) then
            return true
        end
    end
end

function events.OnTick(lagFree)
    OriUtils.CheckFlashSlot()

    Qiyana.HandleOnNewQ()

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
    {slot = slots.Q, id = "Q", displayText = "Q1/Q2 [Edge of Ixtal/Elemental Wrath]", range = function() if Qiyana.HasQ2() then return spells.Q2.Range else return spells.Q1.Range end end},
    {slot = slots.W, id = "W", displayText = "W [Terrashape]", range = spells.W.Range},
    {slot = slots.E, id = "E", displayText = "E [Audacity]", range = spells.E.Range},
    {slot = slots.R, id = "R", displayText = "R [Supreme Display of Talent]", range = spells.R.Range}
}

local pointDrawData = {
    ["Terrain"] = {str = "T", color = 0xF5900CFF},
    ["River"] = {str = "R", color = 0x08C3C9FF},
    ["Brush"] = {str = "B", color = 0x0AAD18FF},
    ["None"] = {str = "N", color = 0x9D00FFFF}
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

    if OriUtils.MGet("draw.QState") then
        local useAlways = OriUtils.MGet("combo.useQ.mode")

        local text = useAlways and "Q: Always" or "Q: After AA"
        local color = useAlways and 0x00FF00FF or 0xFF0000FF

        --local screenPos = myPos:ToScreen()
        --screenPos.y = screenPos.y + 60

        Renderer.DrawTextOnPlayer(text, color)
    end

    if OriUtils.MGet("draw.WDebug") then
        local points = Qiyana.GetWUniformPositions(myPos, Renderer.GetMousePos())
        local posRadius = Qiyana.MiscData.WUniformData.PosRadius

        for _, point in ipairs(points) do
            local pointType = OriUtils.GetPointType(point)
            local data = pointDrawData[pointType]

            if data then
                Renderer.DrawCircle3D(point, posRadius, 25, 2, data.color)
                Renderer.DrawText(point:ToScreen(), Vector(0, 0), data.str, data.color)
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

    local damageToDeal = 0

    local useElectrocute = OriUtils.Perks.Electrocute.HasBuff
    local useProwler = OriUtils.MGet("combo.useProwler") and OriUtils.GetProwlerSlot() or target:GetBuff("6693amp")
    local useQ = OriUtils.CanCastSpell(slots.Q, "combo.useQ")
    local useW = OriUtils.CanCastSpell(slots.W, "combo.useW")
    local useE = OriUtils.CanCastSpell(slots.E, "combo.useE")
    local useR = OriUtils.CanCastSpell(slots.R, "ks.useR") and OriUtils.MGet("ks.useR.wl." .. target.CharName, true)

    if not Qiyana.TargetHasPassiveBuff(target) then
        damageToDeal = damageToDeal + Qiyana.GetPassiveDamage(target)
    end

    if useElectrocute then
        damageToDeal = damageToDeal + OriUtils.GetElectrocuteDamage(target)
    end

    if useQ then
        local qDmg = Qiyana.GetSpellDamage(target, slots.Q)

        if useW then
            qDmg = qDmg * 2
        end

        damageToDeal = damageToDeal + qDmg
    end

    if Qiyana.HasQ2() then
        damageToDeal = damageToDeal + Qiyana.GetSpellDamage(target, slots.W)
    end

    if useE then
        damageToDeal = damageToDeal + Qiyana.GetSpellDamage(target, slots.E)
    end

    if useR then
        damageToDeal = damageToDeal + Qiyana.GetSpellDamage(target, slots.R)
    end

    if useProwler then
        damageToDeal = damageToDeal + (damageToDeal * 0.15)
    end

    insert(dmgList, damageToDeal)
end

---@param obj GameObject
---@param buffInst BuffInst
function events.OnBuffGain(obj, buffInst)
    if obj and obj.IsMe and buffInst then
        --INFO("Qiyana gained buff: " .. buffInst.Name)
    end

    if obj and obj.IsMe and buffInst then
        if buffInst.Name == "qiyanaq_grass_stealth_buff" then
            Qiyana.MiscData.HasGrassStealth = true
        end

        if buffInst.Name == OriUtils.Perks.Electrocute.BuffName then
            OriUtils.Perks.Electrocute.HasBuff = true
        end
    end
end

---@param obj GameObject
---@param buffInst BuffInst
function events.OnBuffLost(obj, buffInst)
    if obj and obj.IsMe and buffInst then
        --INFO("Qiyana lost buff: " .. buffInst.Name)
    end

    if obj and obj.IsMe and buffInst then
        if buffInst.Name == "qiyanaq_grass_stealth_buff" then
            Qiyana.MiscData.HasGrassStealth = false
        end

        if buffInst.Name == OriUtils.Perks.Electrocute.BuffName then
            OriUtils.Perks.Electrocute.HasBuff = false
        end
    end
end

local preAttackData = {
    ["Combo"] = function() return OriUtils.MGet("combo.brushPassive") end,
    ["Harass"] = function() return OriUtils.MGet("harass.brushPassive") end
}
function events.OnPreAttack(args)
    local data = preAttackData[Orbwalker.GetMode()]

    if data and data() and Qiyana.MiscData.HasGrassStealth then
        args.Process = false
    end
end

---@param target AttackableUnit
function events.OnPostAttack(target)
    local me = Player

    local orbMode = Orbwalker.GetMode()
    
    if orbMode == "Combo" and OriUtils.CanCastSpell(slots.Q, "combo.useQ") then
        if OriUtils.MGet("combo.useQ.mode") == false then
            local hasQ2 = Qiyana.HasQ2()
            
            ---@type Skillshot
            local spell = hasQ2 and spells.Q2 or spells.Q1

            local forcedTarget = TS:GetForcedTarget()
            
            local target = OriUtils.ChooseTarget(forcedTarget, {spell.Range})

            if target and target:Distance(me) < spell.Range then
                local pred = spell:GetPrediction(target)

                if pred then
                    if hasQ2 and Qiyana.CanQ2Hit(target, pred) or not hasQ2 then
                        if pred.HitChanceEnum >= Enums.HitChance.Low then
                            if Qiyana.CastQ(pred.CastPosition) then
                                return
                            end
                        end
                    end
                end
            end
        end
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

---@param newQType string
function events.OnNewQ(newQType)
    --INFO("OnNewQ event called with arg: " .. newQType)
    Qiyana.MiscData.LastElement = newQType
end

function Qiyana.RegisterEvents()
    for eventName, eventId in pairs(Enums.Events) do
        if events[eventName] then
            EventManager.RegisterCallback(eventId, events[eventName])
        end
    end

    EventManager.RegisterEvent("Qiyana.OnNewQ")
    EventManager.RegisterCallback("Qiyana.OnNewQ", events.OnNewQ)
end

function Qiyana.InitMenu()
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

    local function QiyanaMenu()
        Menu.NewTree("Qiyana.comboMenu", "Combo Settings", function()
            Menu.Checkbox("Qiyana.combo.useProwler", "Use prowler items in combo", true)
            Menu.Checkbox("Qiyana.combo.brushPassive", "Don't AA or cast Q/E while stealthed", false)

            Menu.ColumnLayout("Qiyana.comboMenu.QW", "Qiyana.comboMenu.QW", 2, true, function()
                QHeader()

                Menu.Checkbox("Qiyana.combo.useQ", "Enable Q", true)
                Menu.Indent(function()
                    Menu.Keybind("Qiyana.combo.useQ.mode", "Toggle Q: After AA/Always", string.byte("Z"), true, false, true)
                    Menu.Indent(function()
                        Menu.Checkbox("Qiyana.combo.useQ.mode.fallback", "Always use Q if target is outside AA range\nand E is not ready", true)
                    end)
                end)

                Menu.NextColumn()

                WHeader()

                Menu.Checkbox("Qiyana.combo.useW", "Enable W", true)
                Menu.Indent(function()
                    Menu.Dropdown("Qiyana.combo.useW.mode", "Mode", 0, {"To reset Q", "Always"})
                    if OriUtils.MGet("combo.useW.mode") == 0 then 
                        Menu.Indent(function()
                            --Menu.Checkbox("Qiyana.combo.useW.mode.waitQ", "Don't cast W if Q is ready in 1.25 seconds", false)
                            Menu.Checkbox("Qiyana.combo.useW.forceW", "Force W if Q1 is ready but target\nis outside range", false)
                        end)
                    end
                    Menu.Dropdown("Qiyana.combo.useW.dir", "Cast towards", 0, {"Mouse", "Target"})
                    Menu.NewTree("Qiyana.comboMenu.W.priority", "Element Priority", function()
                        Menu.Dropdown("Qiyana.combo.useW.prio1", "1st Priority", 0, {"River", "Brush", "Terrain"})
                        Menu.Dropdown("Qiyana.combo.useW.prio2", "2nd Priority", 1, {"River", "Brush", "Terrain"})
                        Menu.Dropdown("Qiyana.combo.useW.prio3", "3rd Priority", 2, {"River", "Brush", "Terrain"})
                        Menu.Checkbox("Qiyana.combo.useW.different", "Always try to pick a different element", true)
                        Menu.Checkbox("Qiyana.combo.useW.override", "Force Terrain if target HP% < 50", true)
                    end)
                end)
            end)

            Menu.ColumnLayout("Qiyana.comboMenu.ER", "Qiyana.comboMenu.ER", 2, true, function()
                EHeader()

                Menu.Checkbox("Qiyana.combo.useE", "Enable E", true)
                Menu.Indent(function()
                    Menu.Slider("Qiyana.combo.useE.minDist", "Min dist to dash", 400, 0, spells.E.Range, 1)
                    --Menu.Checkbox("Qiyana.combo.useE.prio", "Prio E before Q if target is static or not facing you", false)
                    Menu.Checkbox("Qiyana.combo.useE.beforeProwler", "Gapclose with E if Prowler is ready", true)
                end)

                Menu.NextColumn()

                --RHeader()
            end)
        end)

        Menu.NewTree("Qiyana.drawMenu", "Draw Settings", function()
            Menu.Separator("Draw Settings")
            OriUtils.AddDrawMenu(drawData)

            Menu.Checkbox("Qiyana.draw.QState", "Draw Toggle Q State", true)

            Menu.Checkbox("Qiyana.draw.WDebug", "Draw W Analysis", false)
        end)

        Menu.NewTree("Qiyana.harassMenu", "Harass Settings", function()
            Menu.Checkbox("Qiyana.harass.brushPassive", "Don't AA or cast Q/E while stealthed", true)

            QHeader()

            Menu.Checkbox("Qiyana.harass.useQ", "Enable Q", true)

            WHeader()

            Menu.Checkbox("Qiyana.harass.useW", "Enable W", true)
            Menu.Indent(function()
                Menu.Dropdown("Qiyana.harass.useW.mode", "Mode", 0, {"Combo Settings", "Always try to reset to Brush"})
            end)

            EHeader()

            Menu.Checkbox("Qiyana.harass.useE", "Enable E", false)

            Menu.Slider("Qiyana.harass.minMana", "Harass minimum mana %", 25, 0, 100, 1)
        end)

        Menu.NewTree("Qiyana.clearMenu", "Clear Settings", function()
            QHeader()

            Menu.Checkbox("Qiyana.clear.useQ", "Enable Q", true)
            Menu.Indent(function()
                Menu.Slider("Qiyana.clear.useQ.minHit", "If it will hit X minions", 1, 1, 5, 1)
            end)

            WHeader()

            Menu.Checkbox("Qiyana.clear.useW", "Enable W (Combo Settings)", false)

            EHeader()

            Menu.Checkbox("Qiyana.clear.useE", "Enable E (Last hit minions outside AA range)", false)
            Menu.Indent(function()
                Menu.Checkbox("Qiyana.clear.useE.turret", "Allow under turret", false)
            end)

            Menu.Checkbox("Qiyana.clear.enemyAround", "Clear even if enemy is around", false)
            Menu.Slider("Qiyana.clear.minMana", "Clear minimum mana %", 25, 0, 100, 1)
        end)

        Menu.NewTree("Qiyana.lasthitMenu", "Last hit Settings", function()
            QHeader()

            Menu.Checkbox("Qiyana.lh.useQ", "Enable Q1", true)
            Menu.Indent(function()
                Menu.Slider("Qiyana.lh.useQ.minHit", "If it will kill X minions", 2, 1, 5, 1)
            end)

            EHeader()

            Menu.Checkbox("Qiyana.lh.useE", "Enable E (If minion is outside AA range", true)
            Menu.Indent(function()
                Menu.Checkbox("Qiyana.lh.useE.turret", "Allow under turret", false)
            end)

            Menu.Checkbox("Qiyana.lh.enemyAround", "Last hit even if enemy is around", false)
            Menu.Slider("Qiyana.lh.minMana", "Last hit minimum mana %", 25, 0, 100, 1)
        end)

        Menu.NewTree("Qiyana.fleeMenu", "Flee Menu", function()
            WHeader()

            Menu.Checkbox("Qiyana.flee.useW", "Enable W", false)

            EHeader()

            Menu.Checkbox("Qiyana.flee.useE", "Enable E", true)
        end)

        Menu.NewTree("Qiyana.ksMenu", "Killsteal Settings", function()
            RHeader()

            Menu.Checkbox("Qiyana.ks.useR", "Enable R", true)
            Menu.Indent(function()
                Menu.Checkbox("Qiyana.ks.useR.comboOnly", "Only during combo mode", false)
                Menu.Dropdown("Qiyana.ks.useR.mode", "Mode", 0, {"Killable with just R", "Killable with combo"})
                Menu.NewTree("Qiyana.ksMenu.R.whitelist", "KS R Whitelist", function()
                    local enemyHeroes = ObjManager.Get("enemy", "heroes")

                    local addedWL = {}

                    for _, obj in pairs(enemyHeroes) do
                        local hero = obj.AsHero
                        local heroName = hero.CharName

                        if hero and not addedWL[heroName] then
                            Menu.Checkbox("Qiyana.ks.useR.wl." .. heroName, "KS R " .. heroName, true)

                            addedWL[heroName] = true
                        end
                    end
                end)
            end)
        end)

        Menu.NewTree("Qiyana.miscMenu", "Misc Settings", function()
            RHeader()

            Menu.Keybind("Qiyana.misc.forceR", "Force R to stun", string.byte("T"))
        end)

        Menu.NewTree("Qiyana.hcMenu", "Hitchance Settings", function()
            Menu.Separator("Hitchance Settings")
            Menu.Slider("Qiyana.hc.Q1", "Q1 Hitchance", 15, 0, 100, 1)
            Menu.Slider("Qiyana.hc.Q2", "Q2 Hitchance", 15, 0, 100, 1)
            Menu.Slider("Qiyana.hc.R", "R Hitchance", 35, 0, 100, 1)
        end)

        Menu.Separator("Author: Orietto")
    end

    Menu.RegisterMenu(SCRIPT_NAME, SCRIPT_NAME, QiyanaMenu)
end

function OnLoad()
    OriUtils.LoadRiverPolygons()

    Qiyana.InitMenu()

    Qiyana.RegisterEvents()

    OriUtils.InitElectrocute()

    return true
end
