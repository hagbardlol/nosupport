if Player.CharName ~= "Azir" then return end

local SCRIPT_NAME = "Ori Azir"
local SCRIPT_VERSION_UPDATER = "1.1.2"
local SCRIPT_VERSION = SCRIPT_VERSION_UPDATER
local SCRIPT_LAST_UPDATED = "11/26/2021"
local SCRIPT_AUTHOR = "Orietto"
local SCRIPT_IS_BETA = false

if SCRIPT_IS_BETA then
    SCRIPT_VERSION = SCRIPT_VERSION .. " Beta"
else
    SCRIPT_VERSION = SCRIPT_VERSION .. " Release"
end

local SCRIPT_COLOR = 0xD4C820FF

module(SCRIPT_NAME, package.seeall, log.setup)
clean.module(SCRIPT_NAME, clean.seeall, log.setup)

local insert, sort = table.insert, table.sort
local huge, pow, min, max, floor, ceil = math.huge, math.pow, math.min, math.max, math.floor, math.ceil
local format = string.format

local SDK = _G.CoreEx

SDK.AutoUpdate("https://github.com/hagbardlol/nosupport/raw/main/OriAzir.lua", SCRIPT_VERSION_UPDATER)

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
local HealthPred = Libs.HealthPred
local TS = Libs.TargetSelector()

local Profiler = Libs.Profiler

local slots = {
    Q = Enums.SpellSlots.Q,
    W = Enums.SpellSlots.W,
    E = Enums.SpellSlots.E,
    R = Enums.SpellSlots.R
}

local slotToString = {
    [slots.Q] = "Q",
    [slots.W] = "W",
    [slots.E] = "E",
    [slots.R] = "R"
}

local dmgTypes = {
    Physical = Enums.DamageTypes.Physical,
    Magical = Enums.DamageTypes.Magical,
    True = Enums.DamageTypes.True,
    Mixed = Enums.DamageTypes.Mixed
}

local damages = {
    Q = {
        Base = {70, 90, 110, 130, 150},
        TotalAP = 0.3,
        Type = dmgTypes.Magical
    },
    W = {
        HeroLevel = {50, 52, 54, 56, 58, 60, 62, 65, 70, 75, 80, 90, 100, 110, 120, 130, 140, 150},
        TotalAP = 0.6,
        Type = dmgTypes.Magical
    },
    E = {
        Base = {60, 90, 120, 150, 180},
        TotalAP = 0.4,
        Type = dmgTypes.Magical
    },
    R = {
        Base = {175, 325, 475},
        TotalAP = 0.6,
        Type = dmgTypes.Magical
    }
}

local spells = {
    Q = Spell.Skillshot({
        Slot = slots.Q,
        Range = 740,
        Delay = 0,
        Radius = 140,
        Speed = 1600,
        Type = "Linear"
    }),
    W = Spell.Skillshot({
        Slot = slots.W,
        Range = 560,
        SoldierRange = 300 --320
    }),
    E = Spell.Skillshot({
        Slot = slots.E,
        Range = 1100,
        Speed = 1700
    }),
    R = Spell.Skillshot({
        Slot = slots.R,
        Range = 350,
        BackRange = 275, --300
        FrontRange = 400,
        Delay = 0.25,
        Speed = 1000,
        Radius = 600 / 2,
        Type = "Linear"
    }),
    RBetterHitchance = Spell.Skillshot({
        Slot = slots.R,
        Range = 350,
        BackRange = 220,
        FrontRange = 350,
        Delay = 0.25,
        Speed = 1000,
        Radius = 400 / 2,
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

OriUtils.MiscData.CircleRangeHelpers = {}

OriUtils.SpellData = {}

OriUtils.SpellData.TargetedProjectiles = {
    ["Akshan"] = {
        {slot = slots.R, default = true, blockOnlyOnMissile = true, missileNames = {"AkshanRMissile"}}
    },
    ["Anivia"] = {
        {slot = slots.E}
    },
    ["Annie"] = {
        {slot = slots.Q}
    },
    ["Brand"] = {
        {slot = slots.R, default = true, missileNames = {"BrandR", "BrandRMissile"}}
    },
    ["Caitlyn"] = {
        {slot = slots.R, default = true, blockOnlyOnMissile = true, missileNames = {"CaitlynAceintheHoleMissile"}}
    },
    ["Cassiopeia"] = {
        {slot = slots.E}
    },
    ["Elise"] = {
        {slot = slots.Q, name = "EliseHumanQ"}
    },
    --["FiddleSticks"] = {
    --    {slot = slots.Q} -- Missile can't be destroyed (and also missile does not cause fear. End of cast does)
    --},
    ["Gangplank"] = {
        {slot = slots.Q}
    },
    ["Janna"] = {
        {slot = slots.W}
    },
    ["Jhin"] = {
        {slot = slots.Q}
    },
    ["Kassadin"] = {
        {slot = slots.Q}
    },
    ["Katarina"] = {
        {slot = slots.Q}
    },
    ["Kindred"] = {
        {slot = slots.E}
    },
    ["Leblanc"] = {
        {slot = slots.Q},
        {slot = slots.R, name = "LeblancRQ"}
    },
    ["Malphite"] = {
        {slot = slots.Q}
    },
    ["MissFortune"] = {
        {slot = slots.Q}
    },
    ["Nami"] = {
        {slot = slots.W}
    },
    ["Ryze"] = {
        {slot = slots.E}
    },
    --["Sejuani"] = {
    --    {slot = slots.E} --Requires testing
    --},
    ["Shaco"] = {
        {slot = slots.E}
    },
    ["Syndra"] = {
        {slot = slots.R, default = true, missileNames = {"SyndraRSpell"}}
    },
    ["Teemo"] = {
        {slot = slots.Q}
    },
    ["Tristana"] = {
        {slot = slots.E}
    },
    ["TwistedFate"] = {
        {slot = slots.W, name = "Gold Card", default = true, blockOnlyOnMissile = true, missileNames = {"GoldCardAttack"}},
        {slot = slots.W, name = "Blue Card", blockOnlyOnMissile = true, missileNames = {"BlueCardAttack"}},
        {slot = slots.W, name = "Red Card", blockOnlyOnMissile = true, missileNames = {"RedCardAttack"}}
    },
    ["Vayne"] = {
        {slot = slots.E}
    },
    ["Veigar"] = {
        {slot = slots.R, default = true, missileNames = {"VeigarR"}}
    },
    ["Viktor"] = {
        {slot = slots.Q}
    }
}

OriUtils.SpellData.TargetedProjectilesIngame = {}

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

function OriUtils.GetFirstElementSortPairs(tbl, compareFunc)
    local first = nil

    for i, v in pairs(tbl) do
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

        Menu.Checkbox(cacheName .. ".draw." .. id, "Draw " .. displayText .. " range", false)
        Menu.Indent(function()
            Menu.ColorPicker(cacheName .. ".draw." .. id .. ".color", "Color", SCRIPT_COLOR)
        end)
    end

    Menu.Separator()

    Menu.Checkbox(cacheName .. ".draw." .. "comboDamage", "Draw combo damage on healthbar", false)
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

function OriUtils.LoadTargetedSpells()
    local database = OriUtils.SpellData.TargetedProjectiles
    local spellsInMatch = OriUtils.SpellData.TargetedProjectilesIngame

    local added = {}

    local enemyHeroes = ObjManager.Get("enemy", "heroes")
    for _, obj in pairs(enemyHeroes) do
        local hero = obj.AsHero
        local heroName = hero.CharName

        if not added[heroName] then
            local heroData = database[heroName]
            if heroData then
                for __, entry in ipairs(heroData) do
                    insert(spellsInMatch, {
                        champion = heroName,
                        slot = entry.slot,
                        name = entry.name,
                        default = entry.default,
                        blockOnlyOnMissile = entry.blockOnlyOnMissile,
                        missileNames = entry.missileNames
                    })
                end
            end

            added[heroName] = true
        end
    end
end

---@param champName string
---@param slot number
---@param spellName string|nil
function OriUtils.FindIngameTargetedSpell(champName, slot, spellName)
    local ingameTargetedSpells = OriUtils.SpellData.TargetedProjectilesIngame

    for _, spell in ipairs(ingameTargetedSpells) do
        if spell.champion == champName and spell.slot == slot then
            if spell.name then
                --if type(spellName) == "string" then 
                    if spell.name == spellName then
                        return spell
                    end
                --end
            else
                return spell
            end
        end
    end

    return nil
end

---@param missileName string
function OriUtils.FindIngameTargetedSpellByMissile(missileName)
    local ingameTargetedSpells = OriUtils.SpellData.TargetedProjectilesIngame

    for _, spell in ipairs(ingameTargetedSpells) do
        if spell.missileNames then
            for __, misName in ipairs(spell.missileNames) do
                if misName == missileName then 
                    return spell
                end
            end
        end
    end

    return nil
end

---@param target AIBaseClient
function OriUtils.IsTargetRunningAway(target)
    return target.IsMoving and not target:IsFacing(Player, 60)
end

function OriUtils.Lerp(from, to, t)
    return (1 - t) * from + t * to
end

function OriUtils.GetTimeCircleRadius(maxRadius, maxDuration, durationLeft)
    local t = durationLeft / maxDuration

    return OriUtils.Lerp(0, maxRadius, t)
end

function OriUtils.GetOpacityForRangeHelper(maxDuration, durationLeft)
    local t = durationLeft / maxDuration

    return OriUtils.Lerp(0x00, 0xFF, t)
end

---@param color number
---@param newOpacity number
---@return number
function OriUtils.ModifyColorOpacity(color, newOpacity)
    local hex = string.format("%08X", color)
    local hexOpacity = string.format("%02X", newOpacity)

    local newHex = hex:sub(1, 6) .. hexOpacity

    return tonumber(newHex, 16)
end

---@param exceptUnit AIHeroClient
function OriUtils.GetAllEnemyHandlesExcept(exceptUnit)
    local result = {}

    local exceptHandle = exceptUnit.Handle

    for handle, obj in pairs(ObjManager.Get("enemy", "heroes")) do
        if handle ~= exceptHandle then
            result[handle] = true
        end
    end

    return result
end

function OriUtils.TableToArray(table)
    local result = {}

    for k, v in pairs(table) do
        result[#result+1] = v
    end

    return result
end

---@param elementsArray string[]
function OriUtils.InitCircleRangeHelpers(elementsArray)
    for i, element in ipairs(elementsArray) do
        OriUtils.MiscData.CircleRangeHelpers[element] = {lastValue = -1, lastChangeT = 0}
    end
end

function OriUtils.HandleCircleRangeHelpers()
    local maxTimeToShow = 3.5
    local defaultColor = 0x00FFFFFF

    local curTime = Game.GetTime()
    local myPos = Player.Position

    if curTime <= maxTimeToShow then
        return
    end

    for elem, data in pairs(OriUtils.MiscData.CircleRangeHelpers) do
        if data.lastValue == -1 then
            data.lastValue = OriUtils.MGet(elem)
        else
            local newValue = OriUtils.MGet(elem)

            if data.lastValue ~= newValue then
                data.lastValue = newValue

                data.lastChangeT = curTime
            end

            if curTime < data.lastChangeT + maxTimeToShow then
                local remainingTime = (data.lastChangeT + maxTimeToShow) - curTime

                local newOp = OriUtils.GetOpacityForRangeHelper(maxTimeToShow, remainingTime)

                local newColor = OriUtils.ModifyColorOpacity(defaultColor, newOp)

                Renderer.DrawCircle3D(myPos, data.lastValue, 30, 4, newColor)
            end
        end
    end
end


local bDebugR = false

local debugInsecR = {}
debugInsecR.startPos = nil
debugInsecR.endPos = nil
debugInsecR.fastPredPos = nil
debugInsecR.colResultPos = nil
debugInsecR.segmentPoint = nil
debugInsecR.perpPath = nil
debugInsecR.bAnalyzed = false
debugInsecR.lastAnalysisT = 0

---@class SoldierInfo
---@field unit GameObject
---@field expireTime number
local t_SoldierInfo


local Azir = {}

Azir.MiscData = {}

Azir.MiscData.LastRLevel = 0

---@type table< Handle_t, SoldierInfo >
Azir.MiscData.Soldiers = {}

Azir.MiscData.LastCheckDanglingSoldiers = 0

Azir.MiscData.Insec = {}
---@type Vector
Azir.MiscData.Insec.CustomPos = nil
---@type Vector
Azir.MiscData.Insec.BackupEndPos = nil

local qCastTimers = { [slots.Q] = 0.25 }
---@param target AIBaseClient
function Azir.CastQ(pos)
    if not OriUtils.CheckCastTimers(qCastTimers) then return false end

    return OriUtils.CastSpell(slots.Q, pos)
end

local wCastTimers = { [slots.W] = 0.25}
function Azir.CastW(pos)
    if not OriUtils.CheckCastTimers(wCastTimers) then return false end

    return OriUtils.CastSpell(slots.W, pos)
end

local eCastTimers = { [slots.E] = 0.25, [slots.W] = 0.25 }
---@param pos Vector
function Azir.CastE(pos)
    if not OriUtils.CheckCastTimers(eCastTimers) then return false end

    return OriUtils.CastSpell(slots.E, pos)
end

local rCastTimers = { [slots.R] = 0.25 }
function Azir.CastR(pos)
    if not OriUtils.CheckCastTimers(rCastTimers) then return false end

    return OriUtils.CastSpell(slots.R, pos)
end

function Azir.GetHitchance(slot)
    local hc = 0.5

    if slot == slots.Q then
        hc = OriUtils.MGet("hc.Q") * 0.01
    elseif slot == slots.R then
        --hc = OriUtils.MGet("hc.R") * 0.01
    end

    return hc
end

---@return GameObject[]
function Azir.GetRealSoldiers()
    local result = {}

    local allSoldiers = Azir.MiscData.Soldiers
    for _, soldierInfo in pairs(allSoldiers) do
        local soldier = soldierInfo.unit
        
        if soldier.IsValid and not soldier.IsDead then
            result[#result+1] = soldier
        end
    end

    return result
end

---@param soldiers GameObject[]
function Azir.AreAllSoldiersStatic(soldiers)
    for _, obj in ipairs(soldiers) do
        local soldier = obj.AsAI

        if soldier.Pathing.IsDashing and soldier.IsMoving then
            return false
        end
    end

    return true
end

---@param pos Vector
---@param soldiers GameObject[]
---@param dist number|nil
function Azir.IsAnySoldierNearPos(pos, soldiers, dist)
    dist = dist or spells.W.SoldierRange

    for _, obj in ipairs(soldiers) do
        local soldier = obj.AsAI

        if soldier:Distance(pos) < dist then
            return true
        end
    end

    return false
end

function Azir.UpdateRRadius()
    local curRLevel = Player:GetSpell(slots.R).Level

    if curRLevel ~= Azir.MiscData.LastRLevel then
        Azir.MiscData.LastRLevel = curRLevel

        spells.R.Radius = ({300, 350, 400})[curRLevel] -- {310, 360, 410}
        spells.RBetterHitchance.Radius = ({200, 225, 250})[curRLevel]

        --INFO("Update R Radius to " .. tostring(spells.R.Radius))
    end
end

---@param target AIBaseClient
---@param soldiers GameObject[]
---@return PredictionResult|nil
function Azir.GetFirstSoldierPrediction(target, soldiers)
    local predInput = {
        Range = huge,
        Delay = spells.Q.Delay,
        Speed = spells.Q.Speed,
        Radius = spells.Q.Radius,
        Type = "Linear"
    }

    local hc = Azir.GetHitchance(slots.Q)

    for _, soldier in ipairs(soldiers) do
        local pred = Prediction.GetPredictedPosition(target, predInput, soldier.Position)
        if pred and pred.HitChance > hc then
            return pred
        end
    end

    return nil
end

local slotToDamageTable = {
    [slots.Q] = damages.Q,
    [slots.W] = damages.W,
    [slots.E] = damages.E,
    [slots.R] = damages.R
}

---@param target AIBaseClient
function Azir.GetSpellDamage(target, slot)
    local me = Player

    local rawDamage = 0
    local dmgType = nil

    local spellLevel = me:GetSpell(slot).Level
    local heroLevel = min(18, me.Level)

    if spellLevel >= 1 then
        local data = slotToDamageTable[slot]

        if data then
            dmgType = data.Type

            if data.Base then
                rawDamage = rawDamage + data.Base[spellLevel]
            end

            if data.HeroLevel then
                rawDamage = rawDamage + data.HeroLevel[heroLevel]
            end

            if data.TotalAP then
                rawDamage = rawDamage + (me.TotalAP * data.TotalAP)
            end

            if dmgType == dmgTypes.Physical then
                return DmgLib.CalculatePhysicalDamage(me, target, rawDamage)
            elseif dmgType == dmgTypes.Magical then
                return DmgLib.CalculateMagicalDamage(me, target, rawDamage)
            else
                return rawDamage
            end
        end
    end

    return 0
end

---@param target AIHeroClient
---@param targetEndPos Vector
---@param spellRadius number
---@param threshold number
---@return boolean
function Azir.PerpendicularCheck(target, dir, spellRadius, threshold)
    local me = Player
    local myPos = me.ServerPos

    local targetPos = target.ServerPos
    
    local perp = dir:Perpendicular()

    local p1 = targetPos + perp * spellRadius
    local p2 = targetPos + perp * -spellRadius

    local isOnSegment, pointSegment = myPos:ProjectOn(p1, p2)
    if not isOnSegment then
        return false
    end

    local path = Geometry.Path(p1, p2)
    return path:Distance(myPos) < threshold, pointSegment, path
end

---@param target AIHeroClient
---@param customEndPos Vector|nil @If this is nil then it will try to cast backwards, perpendicular to the target
---@return CollisionResult|nil, Vector @First retval is nil if Perp check is enabled and it fails, Vector is collision data endPos
function Azir.GetRCollision(target, customEndPos)
    local me = Player
    local myPos = me.ServerPos
    local heroPos = target.ServerPos
    local dir = nil

    if customEndPos then
        dir = (customEndPos - heroPos):Normalized()
    end

    local rSpell = spells.R
    if customEndPos and OriUtils.MGet("hc.RInsec") == 1 then
        rSpell = spells.RBetterHitchance
    end

    local startPos = nil
    if customEndPos then
        --startPos = myPos:Extended(customEndPos, -rSpell.BackRange)
        startPos = myPos + dir * -rSpell.BackRange
    else
        startPos = myPos:Extended(heroPos, rSpell.BackRange)
    end

    local endPos = nil
    if customEndPos then
        --endPos = myPos:Extended(customEndPos, rSpell.FrontRange)
        endPos = myPos + dir * rSpell.FrontRange
    else
        endPos = myPos:Extended(heroPos, -rSpell.FrontRange)
    end

    local width = rSpell.Radius * 2
    local speed = rSpell.Speed
    local delay = rSpell.Delay * 1000
    local handlesToIgnore = OriUtils.GetAllEnemyHandlesExcept(target)

    local pass = nil
    local segPoint = nil
    local path = nil
    if customEndPos and OriUtils.MGet("hc.RInsec.perp") then
        pass, segPoint, path = Azir.PerpendicularCheck(target, dir, rSpell.Radius, 250)

        if not pass then
            return nil
        end
    end
    
    return Collision.SearchHeroes(startPos, endPos, width, speed, delay, 1, "enemy", handlesToIgnore), endPos, startPos, segPoint, path
end

---@param dashPos Vector
---@param isInsec boolean
function Azir.DashTo(dashPos, isInsec)
    local me = Player
    local myPos = me.ServerPos

    local function SpellCheck(slot, fleeMenuId)
        if isInsec then
            return OriUtils.IsSpellReady(slot)
        else
            return OriUtils.CanCastSpell(slot, fleeMenuId)
        end
    end

    if not SpellCheck(slots.E, "flee.useE") then
        return false
    end
    
    local checkDist = 325

    local soldiers = Azir.GetRealSoldiers()

    local directSoldiers = {}
    local eFirstSoldiers = {} -- Soldiers that are closer to dashPos than Azir, so we'll cast E first and Q second
    local potentialSoldiers = {}

    ---@param firstPos Vector
    local function GetTrueWCastPos(firstPos)
        local wRange = spells.W.Range

        if myPos:Distance(firstPos) > wRange then
            return myPos:Extended(firstPos, wRange)
        end

        return firstPos
    end

    for _, soldier in ipairs(soldiers) do
        local dist = soldier:Distance(dashPos)
        local myDist = soldier:Distance(myPos)
        local myDistToMouse = dashPos:Distance(myPos)

        if myDist < spells.E.Range then
            if dist < checkDist then
                directSoldiers[#directSoldiers+1] = soldier
            end

            if dist < myDistToMouse then
                eFirstSoldiers[#eFirstSoldiers+1] = soldier
            end

            potentialSoldiers[#potentialSoldiers+1] = soldier
        end
    end

    local directSoldier = OriUtils.GetFirstElementSort(directSoldiers, function(elemA, elemB)
        return dashPos:Distance(elemA) < dashPos:Distance(elemB)
    end)

    if directSoldier then
        if Azir.CastE(directSoldier.Position) then
            return true
        end
    else
        if #eFirstSoldiers > 0 then
            local closestToMouse = OriUtils.GetFirstElementSort(eFirstSoldiers, function(elemA, elemB)
                return dashPos:Distance(elemA) < dashPos:Distance(elemB)
            end)

            local ePos = closestToMouse.Position

            if SpellCheck(slots.Q, "flee.useQ") then
                if Azir.CastE(ePos) then
                    local distToEPos = me:EdgeDistance(ePos)
                    if OriUtils.MGet("misc.saferDash") then
                        distToEPos = max(distToEPos - 70, 0)
                    end

                    local speed = spells.E.Speed
                    local timeToReach = distToEPos / speed

                    local ping = Game.GetLatency()

                    delay(max(25, timeToReach * 1000 - ping), function() Azir.CastQ(dashPos) end)
                    return true
                end
            else
                if Azir.CastE(ePos) then
                    return true
                end
            end
        elseif SpellCheck(slots.W, "flee.useW") then
            if Azir.CastW(GetTrueWCastPos(dashPos)) then
                return true
            end
        elseif #potentialSoldiers > 0 then
            if SpellCheck(slots.Q, "flee.useQ") then
                local closestToMouse = OriUtils.GetFirstElementSort(potentialSoldiers, function(elemA, elemB)
                    return dashPos:Distance(elemA) < dashPos:Distance(elemB)
                end)

                local ePos = closestToMouse.Position

                if Azir.CastQ(dashPos) then
                    delay(75, function() Azir.CastE(ePos) end)

                    return true
                end
            end
        end
    end
end

function Azir.SetAndResetCustomPos()
    if OriUtils.MGet("insec.method.custom.setPos") then
        Azir.MiscData.Insec.CustomPos = Renderer.GetMousePos()
    end

    if OriUtils.MGet("insec.method.custom.clearPos") then
        Azir.MiscData.Insec.CustomPos = nil
    end
end

---@return Vector|nil
function Azir.GetInsecTargetPos()
    if OriUtils.MGet("insec.method.custom") and Azir.MiscData.Insec.CustomPos then
        return Azir.MiscData.Insec.CustomPos
    end

    local me = Player

    local function closestFunc(elemA, elemB)
        return elemA:Distance(me) < elemB:Distance(me)
    end

    if OriUtils.MGet("insec.method.turret") then
        local allyTurrets = OriUtils.TableToArray(ObjManager.Get("ally", "turrets"))
        local maxRange = OriUtils.MGet("insec.method.turret.maxRange")

        sort(allyTurrets, closestFunc)

        for _, obj in ipairs(allyTurrets) do
            local turret = obj.AsTurret

            if not turret.IsDead and me:Distance(turret) < maxRange then
                return turret.ServerPos
            end
        end
    end

    if OriUtils.MGet("insec.method.ally") then
        local allyHeroes = OriUtils.TableToArray(ObjManager.Get("ally", "heroes"))
        local maxRange = OriUtils.MGet("insec.method.ally.maxRange")

        sort(allyHeroes, closestFunc)

        for _, obj in ipairs(allyHeroes) do
            local hero = obj.AsHero

            if not hero.IsMe and OriUtils.IsValidTarget(hero, maxRange) then
                return hero.ServerPos
            end
        end
    end

    return nil
end

function Azir.CheckDanglingSoldiers()
    local curTime = Game.GetTime()

    if curTime > Azir.MiscData.LastCheckDanglingSoldiers + 1 then
        Azir.MiscData.LastCheckDanglingSoldiers = curTime

        for handle, soldierInfo in pairs(Azir.MiscData.Soldiers) do
            local expireTime = soldierInfo.expireTime

            if curTime > expireTime then
                Azir.MiscData.Soldiers[handle] = nil

                --INFO("Deleted soldier with handle %d due to expire time", handle)
            end
        end
    end
end

function Azir.HandleBackupInsecPos()
    local lastGoodPos = Azir.GetInsecTargetPos()
    local isPressingInsec = OriUtils.MGet("insec.key")

    if isPressingInsec then
        if lastGoodPos then
            Azir.MiscData.Insec.BackupEndPos = lastGoodPos
        end
    else
        if Azir.MiscData.Insec.BackupEndPos then
            Azir.MiscData.Insec.BackupEndPos = nil
        end
    end
end

function fightModes.Insec()
    local me = Player

    local mousePos = Renderer.GetMousePos()

    local forcedTarget = TS:GetForcedTarget()

    if OriUtils.MGet("insec.move") then
        Orbwalker.Orbwalk(mousePos)
    end

    if not OriUtils.IsSpellReady(slots.R) then
        return false
    end

    local gapclose = OriUtils.MGet("insec.gapclose")

    local ranges = {spells.R.FrontRange}
    if gapclose then
        insert(ranges, spells.E.Range)
    end

    local target = OriUtils.ChooseTarget(forcedTarget, ranges)
    if not target then
        return false
    end

    local targetPos = Azir.GetInsecTargetPos()
    if not targetPos then
        targetPos = Azir.MiscData.Insec.BackupEndPos

        if not targetPos then
            return false
        end
    end

    local col, endP, startP, segPoint, path = Azir.GetRCollision(target, targetPos)
    if col and col.Result then
        if Azir.CastR(targetPos) then
            if not debugInsecR.bAnalyzed then
                debugInsecR.bAnalyzed = true
                debugInsecR.startPos = startP
                debugInsecR.endPos = endP
                debugInsecR.fastPredPos = target:FastPrediction(spells.R.Delay * 1000 + 1000 * (target:EdgeDistance(startP) / spells.R.Speed))
                debugInsecR.colResultPos = col.Positions[1]
                debugInsecR.segmentPoint = segPoint
                debugInsecR.perpPath = path
                debugInsecR.lastAnalysisT = Game.GetTime()
            end

            if OriUtils.MGet("insec.soldierLandPos") then
                local colPoint = col.Positions[1]
                local finalLineCenter = me.ServerPos:Extended(endP, 650)
                local pushDir = (endP - startP):Normalized()
                local perp = pushDir:Perpendicular()

                local rRadius = spells.R.Radius

                local p1 = finalLineCenter + perp * rRadius
                local p2 = finalLineCenter + perp * -rRadius

                local isOnSegment, segmentPoint = colPoint:ProjectOn(p1, p2)
                if isOnSegment then
                    delay(100, function() if OriUtils.IsSpellReady(slots.W) then Azir.CastW(segmentPoint) end end)
                end
            end

            return true
        end
    end

    if gapclose then
        local fp = target:FastPrediction(1000)
        if fp then
            local dashPos = target.ServerPos:Extended(me, -250)
            if me:Distance(fp) > me:Distance(target) then
                dashPos = fp
            end

            if me:Distance(dashPos) < spells.Q.Range + spells.W.Range then
                return Azir.DashTo(dashPos, true)
            end
        end
    end
end

function fightModes.ExtraModes(lagFree)
    if OriUtils.MGet("insec.key") then
        return fightModes.Insec()
    end
end

function fightModes.Killsteal(lagFree)
    if Orbwalker.GetMode() == "Combo" or not OriUtils.MGet("ks.onlyCombo") then
        local me = Player
        local myPos = me.ServerPos

        local enemies = ObjManager.GetNearby("enemy", "heroes")
        
        for _, obj in ipairs(enemies) do
            local hero = obj.AsHero
            
            if OriUtils.IsValidTarget(hero) then
                local heroName = hero.CharName
                local heroPos = hero.ServerPos
                local heroHealth = HealthPred.GetHealthPrediction(hero, 0)

                if OriUtils.CanCastSpell(slots.R, "ks.useR") and OriUtils.MGet("ks.rWL." .. heroName, true) then
                    if heroHealth > 0 and heroHealth < Azir.GetSpellDamage(hero, slots.R) then 
                        local col, endPos = Azir.GetRCollision(hero)

                        if col and col.Result then
                            if Azir.CastR(endPos) then
                                return true
                            end
                        end
                    end
                end
            end
        end
    end
end

function fightModes.Flee(lagFree)
    local fleePos = Renderer.GetMousePos()

    if OriUtils.MGet("flee.forceMaxRange") then
        fleePos = Player.ServerPos:Extended(fleePos, spells.E.Range + spells.Q.Range)
    end

    return Azir.DashTo(fleePos, false)
end

function fightModes.Combo(lagFree)
    local me = Player

    local forcedTarget = TS:GetForcedTarget()

    local soldiers = Azir.GetRealSoldiers()

    if OriUtils.CanCastSpell(slots.W, "combo.useW") then
        local wRange = spells.W.Range + spells.W.SoldierRange / 2

        local target = OriUtils.ChooseTarget(forcedTarget, {wRange})
        if target and target:Distance(me) < wRange then
            if Azir.CastW(target.ServerPos) then
                return true
            end
        end
    end

    ---@param target AIHeroClient
    ---@param soldiers GameObject[]
    local function QSmartChecks(target, soldiers)
        local nSoldiers = #soldiers

        if nSoldiers >= 2 then
            return true
        elseif nSoldiers == 1 then
            local targetHealth = HealthPred.GetHealthPrediction(target, 0)
            local qDmg = Azir.GetSpellDamage(target, slots.Q)
            local wDmg = Azir.GetSpellDamage(target, slots.W)

            local damagesToCheck = {
                qDmg,
                wDmg,
                qDmg + wDmg
            }

            for _, dmg in ipairs(damagesToCheck) do
                if targetHealth < dmg then
                    return true
                end
            end
        end

        return false
    end

    if OriUtils.CanCastSpell(slots.Q, "combo.useQ") then
        local qRange = spells.Q.Range

        local target = OriUtils.ChooseTarget(forcedTarget, {qRange})
        if target and target:Distance(me) < qRange then
            local qMode = OriUtils.MGet("combo.useQ.mode")

            local shouldCast = false
            if qMode == 0 then
                shouldCast = true
            elseif qMode == 1 and QSmartChecks(target, soldiers) then
                shouldCast = true
            end

            if OriUtils.MGet("combo.useQ.reachOnly") and Azir.IsAnySoldierNearPos(target.ServerPos, soldiers) then
                shouldCast = false
            end

            if shouldCast then
                local pred = Azir.GetFirstSoldierPrediction(target, soldiers)
                if pred then
                    if Azir.CastQ(pred.CastPosition) then
                        return true
                    end
                end
            end
        end
    end

    local gpUnderTurret = OriUtils.MGet("combo.useE.gapclose.turret")

    if OriUtils.CanCastSpell(slots.E, "combo.useE") and OriUtils.MGet("combo.useE.gapclose") then
        local eRange = spells.E.Range + spells.W.SoldierRange / 2
        
        local target = OriUtils.ChooseTarget(forcedTarget, {eRange})
        
        if target and target:Distance(me) < eRange then
            if target.HealthPercent * 100 < OriUtils.MGet("combo.useE.gapclose.minHealth") then
                local aaRangeHalf = Orbwalker.GetTrueAutoAttackRange(me, target) / 2
        
                for _, soldier in ipairs(soldiers) do
                    if soldier:Distance(target) < aaRangeHalf then
                        if gpUnderTurret or not OriUtils.IsPosUnderTurret(soldier.Position) then
                            if Azir.CastE(soldier.Position) then
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

    local forcedTarget = TS:GetForcedTarget()

    local soldiers = Azir.GetRealSoldiers()

    local canUseW = OriUtils.CanCastSpell(slots.W, "harass.useW")

    if canUseW then
        local wRange = spells.W.Range + spells.W.SoldierRange / 2

        local target = OriUtils.ChooseTarget(forcedTarget, {wRange})
        if target and target:Distance(me) < wRange then
            if Azir.CastW(target.ServerPos) then
                return true
            end
        end
    end

    if OriUtils.CanCastSpell(slots.Q, "harass.useQ") then
        local qRange = spells.Q.Range

        local target = OriUtils.ChooseTarget(forcedTarget, {qRange})
        if target and target:Distance(me) < qRange then
            if canUseW and OriUtils.MGet("harass.useW.comboQ") then
                if Azir.CastW(target.ServerPos) then
                    return true
                end
            end

            local pred = Azir.GetFirstSoldierPrediction(target, soldiers)
            if pred then
                if Azir.CastQ(pred.CastPosition) then
                    return true
                end
            end
        end
    end
end

function fightModes.Waveclear(lagFree)
    --[[
        if not (OriUtils.MGet("clear.enemyAround") or not TS:GetTarget(1500)) then
            return false
        end
    --]]

    local enemyNear = TS:GetTarget(1500)

    local soldiers = Azir.GetRealSoldiers()
    local bStaticSoldiers = Azir.AreAllSoldiersStatic(soldiers)

    local minMinions = OriUtils.MGet("clear.minMinions")

    local canUseQ = OriUtils.CanCastSpell(slots.Q, "clear.useQ")

    if canUseQ and #soldiers > 0 then
        if OriUtils.MGet("clear.useQ.enemyAround") or not enemyNear then
            local minions = OriUtils.GetEnemyAndJungleMinions(spells.Q.Range)
            local minionsPos = {}
            
            for i, minion in ipairs(minions) do
                minionsPos[i] = minion.ServerPos
            end
            
            local bestPos, hits = Geometry.BestCoveringCircle(minionsPos, spells.W.SoldierRange)
            if bestPos and hits >= minMinions then
                if not Azir.IsAnySoldierNearPos(bestPos, soldiers, spells.W.SoldierRange * 0.5) then
                    if Azir.CastQ(bestPos) then
                        return true
                    end
                end
            end
        end
    end

    if OriUtils.CanCastSpell(slots.W, "clear.useW") and (#soldiers == 0 or (not canUseQ and bStaticSoldiers)) then
        if OriUtils.MGet("clear.useW.enemyAround") or not enemyNear then
            local minions = OriUtils.GetEnemyAndJungleMinions(spells.W.Range)
            local minionsPos = {}
            
            for i, minion in ipairs(minions) do
                minionsPos[i] = minion.ServerPos
            end
            
            local bestPos, hits = Geometry.BestCoveringCircle(minionsPos, spells.W.SoldierRange)
            if bestPos and hits >= minMinions then
                if not Azir.IsAnySoldierNearPos(bestPos, soldiers, spells.W.SoldierRange) then
                    if Azir.CastW(bestPos) then
                        return true
                    end
                end
            end
        end
    end
end

function events.OnTick(lagFree)
    if bDebugR then
        if debugInsecR.bAnalyzed then
            local curTime = Game.GetTime()

            if curTime > debugInsecR.lastAnalysisT + 2 then
                debugInsecR.bAnalyzed = false
            end
        end
    end

    OriUtils.CheckFlashSlot()

    Azir.CheckDanglingSoldiers()

    Azir.HandleBackupInsecPos()

    Azir.UpdateRRadius()

    Azir.SetAndResetCustomPos()

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
    {slot = slots.Q, id = "Q", displayText = "Q [Conquering Sands]", range = spells.Q.Range},
    {slot = slots.W, id = "W", displayText = "W [Arise!]", range = spells.W.Range},
    {slot = slots.E, id = "E", displayText = "E [Shifting Sands]", range = spells.E.Range},
    {slot = slots.R, id = "R", displayText = "R [Emperor's Divide]", range = spells.R.Range}
}

function events.OnDraw()
    local me = Player

    if me.IsDead then
        return
    end

    local myPos = me.Position

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

    if OriUtils.MGet("draw.soldiersRange") then
        local soldiers = Azir.GetRealSoldiers()
        for _, soldier in ipairs(soldiers) do
            Renderer.DrawCircle3D(soldier.Position, spells.W.SoldierRange, 30, 2, OriUtils.MGet("draw.soldiersRange.color"))
        end
    end

    if OriUtils.MGet("draw.customPos") and Azir.MiscData.Insec.CustomPos then
        local customPos = Azir.MiscData.Insec.CustomPos
        local color = OriUtils.MGet("draw.customPos.color")

        Renderer.DrawCircle3D(customPos, 125, 30, 3, color)
        Renderer.DrawLine3D(myPos, customPos, 2, color)
    end

    if OriUtils.MGet("draw.gpEStatus") then
        local gpEState = OriUtils.MGet("combo.useE.gapclose")

        local text = gpEState and "Gapclose with E: On" or "Gapclose with E: Off"
        local color = gpEState and 0x00FF00FF or 0xFF0000FF

        Renderer.DrawTextOnPlayer(text, color)
    end

    OriUtils.HandleCircleRangeHelpers()

    if OriUtils.MGet("draw.backupPos") and Azir.MiscData.Insec.BackupEndPos then
        local color = OriUtils.MGet("draw.backupPos.color")

        Renderer.DrawLine3D(myPos, Azir.MiscData.Insec.BackupEndPos, 4, color)
    end

    if bDebugR then
        local tbl = debugInsecR
        if tbl.startPos and tbl.endPos and tbl.fastPredPos and tbl.colResultPos then
            Renderer.DrawRectOutline3D(tbl.startPos, tbl.endPos, OriUtils.MGet("hc.RInsec") == 0 and (spells.R.Radius * 2) or (spells.RBetterHitchance.Radius * 2), 2, 0x00FF00FF)
            Renderer.DrawCircle3D(tbl.fastPredPos, 50, 30, 2, 0xFF0000FF)
            Renderer.DrawCircle3D(tbl.colResultPos, 75, 30, 2, 0x0000FFFF)
        end

        if tbl.segmentPoint and tbl.perpPath then
            Renderer.DrawCircle3D(tbl.segmentPoint, 100, 30, 2, 0xFF00FFFF)
            tbl.perpPath:Draw(0xFFFF00FF)
        end
    end
end

---@param target AIHeroClient
function events.OnDrawDamage(target, dmgList)
    if not OriUtils.MGet("draw.comboDamage") then
        return
    end

    local me = Player

    local damageToDeal = 0

    local useElectrocute = OriUtils.Perks.Electrocute.HasBuff
    local useQ = OriUtils.CanCastSpell(slots.Q, "combo.useQ")
    local useW = OriUtils.CanCastSpell(slots.W, "combo.useW")
    local useE = OriUtils.CanCastSpell(slots.E, "combo.useE")
    local useR = OriUtils.CanCastSpell(slots.R, "ks.useR") and OriUtils.MGet("ks.rWL." .. target.CharName, true)

    if useElectrocute then
        damageToDeal = damageToDeal + OriUtils.GetElectrocuteDamage(target)
    end

    if useQ then
        damageToDeal = damageToDeal + Azir.GetSpellDamage(target, slots.Q)
    end

    if useW or #Azir.GetRealSoldiers() > 0 then
        damageToDeal = damageToDeal + Azir.GetSpellDamage(target, slots.W) * 2
    end

    if useE then
        damageToDeal = damageToDeal + Azir.GetSpellDamage(target, slots.E)
    end

    if useR then
        damageToDeal = damageToDeal + Azir.GetSpellDamage(target, slots.R)
    end

    insert(dmgList, damageToDeal)
end

---@param obj GameObject
function events.OnCreateObject(obj)
    if obj then
        if obj.IsAlly and obj.Name == "AzirSoldier" then
            local expireTime = Game.GetTime() + 10

            Azir.MiscData.Soldiers[obj.Handle] = {unit = obj, expireTime = expireTime}
        end
    end
end

---@param obj GameObject
function events.OnDeleteObject(obj)
    if obj then
        Azir.MiscData.Soldiers[obj.Handle] = nil
    end
end

---@param obj GameObject
---@param buffInst BuffInst
function events.OnBuffGain(obj, buffInst)
    if obj and buffInst then
        if obj.IsMe then
            if buffInst.Name == OriUtils.Perks.Electrocute.BuffName then
                OriUtils.Perks.Electrocute.HasBuff = true
            end
        end
    end
end

---@param obj GameObject
---@param buffInst BuffInst
function events.OnBuffLost(obj, buffInst)
    if obj and buffInst then
        if obj.IsMe then
            if buffInst.Name == OriUtils.Perks.Electrocute.BuffName then
                OriUtils.Perks.Electrocute.HasBuff = false
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

function Azir.RegisterEvents()
    for eventName, eventId in pairs(Enums.Events) do
        if events[eventName] then
            EventManager.RegisterCallback(eventId, events[eventName])
        end
    end
end

function Azir.InitMenu()
    local function QHeader()
        Menu.ColoredText(drawData[1].displayText, SCRIPT_COLOR, true)
    end

    local function WHeader()
        Menu.ColoredText(drawData[2].displayText, SCRIPT_COLOR, true)
    end

    local function EHeader()
        Menu.ColoredText(drawData[3].displayText, SCRIPT_COLOR, true)
    end

    local function RHeader()
        Menu.ColoredText(drawData[4].displayText, SCRIPT_COLOR, true)
    end

    local function AzirMenu()
        Menu.Text("Version: " .. SCRIPT_VERSION, true)
        Menu.Text("Last Updated: " .. SCRIPT_LAST_UPDATED, true)
        if SCRIPT_IS_BETA then
            Menu.ColoredText("This is a beta, if you find any issues, report them to " .. SCRIPT_AUTHOR, 0xFFFF00FF, true)
        end

        Menu.NewTree("Azir.comboMenu", "Combo Settings", function()
            Menu.ColumnLayout("Azir.comboMenu.QW", "Azir.comboMenu.QW", 2, true, function()
                QHeader()

                Menu.Checkbox("Azir.combo.useQ", "Enable Q", true)
                Menu.Indent(function()
                    Menu.Dropdown("Azir.combo.useQ.mode", "Mode", 1, {"Always", "Smart"})
                    Menu.Indent(function()
                        Menu.ColoredText("Smart mode will wait until there are 2 or more available soldiers\nOR enemy is killable with Q/W/Q+W", 0xFFFF00FF)
                    end)
                    Menu.Checkbox("Azir.combo.useQ.reachOnly", "Use only when no soldier is in AA range", true)
                end)

                Menu.NextColumn()

                WHeader()

                Menu.Checkbox("Azir.combo.useW", "Enable W", true)
            end)

            Menu.Separator()

            Menu.ColumnLayout("Azir.comboMenu.ER", "Azir.comboMenu.ER", 2, true, function()
                EHeader()

                Menu.Checkbox("Azir.combo.useE", "Enable E", false)
                Menu.Indent(function()
                    Menu.Keybind("Azir.combo.useE.gapclose", "Toggle Gapclose with E", string.byte("Z"), true, false, true)
                    Menu.Indent(function()
                        Menu.Slider("Azir.combo.useE.gapclose.minHealth", "Min target HP % to gapclose", 40, 0, 100, 1)
                        Menu.Checkbox("Azir.combo.useE.gapclose.turret", "Gapclose under turret", false)
                    end)
                end)

                Menu.NextColumn()

                --RHeader()

                --Menu.Checkbox("Azir.combo.useR", "Enable R", false)
            end)
        end)

        Menu.NewTree("Azir.harassMenu", "Harass Settings", function()
            QHeader()

            Menu.Checkbox("Azir.harass.useQ", "Enable Q", true)
            --[[
            Menu.Indent(function()
                Menu.Slider("Azir.harass.useQ.minW", "Min soldiers to Q", 1, 1, 3, 1)
            end)
            --]]

            Menu.Separator()

            WHeader()

            Menu.Checkbox("Azir.harass.useW", "Enable W", true)
            Menu.Indent(function()
                Menu.Checkbox("Azir.harass.useW.comboQ", "Use early")
                Menu.Indent(function()
                    Menu.ColoredText("This option will use W for a W-Q combo if target is in Q range and Q is available", 0xFFFF00FF)
                end)
            end)
        end)

        Menu.NewTree("Azir.clearMenu", "Clear Settings", function()
            Menu.Slider("Azir.clear.minMinions", "Min minions to use spells", 2, 1, 5, 1)
            
            QHeader()
            
            Menu.Checkbox("Azir.clear.useQ", "Enable Q", false)
            Menu.Indent(function()
                Menu.Checkbox("Azir.clear.useQ.enemyAround", "Clear with Q even if enemies around", false)
            end)

            Menu.Separator()

            WHeader()

            Menu.Checkbox("Azir.clear.useW", "Enable W", false)
            Menu.Indent(function()
                Menu.Checkbox("Azir.clear.useW.enemyAround", "Clear with W even if enemies around", true)
            end)
        end)

        Menu.NewTree("Azir.fleeMenu", "Flee Settings", function()
            Menu.Checkbox("Azir.flee.forceMaxRange", "Always try to flee at max range", false)

            QHeader()

            Menu.Checkbox("Azir.flee.useQ", "Enable Q", true)

            Menu.Separator()

            WHeader()

            Menu.Checkbox("Azir.flee.useW", "Enable W if no good soldier near mouse", true)

            Menu.Separator()

            EHeader()

            Menu.Checkbox("Azir.flee.useE", "Enable E", true)
        end)

        Menu.NewTree("Azir.insecMenu", "Insec Settings", function()
            Menu.Keybind("Azir.insec.key", "Insec Key", string.byte("T"))

            Menu.Checkbox("Azir.insec.gapclose", "Smart gapclose with Q-W-E", true)
            Menu.Checkbox("Azir.insec.move", "Move to mouse pos", true)
            
            Menu.Separator()

            Menu.Checkbox("Azir.insec.soldierLandPos", "Place soldier near where\nenemy will land after insec", true)

            Menu.Separator()

            Menu.ColoredText("Insec target positions", SCRIPT_COLOR)


            Menu.Indent(function()
                Menu.Checkbox("Azir.insec.method.custom", "To custom pos", true)
                Menu.Indent(function()
                    Menu.Keybind("Azir.insec.method.custom.setPos", "Set custom pos", string.byte("G"))
                    Menu.Keybind("Azir.insec.method.custom.clearPos", "Clear custom pos", string.byte("H"))
                end)
                
                Menu.Separator()
                
                Menu.Checkbox("Azir.insec.method.turret", "To ally turret", true)
                Menu.Slider("Azir.insec.method.turret.maxRange", "Ally turret max check range", 3000, 1000, 3000, 100)

                Menu.Separator()
            
                Menu.Checkbox("Azir.insec.method.ally", "To ally hero", true)
                Menu.Slider("Azir.insec.method.ally.maxRange", "Ally hero max check range", 2000, 1000, 3000, 100)
            end)
        end)

        Menu.NewTree("Azir.ksMenu", "Killsteal Settings", function()
            Menu.Checkbox("Azir.ks.onlyCombo", "Only KS during Combo mode", true)

            Menu.Separator()

            RHeader()

            Menu.Checkbox("Azir.ks.useR", "Use R to KS", true)
            Menu.Indent(function()
                Menu.NewTree("Azir.ksMenu.rWhitelist", "KS R Whitelist", function()
                    local enemyHeroes = ObjManager.Get("enemy", "heroes")

                    local addedWL = {}

                    for _, obj in pairs(enemyHeroes) do
                        local hero = obj.AsHero
                        local heroName = hero.CharName

                        if hero and not addedWL[heroName] then
                            Menu.Checkbox("Azir.ks.rWL." .. heroName, "R KS on " .. heroName, true)

                            addedWL[heroName] = true
                        end
                    end
                end)
            end)
        end)

        Menu.NewTree("Azir.miscMenu", "Misc Settings", function()
            Menu.Checkbox("Azir.misc.saferDash", "Safer E-Q dash\nWill use Q earlier when dashing in flee or insec", false)
        end)

        Menu.NewTree("Azir.drawMenu", "Draw Settings", function()
            OriUtils.AddDrawMenu(drawData)

            Menu.Separator()

            Menu.Checkbox("Azir.draw.gpEStatus", "Print gapclose with E status", true)

            Menu.Separator()

            Menu.Checkbox("Azir.draw.soldiersRange", "Draw active soldiers range", false)
            Menu.ColorPicker("Azir.draw.soldiersRange.color", "Active soldiers range color", SCRIPT_COLOR)

            Menu.Separator()

            Menu.Checkbox("Azir.draw.customPos", "Draw insec custom pos indicators", true)
            Menu.ColorPicker("Azir.draw.customPos.color", "Insec custom pos indicators color", SCRIPT_COLOR)

            Menu.Checkbox("Azir.draw.backupPos", "Draw insec backup pos line", false)
            Menu.ColorPicker("Azir.draw.backupPos.color", "Insec backup pos line color", 0x00FF00FF)
        end)

        Menu.NewTree("Azir.hcMenu", "Hitchance Settings", function()
            Menu.Slider("Azir.hc.Q", "Q Hitchance", 35, 0, 100, 1)
            --Menu.Slider("Azir.hc.R", "R Hitchance", 40, 0, 100, 1)
            Menu.Dropdown("Azir.hc.RInsec", "Insec R Hitchance", 1, {"Use more often (Less accuracy)", "Better accuracy (Used less frequently)"})
            Menu.Indent(function()
                Menu.Checkbox("Azir.hc.RInsec.perp", "Enable perpendicular check", true)
            end)
        end)

        Menu.Text("Author: " .. SCRIPT_AUTHOR, true)
    end

    Menu.RegisterMenu(SCRIPT_NAME, SCRIPT_NAME, AzirMenu)
end

function OnLoad()
    Azir.InitMenu()

    OriUtils.InitCircleRangeHelpers({
        "insec.method.turret.maxRange",
        "insec.method.ally.maxRange"
    })

    Azir.RegisterEvents()

    OriUtils.InitElectrocute()

    return true
end