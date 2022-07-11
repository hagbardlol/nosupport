if Player.CharName ~= "Katarina" then return end

local SCRIPT_NAME = "Ori Katarina"
local SCRIPT_VERSION_UPDATER = "1.0.5"
local SCRIPT_VERSION = SCRIPT_VERSION_UPDATER
local SCRIPT_LAST_UPDATED = "11/28/2021"
local SCRIPT_AUTHOR = "Orietto"
local SCRIPT_IS_BETA = false

if SCRIPT_IS_BETA then
    SCRIPT_VERSION = SCRIPT_VERSION .. " Beta"
else
    SCRIPT_VERSION = SCRIPT_VERSION .. " Release"
end

local SCRIPT_COLOR = 0x9E34EBFF

module(SCRIPT_NAME, package.seeall, log.setup)
clean.module(SCRIPT_NAME, clean.seeall, log.setup)

local insert, sort = table.insert, table.sort
local huge, pow, min, max, floor, ceil = math.huge, math.pow, math.min, math.max, math.floor, math.ceil
local format = string.format

local SDK = _G.CoreEx

SDK.AutoUpdate("https://raw.githubusercontent.com/hagbardlol/nosupport/main/OriKatarina.lua", SCRIPT_VERSION_UPDATER)

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
    Passive = {
        Base = {68, 72, 77, 82, 89, 96, 103, 112, 121, 131, 142, 154, 166, 180, 194, 208, 224, 240},
        BonusAD = 0.75,
        TotalAP = function(heroLevel)
            if heroLevel >= 16 then
                return 0.88
            elseif heroLevel >= 11 then
                return 0.77
            elseif heroLevel >= 6 then
                return 0.66
            else
                return 0.55
            end
        end,
        Type = dmgTypes.Magical
    },
    Q = {
        Base = {75, 105, 135, 165, 195},
        TotalAP = 0.3,
        Type = dmgTypes.Magical
    },
    E = {
        Base = {15, 30, 45, 60, 75},
        TotalAD = 0.5,
        TotalAP = 0.25,
        Type = dmgTypes.Magical
    },
    R = {
        PhysDmg = function()
            local me = Player
            local base = 0.16

            local baseAS = 0.658
            local totalAS = baseAS + me.AttackSpeedMod

            return (base + (totalAS * 0.128)) * me.BonusAD
        end,
        MagicDmg = function(spellLevel)
            local me = Player
            local base = {25, 37.5, 50}
            local totalAP = 0.19

            return base[spellLevel] + (totalAP * me.TotalAP)
        end,
        Type = dmgTypes.Mixed
    }
}

local spells = {
    Q = Spell.Targeted({
        Slot = slots.Q,
        Range = 620
    }),
    W = Spell.Active({
        Slot = slots.W,
        Range = 0,
        SpinRadius = 340,
        DaggerRadius = 200 --150
    }),
    E = Spell.Skillshot({
        Slot = slots.E,
        Range = 720
    }),
    R = Spell.Active({
        Slot = slots.R,
        Range = 550,
        Daggers = 15
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


local Katarina = {}

Katarina.MiscData = {}

Katarina.MiscData.Daggers = {}

Katarina.MiscData.GroundDaggers = {}

Katarina.MiscData.IsUlting = false

Katarina.MiscData.KSCastRAfterW = false


local qCastTimers = { [slots.Q] = 0.25, [slots.R] = 0.25 }
---@param target AIBaseClient
function Katarina.CastQ(target)
    if not OriUtils.CheckCastTimers(qCastTimers) then return false end

    local colResult = Collision.SearchYasuoWall(Player.ServerPos, target.ServerPos, 60, 1600, 250, 1, "enemy")
    if colResult.Result or #colResult.Objects > 0 then
        return false
    end

    return OriUtils.CastSpell(slots.Q, target)
end

local wCastTimers = { [slots.W] = 0.25, [slots.R] = 0.25 }
function Katarina.CastW()
    if not OriUtils.CheckCastTimers(wCastTimers) then return false end

    return OriUtils.CastSpell(slots.W, Player)
end

local eCastTimers = { [slots.E] = 0.25, [slots.R] = 0.25 }
---@param pos Vector
function Katarina.CastE(pos)
    if not OriUtils.CheckCastTimers(eCastTimers) then return false end

    return OriUtils.CastSpell(slots.E, pos)
end

local rCastTimers = { [slots.R] = 0.25 }
function Katarina.CastR()
    if not OriUtils.CheckCastTimers(rCastTimers) then return false end

    return OriUtils.CastSpell(slots.R, Player)
end

---@param target AIHeroClient
function Katarina.GetDynamicRDaggers(target)
    if not spells.R:IsInRange(target) then
        return 0
    end

    local me = Player

    local daggerInterval = 0.166

    local targetSpeed = target.MoveSpeed
    local distanceToEscape = spells.R.Range - me:Distance(target)

    local timeToEscape = distanceToEscape / targetSpeed

    local daggersBeforeEscape = floor(timeToEscape / daggerInterval)

    return daggersBeforeEscape
end

---@param target AIHeroClient
function Katarina.GetRDaggersAmount(target)
    local rDaggersMode = OriUtils.MGet("global.rDaggersMode")

    if not rDaggersMode then
        return OriUtils.MGet("global.rDaggers")
    else
        return Katarina.GetDynamicRDaggers(target)
    end

    return 15
end

local slotToDamageTable = {
    [slots.Q] = damages.Q,
    [slots.E] = damages.E
}
function Katarina.GetPassiveDamage(target)
    local me = Player

    local passive = damages.Passive
    local heroLevel = me.Level

    local rawDamage = passive.Base[min(18, heroLevel)] + (passive.BonusAD * me.BonusAD) + (passive.TotalAP(heroLevel) * me.TotalAP)

    return DmgLib.CalculateMagicalDamage(me, target, rawDamage)
end

function Katarina.GetSpellDamage(target, slot)
    if slot == slots.R then
        ERROR("GetSpellDamage called with R slot, use GetRDamage instead")
    end

    local me = Player

    local rawDamage = 0
    local dmgType = nil

    local spellLevel = me:GetSpell(slot).Level

    if spellLevel >= 1 then
        local data = slotToDamageTable[slot]
        
        if data then
            dmgType = data.Type
            
            rawDamage = rawDamage + data.Base[spellLevel]
            
            if data.TotalAD then
                rawDamage = rawDamage + (data.TotalAD * me.TotalAD)
            end
            
            if data.TotalAP then
                rawDamage = rawDamage + (data.TotalAP * me.TotalAP)
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

---@param target AIBaseClient
---@param daggersAmount number
function Katarina.GetRDamage(target, daggersAmount)
    daggersAmount = min(daggersAmount, 15)

    local me = Player

    local rData = damages.R
    local spellLevel = me:GetSpell(slots.R).Level

    local rawDamagePhys = rData.PhysDmg() * daggersAmount
    local rawDamageMagic = rData.MagicDmg(spellLevel) * daggersAmount

    local totalDamage = 0
    totalDamage = totalDamage + DmgLib.CalculatePhysicalDamage(me, target, rawDamagePhys)
    totalDamage = totalDamage + DmgLib.CalculateMagicalDamage(me, target, rawDamageMagic)    

    return totalDamage
end

---@param target AIHeroClient
---@param drawingMode boolean
function Katarina.GetBestCombo(target, drawingMode)
    local result = {
        CanKill = false,
        Damage = 0,
        Mana = 0,
        SpellStatus = {
            Q = false,
            W = false,
            E = false,
            R = false
        }
    }

    local me = Player

    local QCondition = OriUtils.CanCastSpell(slots.Q, "ks.useQ") and (drawingMode or spells.Q:IsInRange(target))
    local WCondition = OriUtils.CanCastSpell(slots.W, "ks.useW")
    local ECondition = OriUtils.CanCastSpell(slots.E, "ks.useE") and (drawingMode or spells.E:IsInRange(target))
    local RCondition = OriUtils.CanCastSpell(slots.R, "ks.useR")

    local fullHealth = target.Health + target.ShieldAll

    local check = {false, true}
    local dontCheck = {false}

    for _, QVal in ipairs(QCondition and check or dontCheck) do
        local tempDamage = 0
        local tempMana = 0
        local tempStatus = {
            Q = false,
            W = false,
            E = false,
            R = false
        }

        if QVal then
            tempDamage = tempDamage + Katarina.GetSpellDamage(target, slots.Q)
            tempMana = tempMana + spells.Q:GetManaCost()
            tempStatus.Q = true
        end

        for __, EVal in ipairs(ECondition and check or dontCheck) do
            if EVal then
                tempDamage = tempDamage + Katarina.GetSpellDamage(target, slots.E)
                tempMana = tempMana + spells.E:GetManaCost()
                tempStatus.E = true
            end

            for ___, WVal in ipairs(WCondition and check or dontCheck) do
                if WVal then
                    tempDamage = tempDamage + Katarina.GetPassiveDamage(target)
                    tempMana = tempMana + spells.W:GetManaCost()
                    tempStatus.W = true
                end

                for ____, RVal in ipairs(RCondition and check or dontCheck) do
                    if RVal then
                        tempDamage = tempDamage + Katarina.GetRDamage(target, Katarina.GetRDaggersAmount(target))
                        tempMana = tempMana + spells.R:GetManaCost()
                        tempStatus.R = true
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
    end

    return result
end

---@param obj GameObject
function Katarina.IsObjectDagger(obj)
    local objName = obj.Name

    return string.starts_with(objName, "Katarina_") and string.ends_with(objName, "_W_Indicator_Ally")
end

---@param obj GameObject
function Katarina.IsObjectGroundDagger(obj)
    local objName = obj.Name

    return string.starts_with(objName, "Katarina_") and string.ends_with(objName, "_Dagger_Ground_Indicator")
end

function Katarina.CheckCancelR()
    if OriUtils.MGet("combo.useR.cancelNoEnemies") then
        if Katarina.MiscData.IsUlting then
            local me = Player

            local enemiesInsideR = spells.R:GetTargets()

            if #enemiesInsideR == 0 then
                Input.MoveTo(me.ServerPos)
                
                return true
            end

            ---@param elemA AIHeroClient
            ---@param elemB AIHeroClient
            ---@type AIHeroClient
            local closestEnemy = OriUtils.GetFirstElementSort(enemiesInsideR, function(elemA, elemB)
                return me:Distance(elemA) < me:Distance(elemB)
            end)

            if closestEnemy and spells.R:IsLeavingRange(closestEnemy) then
                Input.MoveTo(me.ServerPos)
                
                return true
            end
        end
    end

    return false
end

function Katarina.CastRAfterWInKS()
    local lastCastW = lastCastT[slots.W]
    local curTime = Game.GetTime()

    if Katarina.MiscData.KSCastRAfterW then
        if curTime > lastCastW + 1 then
            Katarina.MiscData.KSCastRAfterW = false
            return false
        else
            if OriUtils.IsSpellReady(slots.R) then
                if Katarina.CastR() then
                    return true
                end
            end
        end
    end

    return false
end

---@param aroundPos Vector
---@param maxDist number|nil
---@return GameObject[]
function Katarina.GetShunpoableUnits(aroundPos, maxDist)
    maxDist = maxDist or 450

    local me = Player

    local result = {}

    local eRange = spells.E.Range

    if aroundPos:Distance(me) > eRange then
        aroundPos = me.ServerPos:Extended(aroundPos, eRange)
    end

    ---@param unit GameObject
    local function AddIfValid(unit)
        if unit and OriUtils.IsValidTarget(unit, eRange) and not unit.IsMe then
            local dist = aroundPos:Distance(unit)

            if dist < maxDist then
                result[#result+1] = unit
            end
        end
    end

    local function AddIfValidDagger(dagger)
        local daggerPos = dagger.Position

        if spells.E:IsInRange(dagger.Position) then
            local dist = aroundPos:Distance(dagger)

            if dist < maxDist then
                result[#result+1] = dagger
            end
        end
    end

    local allHeroes = ObjManager.GetNearby("all", "heroes")
    local allMinions = ObjManager.GetNearby("all", "minions")
    local allDaggers = Katarina.MiscData.Daggers

    for _, hero in ipairs(allHeroes) do
        AddIfValid(hero)
    end

    for _, minion in ipairs(allMinions) do
        AddIfValid(minion)
    end

    for _, dagger in pairs(allDaggers) do
        AddIfValidDagger(dagger)
    end

    return result
end

---@param target AIHeroClient
function Katarina.GapcloseKS(target)
    local qDamage = Katarina.GetSpellDamage(target, slots.Q)
    local eDamage = Katarina.GetSpellDamage(target, slots.E)

    local useQ = OriUtils.CanCastSpell(slots.Q, "ks.useQ")
    local useE = OriUtils.CanCastSpell(slots.E, "ks.useE")

    local heroHealth = target.Health + target.ShieldAll

    if useE then
        if spells.E:IsInRange(target) then
            if useQ then
                if heroHealth < qDamage or heroHealth < qDamage + eDamage then
                    if Katarina.CastE(target.ServerPos) then
                        return true
                    end
                end
            end
        else
            local shunpoUnits = Katarina.GetShunpoableUnits(target.ServerPos, spells.E.Range)
            ---@type GameObject[]
            local possibleUnitsForQ = {}
            ---@type GameObject[]
            local possibleUnitsForE = {}
    
            for _, obj in ipairs(shunpoUnits) do
                local targetDist = obj:Distance(target)
    
                if spells.E:IsInRange(obj) then
                    if targetDist < spells.Q.Range - 40 then
                        possibleUnitsForQ[#possibleUnitsForQ+1] = obj
                    end
    
                    if targetDist < spells.E.Range - 40 and Katarina.IsObjectDagger(obj) then
                        possibleUnitsForE[#possibleUnitsForE+1] = obj
                    end
                end
            end
    
            if heroHealth < qDamage and useQ and not spells.Q:IsInRange(target) then
                ---@param elemA GameObject
                ---@param elemB GameObject
                ---@type GameObject
                local bestObj = OriUtils.GetFirstElementSort(possibleUnitsForQ, function(elemA, elemB)
                    return elemA:Distance(target) < elemB:Distance(target)
                end)
    
                if bestObj then
                    local castPos = bestObj.Position:Extended(target, 40)
    
                    if Katarina.CastE(castPos) then
                        return true
                    end
                end
            end
    
            if heroHealth < eDamage or (heroHealth < eDamage + qDamage and useQ) then
                ---@param elemA GameObject
                ---@param elemB GameObject
                ---@type GameObject
                local bestObj = OriUtils.GetFirstElementSort(possibleUnitsForE, function(elemA, elemB)
                    return elemA:Distance(target) < elemB:Distance(target)
                end)
    
                if bestObj then
                    local castPos = bestObj.Position:Extended(target, 40)
    
                    if Katarina.CastE(castPos) then
                        return true
                    end
                end
            end
        end
    end
end

function fightModes.Killsteal()
    local me = Player

    if Orbwalker.GetMode() == "Combo" or not OriUtils.MGet("ks.onlyCombo") then
        if Katarina.CastRAfterWInKS() then
            return true
        end

        local enemies = ObjManager.GetNearby("enemy", "heroes")
        local enemiesAsHeroes = {}
    
        for _, obj in ipairs(enemies) do
            enemiesAsHeroes[#enemiesAsHeroes+1] = obj.AsHero
        end
    
        local sortedEnemies = TS:SortTargetsForMode(enemiesAsHeroes, "SetnaBest TM")
    
        local isUlting = Katarina.MiscData.IsUlting
        local myPos = Player.ServerPos

        local function CancelR()
            if isUlting then
                Input.MoveTo(myPos)
                return true
            end

            return false
        end

        --SmartKS
        for _, hero in ipairs(sortedEnemies) do
            if OriUtils.IsValidTarget(hero) and OriUtils.MGet("ks.wl." .. hero.CharName, true) then
                if Katarina.GapcloseKS(hero) then
                    return true
                end

                local bestCombo = Katarina.GetBestCombo(hero, false)
    
                local heroPos = hero.ServerPos
                local dist = me:Distance(hero)

                if bestCombo.CanKill then
                    if bestCombo.SpellStatus.Q then
                        if not bestCombo.SpellStatus.R and CancelR() then
                            return true
                        end

                        if Katarina.CastQ(hero) then
                            return true
                        end
                    end
    
                    if bestCombo.SpellStatus.E then
                        if not bestCombo.SpellStatus.R and CancelR() then
                            return true
                        end

                        if Katarina.CastE(heroPos) then
                            return true
                        end
                    end
    
                    if bestCombo.SpellStatus.W and dist < spells.W.SpinRadius and not isUlting then
                        if Katarina.CastW() then
                            if bestCombo.SpellStatus.R then
                                Katarina.MiscData.KSCastRAfterW = true
                            end

                            return true
                        end
                    end
                    
                    local function CanUseOnlyR()
                        return not bestCombo.SpellStatus.Q and not bestCombo.SpellStatus.W and not bestCombo.SpellStatus.E
                    end

                    if bestCombo.SpellStatus.R and CanUseOnlyR() and dist < spells.R.Range / 2 then
                        if Katarina.CastR() then
                            return true
                        end
                    end
                end
            end
        end
    end
end

function fightModes.Flee()
    if OriUtils.CanCastSpell(slots.W, "flee.useW") then
        if Katarina.CastW() then
            return true
        end
    end

    if OriUtils.CanCastSpell(slots.E, "flee.useE") then
        local targetPos = Renderer.GetMousePos()
        local possibleUnits = Katarina.GetShunpoableUnits(targetPos)

        ---@param elemA AIBaseClient
        ---@param elemB AIBaseClient
        local closestToCenter = OriUtils.GetFirstElementSort(possibleUnits, function(elemA, elemB)
            return elemA:Distance(targetPos) < elemB:Distance(targetPos)
        end)

        if closestToCenter then
            if Katarina.CastE(closestToCenter.Position) then
                return true
            end
        end
    end
end

function fightModes.Combo()
    if Katarina.MiscData.IsUlting then
        return false
    end

    local me = Player

    local forcedTarget = TS:GetForcedTarget()

    --Normal Combo
    if OriUtils.CanCastSpell(slots.Q, "combo.useQ") then
        local qRange = spells.Q.Range

        local target = OriUtils.ChooseTarget(forcedTarget, {qRange})
        if target and target:Distance(me) < qRange then
            if Katarina.CastQ(target) then
                return true
            end
        end
    end

    local function ShouldCastE()
        local spellPrio = OriUtils.MGet("combo.spellPrio")

        if spellPrio == 0 then
            if OriUtils.CanCastSpell(slots.Q, "combo.useQ") then
                return false
            else
                return true
            end
        else
            return true
        end
    end

    if OriUtils.CanCastSpell(slots.E, "combo.useE") and ShouldCastE() then
        local eRange = spells.E.Range

        local target = OriUtils.ChooseTarget(forcedTarget, {eRange})
        if target and target:Distance(me) < eRange then
            if OriUtils.MGet("combo.useE.dagger") then
                local validDaggers = {}
                
                local daggerRadius = spells.W.DaggerRadius

                for _, dagger in pairs(Katarina.MiscData.Daggers) do
                    local closestPoint = dagger.Position:Extended(me, daggerRadius)
                    if spells.E:IsInRange(closestPoint) then
                        validDaggers[#validDaggers+1] = dagger
                    end
                end

                ---@param elemA GameObject
                ---@param elemB GameObject
                ---@type GameObject
                local closestDaggerToEnemy = OriUtils.GetFirstElementSort(validDaggers, function(elemA, elemB)
                    return elemA:Distance(target) < elemB:Distance(target)
                end)

                if closestDaggerToEnemy and closestDaggerToEnemy:Distance(target) < spells.W.SpinRadius + daggerRadius then
                    local bestPos = closestDaggerToEnemy.Position:Extended(target, daggerRadius)
                    if Katarina.CastE(bestPos) then
                        return true
                    end
                end
            end

            if OriUtils.MGet("combo.useE.champion") then
                if Katarina.CastE(target.ServerPos) then --TODO: Possibly modify position
                    return true
                end
            end
        end
    end

    if OriUtils.CanCastSpell(slots.W, "combo.useW") then
        if OriUtils.MGet("combo.useW.chase") then 
            local searchRange = spells.E.Range
            
            local target = OriUtils.ChooseTarget(forcedTarget, {searchRange})
            if target and target:Distance(me) < searchRange and OriUtils.IsTargetRunningAway(target) then
                if Katarina.CastW() then
                    return true
                end
            end
        end

        if OriUtils.MGet("combo.useW.near") then
            local spinRadius = spells.W.SpinRadius

            local target = OriUtils.ChooseTarget(forcedTarget, {spinRadius})
            if target and target:Distance(me) < spinRadius then
                if Katarina.CastW() then
                    return true
                end
            end
        end
    end

    if OriUtils.CanCastSpell(slots.R, "combo.useR") then
        if OriUtils.MGet("combo.useR.minEnemies") then
            local nTargets = #spells.R:GetTargets()
            local minTargets = OriUtils.MGet("combo.useR.minEnemies.number")

            if nTargets >= minTargets then
                if Katarina.CastR() then
                    return true
                end
            end
        end
    end
end

function fightModes.Harass()
    if Katarina.MiscData.IsUlting then
        return false
    end

    local me = Player

    local forcedTarget = TS:GetForcedTarget()

    if OriUtils.CanCastSpell(slots.Q, "harass.useQ") then
        local qRange = spells.Q.Range

        local target = OriUtils.ChooseTarget(forcedTarget, {qRange})
        if target and target:Distance(me) < qRange then
            if Katarina.CastQ(target) then
                return true
            end
        end
    end
end

function fightModes.Waveclear()
    local me = Player

    if not (OriUtils.MGet("clear.enemyAround") or not TS:GetTarget(1000)) then
        return false
    end

    if OriUtils.CanCastSpell(slots.Q, "clear.useQ") then
        local qMinions = OriUtils.GetEnemyAndJungleMinions(spells.Q.Range)

        for _, minion in ipairs(qMinions) do
            if Katarina.CastQ(minion) then
                return true
            end
        end
    end

    if OriUtils.CanCastSpell(slots.W, "clear.useW") then
        local wMinions = #OriUtils.GetEnemyAndJungleMinions(spells.W.SpinRadius)
        
        if wMinions >= OriUtils.MGet("clear.useW.minHit") then
            if Katarina.CastW() then
                return true
            end
        end
    end

    if OriUtils.CanCastSpell(slots.E, "clear.useE") then
        local daggers = Katarina.MiscData.Daggers
        local aaRange = Orbwalker.GetTrueAutoAttackRange(me)

        local underTurret = OriUtils.MGet("clear.useE.turret")

        for _, dagger in pairs(daggers) do
            local daggerPos = dagger.Position

            if underTurret or not OriUtils.IsPosUnderTurret(daggerPos) then
                if spells.E:IsInRange(daggerPos) then
                    local dist = me:Distance(dagger)
                    
                    if dist > aaRange then
                        local minionsAroundDagger = #OriUtils.GetEnemyAndJungleMinions(spells.W.SpinRadius, daggerPos)
                        
                        if minionsAroundDagger > 0 then
                            if Katarina.CastE(daggerPos) then
                                return true
                            end
                        end
                    end
                end
            end
        end
    end
end

function fightModes.Lasthit()
    local me = Player

    if not (OriUtils.MGet("lh.enemyAround") or not TS:GetTarget(1000)) then
        return false
    end

    local useQ = OriUtils.CanCastSpell(slots.Q, "lh.useQ")
    local useE = OriUtils.CanCastSpell(slots.E, "lh.useE")

    local minions = OriUtils.GetEnemyAndJungleMinions(spells.E.Range)

    for _, minion in ipairs(minions) do
        local dist = me:Distance(minion)
        local minionHealth = minion.Health

        if useE then
            local aaRange = Orbwalker.GetTrueAutoAttackRange(me)

            if dist > aaRange and minionHealth < Katarina.GetSpellDamage(minion, slots.E) then
                if Katarina.CastE(minion.ServerPos) then
                    return true
                end
            end
        end

        if useQ then
            if dist < spells.Q.Range and minionHealth < Katarina.GetSpellDamage(minion, slots.Q) then
                if Katarina.CastQ(minion) then
                    return true
                end
            end
        end
    end
end

--Not using lagFree on purpose this time
function events.OnTick(lagFree)
    OriUtils.CheckFlashSlot()

    if not OriUtils.ShouldRunLogic() then
        return
    end

    if Katarina.CheckCancelR() then
        return
    end

    if fightModes.Killsteal and fightModes.Killsteal() then
        return
    end

    if fightModes.ExtraModes and fightModes.ExtraModes() then
        return
    end

    local modeToExecute = fightModes[Orbwalker.GetMode()]
    if modeToExecute and modeToExecute() then
        return
    end
end

local drawData = {
    {slot = slots.Q, id = "Q", displayText = "Q [Bouncing Blade]", range = spells.Q.Range},
    {slot = slots.W, id = "W", displayText = "W [Preparation]", range = spells.W.Range},
    {slot = slots.E, id = "E", displayText = "E [Shunpo]", range = spells.E.Range},
    {slot = slots.R, id = "R", displayText = "R [Death Lotus]", range = spells.R.Range}
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

    if OriUtils.MGet("draw.daggers") then
        local color = OriUtils.MGet("draw.daggers.color")

        for _, dagger in pairs(Katarina.MiscData.Daggers) do
            local daggerPos = dagger.Position

            Renderer.DrawLine3D(myPos, daggerPos, 2, color)
            Renderer.DrawCircle3D(daggerPos, 200, 30, 3, color)
        end
    end

    if OriUtils.MGet("draw.daggersDuration") then
        local color = OriUtils.MGet("draw.daggersDuration.color")
        local curTime = Game.GetTime()

        for _, groundDagger in pairs(Katarina.MiscData.GroundDaggers) do
            ---@type Vector
            local pos = groundDagger.obj.Position
            local creationTime = groundDagger.creationTime
            local remainingTime = (creationTime + 4) - curTime

            local circleRadius = OriUtils.GetTimeCircleRadius(400, 4, remainingTime)

            Renderer.DrawCircle3D(pos, circleRadius, 30, 2, color)

            if remainingTime > 0 then 
                local screenPos = pos:ToScreen()
                screenPos.x = screenPos.x + 25
                screenPos.y = screenPos.y + 25
                Renderer.DrawText(screenPos, Vector(0, 0), format("%.1f", remainingTime), color, 20)
            end
        end
    end

    if OriUtils.MGet("draw.smartKSRState") then
        local RState = OriUtils.MGet("ks.useR")

        local text = RState and "SmartKS R: On" or "SmartKS R: Off"
        local color = RState and 0x00FF00FF or 0xFF0000FF

        Renderer.DrawTextOnPlayer(text, color)
    end

    if OriUtils.MGet("draw.rCalcsState") then
        local rCalc = OriUtils.MGet("global.rDaggersMode")

        local text = rCalc and "R Calcs: Dynamic" or "R Calcs: Static"
        local color = rCalc and 0x00FF00FF or 0xFF0000FF

        Renderer.DrawTextOnPlayer(text, color)
    end

    --[[
    local allHeroes = TS:GetTargets(huge)

    for _, hero in ipairs(allHeroes) do
        local daggersAmount = Katarina.GetDynamicRDaggers(hero)
        local screenPos = hero.Position:ToScreen()

        Renderer.DrawText(screenPos, Vector(0, 0, 40), tostring(daggersAmount), 0xFFFFFFFF)
    end
    --]]
end

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
    local useR = OriUtils.CanCastSpell(slots.R, "combo.useR")

    damageToDeal = damageToDeal + DmgLib.GetAutoAttackDamage(me, target, true)

    if useElectrocute then
        damageToDeal = damageToDeal + OriUtils.GetElectrocuteDamage(target)
    end

    if useQ then
        damageToDeal = damageToDeal + Katarina.GetSpellDamage(target, slots.Q)

        --damageToDeal = damageToDeal + Katarina.GetPassiveDamage(target)
    end

    if useW then
        damageToDeal = damageToDeal + Katarina.GetPassiveDamage(target)
    end

    if useE then
        damageToDeal = damageToDeal + Katarina.GetSpellDamage(target, slots.E)
    end

    if useR then
        damageToDeal = damageToDeal + Katarina.GetRDamage(target, Katarina.GetRDaggersAmount(target))
    end

    insert(dmgList, damageToDeal)
end

---@param obj GameObject
function events.OnCreateObject(obj)
    if obj and obj.IsValid then
        if Katarina.IsObjectDagger(obj) then
            Katarina.MiscData.Daggers[obj.Handle] = obj
        end

        if Katarina.IsObjectGroundDagger(obj) then
            Katarina.MiscData.GroundDaggers[obj.Handle] = {creationTime = Game.GetTime(), obj = obj}
        end
    end
end

---@param obj GameObject
function events.OnDeleteObject(obj)
    if obj and obj.IsValid then
        --if Katarina.IsObjectDagger(obj) then
            Katarina.MiscData.Daggers[obj.Handle] = nil
        --end

        --if Katarina.IsObjectGroundDagger(obj) then
            Katarina.MiscData.GroundDaggers[obj.Handle] = nil
        --end
    end
end

---@param obj GameObject
---@param buffInst BuffInst
function events.OnBuffGain(obj, buffInst)
    if obj and buffInst then
        if obj.IsMe then
            if buffInst.Name == "katarinarsound" then
                Katarina.MiscData.IsUlting = true
            end

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
            if buffInst.Name == "katarinarsound" then
                Katarina.MiscData.IsUlting = false
            end

            if buffInst.Name == OriUtils.Perks.Electrocute.BuffName then
                OriUtils.Perks.Electrocute.HasBuff = false
            end
        end
    end
end

function events.OnPreAttack(args)
    if Katarina.MiscData.IsUlting then
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

function Katarina.RegisterEvents()
    for eventName, eventId in pairs(Enums.Events) do
        if events[eventName] then
            EventManager.RegisterCallback(eventId, events[eventName])
        end
    end
end

function Katarina.InitMenu()
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

    local function KatarinaMenu()
        Menu.Text("Version: " .. SCRIPT_VERSION, true)
        Menu.Text("Last Updated: " .. SCRIPT_LAST_UPDATED, true)
        if SCRIPT_IS_BETA then
            Menu.ColoredText("This is a beta, if you find any issues, report them to " .. SCRIPT_AUTHOR, 0xFFFF00FF, true)
        end

        Menu.NewTree("Katarina.globalMenu", "Global Settings", function()
            --Menu.Dropdown("Katarina.global.rDaggersMode", "R Damage Calculations", 0, {"Static", "Dynamic"})
            Menu.Keybind("Katarina.global.rDaggersMode", "R Damage Calcs: Static/Dynamic", string.byte("Z"), true, false)

            Menu.Indent(function()
                Menu.Slider("Katarina.global.rDaggers", "Static: R Daggers to consider in calculations", 15, 1, 15, 1)
                Menu.ColoredText("Dynamic mode only considers the daggers that would hit the enemy if this started moving away from Katarina at their current speed", 0x00FFFFFF)
                --[[
                    if rCalculationsMode == 0 then 
                        Menu.Slider("Katarina.global.rDaggers", "R Daggers to consider in calculations", 15, 1, 15, 1)
                    elseif rCalculationsMode == 1 then
                        Menu.ColoredText("Dynamic mode only considers the daggers that would hit the enemy if this started moving away from Katarina at their current speed", 0x00FFFFFF)
                    end
                --]]
            end)
        end)

        Menu.NewTree("Katarina.comboMenu", "Combo Settings", function()
            Menu.Dropdown("Katarina.combo.spellPrio", "Combo to Champion Spell Priority", 0, {"Q >> E", "E >> Q"})

            Menu.ColumnLayout("Katarina.comboMenu.QW", "Katarina.comboMenu.QW", 2, true, function()
                QHeader()

                Menu.Checkbox("Katarina.combo.useQ", "Enable Q", true)

                Menu.NextColumn()

                WHeader()

                Menu.Checkbox("Katarina.combo.useW", "Enable W", true)
                Menu.Indent(function()
                    Menu.Checkbox("Katarina.combo.useW.near", "If enemy is near you", true)
                    Menu.Checkbox("Katarina.combo.useW.chase", "If enemy is running away from you", false)
                end)
            end)

            Menu.Separator()

            Menu.ColumnLayout("Katarina.comboMenu.ER", "Katarina.comboMenu.ER", 2, true, function()
                EHeader()

                Menu.Checkbox("Katarina.combo.useE", "Enable E", true)
                Menu.Indent(function()
                    Menu.Checkbox("Katarina.combo.useE.dagger", "To Dagger", true)
                    --Menu.Keybind("Katarina.combo.useE.champion", "To Champion: Off/On", string.byte("Z"), true, false, true)
                    Menu.Checkbox("Katarina.combo.useE.champion", "To Champion", false)
                end)

                Menu.NextColumn()

                RHeader()

                Menu.Checkbox("Katarina.combo.useR", "Enable R", true)
                Menu.Indent(function()
                    Menu.Checkbox("Katarina.combo.useR.minEnemies", "Use if X enemies around you", true)
                    Menu.Indent(function()
                        Menu.Slider("Katarina.combo.useR.minEnemies.number", "Min enemies", 3, 1, 3, 1)
                    end)
                    --Menu.Checkbox("Katarina.combo.useR.killable", "Use if enemy killable", true)
                    Menu.Checkbox("Katarina.combo.useR.cancelNoEnemies", "Cancel R if no enemies around", true)
                end)
            end)
        end)

        Menu.NewTree("Katarina.harassMenu", "Harass Settings", function()
            QHeader()

            Menu.Checkbox("Katarina.harass.useQ", "Enable Q", true)
        end)

        Menu.NewTree("Katarina.clearMenu", "Clear Settings", function()
            Menu.Checkbox("Katarina.clear.enemyAround", "Clear even if enemies around", false)

            Menu.Separator()

            QHeader()

            Menu.Checkbox("Katarina.clear.useQ", "Enable Q", true)

            Menu.Separator()

            WHeader()

            Menu.Checkbox("Katarina.clear.useW", "Enable W", true)
            Menu.Indent(function()
                Menu.Slider("Katarina.clear.useW.minHit", "Min hit", 3, 1, 5, 1)
            end)

            Menu.Separator()

            EHeader()

            Menu.Checkbox("Katarina.clear.useE", "Enable E to daggers", true)
            Menu.Indent(function()
                Menu.Checkbox("Katarina.clear.useE.turret", "Use under turret", false)
            end)
        end)

        Menu.NewTree("Katarina.lhMenu", "Last hit Settings", function()
            Menu.Checkbox("Katarina.lh.enemyAround", "Last hit even if enemies around", false)

            Menu.Separator()
            
            QHeader()

            Menu.Checkbox("Katarina.lh.useQ", "Enable Q", true)

            Menu.Separator()

            EHeader()

            Menu.Checkbox("Katarina.lh.useE", "Enable E on killable minions outside AA range", false)
        end)

        Menu.NewTree("Katarina.fleeMenu", "Flee Settings", function()
            WHeader()

            Menu.Checkbox("Katarina.flee.useW", "Enable W to flee", true)

            Menu.Separator()

            EHeader()

            Menu.Checkbox("Katarina.flee.useE", "Enable E to flee", true)
        end)

        Menu.NewTree("Katarina.ksMenu", "Smart KS", function()
            Menu.Checkbox("Katarina.ks.useQ", "Use Q in Smart KS", true)
            Menu.Checkbox("Katarina.ks.useW", "Use W in Smart KS", true)
            Menu.Checkbox("Katarina.ks.useE", "Use E in Smart KS", true)
            Menu.Keybind("Katarina.ks.useR", "Use R in Smart KS", string.byte("T"), true, true)

            Menu.Checkbox("Katarina.ks.onlyCombo", "Smart KS only during Combo", true)

            Menu.NewTree("Katarina.ksMenu.whitelist", "Smart KS Whitelist", function()                
                local enemyHeroes = ObjManager.Get("enemy", "heroes")
                
                local addedWL = {}
                
                for _, obj in pairs(enemyHeroes) do
                    local hero = obj.AsHero
                    local heroName = hero.CharName
                    
                    if hero and not addedWL[heroName] then
                        Menu.Checkbox("Katarina.ks.wl." .. heroName, "Smart KS on " .. heroName, true)
                        
                        addedWL[heroName] = true
                    end
                end
            end)
        end)

        Menu.NewTree("Katarina.drawMenu", "Draw Settings", function()
            OriUtils.AddDrawMenu(drawData)

            Menu.Separator()

            Menu.Checkbox("Katarina.draw.smartKSRState", "Print Smart KS R state", true)
            Menu.Checkbox("Katarina.draw.rCalcsState", "Print R Calculations mode state", true)

            Menu.Separator()

            Menu.Checkbox("Katarina.draw.daggers", "Draw daggers indicators", false)
            Menu.ColorPicker("Katarina.draw.daggers.color", "Daggers color", SCRIPT_COLOR)

            Menu.Separator()

            Menu.Checkbox("Katarina.draw.daggersDuration", "Draw daggers duration", false)
            Menu.ColorPicker("Katarina.draw.daggersDuration.color", "Daggers duration circle color", SCRIPT_COLOR)
        end)

        Menu.Text("Author: " .. SCRIPT_AUTHOR, true)
    end

    Menu.RegisterMenu(SCRIPT_NAME, SCRIPT_NAME, KatarinaMenu)
end

function OnLoad()
    Katarina.InitMenu()

    Katarina.RegisterEvents()

    OriUtils.InitElectrocute()

    return true
end
