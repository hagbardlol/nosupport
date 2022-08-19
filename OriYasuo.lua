if Player.CharName ~= "Yasuo" then return end

local SCRIPT_NAME = "Ori Yasuo"
local SCRIPT_VERSION_UPDATER = "2.2.5"
local SCRIPT_VERSION = SCRIPT_VERSION_UPDATER
local SCRIPT_LAST_UPDATED = "08/18/2022"
local SCRIPT_AUTHOR = "Orietto"
local SCRIPT_IS_BETA = false

if SCRIPT_IS_BETA then
    SCRIPT_VERSION = SCRIPT_VERSION .. " Beta"
else
    SCRIPT_VERSION = SCRIPT_VERSION .. " Release"
end

local SCRIPT_COLOR = 0x0BDFE3FF

module(SCRIPT_NAME, package.seeall, log.setup)
clean.module(SCRIPT_NAME, clean.seeall, log.setup)

local insert, sort = table.insert, table.sort
local huge, pow, min, max = math.huge, math.pow, math.min, math.max

local SDK = _G.CoreEx

SDK.AutoUpdate("https://raw.githubusercontent.com/hagbardlol/nosupport/main/OriYasuo.lua", SCRIPT_VERSION_UPDATER)

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

local slotToString = {
    [slots.Q] = "Q",
    [slots.W] = "W",
    [slots.E] = "E",
    [slots.R] = "R"
}

local dmgTypes = {
    Physical = Enums.DamageTypes.Physical,
    Magical = Enums.DamageTypes.Magical,
    True = Enums.DamageTypes.True
}

local damages = {
    Q = {
        Base = {20, 45, 70, 95, 120},
        TotalAD = 1.0,
        Type = dmgTypes.Physical
    },
    E = {
        Base = {60, 70, 80, 90, 100},
        BonusAD = 0.2,
        TotalAP = 0.6,
        Type = dmgTypes.Magical
    },
    R = {
        Base = {200, 300, 400},
        BonusAD = 1.5,
        Type = dmgTypes.Physical
    }
}

local spells = {
    Q1 = Spell.Skillshot({
        Slot = slots.Q,
        Delay = 0.4,
        Speed = huge,
        Range = 475,
        Radius = 45 / 2,
        Type = "Linear"
    }),
    Q3 = Spell.Skillshot({
        Slot = slots.Q,
        Delay = 0.4,
        Speed = 1200,
        Range = 1050,
        Radius = 90 / 2,
        Type = "Linear",
        Collisions = {Heroes = false, Minions = false, WindWall = true}
    }),
    QCircle = {
        Radius = 220,
        MinDistToEnd = 300
    },
    W = Spell.Skillshot({
        Slot = slots.W,
        Range = 400,
        Type = "Linear"
    }),
    QCircle = {
        Radius = 220,
        MinDistToEnd = 300
    },
    E = Spell.Targeted({
        Slot = slots.E,
        Speed = 750,
        Range = 475
    }),
    R = Spell.Skillshot({
        Slot = slots.R,
        Delay = 0,
        Speed = huge,
        Range = 1400,
        Radius = 400,
        Type = "Circular"
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

local Yasuo = {}

Yasuo.rBuffEnemies = {}

Yasuo.MiscData = {}
Yasuo.MiscData.LastAttackSpeedMod = 0
Yasuo.MiscData.Q3BuffEndT = nil
Yasuo.MiscData.LastQE = 0

local qCastTimers = { [slots.Q] = 0.25, [slots.E] = 0.15 }
function Yasuo.CastQ(pos)
    if not OriUtils.CheckCastTimers(qCastTimers) then return false end

    if Orbwalker.IsWindingUp() then return false end

    return OriUtils.CastSpell(slots.Q, pos)
end

local wCastTimers = { [slots.W] = 0.25 }
function Yasuo.CastW(pos)
    if not OriUtils.CheckCastTimers(wCastTimers) then return false end

    return OriUtils.CastSpell(slots.W, pos)
end

local eCastTimers = { [slots.E] = 0.1, [slots.Q] = 0.15 }
function Yasuo.CastE(unit)
    if not OriUtils.CheckCastTimers(eCastTimers) then return false end

    if Orbwalker.IsWindingUp() then return false end

    return OriUtils.CastSpell(slots.E, unit)
end

local rCastTimers = { [slots.R] = 0.25 }
function Yasuo.CastR(pos)
    if not OriUtils.CheckCastTimers(rCastTimers) then return false end

    return OriUtils.CastSpell(slots.R, pos)
end

function Yasuo.GetQDelay()
    local bonusASPercent = (Player.AttackSpeedMod - 1) * 100
    return 0.4 * (1 - (0.01 * min(bonusASPercent, 111.1) / 1.67))
end

local slotToDamageTable = {
    [slots.Q] = damages.Q,
    [slots.E] = damages.E,
    [slots.R] = damages.R
}
function Yasuo.GetDamage(target, slot)
    local me = Player

    local rawDamage = 0
    local dmgType = nil

    local spellLevel = me:GetSpell(slot).Level

    local data = slotToDamageTable[slot]

    if data then
        dmgType = data.Type
        rawDamage = data.Base[spellLevel]

        if data.TotalAD then
            rawDamage = rawDamage + (data.TotalAD * me.TotalAD)
        end

        if data.BonusAD then
            rawDamage = rawDamage + (data.BonusAD * me.BonusAD)
        end

        if data.TotalAP then
            rawDamage = rawDamage + (data.TotalAP * me.TotalAP)
        end

        if dmgType == Enums.DamageTypes.Physical then
            return DmgLib.CalculatePhysicalDamage(me, target, rawDamage)
        elseif dmgType == Enums.DamageTypes.Magical then
            return DmgLib.CalculateMagicalDamage(me, target, rawDamage)
        else
            return rawDamage
        end
    end

    return 0
end

function Yasuo.HasQ3()
    return Player:GetSpell(slots.Q).Name == "YasuoQ3Wrapper"
end

function Yasuo.PosAfterE(target)
    return Player.ServerPos:Extended(target, spells.E.Range)
end

---@param target AIBaseClient
function Yasuo.CanCastE(target)
    return not target:GetBuff("YasuoE") --TODO: Get index
end

---@param target AIHeroClient
---@return number|nil @Returns a number if can cast R on target, else returns nil
function Yasuo.GetLongestRBuffDuration(target)
    local longestDuration = 0
    local curTime = Game.GetTime()

    local enemyBuffs = Yasuo.rBuffEnemies[target.Handle]

    if enemyBuffs then
        for _, endTime in pairs(enemyBuffs) do
            local durationLeft = endTime - curTime

            if durationLeft > longestDuration then
                longestDuration = durationLeft
            end
        end
    end

    if longestDuration == 0 then
        return nil
    end

    return longestDuration
end

function Yasuo.GetLimitRFall()
    local baseLimit = OriUtils.MGet("combo.useR.fallLimit") * 0.001

    return baseLimit + (Game.GetLatency() / 1000) * 2
end

---@param targets AIHeroClient[]
function Yasuo.GetGroupTimeLeftR(targets)
    local firstToFallT = huge

    for _, hero in ipairs(targets) do
        local timeLeft = Yasuo.GetLongestRBuffDuration(hero)

        if timeLeft < firstToFallT then
            firstToFallT = timeLeft
        end
    end

    return firstToFallT
end

---@param mainTarget AIHeroClient
---@return AIHeroClient[]
function Yasuo.GetAirborneEnemiesAround(mainTarget)
    local result = {}

    local pos = mainTarget.ServerPos

    local enemyHeroes = ObjManager.Get("enemy", "heroes")

    for _, hero in pairs(enemyHeroes) do
        local enemy = hero.AsHero

        if OriUtils.IsValidTarget(enemy, spells.R.Radius, pos) and Yasuo.GetLongestRBuffDuration(enemy) then
            result[#result+1] = enemy
        end
    end

    return result
end

function Yasuo.UpdateQDelay()
    local curMod = Player.AttackSpeedMod

    if curMod ~= Yasuo.MiscData.LastAttackSpeedMod then
        Yasuo.MiscData.LastAttackSpeedMod = curMod

        local newDelay = Yasuo.GetQDelay()
        spells.Q1.Delay = newDelay
        spells.Q3.Delay = newDelay
    end
end

---@param pos Vector
---@param forcedHero AIHeroClient
---@return boolean, boolean @returns hasHero, hasMinion
function Yasuo.PosHasQCircleTargets(pos, forcedHero)
    local hasHero, hasMinion = false, false

    local qCircle = spells.QCircle

    local enemyHeroes = ObjManager.GetNearby("enemy", "heroes") --GetNearby since Yasuo's dash doesn't go over 1500 units :P
    for _, hero in ipairs(enemyHeroes) do
        local enemy = hero.AsHero

        if OriUtils.IsValidTarget(enemy, qCircle.Radius, pos) then
            if forcedHero and forcedHero.Handle == enemy.Handle or not forcedHero then
                hasHero = true
                break
            end
        end
    end

    local minions = OriUtils.GetEnemyAndJungleMinions(qCircle.Radius, pos)
    if #minions > 0 then
        hasMinion = true
    end

    return hasHero, hasMinion
end

---@param target AIBaseClient|nil
---@return AIBaseClient
function Yasuo.GetDashableObj(target)
    ---@type Vector
    local pos = target and target.ServerPos or Renderer.GetMousePos()

    local me = Player
    local eRange = spells.E.Range

    local possibleDash = {}

    local distToMe = pos:Distance(me)

    local function IsEndPosCloser(unit)
        local posAfterE = Yasuo.PosAfterE(unit)

        return posAfterE:Distance(pos) < distToMe
    end

    local function IsUnitSuitable(unit)
        return Yasuo.CanCastE(unit) and IsEndPosCloser(unit)
    end

    local enemyHeroes = ObjManager.GetNearby("enemy", "heroes")

    for _, obj in ipairs(enemyHeroes) do
        local hero = obj.AsHero

        if OriUtils.IsValidTarget(hero, eRange) and IsUnitSuitable(hero) then
            possibleDash[#possibleDash+1] = hero
        end
    end

    local minions = OriUtils.GetEnemyAndJungleMinions(eRange, me.ServerPos)

    for _, minion in ipairs(minions) do
        if IsUnitSuitable(minion) then
            possibleDash[#possibleDash+1] = minion
        end
    end

    if #possibleDash == 0 then
        return nil
    end

    ---@param elemA AIBaseClient
    ---@param elemB AIBaseClient
    local bestObj = OriUtils.GetFirstElementSort(possibleDash, function(elemA, elemB)
        return Yasuo.PosAfterE(elemA):Distance(pos) < Yasuo.PosAfterE(elemB):Distance(pos)
    end)

    return bestObj
end

---@param enemyHero AIHeroClient
---@param menuHealth number
---@param menuAirborne number @integer
---@param fallLimit number
---@return boolean, number|nil, boolean @Second return value indicates if menuAirborne check was valid and how many airborne enemies are near target. Third return value indicates if there's time to do the minicombo before ulting
function Yasuo.SatisfiesRConditions(enemyHero, menuHealth, menuAirborne, fallLimit)
    local longestBuffDuration = Yasuo.GetLongestRBuffDuration(enemyHero)

    if not (OriUtils.IsValidTarget(enemyHero, spells.R.Range) and longestBuffDuration) then
        return false, nil, false
    end

    local enemiesAround = Yasuo.GetAirborneEnemiesAround(enemyHero)

    if #enemiesAround >= menuAirborne then
        local firstToFall = Yasuo.GetGroupTimeLeftR(enemiesAround)

        if firstToFall <= fallLimit then
            return true, #enemiesAround, false
        else
            return false, #enemiesAround, true --We return early here to maximize damage on airborne targets before using R
        end
    else
        local targetHP = enemyHero.HealthPercent * 100

        if targetHP <= menuHealth then
            if longestBuffDuration <= fallLimit then 
                return true, nil, false
            else
                return false, nil, true --We return early here to maximize damage on airborne targets before using R
            end
        end
    end
    
    return false, nil, false
end

---@param menuHealth number
---@param menuAirborne number @integer
---@param fallLimit number
---@param menuMaxDamage boolean
---@return AIHeroClient|nil, boolean @Second return value indicated if should do a minicombo
function Yasuo.GetBestRTarget(menuHealth, menuAirborne, fallLimit, menuMaxDamage)
    local enemyHeroes = ObjManager.GetNearby("enemy", "heroes")

    local mostAirborneEnemies = {amount = 0, centerUnit = nil}

    local validTargets = {}

    local shouldMiniCombo = false

    for _, obj in ipairs(enemyHeroes) do
        local hero = obj.AsHero

        local shouldCast, numAirborne, shouldWait = Yasuo.SatisfiesRConditions(hero, menuHealth, menuAirborne, fallLimit)

        shouldMiniCombo = shouldWait and menuMaxDamage

        if shouldCast or shouldMiniCombo then
            validTargets[hero.Handle] = true
        end

        if numAirborne and numAirborne > mostAirborneEnemies.amount then
            mostAirborneEnemies.amount = numAirborne
            mostAirborneEnemies.centerUnit = hero
        end
    end

    if mostAirborneEnemies.amount > 0 then
        if validTargets[mostAirborneEnemies.centerUnit.Handle] then
            return mostAirborneEnemies.centerUnit, shouldMiniCombo
        end
    else
        local indexedTable = {} --Hackish
        for handle in pairs(validTargets) do
            indexedTable[#indexedTable+1] = ObjManager.GetObjectByHandle(handle).AsHero
        end

        ---@param elemA AIHeroClient
        ---@param elemB AIHeroClient
        local bestTarget = OriUtils.GetFirstElementSort(indexedTable, function(elemA, elemB)
            return elemA.HealthPercent < elemB.HealthPercent
        end)

        return bestTarget, shouldMiniCombo
    end

    return nil, false
end

---@param forcedTarget AIHeroClient|nil
---@return boolean, Vector|nil, boolean|nil @returns if R should be casted and where. Third return value indicates if should do a mini combo
function Yasuo.ShouldCastR(forcedTarget)
    local target = nil

    local menuHealth = OriUtils.MGet("combo.useR.minHealth")
    local menuAirborne = OriUtils.MGet("combo.useR.enemyCount")
    local fallLimit = Yasuo.GetLimitRFall()

    local maximizeDamage = OriUtils.MGet("combo.useR.maxDamage")

    local shouldMiniCombo = false

    if forcedTarget then
        local shouldCast, _, shouldWait = Yasuo.SatisfiesRConditions(forcedTarget, menuHealth, menuAirborne, fallLimit)

        shouldMiniCombo = shouldWait and maximizeDamage

        if shouldCast or shouldMiniCombo then 
            target = forcedTarget
        end
    elseif not forcedTarget then
        target, shouldMiniCombo = Yasuo.GetBestRTarget(menuHealth, menuAirborne, fallLimit, maximizeDamage)
    end

    if not target then
        return false, nil, nil
    end

    return true, target.ServerPos, shouldMiniCombo
end

---@param target AIHeroClient
function Yasuo.GapcloseToTarget(target)
    local minDist = OriUtils.MGet("combo.useE.GC.minDist")

    if Player:Distance(target) > minDist then
        local dashObj = Yasuo.GetDashableObj(target)

        if dashObj then
            local posAfterE = Yasuo.PosAfterE(dashObj)

            if not OriUtils.IsPosUnderTurret(posAfterE) or OriUtils.MGet("combo.useE.GC.turret") then
                if Yasuo.CastE(dashObj) then
                    return true
                end
            end
        end
    end

    return false
end

---@param target AIHeroClient
function Yasuo.KiteAroundTarget(target)
    local turretCond = OriUtils.MGet("combo.useE.kiting.turret")
    local maxHealth = OriUtils.MGet("combo.useE.kiting.maxHealth")
    local maxDist = OriUtils.MGet("combo.useE.kiting.maxDist")

    maxDist = maxDist * maxDist

    if target.HealthPercent * 100 < maxHealth then
        return false
    end

    local targetPos = target.ServerPos
    local eRange = spells.E.Range

    ---@param unit AIMinionClient
    local function ShouldKite(unit)
        if not (OriUtils.IsValidTarget(unit, eRange) and Yasuo.CanCastE(unit)) then
            return false
        end

        local posAfterE = Yasuo.PosAfterE(unit)

        if posAfterE:DistanceSqr(targetPos) > maxDist then
            return false
        end

        if OriUtils.IsPosUnderTurret(posAfterE) and not turretCond then
            return false
        end

        return true
    end

    local minions = OriUtils.GetEnemyAndJungleMinions(eRange)

    for _, obj in ipairs(minions) do
        local minion = obj.AsMinion

        if ShouldKite(minion) then
            if Yasuo.CastE(minion) then
                return true
            end
        end
    end

    return false
end

---@param target AIHeroClient
function Yasuo.CanGapcloseTo(target)
    if not OriUtils.MGet("combo.useE") then
        return false
    end
    
    local me = Player

    local originalDist = me:Distance(target)

    ---@param unit AIBaseClient
    local function IsValid(unit)
        if not OriUtils.IsValidTarget(unit, originalDist) then
            return false
        end

        if not Yasuo.CanCastE(unit) then
            return false
        end

        local posAfterE = Yasuo.PosAfterE(unit)

        if posAfterE:Distance(target) < originalDist then
            return true
        end

        return false
    end

    local minions = OriUtils.GetEnemyAndJungleMinions(originalDist)

    for _, minion in ipairs(minions) do
        if IsValid(minion) then
            return true
        end
    end

    local heroes = ObjManager.GetNearby("enemy", "heroes")

    for _, obj in ipairs(heroes) do
        if IsValid(obj.AsHero) then
            return true
        end
    end

    return false
end

---@param target AIHeroClient
function Yasuo.ComboKillable(target)
    local me = Player

    local damageToDeal = 0
    local targetHealth = target.Health + target.ShieldAll

    local useQ = OriUtils.MGet("combo.useQ") and me:GetSpell(slots.Q).Level >= 1
    local useE = OriUtils.MGet("combo.useE") and me:GetSpell(slots.E).Level >= 1
    local useR = OriUtils.CanCastSpell(slots.R, "combo.useR") and me:GetSpell(slots.R).Level >= 1

    damageToDeal = DmgLib.GetAutoAttackDamage(me, target, true) * 3

    if useQ then
        damageToDeal = damageToDeal + Yasuo.GetDamage(target, slots.Q)
    end

    if useE then
        damageToDeal = damageToDeal + Yasuo.GetDamage(target, slots.E)
    end

    if useR then
        damageToDeal = damageToDeal + Yasuo.GetDamage(target, slots.R)
    end

    return targetHealth < damageToDeal
end

function Yasuo.GetHitchance(slot, isQ3)
    local hc = 0.5

    if slot == slots.Q then
        if isQ3 then
            hc = OriUtils.MGet("hc.Q3") * 0.01
        else
            hc = OriUtils.MGet("hc.Q1") * 0.01
        end
    end

    return hc
end

function Yasuo.ShouldQ3Combo(unit, expireQ3)
    if OriUtils.MGet("combo.useQ.alwaysQ3") then
        return true
    end

    if expireQ3 then
        return true
    end

    if not OriUtils.MGet("combo.useE") then
        return true
    end

    if not (Player:GetSpell(slots.E).Level > 0) then
        return true
    end

    if not Yasuo.CanGapcloseTo(unit) then
        return true
    end

    if not Yasuo.ComboKillable(unit) then
        return true
    end

    return false
end

---@param minion AIMinionClient
function Yasuo.IsMinionKillableWith(minion, useQ, useE)
    local targetHealth = minion.Health + minion.ShieldAll

    if useQ and useE then
        return targetHealth < Yasuo.GetDamage(minion, slots.Q) + Yasuo.GetDamage(minion, slots.E)
    elseif useQ then
        return targetHealth < Yasuo.GetDamage(minion, slots.Q)
    elseif useE then
        return targetHealth < Yasuo.GetDamage(minion, slots.E)
    end

    return false
end

function Yasuo.Beyblade()
    local mousePos = Renderer.GetMousePos()

    local forcedTarget = TS:GetForcedTarget()

    local preESearchRange = spells.Flash.Range + spells.QCircle.Radius + spells.E.Range
    local postESearchRange = spells.Flash.Range + spells.QCircle.Radius

    local farTarget = OriUtils.ChooseTarget(forcedTarget, {preESearchRange})
    local closeTarget = OriUtils.ChooseTarget(forcedTarget, {postESearchRange})

    Orbwalker.Orbwalk(mousePos, farTarget)

    local flashReady = spells.Flash.Slot and OriUtils.IsSpellReady(spells.Flash.Slot)

    if not (flashReady and OriUtils.IsSpellReady(slots.Q)) then
        return
    end

    if not Yasuo.HasQ3() then
        return
    end

    if OriUtils.IsDashing() then
        if closeTarget then
            if Yasuo.CastQ(Player.ServerPos) then
                local targetPos = closeTarget.ServerPos

                delay(50, function()
                    OriUtils.CastFlash(targetPos)
                end)

                if OriUtils.CanCastSpell(slots.R, "bb.useR") then
                    delay(250, function()
                        Yasuo.CastR(targetPos)
                    end)
                end
            end
        end
    else
        if OriUtils.IsSpellReady(slots.E) then
            if farTarget then
                local dashObj = Yasuo.GetDashableObj(farTarget)

                if dashObj and dashObj.Handle ~= farTarget.Handle then
                    local endPos = Yasuo.PosAfterE(dashObj)

                    if endPos:Distance(farTarget) < postESearchRange then
                        if Yasuo.CastE(dashObj) then
                            return true
                        end
                    end
                end
            end
        end
    end
end

---@param targetRPos Vector
function Yasuo.MiniCombo(targetRPos)
    if not OriUtils.CanCastSpell(slots.R, "combo.useR") then
        return false
    end

    local eRange = spells.E.Range
    local rRange = spells.R.Range

    local me = Player

    if OriUtils.IsDashing() then
        if OriUtils.IsSpellReady(slots.Q) then
            if Yasuo.CastQ(me.ServerPos) then
                delay(50, function()
                    Yasuo.CastR(targetRPos)
                end)

                return true
            end
        end
    else
        if not OriUtils.IsSpellReady(slots.E) then
            return false
        end

        ---@param endPos AIBaseClient
        local function IsValid(unit)
            if me:Distance(unit) > eRange then
                return false
            end

            local endPos = Yasuo.PosAfterE(unit)

            if endPos:Distance(targetRPos) < rRange and Yasuo.CanCastE(unit) then
                return true
            end

            return false
        end

        local enemyHeroes = ObjManager.GetNearby("enemy", "heroes")

        for _, obj in ipairs(enemyHeroes) do
            local hero = obj.AsHero

            if OriUtils.IsValidTarget(hero) and IsValid(hero) then
                if Yasuo.CastE(hero) then
                    return true
                end
            end
        end

        local minions = OriUtils.GetEnemyAndJungleMinions(eRange)

        for _, minion in ipairs(minions) do
            if IsValid(minion) then
                if Yasuo.CastE(minion) then
                    return true
                end
            end
        end
    end
end

function Yasuo.ShouldBlockSpell()
    if not OriUtils.CanCastSpell(slots.W, "misc.useWTargeted") then
        return false
    end

    local blockMode = OriUtils.MGet("misc.useWTargeted.mode")
    if blockMode == 0 then
        return true
    elseif blockMode == 1 then
        return Player.HealthPercent * 100 < OriUtils.MGet("misc.useWTargeted.minHealth")
    end
end

function Yasuo.IsQ3AboutToExpire(menuId)
    if OriUtils.MGet(menuId) and Yasuo.MiscData.Q3BuffEndT then
        local durationLeft = Yasuo.MiscData.Q3BuffEndT - Game.GetTime()

        if durationLeft <= 0.75 then
            return true
        end
    end

    return false
end

function fightModes.ExtraModes(lagFree)
    if OriUtils.MGet("bb.key") then
        if Yasuo.Beyblade() then
            return true
        end
    end

    if lagFree == 2 and OriUtils.CanCastSpell(slots.Q, "misc.stackQ") then
        if not Yasuo.HasQ3() and not OriUtils.IsDashing() then 
            local q1Range = spells.Q1.Range

            local target = TS:GetTarget(q1Range)
            
            if not target then
                local minions = OriUtils.GetEnemyAndJungleMinions(q1Range)

                for _, minion in ipairs(minions) do
                    local minionHealth = minion.Health + minion.ShieldAll

                    if minionHealth < Yasuo.GetDamage(minion, slots.Q) then
                        target = minion

                        break
                    end
                end

                if not target then
                    local me = Player

                    ---@param elemA AIMinionClient
                    ---@param elemB AIMinionClient
                    ---@type AIMinionClient
                    target = OriUtils.GetFirstElementSort(minions, function(elemA, elemB)
                        return me:Distance(elemA) < me:Distance(elemB)
                    end)
                end
            end
            
            if target then
                local pred = spells.Q1:GetPrediction(target)
                
                if pred and pred.CastPosition then
                    if pred.HitChanceEnum >= Enums.HitChance.Low then
                        if Yasuo.CastQ(pred.CastPosition) then
                            return true
                        end
                    end
                end
            end
        end
    end
end

function fightModes.Flee(lagFree)
    if not OriUtils.MGet("flee.useE") then return false end

    if lagFree == 1 and OriUtils.CanCastSpell(slots.Q, "flee.stackQ") then
        if not Yasuo.HasQ3() and OriUtils.IsDashing() then
            local endPos = OriUtils.GetDashEndPos()

            if endPos then
                local hasHero, hasMinion = Yasuo.PosHasQCircleTargets(endPos)

                if hasHero or hasMinion then
                    if Yasuo.CastQ(Player.ServerPos) then
                        return true
                    end
                end
            end
        end
    elseif lagFree == 2 and OriUtils.IsSpellReady(slots.E) then
        local bestDashableObj = Yasuo.GetDashableObj()

        if bestDashableObj then
            if Yasuo.CastE(bestDashableObj) then
                return true
            end
        end
    end

    return false
end

function fightModes.Combo(lagFree)
    local forcedTarget = TS:GetForcedTarget()

    if lagFree == 1 and OriUtils.CanCastSpell(slots.R, "combo.useR") then
        local shouldCast, targetPos, maximizeDamage = Yasuo.ShouldCastR(forcedTarget)

        if maximizeDamage then
            if Yasuo.MiniCombo(targetPos) then
                return true
            end
        elseif shouldCast then
            if Yasuo.CastR(targetPos) then
                return true
            end
        end
    elseif lagFree == 2 and OriUtils.CanCastSpell(slots.E, "combo.useE") then
        local target = OriUtils.ChooseTarget(forcedTarget, {spells.Q1.Range, spells.Q3.Range + 600})

        if target then
            local gapclose = OriUtils.MGet("combo.useE.GC")
            
            if gapclose then
                if Yasuo.GapcloseToTarget(target) then
                    return true
                end
            end

            local kite = OriUtils.MGet("combo.useE.kiting")

            if kite then
                if Yasuo.KiteAroundTarget(target) then
                    return true
                end
            end
        end
    elseif (lagFree == 3 or lagFree == 4) and OriUtils.CanCastSpell(slots.Q, "combo.useQ") then
        local hasQ3 = Yasuo.HasQ3()

        ---@type Skillshot
        local spell = hasQ3 and spells.Q3 or spells.Q1

        local target = OriUtils.ChooseTarget(forcedTarget, {spell.Range})

        if target then
            if OriUtils.IsDashing() then
                local endPos = OriUtils.GetDashEndPos()

                if endPos then
                    local myPos = Player.ServerPos

                    local hasHero, hasMinion = Yasuo.PosHasQCircleTargets(endPos, target)

                    if hasHero then
                        if Yasuo.CastQ(myPos) then
                            return true
                        end
                    end

                    if hasMinion and not hasQ3 and OriUtils.MGet("combo.useQ.stack") then
                        if Yasuo.CastQ(myPos) then
                            return true
                        end
                    end
                end
            else
                local q3Expires = Yasuo.IsQ3AboutToExpire("combo.useQ.expireQ3")

                if hasQ3 and Yasuo.ShouldQ3Combo(target, q3Expires) or not hasQ3 then
                    local pred = spell:GetPrediction(target)

                    if pred and pred.CastPosition then
                        local passesHitchance = false

                        if q3Expires then
                            passesHitchance = pred.HitChanceEnum >= Enums.HitChance.Low
                        else
                            passesHitchance = pred.HitChance >= Yasuo.GetHitchance(slots.Q, hasQ3)
                        end

                        if passesHitchance then
                            if Yasuo.CastQ(pred.CastPosition) then
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
    local forcedTarget = TS:GetForcedTarget()

    local function HarassLastHit(spellRange, spellDelay)
        if not TS:GetTarget(spellRange + 100) then
            local minions = OriUtils.GetEnemyAndJungleMinions(spellRange)

            for _, minion in ipairs(minions) do
                if not Orbwalker.IsLasthitMinion(minion) then
                    if minion.Health < Yasuo.GetDamage(minion, slots.Q) then
                        local predPos = minion:FastPrediction(spellDelay * 1000)

                        if predPos then
                            if Yasuo.CastQ(predPos) then
                                return true
                            end
                        end
                    end
                end
            end
        end

        return false
    end

    if (lagFree == 3 or lagFree == 4) and OriUtils.CanCastSpell(slots.Q, "harass.useQ") then
        local myPos = Player.ServerPos

        local hasQ3 = Yasuo.HasQ3()

        if (not hasQ3 or OriUtils.MGet("harass.useQ.Q3")) and (not OriUtils.IsPosUnderTurret(myPos) or OriUtils.MGet("harass.useQ.turret")) then
            if not OriUtils.IsDashing() then
                local q3Expires = Yasuo.IsQ3AboutToExpire("harass.useQ.expireQ3")

                ---@type Skillshot
                local spell = hasQ3 and spells.Q3 or spells.Q1
                local spellRange = spell.Range

                local target = OriUtils.ChooseTarget(forcedTarget, {spellRange})

                if target then
                    local pred = spell:GetPrediction(target)

                    if pred and pred.CastPosition then
                        local passesHitchance = false

                        if q3Expires then
                            passesHitchance = pred.HitChanceEnum >= Enums.HitChance.Low
                        else
                            passesHitchance = pred.HitChance >= Yasuo.GetHitchance(slots.Q, hasQ3)
                        end

                        if passesHitchance then
                            if Yasuo.CastQ(pred.CastPosition) then
                                return true
                            end
                        end
                    end
                end

                if OriUtils.MGet("harass.useQ.lastHit") and not hasQ3 then
                    if HarassLastHit(spellRange, spell.Delay) then
                        return true
                    end
                end
            end
        end
    end
end

function fightModes.Waveclear(lagFree)
    local useQ = OriUtils.MGet("clear.useQ")
    local useQFullCheck = useQ and OriUtils.IsSpellReady(slots.Q)
    local useE = OriUtils.MGet("clear.useE")
    local useETurret = OriUtils.MGet("clear.useE.turret")
    local useELastHitOnly = OriUtils.MGet("clear.useE.lastHit")
    
    local me = Player

    local hasQ3 = Yasuo.HasQ3()

    ---@type Skillshot
    local spell = hasQ3 and spells.Q3 or spells.Q1

    local isDashing = OriUtils.IsDashing()
    local dashEndPos = nil
    local hasHero, hasMinion = false, false

    if isDashing then
        dashEndPos = OriUtils.GetDashEndPos()
        hasHero, hasMinion = Yasuo.PosHasQCircleTargets(dashEndPos)
    end

    local eRange = spells.E.Range
    local q3Width = spells.Q3.Radius * 2
    local qDelayMs = spells.Q1.Delay * 1000

    ---@type AIMinionClient[]
    local possibleQUnits = {}
    local possibleQPositions = {}
    
    local minions = OriUtils.GetEnemyAndJungleMinions(spells.Q3.Range)
    
    local function TurretCond(afterEPos)
        return useETurret or not OriUtils.IsPosUnderTurret(afterEPos)
    end

    ---@param endPos Vector
    ---@param minionCache AIMinionClient[]
    local function EQNumHits(endPos, minionCache)
        local qCircleRadius = spells.QCircle.Radius

        local count = 0

        for _, minion in ipairs(minionCache) do
            if endPos:Distance(minion) < qCircleRadius then
                count = count + 1
            end
        end

        return count
    end

    ---@param minion AIMinionClient
    local function IsJungleMinion(minion)
        return minion.TeamId == Enums.Teams.Neutral
    end

    for _, minion in ipairs(minions) do
        local afterEPos = Yasuo.PosAfterE(minion)
        local distToMinion = me:Distance(minion)

        if (lagFree == 1 or lagFree == 2) and useE and OriUtils.IsSpellReady(slots.E) then
            if distToMinion < eRange and Yasuo.CanCastE(minion) and TurretCond(afterEPos) then
                if IsJungleMinion(minion) then
                    if Yasuo.CastE(minion) then
                        return true
                    end
                end

                if Yasuo.IsMinionKillableWith(minion, false, true) then
                    if Yasuo.CastE(minion) then
                        return true
                    end
                end
                
                if not useELastHitOnly and not hasQ3 and useQFullCheck then
                    if Yasuo.IsMinionKillableWith(minion, true, true) or EQNumHits(afterEPos, minions) >= 2 then
                        if Yasuo.CastE(minion) then
                            return true
                        end
                    end
                end
            end
        elseif (lagFree == 3 or lagFree == 4) and useQFullCheck then
            if isDashing then
                if not hasQ3 and hasMinion then
                    if Yasuo.CastQ(me.ServerPos) then
                        return true
                    end
                end
            else
                if distToMinion < spell.Range then
                    possibleQUnits[#possibleQUnits+1] = minion
                    possibleQPositions[#possibleQPositions+1] = minion.ServerPos
                end
            end
        end
    end

    local nUnits = #possibleQUnits
    if nUnits > 0 then
        local useQ3 = OriUtils.MGet("clear.useQ.Q3")
        local useQ3MinHit = OriUtils.MGet("clear.useQ.Q3.minHit")

        if hasQ3 then
            if useQ3 then
                local bestPos, hits = Geometry.BestCoveringRectangle(possibleQPositions, me.ServerPos, q3Width)

                if hits >= useQ3MinHit and bestPos then
                    if Yasuo.CastQ(bestPos) then
                        return true
                    end
                end
            end
        else
            for _, minion in ipairs(possibleQUnits) do
                if Yasuo.IsMinionKillableWith(minion, true, false) and not Orbwalker.IsLasthitMinion(minion) then
                    local pred = minion:FastPrediction(qDelayMs)

                    if pred then
                        if Yasuo.CastQ(pred) then
                            return true
                        end
                    end
                end
            end
        end

        ---@param qUnits AIMinionClient[]
        ---@return AIMinionClient|nil
        local function HasJungleMinion(qUnits)
            for _, minion in ipairs(qUnits) do
                if IsJungleMinion(minion) then
                    return minion
                end
            end

            return nil
        end

        if useQ3 or not hasQ3 then
            if nUnits < useQ3MinHit and OriUtils.MGet("clear.useQ.Q3.minHit.fallback") then
                local jungleMinion = HasJungleMinion(possibleQUnits)

                if jungleMinion then
                    local pred = jungleMinion:FastPrediction(qDelayMs)

                    if pred then
                        if Yasuo.CastQ(pred) then
                            return true
                        end
                    end
                end

                ---@param elemA AIMinionClient
                ---@param elemB AIMinionClient
                ---@type AIMinionClient
                local bestTarget = OriUtils.GetFirstElementSort(possibleQUnits, function(elemA, elemB)
                    return elemA.MaxHealth > elemB.MaxHealth
                end)

                local pred = bestTarget:FastPrediction(qDelayMs)

                if pred then
                    if Yasuo.CastQ(pred) then
                        return true
                    end
                end
            end
        end
    end
end

function fightModes.Lasthit(lagFree)
    local me = Player

    local minions = OriUtils.GetEnemyAndJungleMinions(spells.Q3.Range)

    local eRange = spells.E.Range

    local qDelayMs = spells.Q1.Delay * 1000

    local hasQ3 = Yasuo.HasQ3()

    ---@type Skillshot
    local spell = hasQ3 and spells.Q3 or spells.Q1

    local useQ3 = OriUtils.MGet("lh.useQ.Q3")
    local useETurret = OriUtils.MGet("lh.useE.turret")

    local function TurretCond(afterEPos)
        return useETurret or not OriUtils.IsPosUnderTurret(afterEPos)
    end

    for _, minion in ipairs(minions) do
        local distToMinion = me:Distance(minion)
        local afterEPos = Yasuo.PosAfterE(minion)
        
        if (lagFree == 1 or lagFree == 2) and OriUtils.CanCastSpell(slots.E, "lh.useE") then
            if distToMinion < eRange and Yasuo.CanCastE(minion) and TurretCond(afterEPos) then
                if Yasuo.IsMinionKillableWith(minion, false, true) then
                    if Yasuo.CastE(minion) then
                        return true
                    end
                end
            end
        elseif (lagFree == 3 or lagFree == 4) and OriUtils.CanCastSpell(slots.Q, "lh.useQ") then
            if not hasQ3 or useQ3 then
                if distToMinion < spell.Range and not Orbwalker.IsLasthitMinion(minion) then
                    if Yasuo.IsMinionKillableWith(minion, true, false) then
                        local pred = minion:FastPrediction(qDelayMs)

                        if pred then
                            if Yasuo.CastQ(pred) then
                                return true
                            end
                        end
                    end
                end
            end
        end
    end
end

function events.OnTick(lagFree)
    Yasuo.UpdateQDelay()

    OriUtils.CheckFlashSlot()

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

local drawData = {
    {slot = slots.Q, id = "Q", displayText = "Q1/Q3 [Steel Tempest]", range = function() if Yasuo.HasQ3() then return spells.Q3.Range else return spells.Q1.Range end end},
    {slot = slots.W, id = "W", displayText = "W [Wind Wall]", range = spells.W.Range},
    {slot = slots.E, id = "E", displayText = "E [Sweeping Blade]", range = spells.E.Range},
    {slot = slots.R, id = "R", displayText = "R [Last Breath]", range = spells.R.Range}
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

    if OriUtils.MGet("draw.bbWarnings") and OriUtils.MGet("bb.key") then
        local warning = nil

        if not spells.Flash.Slot then
            warning = "Beyblade: Flash not detected"
        elseif not OriUtils.IsSpellReady(spells.Flash.Slot) then
            warning = "Beyblade: Flash not ready"
        elseif not Yasuo.HasQ3() then
            warning = "Beyblade: Missing Q3"
        end

        if warning ~= nil then
            local resolution = Renderer.GetResolution()
            local scrX = resolution.x * 0.5
            local scrY = resolution.y * 0.25
            local scrPos = Vector(scrX, scrY)

            Renderer.DrawText(scrPos, Vector(0, 40), warning, 0xFFFF00FF)
        end
    end
end

function events.OnDrawDamage(unit, dmgList)
    if not OriUtils.MGet("draw.comboDamage") then
        return
    end

    local damageToDeal = 0

    damageToDeal = damageToDeal + DmgLib.GetAutoAttackDamage(Player, unit, true) * 2

    if OriUtils.CanCastSpell(slots.Q, "combo.useQ") then
        damageToDeal = damageToDeal + Yasuo.GetDamage(unit, slots.Q)
    end

    if OriUtils.CanCastSpell(slots.E, "combo.useE") and Yasuo.CanCastE(unit) then
        damageToDeal = damageToDeal + Yasuo.GetDamage(unit, slots.E)
    end

    if OriUtils.CanCastSpell(slots.R, "combo.useR") then
        damageToDeal = damageToDeal + Yasuo.GetDamage(unit, slots.R)
    end

    insert(dmgList, damageToDeal)
end

---@param obj GameObject
function events.OnCreateObject(obj)
    if not obj or not obj.IsMissile then
        return
    end
    
    local missile = obj.AsMissile

    if (not missile.Caster or not missile.Caster.IsMinion) and missile.IsEnemy and missile.Target and missile.Target.IsMe then
        --INFO("Missile name: %s", missile.Name)
    end

    if Yasuo.ShouldBlockSpell() then
        if missile.IsEnemy and missile.Target and missile.Target.IsMe then
            local spell = OriUtils.FindIngameTargetedSpellByMissile(missile.Name)

            if spell then
                local id = "blockTargeted." .. spell.champion .. "." .. slotToString[spell.slot]

                if spell.name then
                    id = id .. "." .. spell.name
                end

                if OriUtils.MGet(id, true) then
                    if Yasuo.CastW(missile.StartPos) then
                        return
                    end
                end
            end
        end
    end

    if OriUtils.CanCastSpell(slots.W, "misc.useW") and Player.HealthPercent * 100 < OriUtils.MGet("misc.useW.minHealth") then        
        if not missile.IsBasicAttack or not missile.Target or not missile.Target.IsMe then
            return
        end
        
        local caster = missile.Caster
        
        if not caster or not caster.IsHero or caster.IsAlly then
            return
        end
        
        local hero = caster.AsHero
        local charName = hero.CharName
        
        local whitelistValue = OriUtils.MGet("blockAA." .. charName)
        
        if whitelistValue then
            if Yasuo.CastW(hero.ServerPos) then
                return
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

---@param obj GameObject
---@param buffInst BuffInst
function events.OnBuffGain(obj, buffInst)
    if not obj or not buffInst then return end

    if obj.IsMe and buffInst.Name == "YasuoQ2" then
        Yasuo.MiscData.Q3BuffEndT = buffInst.EndTime
        
        return
    end

    if obj.IsAlly or not obj.IsHero then return end

    local buffType = buffInst.BuffType

    if buffType ~= Enums.BuffTypes.Knockup and buffType ~= Enums.BuffTypes.Knockback then return end

    if not Yasuo.rBuffEnemies[obj.Handle] then
        Yasuo.rBuffEnemies[obj.Handle] = {}
    end

    Yasuo.rBuffEnemies[obj.Handle][buffInst.Name] = buffInst.EndTime
end

---@param obj GameObject
---@param buffInst BuffInst
function events.OnBuffLost(obj, buffInst)
    if not obj or not buffInst then return end

    if obj.IsMe and buffInst.Name == "YasuoQ2" then
        Yasuo.MiscData.Q3BuffEndT = nil

        return
    end

    if obj.IsAlly or not obj.IsHero then return end

    local buffType = buffInst.BuffType

    if buffType ~= Enums.BuffTypes.Knockup and buffType ~= Enums.BuffTypes.Knockback then return end

    if not Yasuo.rBuffEnemies[obj.Handle] then
        Yasuo.rBuffEnemies[obj.Handle] = {}
    end

    local enemyBuffs = Yasuo.rBuffEnemies[obj.Handle]

    local buffName = buffInst.Name

    if enemyBuffs and enemyBuffs[buffName] then
        enemyBuffs[buffName] = nil
    end
end

local spellsQE = {
    ["YasuoQE1"] = true,
    ["YasuoQE2"] = true,
    ["YasuoQE3"] = true,
}
---@param obj GameObject
---@param spellCast SpellCast
function events.OnProcessSpell(obj, spellCast)
    if obj and spellCast then
        if obj.IsMe and spellsQE[spellCast.Name] then
            Yasuo.MiscData.LastQE = Game.GetTime()
        end

        if Yasuo.ShouldBlockSpell() then
            if obj.IsHero and obj.IsEnemy and spellCast.Target and spellCast.Target.IsMe then
                local enemyHero = obj.AsHero
                local enemyHeroName = enemyHero.CharName
                local spellSlot = spellCast.Slot
                local slotStr = slotToString[spellSlot]
                local spellName = spellCast.Name

                if slotStr then
                    local spell = OriUtils.FindIngameTargetedSpell(enemyHeroName, spellSlot, spellName)

                    if spell and not spell.blockOnlyOnMissile then 
                        --INFO("OPS: Detected valid spellcast: " .. enemyHeroName .. " " .. slotStr)
                        local id = "blockTargeted" .. "." .. enemyHeroName .. "." .. slotStr
                        
                        local bCastW = false
                        if OriUtils.MGet(id, true) then
                            bCastW = true
                        else
                            id = id .. "." .. spellName
                            
                            if OriUtils.MGet(id, true) then
                                bCastW = true
                            end
                        end
                        
                        if bCastW then
                            Yasuo.CastW(enemyHero.ServerPos)
                        end
                    end
                end
            end
        end
    end
end

---@param obj GameObject
---@param spellCast SpellCast
function events.OnSpellCastDISABLED(obj, spellCast)
    if obj and spellCast then
        if Yasuo.ShouldBlockSpell() then
            if obj.IsHero and obj.IsEnemy and spellCast.Target and spellCast.Target.IsMe then
                local enemyHero = obj.AsHero
                local enemyHeroName = enemyHero.CharName
                local spellSlot = spellCast.Slot
                local slotStr = slotToString[spellSlot]
                local spellName = spellCast.Name

                if slotStr then
                    local spell = OriUtils.FindIngameTargetedSpell(enemyHeroName, spellSlot, spellName)

                    if spell and spell.blockOnEnd then 
                        INFO("OSC: Detected valid spellcast: " .. enemyHeroName .. " " .. slotStr)
                        local id = "blockTargeted" .. "." .. enemyHeroName .. "." .. slotStr
                        
                        local bCastW = false
                        if OriUtils.MGet(id, true) then
                            bCastW = true
                        else
                            id = id .. "." .. spellName
                            
                            if OriUtils.MGet(id, true) then
                                bCastW = true
                            end
                        end
                        
                        if bCastW then
                            Yasuo.CastW(enemyHero.ServerPos)
                        end
                    end
                end
            end
        end
    end
end

function events.OnPreAttack(args)
    local curTime = Game.GetTime()

    if curTime < Yasuo.MiscData.LastQE + spells.Q1.Delay then
        args.Process = false
    end
end

function Yasuo.RegisterEvents()
    for eventName, eventId in pairs(Enums.Events) do
        if events[eventName] then
            EventManager.RegisterCallback(eventId, events[eventName])
        end
    end
end

function Yasuo.InitMenu()
    local function YasuoMenu()
        Menu.NewTree("Yasuo.comboMenu", "Combo Settings", function()
            Menu.ColumnLayout("Yasuo.comboMenu.QW", "Yasuo.comboMenu.QW", 2, true, function()
                Menu.Separator("Q [Steel Tempest]")

                Menu.Checkbox("Yasuo.combo.useQ", "Enable Q", true)
                Menu.Indent(function()                
                    Menu.Checkbox("Yasuo.combo.useQ.stack", "Stack while dashing", false)
                    Menu.Checkbox("Yasuo.combo.useQ.expireQ3", "Force Q3 when it's about to expire", true)
                    Menu.Checkbox("Yasuo.combo.useQ.alwaysQ3", "Always prio Q3 instead of EQ3", false)
                end)

                Menu.NextColumn()

                --Menu.Separator("W [Wind Wall]")
            end)

            Menu.ColumnLayout("Yasuo.comboMenu.ER", "Yasuo.comboMenu.ER", 2, true, function()
                Menu.Separator("E [Sweeping Blade]")

                Menu.Checkbox("Yasuo.combo.useE", "Enable E", true)
                Menu.Indent(function()
                    Menu.Checkbox("Yasuo.combo.useE.kiting", "Kite around target", true)
                    Menu.Indent(function()
                        Menu.Checkbox("Yasuo.combo.useE.kiting.turret", "End pos under turret", false)
                        Menu.Slider("Yasuo.combo.useE.kiting.maxDist", "Max dist after kite", 300, 50, spells.E.Range, 1)
                        Menu.Slider("Yasuo.combo.useE.kiting.maxHealth", "Max target %HP to kite", 30, 1, 100, 1)

                    end)
                    Menu.Checkbox("Yasuo.combo.useE.GC", "Gapclose to target", true)
                    Menu.Indent(function()
                        Menu.Checkbox("Yasuo.combo.useE.GC.turret", "End pos under turret", true)
                        Menu.Slider("Yasuo.combo.useE.GC.minDist", "Min dist to gapclose", 300, 1, spells.E.Range, 1)
                    end)
                end)

                Menu.NextColumn()

                Menu.Separator("R [Last Breath]")

                Menu.Checkbox("Yasuo.combo.useR", "Enable R", true)
                Menu.Indent(function()
                    Menu.Slider("Yasuo.combo.useR.fallLimit", "Wait until X to cast", 140, 100, 250, 10)
                    Menu.Indent(function()
                        --Menu.Text("Wait until knockup/knockback buff remaining duration is X milliseconds or lower")
                    end)
                    Menu.Slider("Yasuo.combo.useR.minHealth", "If enemy %HP <=", 55, 1, 100, 1)
                    Menu.Slider("Yasuo.combo.useR.enemyCount", "If X enemies airborne", 2, 1, 5, 1)
                    Menu.Checkbox("Yasuo.combo.useR.maxDamage", "Try to maximize damage by EQ another unit", false)
                    Menu.Indent(function()
                        --Menu.Text("It will buffer EQ on another unit before using R on main target if this is too far away")
                    end)
                end)
            end)
        end)

        Menu.NewTree("Yasuo.drawMenu", "Drawings", function()
                Menu.Separator("Drawings")
            OriUtils.AddDrawMenu(drawData)

            Menu.Checkbox("Yasuo.draw.bbWarnings", "Print beyblade warnings", false)
        end)

        Menu.NewTree("Yasuo.beybladeMenu", "Beyblade Settings", function()
            Menu.Separator("Beyblade Settings")
            Menu.Keybind("Yasuo.bb.key", "Beyblade Key", string.byte("T"))
            Menu.Checkbox("Yasuo.bb.useR", "Use R (if available) after beyblade", true)
        end)

        Menu.NewTree("Yasuo.harassMenu", "Harass Settings", function()
            Menu.Separator("Q [Steel Tempest]")

            Menu.Checkbox("Yasuo.harass.useQ", "Enable Q", true)
            Menu.Indent(function()
                Menu.Checkbox("Yasuo.harass.useQ.Q3", "Use Q3", true)
                Menu.Checkbox("Yasuo.harass.useQ.expireQ3", "Force Q3 when it's about to expire", true)
                Menu.Checkbox("Yasuo.harass.useQ.turret", "Use under turret", true)
                Menu.Checkbox("Yasuo.harass.useQ.lastHit", "Use Q1/Q2 to last hit", true)
            end)
        end)

        Menu.NewTree("Yasuo.clearMenu", "Clear Settings", function()
            Menu.Separator("Q [Steel Tempest]")

            Menu.Checkbox("Yasuo.clear.useQ", "Enable Q", true)
            Menu.Indent(function()
                Menu.Checkbox("Yasuo.clear.useQ.Q3", "Use Q3", true)
                Menu.Indent(function()
                    Menu.Slider("Yasuo.clear.useQ.Q3.minHit", "Line Q3 min hit", 2, 1, 5, 1)
                    Menu.Indent(function()
                        Menu.Checkbox("Yasuo.clear.useQ.Q3.minHit.fallback", "Cast anyway on less minions", true)
                        Menu.Text("If there are less than X minions, it will cast Line Q3 on them")
                    end)
                end)
            end)

            Menu.Separator("E [Sweeping Blade]")

            Menu.Checkbox("Yasuo.clear.useE", "Enable E", true)
            Menu.Indent(function()
                Menu.Checkbox("Yasuo.clear.useE.lastHit", "Only to last hit", false)
                Menu.Checkbox("Yasuo.clear.useE.turret", "Use under turret", false)
            end)
        end)

        Menu.NewTree("Yasuo.lhMenu", "Last Hit Settings", function()
            Menu.Separator("Q [Steel Tempest]")

            Menu.Checkbox("Yasuo.lh.useQ", "Enable Q", true)
            Menu.Indent(function()
                Menu.Checkbox("Yasuo.lh.useQ.Q3", "Use Q3", false)
            end)

            Menu.Separator("E [Sweeping Blade]")

            Menu.Checkbox("Yasuo.lh.useE", "Enable E", true)
            Menu.Indent(function()
                Menu.Checkbox("Yasuo.lh.useE.turret", "Use under turret", false)
            end)
        end)

        Menu.NewTree("Yasuo.fleeMenu", "Flee Settings", function()
                Menu.Separator("Flee Settings")
            Menu.Checkbox("Yasuo.flee.useE", "Use E", true)
            Menu.Indent(function()
                Menu.Checkbox("Yasuo.flee.stackQ", "Stack Q while fleeing", true)
            end)
        end)

        Menu.NewTree("Yasuo.miscMenu", "Misc Settings", function()
                Menu.Separator("Misc Settings")
            Menu.Keybind("Yasuo.misc.stackQ", "Stack Q", string.byte("G"))

            Menu.Checkbox("Yasuo.misc.useW", "Enable W to block AAs", true)
            Menu.Indent(function()
                Menu.Slider("Yasuo.misc.useW.minHealth", "If my %HP <", 55, 0, 100, 1)
                Menu.NewTree("Yasuo.misc.useW.wlMenu", "Target whitelist", function()
                    local enemyHeroes = ObjManager.Get("enemy", "heroes")

                    local addedWL = {}
                    local checkAgainst = OriUtils.MiscData.Champions.NoProjectileRanged

                    for _, obj in pairs(enemyHeroes) do
                        local hero = obj.AsHero
                        local charName = hero.CharName

                        if hero and hero.IsRanged and not checkAgainst[charName] and not addedWL[charName] then
                            Menu.Checkbox("Yasuo.blockAA." .. charName, "Block " .. charName .. "'s AAs", true)

                            addedWL[charName] = true
                        end
                    end
                end)
            end)

            Menu.Checkbox("Yasuo.misc.useWTargeted", "Enable W to block targeted spells", true)
            Menu.Indent(function()
                Menu.Dropdown("Yasuo.misc.useWTargeted.mode", "Mode", 0, {"Always", "If I have under X %HP"})

                if OriUtils.MGet("misc.useWTargeted.mode") == 1 then
                    Menu.Indent(function()
                        Menu.Slider("Yasuo.misc.useWTargeted.minHealth", "If my %HP <", 70, 0, 100, 1)
                    end)
                end

                Menu.NewTree("Yasuo.misc.useWTargeted.wlMenu", "Spell Whitelist", function()
                    local ingameSpells = OriUtils.SpellData.TargetedProjectilesIngame

                    if #ingameSpells == 0 then
                        Menu.ColoredText("No targeted projectiles detected this game", SCRIPT_COLOR, false)
                        return
                    end

                    for _, spellInfo in ipairs(ingameSpells) do
                        local slotStr = slotToString[spellInfo.slot]

                        local id = "Yasuo.blockTargeted." .. spellInfo.champion .. "." .. slotStr
                        local display = "Block " .. spellInfo.champion .. " " .. slotStr

                        if spellInfo.name then
                            id = id .. "." .. spellInfo.name
                            display = display .. " " .. "(" .. spellInfo.name .. ")"
                        end

                        Menu.Checkbox(id, display, spellInfo.default)
                    end
                end)
            end)
        end)

        Menu.NewTree("Yasuo.hcMenu", "Hitchance Settings", function()
                Menu.Separator("Hitchance Settings")
            Menu.Slider("Yasuo.hc.Q1", "Q1/Q2 Hitchance", 15, 0, 100, 1)
            Menu.Slider("Yasuo.hc.Q3", "Q3 Hitchance", 35, 0, 100, 1)
        end)

        Menu.Separator("Author: Orietto")
    end

    Menu.RegisterMenu(SCRIPT_NAME, SCRIPT_NAME, YasuoMenu)
end

function OnLoad()
    OriUtils.LoadTargetedSpells()

    Yasuo.InitMenu()

    Yasuo.RegisterEvents()

    return true
end
