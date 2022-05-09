if Player.CharName ~= "LeeSin" then return end

local SCRIPT_NAME = "Ori Leesin"
local SCRIPT_VERSION_UPDATER = "2.0.2"
local SCRIPT_VERSION = SCRIPT_VERSION_UPDATER
local SCRIPT_LAST_UPDATED = "12/31/2021"
local SCRIPT_AUTHOR = "Orietto"
local SCRIPT_IS_BETA = false

if SCRIPT_IS_BETA then
    SCRIPT_VERSION = SCRIPT_VERSION .. " Beta"
else
    SCRIPT_VERSION = SCRIPT_VERSION .. " Release"
end

local SCRIPT_COLOR = 0xDE9714FF

module(SCRIPT_NAME, package.seeall, log.setup)
clean.module(SCRIPT_NAME, clean.seeall, log.setup)

local insert, sort = table.insert, table.sort
local huge, pow, min, max, floor, ceil = math.huge, math.pow, math.min, math.max, math.floor, math.ceil
local format = string.format

local SDK = _G.CoreEx

SDK.AutoUpdate("https://github.com/hagbardlol/nosupport/raw/main/OriLeesin.lua", SCRIPT_VERSION_UPDATER)

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
    Q1 = {
        Base = {55, 80, 105, 130, 155},
        BonusAD = 1.0,
        Type = dmgTypes.Physical
    },
    Q2 = {
        Base = {55, 80, 105, 130, 155},
        BonusAD = 1.0,
        ---@param target AIBaseClient
        MissingHealthIncrease = function(target, simulatedHealth)
            local curHealth = simulatedHealth or target.Health
            local maxHealth = target.MaxHealth

            local misHealthPercent = 1 - (curHealth / maxHealth)

            return misHealthPercent + 1
        end,
        Type = dmgTypes.Physical
    },
    E1 = {
        Base = {100, 130, 160, 190, 220},
        BonusAD = 1.0,
        Type = dmgTypes.Magical
    },
    R = {
        Base = {175, 400, 625},
        BonusAD = 2.0,
        ---@param mainTarget AIHeroClient
        CollisionIncrease = function(mainTarget)
            local basePercent = {0.12, 0.15, 0.18}
            local percent = basePercent[Player:GetSpell(Slots.R).Level]
                
            local bonusHealthPercent = mainTarget.BonusHealth * percent
                
            return bonusHealthPercent
        end,
        Type = dmgTypes.Physical
    }
}

local spells = {
    Q1 = Spell.Skillshot({
        Slot = slots.Q,
        Delay = 0.25,
        Speed = 1800,
        Range = 1100,
        Radius = 130 / 2, --120
        Type = "Linear",
        Collisions = {Heroes = true, Minions = true, WindWall = true}
    }),
    Q2 = Spell.Active({
        Slot = slots.Q,
        Range = 1250
    }),
    W1 = Spell.Targeted({
        Slot = slots.W,
        Range = 700
    }),
    W2 = Spell.Active({
        Slot = slots.W,
        Range = huge
    }),
    E1 = Spell.Active({
        Slot = slots.E,
        Delay = 0.25,
        Range = 420
    }),
    E2 = Spell.Active({
        Slot = slots.E,
        Range = 420
    }),
    R = Spell.Targeted({
        Slot = slots.R,
        Delay = 0.25,
        Range = 370,
        Speed = 870,
        KickDist = 670
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
    },
    Smite = {
        Slot = nil,
        LastCastT = 0,
        LastCheckT = 0,
        Range = 500,
        IsUpgrade = false
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

OriUtils.Items.Wards = {}
OriUtils.Items.Wards.Range = 600
OriUtils.Items.Wards.LastCastT = 0

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

---@param unit AIBaseClient
---@param radius number|nil
---@param fromPos Vector|nil
function OriUtils.IsValidTargetWard(unit, radius, fromPos)
    fromPos = fromPos or Player.ServerPos
    radius = radius or huge

    return unit and unit.MaxHealth > 1 and fromPos:DistanceSqr(unit.ServerPos) < pow(radius, 2) and TS:IsValidTarget(unit)
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

function OriUtils.CastSmite(unit)
    if not spells.Smite.Slot then return false end

    local curTime = Game.GetTime()
    if curTime < spells.Smite.LastCastT + 0.25 then return false end

    return OriUtils.CastSpell(spells.Smite.Slot, unit)
end

function OriUtils.ShouldCastWard()
    local curTime = Game.GetTime()
    return curTime >= OriUtils.Items.Wards.LastCastT + 0.5
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

function OriUtils.CheckSmiteSlot()
    local curTime = Game.GetTime()

    if curTime < spells.Smite.LastCheckT + 1 then return end

    spells.Smite.LastCheckT = curTime

    local function IsSmite(slot)
        return Player:GetSpell(slot).Name == "SummonerSmite"
    end

    local function IsUpgradedSmite(slot)
        local slotName = Player:GetSpell(slot).Name

        return slotName == "S5_SummonerSmitePlayerGanker" or slotName == "S5_SummonerSmiteDuel"
    end

    for _, slot in ipairs(summSlots) do
        if IsSmite(slot) then
            if spells.Smite.Slot ~= slot then
                INFO("Normal Smite was found on %d", slot)

                spells.Smite.Slot = slot
            end

            return
        end

        if IsUpgradedSmite(slot) then
            if not spells.Smite.IsUpgrade or spells.Smite.Slot ~= slot then
                INFO("Upgraded Smite was found on %d", slot)

                spells.Smite.IsUpgrade = true
                spells.Smite.Slot = slot                
            end

            return
        end
    end

    if spells.Smite.Slot ~= nil then
        INFO("Smite was lost")

        spells.Smite.Slot = nil
    end
end

function OriUtils.CanCastSpell(slot, menuId)
    return OriUtils.IsSpellReady(slot) and OriUtils.MGet(menuId)
end

---@return AIMinionClient[], AIMinionClient[], AIMinionClient[] @Returns All, OnlyEnemyMinions, OnlyJungleMinions
function OriUtils.GetEnemyAndJungleMinions(radius, fromPos)
    fromPos = fromPos or Player.ServerPos

    local result = {}
    local onlyEnemy = {}
    local onlyJungle = {}

    ---@param group GameObject[]
    ---@param subFilterEnemy boolean
    local function AddIfValid(group, subFilterEnemy)
        for _, unit in ipairs(group) do
            local minion = unit.AsMinion

            if OriUtils.IsValidTarget(minion, radius, fromPos) then
                result[#result+1] = minion

                if subFilterEnemy then
                    onlyEnemy[#onlyEnemy+1] = minion
                else
                    onlyJungle[#onlyJungle+1] = minion
                end
            end
        end
    end

    local enemyMinions = ObjManager.GetNearby("enemy", "minions")
    local jungleMinions = ObjManager.GetNearby("neutral", "minions")

    AddIfValid(enemyMinions, true)
    AddIfValid(jungleMinions, false)

    return result, onlyEnemy, onlyJungle
end

---@return AIBaseClient[]
function OriUtils.GetAllyUnits(radius, fromPos, addHeroes, addMinions, addWards)
    fromPos = fromPos or Player.ServerPos

    local result = {}

    local function AddIfValid(group, isWardGroup)
        for _, obj in ipairs(group) do
            local unit = obj.AsAI

            if isWardGroup then
                if OriUtils.IsValidTargetWard(unit, radius, fromPos) then
                    result[#result+1] = unit
                end
            else
                if OriUtils.IsValidTarget(unit, radius, fromPos) then
                    result[#result+1] = unit
                end
            end
        end
    end

    if addHeroes then
        local allyHeroes = ObjManager.GetNearby("ally", "heroes")

        AddIfValid(allyHeroes, false)
    end

    if addMinions then
        local allyMinions = ObjManager.GetNearby("ally", "minions")

        AddIfValid(allyMinions, false)
    end

    if addWards then
        local allyWards = ObjManager.GetNearby("ally", "wards")

        AddIfValid(allyWards, true)
    end

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

---@return number|nil, Item|nil
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

---@return function, function, function, function
function OriUtils.GetMenuHeaders(drawData)
    local headers = {}

    for i = 1, 4 do
        headers[i] = function()
            Menu.ColoredText(drawData[i].displayText, SCRIPT_COLOR, true)
        end
    end

    return headers[1], headers[2], headers[3], headers[4]
end

---@param unit AIBaseClient
---This is for non hero targets only
function OriUtils.GetSmiteDamage(unit)
    if not spells.Smite.IsUpgrade then
        return 450
    end

    if unit.IsMonster then
        return 900
    else
        return 500 + unit.MaxHealth * 0.1
    end
end

---@param from Vector
---@param to Vector
---@param lineWidth number|nil
---@param color number|nil
function OriUtils.DrawSimpleArrow(from, to, lineWidth, color)
    lineWidth = lineWidth or 2
    color = color or 0xFF0000FF

    local sideLength = 100

    Renderer.DrawLine3D(from, to, lineWidth, color)

    ---@type Vector
    local dir = (to - from):Normalized()

    local leftDir = dir:Rotated(0, 3.926, 0)
    local rightDir = dir:Rotated(0, 2.356, 0)

    Renderer.DrawLine3D(to, to + leftDir * sideLength, lineWidth, color)
    Renderer.DrawLine3D(to, to + rightDir * sideLength, lineWidth, color)
end

local Lee = {}

Lee.MiscData = {}

Lee.MiscData.WardPriority = {
    {name = "Targon's Buckler", id = 3859},
    {name = "Bulwark of the Mountain", id = 3860},
    {name = "Runesteel Spaulders", id = 3855},
    {name = "Pauldrons of Whiterock", id = 3857},
    {name = "Frostfang", id = 3851},
    {name = "Shard of True Ice", id = 3853},
    {name = "Harrowing Crescent", id = 3863},
    {name = "Black Mist Scythe", id = 3864},
    {name = "Stealth Ward", id = 3340},
    {name = "Control Ward", id = 2055},
}

Lee.MiscData.WardJump = {}
Lee.MiscData.WardJump.IsActive = false
Lee.MiscData.WardJump.LastActiveT = 0
Lee.MiscData.WardJump.PotentialWards = {}

Lee.MiscData.Insec = {}
---@type Vector
Lee.MiscData.Insec.CustomPos = nil
---@type Vector
Lee.MiscData.Insec.BackupEndPos = nil
---@type Vector
Lee.MiscData.Insec.LastInsecPos = nil
Lee.MiscData.Insec.LastActiveT = 0

Lee.MiscData.Bowl = {}
---@type Vector
Lee.MiscData.Bowl.LastBowlPos = nil
Lee.MiscData.Bowl.LastActiveT = 0

Lee.MiscData.InsecBowlMoveToLastT = 0

Lee.MiscData.PassiveName = "blindmonkpassive_cosmetic"
Lee.MiscData.PassiveStacks = 0

Lee.MiscData.Q1Missile = {}
Lee.MiscData.Q1Missile.MissileName = "BlindMonkQOne"
Lee.MiscData.Q1Missile.IsActive = false
Lee.MiscData.Q1Missile.LastCreationTime = 0

local qCastTimers = { [slots.Q] = 0.25, [slots.E] = 0.25 }
---@param q1CastPos Vector|nil
function Lee.CastQ(q1CastPos)
    if not OriUtils.CheckCastTimers(qCastTimers) then return false end

    return OriUtils.CastSpell(slots.Q, q1CastPos or Player)
end

local wCastTimers = { [slots.W] = 0.05 }
---@param w1TargetUnit AIBaseClient|nil
function Lee.CastW(w1TargetUnit)
    if not OriUtils.CheckCastTimers(wCastTimers) then return false end

    return OriUtils.CastSpell(slots.W, w1TargetUnit or Player)
end

local eCastTimers = { [slots.E] = 0.1, [slots.Q] = 0.25, [slots.R] = 0.25 }
function Lee.CastE()
    if not OriUtils.CheckCastTimers(eCastTimers) then return false end

    return OriUtils.CastSpell(slots.E, Player)
end

local rCastTimers = { [slots.R] = 0.25 }
function Lee.CastR(target)
    if not OriUtils.CheckCastTimers(rCastTimers) then return false end

    return OriUtils.CastSpell(slots.R, target)
end

function Lee.HasQ2()
    return Player:GetSpell(slots.Q).Name == "BlindMonkQTwo"
end

function Lee.HasW2()
    return Player:GetSpell(slots.W).Name == "BlindMonkWTwo"
end

function Lee.HasE2()
    return Player:GetSpell(slots.E).Name == "BlindMonkETwo"
end

---@param mainTarget AIHeroClient
---@param minHit number
---@return boolean
function Lee.RWillCollideWith(mainTarget, minHit)
    local me = Player

    local rSpell = spells.R

    local startPos = mainTarget.ServerPos
    local endPos = startPos:Extended(Player, -rSpell.KickDist)
    local width = mainTarget.BoundingRadius * 2
    local speed = rSpell.Speed
    local delay = rSpell.Delay * 1000
    local ignoredHandles = {[mainTarget.Handle] = true}

    local col = Collision.SearchHeroes(startPos, endPos, width, speed, delay, 5, "enemy", ignoredHandles)
    if col and col.Result then
        return #col.Objects >= minHit
    end

    return false
end

---@param checkMinions boolean
---@return AIBaseClient|nil
function Lee.Q2Unit(checkMinions)
    local buffName = "blindmonkqone"

    ---@param unit AIBaseClient
    local function BuffCheck(unit)
        local buffs = unit.Buffs

        for name in pairs(buffs) do
            if name == buffName then
                return true
            end
        end

        return false
    end

    local enemyHeroes = ObjManager.GetNearby("enemy", "heroes")
    for _, obj in ipairs(enemyHeroes) do
        local hero = obj.AsHero

        if OriUtils.IsValidTarget(hero) then
            if BuffCheck(hero) then
                return hero
            end
        end
    end

    if checkMinions then
        local minions = OriUtils.GetEnemyAndJungleMinions(1500)

        for _, minion in ipairs(minions) do
            if BuffCheck(minion) then
                return minion
            end
        end
    end

    return nil
end

---@param target AIHeroClient
function Lee.ComboW(target)
    local wMode = OriUtils.MGet("combo.useW1")
    if wMode == 0 then return false end

    local me = Player

    local w1Range = spells.W1.Range

    local aaRange = Orbwalker.GetTrueAutoAttackRange(me, target)
    local dist = me:Distance(target)

    local function CastOnMe()
        if dist < aaRange then
            if Lee.CastW(Player) then
                return true
            end
        end

        return false
    end

    local function ClosestUnitToTarget(elemA, elemB)
        local distA = target:Distance(elemA)
        local distB = target:Distance(elemB)

        return distA < distB
    end

    local function CastOnAllyHero()
        local filteredAllies = {}

        local allyHeroes = ObjManager.GetNearby("ally", "heroes")
        for _, obj in ipairs(allyHeroes) do
            local hero = obj.AsHero

            if not hero.IsMe and OriUtils.IsValidTarget(hero, w1Range) then
                filteredAllies[#filteredAllies+1] = hero
            end
        end

        ---@type AIHeroClient
        local closestAllyToTarget = OriUtils.GetFirstElementSort(filteredAllies, ClosestUnitToTarget)

        if closestAllyToTarget then
            local allyToTargetDist = target:Distance(closestAllyToTarget)

            if allyToTargetDist < aaRange then
                if Lee.CastW(closestAllyToTarget) then
                    return true
                end
            end
        end

        return false
    end

    local function CastOnAllyMinion()
        local filteredMinions = {}

        local allyMinions = ObjManager.GetNearby("ally", "minions")
        for _, obj in ipairs(allyMinions) do
            local minion = obj.AsMinion

            if OriUtils.IsValidTarget(minion, w1Range) then
                filteredMinions[#filteredMinions+1] = minion
            end
        end

        local closestMinionToTarget = OriUtils.GetFirstElementSort(filteredMinions, ClosestUnitToTarget)

        if closestMinionToTarget then
            local minionToTargetDist = target:Distance(closestMinionToTarget)

            if minionToTargetDist < aaRange then
                if Lee.CastW(closestMinionToTarget) then
                    return true
                end
            end
        end

        return false
    end

    local functionData = {
        [1] = {CastOnMe},
        [2] = {CastOnAllyHero, CastOnMe},
        [3] = {CastOnAllyHero, CastOnMe, CastOnAllyMinion}
    }

    local functionsToCall = functionData[wMode]
    for _, func in ipairs(functionsToCall) do
        if func() then
            return true
        end
    end

    return false
end

function Lee.GetWardSlot()
    for _, wardData in ipairs(Lee.MiscData.WardPriority) do
        if OriUtils.MGet("ward." .. wardData.name) then
            local slot, item = OriUtils.HasItem(wardData.id)

            if slot then
                slot = slot + 6

                if OriUtils.IsSpellReady(slot) then
                    return slot
                end
            end
        end
    end

    return nil
end

function Lee.ClearPotentialWards()
    Lee.MiscData.WardJump.PotentialWards = {}
end

---@param pos Vector
function Lee.WardJump(pos)
    local me = Player

    if not OriUtils.IsSpellReady(slots.W) or Lee.HasW2() then return false end

    local potentialWards = Lee.MiscData.WardJump.PotentialWards

    if OriUtils.MGet("flee.wardJump.jumpExisting") then
        local allyUnits = OriUtils.GetAllyUnits(spells.W1.Range, nil, true, true, true)

        local closestUnit = OriUtils.GetFirstElementSort(allyUnits, function(elemA, elemB)
            local distA = pos:Distance(elemA)
            local distB = pos:Distance(elemB)

            return distA < distB
        end)

        if closestUnit and pos:Distance(closestUnit) < 100 then
            if Lee.CastW(closestUnit) then
                Lee.ClearPotentialWards()

                return true
            end
        end
    end

    for _, wardUnit in ipairs(potentialWards) do
        if Lee.CastW(wardUnit) then
            Lee.ClearPotentialWards()

            return true
        end
    end

    local wardSlot = Lee.GetWardSlot()

    if wardSlot and OriUtils.ShouldCastWard() then    
        if OriUtils.CastSpell(wardSlot, pos) then
            local curTime = Game.GetTime()

            Lee.MiscData.WardJump.IsActive = true
            Lee.MiscData.WardJump.LastActiveT = curTime
            OriUtils.Items.Wards.LastCastT = curTime

            return true
        end
    end

    return false
end

function Lee.ResetVars()
    local curTime = Game.GetTime()
    local maxTime = 0.3

    local wardJumpTbl = Lee.MiscData.WardJump
    if wardJumpTbl.IsActive and curTime > wardJumpTbl.LastActiveT + maxTime then
        wardJumpTbl.IsActive = false
        wardJumpTbl.LastActiveT = 0
        Lee.ClearPotentialWards()
    end

    local insecTbl = Lee.MiscData.Insec
    if insecTbl.LastInsecPos and curTime > insecTbl.LastActiveT + maxTime then
        insecTbl.LastInsecPos = nil
    end

    local bowlTbl = Lee.MiscData.Bowl
    if bowlTbl.LastBowlPos and curTime > bowlTbl.LastActiveT + maxTime then
        bowlTbl.LastBowlPos = nil
    end

    local q1MissileTbl = Lee.MiscData.Q1Missile
    if q1MissileTbl.IsActive and curTime > q1MissileTbl.LastCreationTime + 5 then
        q1MissileTbl.IsActive = false
    end
end

function Lee.SetAndResetCustomPos()
    if OriUtils.MGet("insec.method.custom.setPos") then
        Lee.MiscData.Insec.CustomPos = Renderer.GetMousePos()
    end

    if OriUtils.MGet("insec.method.custom.clearPos") then
        Lee.MiscData.Insec.CustomPos = nil
    end
end

function Lee.GetInsecTargetPos()
    if OriUtils.MGet("insec.method.custom") and Lee.MiscData.Insec.CustomPos then
        return Lee.MiscData.Insec.CustomPos
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

function Lee.HandleBackupInsecPos()
    local lastGoodPos = Lee.GetInsecTargetPos()
    local isPressingInsec = OriUtils.MGet("insec.key")

    if isPressingInsec then
        if lastGoodPos then
            Lee.MiscData.Insec.BackupEndPos = lastGoodPos
        end
    else
        if Lee.MiscData.Insec.BackupEndPos then
            Lee.MiscData.Insec.BackupEndPos = nil
        end
    end
end

function Lee.HandleInsecBowlWardjump()
    if Lee.MiscData.WardJump.IsActive then
        if Lee.MiscData.Insec.LastInsecPos then
            return Lee.WardJump(Lee.MiscData.Insec.LastInsecPos)
        end

        if Lee.MiscData.Bowl.LastBowlPos then
            return Lee.WardJump(Lee.MiscData.Bowl.LastBowlPos)
        end
    end
end

---@param blinkMode number
---@return number|nil, '"Ward"'|'"Flash"'|nil
function Lee.GetInsecBowlRangeForMode(blinkMode)
    local function CheckWard()
        local wardSlot = Lee.GetWardSlot()

        if wardSlot and OriUtils.ShouldCastWard() and OriUtils.IsSpellReady(slots.W) and not Lee.HasW2() then
            return OriUtils.Items.Wards.Range, "Ward"
        end

        return false
    end

    local function CheckFlash()
        if spells.Flash.Slot and OriUtils.IsSpellReady(spells.Flash.Slot) then
            return spells.Flash.Range, "Flash"
        end

        return false
    end

    local data = {
        [0] = {CheckWard},
        [1] = {CheckFlash},
        [2] = {CheckWard, CheckFlash},
        [3] = {CheckFlash, CheckWard}
    }

    local blinkFunctions = data[blinkMode]
    for _, func in ipairs(blinkFunctions) do
        local funcResult, option = func()
        if funcResult then
            return funcResult, option
        end
    end

    return nil, nil
end

---@param firstMinion AIMinionClient
---@param castPos Vector
---@param targetPos Vector
function Lee.ShouldSmiteForGapclose(firstMinion, castPos, targetPos)
    local me = Player
    local myPos = me.ServerPos
    local endPos = myPos:Extended(castPos, myPos:Distance(targetPos))
    local width = spells.Q1.Radius * 2
    local speed = spells.Q1.Speed
    local delay = spells.Q1.Delay * 1000
    local toIgnore = {[firstMinion.Handle] = true}

    local col = Collision.SearchMinions(myPos, endPos, width, speed, delay, 1, "enemy", toIgnore)
    if col and col.Result then
        return false
    end

    return true
end

---@param target AIHeroClient
---@param shouldSmite boolean
function Lee.SmartQGapclose(target, shouldSmite)
    local me = Player

    local minDistToTarget = 400

    if Lee.HasQ2() then
        local q2Unit = Lee.Q2Unit(true)
        if q2Unit then
            local distToTarget = target:Distance(q2Unit)

            if distToTarget < minDistToTarget then
                if Lee.CastQ(nil) then
                    return true
                end
            end
        end
    else
        local pred = spells.Q1:GetPrediction(target)

        if pred then
            if pred.HitChanceEnum >= Enums.HitChance.Medium then
                if Lee.CastQ(pred.CastPosition) then
                    return true
                end
            elseif pred.HitChanceEnum == Enums.HitChance.Collision then 
                local colPoints = pred.CollisionPoints and #pred.CollisionPoints or 0
                if colPoints > 0 then
                    local firstCol = OriUtils.GetFirstElementSort(pred.CollisionObjects, function(elemA, elemB)
                        local distA = me:Distance(elemA)
                        local distB = me:Distance(elemB)

                        return distA < distB
                    end)

                    local dmgToUnit = Lee.GetSpellDamage(firstCol, slots.Q, false)
                    local unitHealth = HealthPred.GetHealthPrediction(firstCol, 0) --Possible TODO: Add collision time

                    if colPoints == 1 and shouldSmite and spells.Smite.Slot and OriUtils.IsSpellReady(spells.Smite.Slot) then
                        if unitHealth < OriUtils.GetSmiteDamage(firstCol) then
                            local distToMinion = me:Distance(firstCol)
                            local distToTargetPos = me:Distance(pred.TargetPosition)

                            if distToMinion < spells.Smite.Range and distToTargetPos < spells.Q1.Range then
                                if Lee.ShouldSmiteForGapclose(firstCol, pred.CastPosition, pred.TargetPosition) then
                                    if Lee.CastQ(pred.CastPosition) then
                                        delay(100, function() OriUtils.CastSmite(firstCol) end)
                                        
                                        return true
                                    end
                                end
                            end
                        end
                    elseif dmgToUnit < unitHealth then
                        local distToTarget = target:Distance(firstCol)
                        
                        if distToTarget < minDistToTarget then
                            if Lee.CastQ(pred.TargetPosition) then
                                return true
                            end
                        end
                    end
                end
            end
        end
    end

    return false
end

local slotToDamageTable = {
    [slots.Q] = function(isPhaseTwo) if isPhaseTwo then return damages.Q2 else return damages.Q1 end end,
    [slots.E] = damages.E1,
    [slots.R] = damages.R
}
---@param target AIBaseClient
---@param slot number
function Lee.GetSpellDamage(target, slot, isPhaseTwo, simulatedHealth, RMainTarget)
    local me = Player

    local rawDamage = 0
    local dmgType = nil

    local spellLevel = me:GetSpell(slot).Level

    if spellLevel >= 1 then
        local data = slotToDamageTable[slot]

        if data then
            if type(data) == "function" then
                data = data(isPhaseTwo)
            end
            
            dmgType = data.Type
            
            if data.Base then
                rawDamage = rawDamage + data.Base[spellLevel]
            end

            if data.BonusAD then
                rawDamage = rawDamage + (me.BonusAD * data.BonusAD)
            end
        
            if data.MissingHealthIncrease then
                rawDamage = rawDamage * data.MissingHealthIncrease(target, simulatedHealth)
            end
        
            if RMainTarget and data.CollisionIncrease then
                rawDamage = rawDamage + data.CollisionIncrease(RMainTarget)
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
function Lee.CheckRQCombo(target)
    if not OriUtils.IsSpellReady(slots.Q) or Lee.HasQ2() then
        return false
    end

    local me = Player

    local startPos = me.ServerPos
    local endPos = target.ServerPos:Extended(me, -spells.R.KickDist)
    local width = spells.Q1.Radius * 2
    local speed = spells.Q1.Speed
    local delay = spells.Q1.Delay * 1000
    local handlesToIgnore = {[target.Handle] = true}

    local col = Collision.SearchHeroes(startPos, endPos, width, speed, delay, 1, "enemy", handlesToIgnore)
    if col and col.Result then
        return false
    end

    col = Collision.SearchMinions(startPos, endPos, width, speed, delay, 1, "enemy")
    if col and col.Result then
        return false
    end

    local rDmg = Lee.GetSpellDamage(target, slots.R)
    local q1Dmg = Lee.GetSpellDamage(target, slots.Q, false)

    local targetHealth = HealthPred.GetHealthPrediction(target, 0)
    local tempHealth = max(0, targetHealth - (rDmg + q1Dmg))

    tempHealth = tempHealth - Lee.GetSpellDamage(target, slots.Q, true, tempHealth)

    if OriUtils.CanCastSpell(slots.E, "combo.useE1") and not Lee.HasE2() then
        local e1Dmg = Lee.GetSpellDamage(target, slots.E)
        tempHealth = tempHealth - e1Dmg
    end

    if tempHealth <= 0 then
        return true
    end

    return false
end

---@param target AIHeroClient
function Lee.CheckRQ2Combo(target)
    if not OriUtils.IsSpellReady(slots.Q) or not Lee.HasQ2() then
        return false
    end

    local q2Unit = Lee.Q2Unit(false)
    if not q2Unit or q2Unit.Handle ~= target.Handle then
        return false
    end

    local me = Player

    local targetHealth = HealthPred.GetKillstealHealth(target, 0, dmgTypes.Physical)
    local rDmg = Lee.GetSpellDamage(target, slots.R)

    local tempHealth = max(0, targetHealth - rDmg)
    tempHealth = tempHealth - Lee.GetSpellDamage(target, slots.Q, true, tempHealth)

    if tempHealth <= 0 then
        return true
    end

    return false
end

function Lee.GetHitchance(slot)
    local hc = 0.5

    if slot == slots.Q then
        hc = OriUtils.MGet("hc.Q1") * 0.01
    end

    return hc
end

---@return AIHeroClient|nil, AIHeroClient|nil @Returns firstTarget, secondTarget
function Lee.GetBowlingTargets(ranges, maxDistBetweenTargets)
    local me = Player

    local firstTarget = nil

    local forcedTarget = TS:GetForcedTarget()

    ---@param elemA AIHeroClient
    ---@param elemB AIHeroClient
    local function MostBonusHPFilter(elemA, elemB)
        return elemA.BonusHealth > elemB.BonusHealth
    end

    ---@param elemA AIHeroClient
    ---@param elemB AIHeroClient
    local function ClosestFilter(elemA, elemB)
        return me:Distance(elemA) < me:Distance(elemB)
    end

    local filterData = {
        [0] = MostBonusHPFilter,
        [1] = ClosestFilter
    }

    if forcedTarget then
        firstTarget = forcedTarget
    else
        local enemyHeroes = TS:GetTargets(ranges[#ranges])

        local bowlMode = OriUtils.MGet("bowl.bowlMode")
        local filter = filterData[bowlMode]

        firstTarget = OriUtils.GetFirstElementSort(enemyHeroes, filter)
    end

    if not firstTarget then
        return nil, nil
    end

    local potentialSecondTargets = {}
    local enemyHeroes = ObjManager.GetNearby("enemy", "heroes")
    for _, obj in ipairs(enemyHeroes) do
        local hero = obj.AsHero

        if OriUtils.IsValidTarget(hero, maxDistBetweenTargets, firstTarget.ServerPos) and hero.Handle ~= firstTarget.Handle then
            potentialSecondTargets[#potentialSecondTargets+1] = hero
        end
    end

    ---@param elemA AIHeroClient
    ---@param elemB AIHeroClient
    local function LowestHPFilter(elemA, elemB)
        return elemA.Health < elemB.Health
    end

    local secondTarget = OriUtils.GetFirstElementSort(potentialSecondTargets, LowestHPFilter)

    if not secondTarget then
        return nil, nil
    end

    return firstTarget, secondTarget
end

function Lee.IsQ1MisActive()
    return Lee.MiscData.Q1Missile.IsActive
end

---@param target AIHeroClient
function Lee.Q2ComboCastChecks(target)
    local me = Player

    local preventClose = OriUtils.MGet("combo.useQ2.preventClose")
    local dist = me:Distance(target)
    local aaRange = Orbwalker.GetTrueAutoAttackRange(me, target)

    local q2Buff = target:GetBuff("BlindMonkQOne")
    local willExpireSoon = q2Buff and q2Buff.DurationLeft < 0.3

    if preventClose and dist < aaRange and not willExpireSoon then
        return false
    end

    return true
end

function fightModes.Flee(lagFree)
    local me = Player

    if OriUtils.MGet("flee.wardJump") then
        local jumpPos = Renderer.GetMousePos()

        if OriUtils.MGet("flee.wardJump.maxRange") or me:Distance(jumpPos) > OriUtils.Items.Wards.Range then
            jumpPos = me.ServerPos:Extended(jumpPos, OriUtils.Items.Wards.Range)
        end

        return Lee.WardJump(jumpPos)
    end
end

function fightModes.Insec()
    local minDistToinsec = 150
    local minDistToWalkToPos = 600

    local me = Player

    local moveToPos = OriUtils.MGet("insec.moveToPos")

    local function WalkToMouse()
        if moveToPos then
            Orbwalker.Orbwalk(Renderer.GetMousePos())
        end
    end

    if not OriUtils.IsSpellReady(slots.R) then
        WalkToMouse()
        return false
    end

    local forcedTarget = TS:GetForcedTarget()

    local gapclose = OriUtils.MGet("insec.gpQ")

    local ranges = {spells.R.Range}

    --local blinkMode = OriUtils.MGet("insec.blinkPriority")
    local blinkRange, blinkOption = Lee.GetInsecBowlRangeForMode(OriUtils.MGet("insec.blinkPriority"))

    if blinkRange then
        insert(ranges, blinkRange)
    end

    local isQReady = OriUtils.IsSpellReady(slots.Q)

    if gapclose and isQReady then
        insert(ranges, spells.Q1.Range)
    end

    local target = OriUtils.ChooseTarget(forcedTarget, ranges)
    if not target then
        WalkToMouse()
        return false
    end

    local targetPos = Lee.GetInsecTargetPos()
    if not targetPos then
        targetPos = Lee.MiscData.Insec.BackupEndPos

        if not targetPos then
            WalkToMouse()
            return false
        end
    end

    local insecPos = target.ServerPos:Extended(targetPos, -200)
    Lee.MiscData.Insec.LastInsecPos = insecPos
    
    local distToInsecPos = me:Distance(insecPos)

    if distToInsecPos <= minDistToinsec then
        if Lee.CastR(target) then
            return true
        end
    elseif distToInsecPos < minDistToWalkToPos and moveToPos then
        Orbwalker.Orbwalk(insecPos)
    else
        WalkToMouse()
    end

    local curTime = Game.GetTime()

    if blinkRange and distToInsecPos < blinkRange and curTime > Lee.MiscData.Insec.LastActiveT + 0.75 then
        if blinkOption == "Ward" then
            local wardSlot = Lee.GetWardSlot()

            if OriUtils.CastSpell(wardSlot, insecPos) then
                Lee.MiscData.WardJump.IsActive = true
                Lee.MiscData.WardJump.LastActiveT = curTime
                OriUtils.Items.Wards.LastCastT = curTime

                Lee.MiscData.Insec.LastActiveT = curTime

                return true
            end
        elseif blinkOption == "Flash" then
            --[[
            if OriUtils.CastSpell(spells.Flash.Slot, insecPos) then
                Lee.MiscData.Insec.LastActiveT = curTime

                return true
            end
            --]]

            if spells.R:IsInRange(target) then
                if Lee.CastR(target) then
                    delay(100, function() OriUtils.CastSpell(spells.Flash.Slot, insecPos) end)
                    Lee.MiscData.Insec.LastActiveT = curTime
                    
                    return true
                end
            end
        end
    elseif gapclose and isQReady then
        if Lee.SmartQGapclose(target, OriUtils.MGet("insec.gpQ.smite")) then
            return true
        end
    end

    return false
end

function fightModes.Bowling()
    local minDistToBowl = 75
    local minDistToWalkToPos = 600

    local maxDistBetweenTargets = 600

    local me = Player

    local moveToPos = OriUtils.MGet("bowl.moveToPos")

    ---@param bowlPos Vector
    local function WalkToPos(bowlPos)
        bowlPos = bowlPos or Renderer.GetMousePos()

        local curTime = Game.GetTime()
        if moveToPos and curTime > Lee.MiscData.InsecBowlMoveToLastT + 0.25 then
            Orbwalker.Orbwalk(bowlPos)
            Lee.MiscData.InsecBowlMoveToLastT = curTime
        end
    end

    if not OriUtils.IsSpellReady(slots.R) then
        WalkToPos()   
        return false
    end

    local ranges = {spells.R.Range}

    local blinkRange, blinkOption = Lee.GetInsecBowlRangeForMode(OriUtils.MGet("bowl.blinkPriority"))

    if blinkRange then
        insert(ranges, blinkRange)
    end

    local gapclose = OriUtils.MGet("bowl.gpQ")
    local useQ = OriUtils.IsSpellReady(slots.Q)
    local specialCases = OriUtils.IsDashing() or Lee.IsQ1MisActive()

    if gapclose and (useQ or specialCases) then
        insert(ranges, spells.Q1.Range)
    end

    local firstTarget, secondTarget = Lee.GetBowlingTargets(ranges, maxDistBetweenTargets)

    if not firstTarget then
        WalkToPos()
        return false
    end

    local predInput = {
        Range = spells.R.KickDist,
        Delay = spells.R.Delay,
        Radius = firstTarget.BoundingRadius,
        Speed = spells.R.Speed,
        Type = "Linear"
    }

    local bowlPos = nil

    local pred = Prediction.GetPredictedPosition(secondTarget, predInput, firstTarget.ServerPos)
    if pred and pred.HitChanceEnum >= Enums.HitChance.Medium then
        bowlPos = firstTarget.ServerPos:Extended(pred.CastPosition, -250)
    end

    if not bowlPos then
        WalkToPos()
        return false
    end

    Lee.MiscData.Bowl.LastBowlPos = bowlPos

    local distToBowlPos = me:Distance(bowlPos)

    if distToBowlPos <= minDistToBowl then
        if Lee.CastR(firstTarget) then
            return true
        end
    elseif distToBowlPos < minDistToWalkToPos and moveToPos then
        WalkToPos(bowlPos)
    else
        WalkToPos()
    end

    local curTime = Game.GetTime()

    if blinkRange and distToBowlPos < blinkRange and curTime > Lee.MiscData.Bowl.LastActiveT + 0.75 then
        if blinkOption == "Ward" then
            local wardSlot = Lee.GetWardSlot()

            if OriUtils.CastSpell(wardSlot, bowlPos) then
                Lee.MiscData.WardJump.IsActive = true
                Lee.MiscData.WardJump.LastActiveT = curTime
                OriUtils.Items.Wards.LastCastT = curTime

                Lee.MiscData.Bowl.LastActiveT = curTime

                return true
            end
        elseif blinkOption == "Flash" then
            if spells.R:IsInRange(firstTarget) then
                if Lee.CastR(firstTarget) then
                    delay(100, function() OriUtils.CastSpell(spells.Flash.Slot, bowlPos) end)
                    Lee.MiscData.Bowl.LastActiveT = curTime
                    
                    return true
                end
            end
        end
    elseif not Lee.MiscData.WardJump.IsActive and gapclose and useQ then
        if Lee.SmartQGapclose(firstTarget, OriUtils.MGet("bowl.gpQ.smite")) then
            return true
        end
    end

    return false
end

function fightModes.ExtraModes(lagFree)
    if OriUtils.MGet("insec.key") then
        return fightModes.Insec()
    end

    if OriUtils.MGet("bowl.key") then
        return fightModes.Bowling()
    end
end

function fightModes.Killsteal(lagFree)
    if Orbwalker.GetMode() == "Combo" or not OriUtils.MGet("ks.onlyCombo") then
        local me = Player
        local myPos = me.ServerPos

        local isQReady = OriUtils.IsSpellReady(slots.Q)
        local hasQ2 = Lee.HasQ2()
        local useQ1 = OriUtils.MGet("ks.useQ1")
        local useQ2 = OriUtils.MGet("ks.useQ2")
        local useE1 = OriUtils.CanCastSpell(slots.E, "ks.useE1") and not Lee.HasE2()
        local useR = OriUtils.CanCastSpell(slots.R, "ks.useR")

        local enemies = ObjManager.GetNearby("enemy", "heroes")
        for _, obj in ipairs(enemies) do
            local hero = obj.AsHero

            if OriUtils.IsValidTarget(hero) then
                local heroName = hero.CharName
                local heroHealthMagic = HealthPred.GetKillstealHealth(hero, 0, dmgTypes.Magical)
                local heroHealthPhysical = HealthPred.GetKillstealHealth(hero, 0, dmgTypes.Physical)

                if useE1 then
                    if spells.E1:IsInRange(hero) and heroHealthMagic < Lee.GetSpellDamage(hero, slots.E) then
                        if Lee.CastE() then
                            return true
                        end
                    end
                end

                if isQReady then
                    if not hasQ2 then      
                        if useQ1 then
                            if heroHealthPhysical < Lee.GetSpellDamage(hero, slots.Q, false) then
                                local pred = spells.Q1:GetPrediction(hero)
                                if pred and pred.HitChanceEnum >= Enums.HitChance.Medium then
                                    if Lee.CastQ(pred.CastPosition) then
                                        return true
                                    end
                                end
                            end
                        end
                    end
                end

                if useR and OriUtils.MGet("ks.useR.wl." .. heroName, true) then
                    if spells.R:IsInRange(hero) and heroHealthPhysical < Lee.GetSpellDamage(hero, slots.R) then
                        if Lee.CastR(hero) then
                            return true
                        end
                    end
                end
            end
        end

        if isQReady and hasQ2 and useQ2 then
            local q2Unit = Lee.Q2Unit()

            if q2Unit then
                local heroHealthPhysical = HealthPred.GetKillstealHealth(q2Unit, 0, dmgTypes.Physical)

                if heroHealthPhysical < Lee.GetSpellDamage(q2Unit, slots.Q, true) then
                    if Lee.CastQ() then
                        return true
                    end
                end
            end
        end
    end
end

function fightModes.Combo(lagFree)
    local me = Player

    local forcedTarget = TS:GetForcedTarget()

    if OriUtils.CanCastSpell(slots.R, "combo.useR") then
        local rTargets = spells.R:GetTargets()

        local useKnockInto = OriUtils.MGet("combo.useR.knockInto")
        local knockIntoMinHit = OriUtils.MGet("combo.useR.knockInto.minHit")
        local useKillableQCombo = OriUtils.MGet("combo.useR.killableQCombo")

        for _, hero in ipairs(rTargets) do
            if useKnockInto then
                if Lee.RWillCollideWith(hero, knockIntoMinHit) then
                    if Lee.CastR(hero) then
                        return true
                    end
                end
            end

            if useKillableQCombo and OriUtils.MGet("combo.useR.killableQCombo.wl." .. hero.CharName, true) then
                if Lee.CheckRQ2Combo(hero) then
                    if Lee.CastR(hero) then
                        delay(spells.R.Delay * 1000 + 100, function() Lee.CastQ() end)

                        return true
                    end
                end

                if Lee.CheckRQCombo(hero) then
                    if Lee.CastR(hero) then
                        delay(spells.R.Delay * 1000 + 100, function() Lee.CastQ(hero.ServerPos) end)

                        return true
                    end
                end
            end
        end
    end

    local bypassPassive = false
    local q1Target = nil
    local q2Unit = nil

    local hasQ2 = Lee.HasQ2()
    local useQ1 = OriUtils.MGet("combo.useQ1")
    local useQ2 = OriUtils.MGet("combo.useQ2")
    local isQReady = OriUtils.IsSpellReady(slots.Q)

    local hasE2 = Lee.HasE2()
    local useE2 = OriUtils.MGet("combo.useE2")
    local isEReady = OriUtils.IsSpellReady(slots.E)

    if isQReady then
        if hasQ2 then
            q2Unit = Lee.Q2Unit()
            if q2Unit and useQ2 then
                local aaRange = Orbwalker.GetTrueAutoAttackRange(me, q2Unit)

                if me:Distance(q2Unit) > aaRange then
                    bypassPassive = true
                end
            end
        else
            if useQ1 then
                q1Target = OriUtils.ChooseTarget(forcedTarget, {spells.Q1.Range})
                if q1Target then
                    local aaRange = Orbwalker.GetTrueAutoAttackRange(me, q1Target)
                    
                    if me:Distance(q1Target) > aaRange then
                        bypassPassive = true
                    end
                end
            end
        end
    end

    if not isQReady or not (useQ1 and useQ2) then
        if isEReady and hasE2 and useE2 then
            local aaRange = Orbwalker.GetTrueAutoAttackRange(me)

            if not TS:GetTarget(aaRange) then
                bypassPassive = true
            end
        end
    end

    local targetPassive = 2 - OriUtils.MGet("combo.passive")
    if Lee.MiscData.PassiveStacks > targetPassive and not bypassPassive then return false end

    if isQReady then
        if hasQ2 then
            if q2Unit and useQ2 then
                if Lee.Q2ComboCastChecks(q2Unit) then
                    if Lee.CastQ(nil) then
                        return true
                    end
                end
            end
        else
            if useQ1 then
                if q1Target then
                    local pred = spells.Q1:GetPrediction(q1Target)
                    if pred and pred.HitChance > Lee.GetHitchance(slots.Q) then
                        if Lee.CastQ(pred.CastPosition) then
                            return true
                        end
                    end
                end
            end
        end
    end

    if OriUtils.IsSpellReady(slots.W) then
        if Lee.HasW2() then
            if OriUtils.MGet("combo.useW2") then
                if Lee.CastW(nil) then
                    return
                end
            end
        else
            if OriUtils.MGet("combo.useW1") then
                if not OriUtils.IsDashing() then
                    local target = OriUtils.ChooseTarget(forcedTarget, {spells.W1.Range})

                    if target and me:Distance(target) < spells.W1.Range then
                        if Lee.ComboW(target) then
                            return true
                        end
                    end
                end
            end
        end
    end

    if OriUtils.IsSpellReady(slots.E) then
        if Lee.HasE2() then
            if OriUtils.MGet("combo.useE2") then
                if Lee.CastE() then
                    return true
                end
            end
        else
            if OriUtils.MGet("combo.useE1") then
                local target = OriUtils.ChooseTarget(forcedTarget, {spells.E1.Range})

                if target and me:Distance(target) < spells.E1.Range then
                    if Lee.CastE() then
                        return true
                    end
                end
            end
        end
    end
end

function fightModes.Harass(lagFree)
    local me = Player

    local forcedTarget = TS:GetForcedTarget()

    if OriUtils.IsSpellReady(slots.Q) then
        if Lee.HasQ2() then
            if OriUtils.MGet("harass.useQ2") and Lee.Q2Unit(false) then
                if Lee.CastQ(nil) then
                    return true
                end
            end
        else
            if OriUtils.MGet("harass.useQ1") then
                local target = OriUtils.ChooseTarget(forcedTarget, {spells.Q1.Range})
                if target and me:Distance(target) < spells.Q1.Range then
                    local pred = spells.Q1:GetPrediction(target)

                    if pred and pred.HitChance > Lee.GetHitchance(slots.Q) then
                        if Lee.CastQ(pred.CastPosition) then
                            return true
                        end
                    end
                end
            end
        end
    end

    if OriUtils.IsSpellReady(slots.E) then
        if Lee.HasE2() then
            if OriUtils.MGet("harass.useE2") then
                if Lee.CastE() then
                    return true
                end
            end
        else
            if OriUtils.MGet("harass.useE1") then
                local target = OriUtils.ChooseTarget(forcedTarget, {spells.E1.Range})
                if target and me:Distance(target) < spells.E1.Range then
                    if Lee.CastE() then
                        return true
                    end
                end
            end
        end
    end
end

function fightModes.Waveclear(lagFree)
    local me = Player

    local _, enemyMinions, jungleMinions = OriUtils.GetEnemyAndJungleMinions()

    local function ClearCombo(minions, isJungleMode, laneE1Hit)
        if isJungleMode then
            sort(minions, function(elemA, elemB)
                return me:Distance(elemA) < me:Distance(elemB)
            end)
        else
            if not (OriUtils.MGet("clear.lane.enemyAround") or not TS:GetTarget(1500)) then
                return false
            end
        end

        local function MenuOption(str)
            if isJungleMode then
                return OriUtils.MGet("clear.jungle." .. str)
            else
                return OriUtils.MGet("clear.lane." .. str)
            end
        end

        local isQReady = OriUtils.IsSpellReady(slots.Q)
        local hasQ2 = Lee.HasQ2()

        local isWReady = OriUtils.IsSpellReady(slots.W)
        local hasW2 = Lee.HasW2()

        local isEReady = OriUtils.IsSpellReady(slots.E)
        local hasE2 = Lee.HasE2()

        local useQ1 = MenuOption("useQ1")
        local useQ2 = MenuOption("useQ2")
        local useW1 = MenuOption("useW1")
        local useW2 = MenuOption("useW2")
        local useE1 = MenuOption("useE1")
        local useE2 = MenuOption("useE2")

        local useE1MinHit = nil
        if not isJungleMode then
            useE1MinHit = MenuOption("useE1.minHit")
        end

        local function BypassPassive(minion)
            if isQReady then
                if hasQ2 then
                    if useQ2 then
                        local q2Unit = Lee.Q2Unit(true)
                        if q2Unit and q2Unit.IsMinion or q2Unit.IsMonster then
                            local dist = me:Distance(q2Unit)
                            local aaRange = Orbwalker.GetTrueAutoAttackRange(me, q2Unit)

                            if dist > aaRange then
                                return true
                            end
                        end
                    end
                else
                    if useQ1 then
                        local dist = me:Distance(minion)
                        local aaRange = Orbwalker.GetTrueAutoAttackRange(me, minion)

                        if dist > aaRange then
                            return true
                        end
                    end
                end
            end

            return false
        end

        local targetPassive = 2 - MenuOption("passive")

        for _, minion in ipairs(minions) do
            if Lee.MiscData.PassiveStacks > targetPassive and not BypassPassive(minion) then return false end

            local distToMinion = me:Distance(minion)

            if isQReady then
                if hasQ2 then
                    if useQ2 then
                        local q2Unit = Lee.Q2Unit(true)
                        if q2Unit and q2Unit.IsMonster or q2Unit.IsMinion then
                            if Lee.CastQ(nil) then
                                return true
                            end
                        end
                    end
                else
                    if useQ1 then
                        local pred = spells.Q1:GetPrediction(minion)
                        if pred and pred.HitChanceEnum >= Enums.HitChance.Medium then
                            if Lee.CastQ(pred.CastPosition) then
                                return true
                            end
                        end
                    end
                end
            end

            if isEReady then
                if hasE2 then
                    if useE2 then
                        if Lee.CastE() then
                            return true
                        end
                    end
                else
                    if useE1 then
                        if (useE1MinHit and laneE1Hit >= useE1MinHit) or (not useE1MinHit and distToMinion < spells.E1.Range) then
                            if Lee.CastE() then
                                return true
                            end
                        end
                    end
                end
            end

            if isWReady then
                if hasW2 then
                    if useW2 then
                        if Lee.CastW(nil) then
                            return true
                        end
                    end
                else
                    if useW1 then
                        if distToMinion < Orbwalker.GetTrueAutoAttackRange(me, minion) then
                            if Lee.CastW(me) then
                                return true
                            end
                        end
                    end
                end
            end
        end
    end

    local minionsInERange = 0
    for _, minion in ipairs(enemyMinions) do
        if me:Distance(minion) < spells.E1.Range then
            minionsInERange = minionsInERange + 1
        end
    end

    if ClearCombo(enemyMinions, false, minionsInERange) then
        return true
    end

    if ClearCombo(jungleMinions, true) then
        return true
    end

    return false
end

function events.OnTick(lagFree)
    OriUtils.CheckFlashSlot()
    OriUtils.CheckSmiteSlot()
    
    Lee.HandleBackupInsecPos()
    
    Lee.SetAndResetCustomPos()

    Lee.HandleInsecBowlWardjump()

    Lee.ResetVars()

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
    {slot = slots.Q, id = "Q", displayText = "Q1/Q2 [Sonic Wave/Resonating Strike]", range = function() if Lee.HasQ2() then return spells.Q2.Range else return spells.Q1.Range end end},
    {slot = slots.W, id = "W", displayText = "W1/W2 [Safeguard/Iron Will]", range = function() if Lee.HasW2() then return 0 else return spells.W1.Range end end},
    {slot = slots.E, id = "E", displayText = "E1/E2 [Tempest/Cripple]", range = function() if Lee.HasE2() then return spells.E2.Range else return spells.E1.Range end end},
    {slot = slots.R, id = "R", displayText = "R [Dragon's Rage]", range = spells.R.Range}
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

    if OriUtils.MGet("draw.customPos") and Lee.MiscData.Insec.CustomPos then
        local customPos = Lee.MiscData.Insec.CustomPos
        local color = OriUtils.MGet("draw.customPos.color")

        Renderer.DrawCircle3D(customPos, 125, 30, 3, color)
        Renderer.DrawLine3D(myPos, customPos, 2, color)
    end

    if OriUtils.MGet("draw.backupPos") and Lee.MiscData.Insec.BackupEndPos then
        local color = OriUtils.MGet("draw.backupPos.color")

        Renderer.DrawLine3D(myPos, Lee.MiscData.Insec.BackupEndPos, 4, color)
    end

    if OriUtils.MGet("draw.bowlingHelper") and OriUtils.IsSpellReady(slots.R) then
        local ranges = {spells.R.Range}

        local blinkRange, blinkOption = Lee.GetInsecBowlRangeForMode(OriUtils.MGet("bowl.blinkPriority"))
    
        if blinkRange then
            insert(ranges, blinkRange)
        end
    
        local gapclose = OriUtils.MGet("bowl.gpQ")
        local useQ = OriUtils.IsSpellReady(slots.Q)
        local specialCases = OriUtils.IsDashing() or Lee.IsQ1MisActive()
    
        if gapclose and (useQ or specialCases) then
            insert(ranges, spells.Q1.Range)
        end

        local firstTarget, secondTarget = Lee.GetBowlingTargets(ranges, 600)

        if firstTarget then
            local fp = firstTarget.ServerPos
            local sp = secondTarget.ServerPos

            OriUtils.DrawSimpleArrow(fp, sp, 2, OriUtils.MGet("draw.bowlingHelper.arrow"))

            local centerPoint = Vector((fp.x + sp.x) / 2, 0, (fp.z + sp.z) / 2)
            Renderer.DrawCircle3D(centerPoint, 600 / 2, 30, 2, OriUtils.MGet("draw.bowlingHelper.validCircle"))
        end
    end

    if OriUtils.MGet("draw.specialRFlash") then
        local rFlashStatus = OriUtils.MGet("insec.specialRFlashKey")

        local text = rFlashStatus and "Special R Flash Insec: On" or "Special R Flash Insec: Off"
        local color = rFlashStatus and 0x00FF00FF or 0xFF0000FF

        Renderer.DrawTextOnPlayer(text, color)
    end

    OriUtils.HandleCircleRangeHelpers()
end

function events.OnDrawDamage(target, dmgList)
    if not OriUtils.MGet("draw.comboDamage") then
        return
    end

    local me = Player

    local damageToDeal = 0

    local useQ2 = OriUtils.MGet("combo.useQ2")

    if OriUtils.Perks.Electrocute.HasBuff then
        damageToDeal = damageToDeal + OriUtils.GetElectrocuteDamage(target)
    end

    if OriUtils.IsSpellReady(slots.Q) then
        if Lee.HasQ2() then
            local q2Unit = Lee.Q2Unit(false)

            if useQ2 and q2Unit and q2Unit.Handle == target.Handle then
                damageToDeal = damageToDeal + Lee.GetSpellDamage(target, slots.Q, true)
            end
        else
            if OriUtils.MGet("combo.useQ1") then
                local q1Damage = Lee.GetSpellDamage(target, slots.Q, false)
                damageToDeal = damageToDeal + q1Damage

                if useQ2 then
                    local tempHealth = HealthPred.GetHealthPrediction(target, 0)
                    tempHealth = max(0, tempHealth - q1Damage)

                    damageToDeal = damageToDeal + Lee.GetSpellDamage(target, slots.Q, true, tempHealth)
                end
            end
        end
    end

    if OriUtils.IsSpellReady(slots.E) then
        if not Lee.HasE2() then
            if OriUtils.MGet("combo.useE1") then
                damageToDeal = damageToDeal + Lee.GetSpellDamage(target, slots.E)
            end
        end
    end

    if OriUtils.CanCastSpell(slots.R, "combo.useR") then
        damageToDeal = damageToDeal + Lee.GetSpellDamage(target, slots.R)
    end

    insert(dmgList, damageToDeal)
end

---@param obj GameObject
---@param buffInst BuffInst
function events.OnBuffGain(obj, buffInst)
    if obj and buffInst then
        if obj.IsMe then
            if buffInst.Name == Lee.MiscData.PassiveName then
                Lee.MiscData.PassiveStacks = 2
            end

            if buffInst.Name == OriUtils.Perks.Electrocute.BuffName then
                OriUtils.Perks.Electrocute.HasBuff = true
            end
        end
    end
end

---@param obj GameObject
---@param buffInst BuffInst
function events.OnBuffUpdate(obj, buffInst)
    if obj and buffInst then
        if obj.IsMe then
            if buffInst.Name == Lee.MiscData.PassiveName then
                Lee.MiscData.PassiveStacks = buffInst.Count
            end
        end
    end
end

---@param obj GameObject
---@param buffInst BuffInst
function events.OnBuffLost(obj, buffInst)
    if obj and buffInst then
        if obj.IsMe then
            if buffInst.Name == Lee.MiscData.PassiveName then
                Lee.MiscData.PassiveStacks = 0
            end

            if buffInst.Name == OriUtils.Perks.Electrocute.BuffName then
                OriUtils.Perks.Electrocute.HasBuff = false
            end
        end
    end
end

---@param obj GameObject
function events.OnCreateObject(obj)
    local me = Player

    if obj then
        if Lee.MiscData.WardJump.IsActive and obj.IsWard and obj.IsAlly then
            local ward = obj.AsMinion
            
            if ward.MaxHealth > 1 and me:Distance(ward) <= spells.W1.Range then
                insert(Lee.MiscData.WardJump.PotentialWards, ward)
            end
        end

        if obj.IsMissile then
            local missile = obj.AsMissile

            if missile.Caster and missile.Caster.IsMe and missile.Name == Lee.MiscData.Q1Missile.MissileName then
                Lee.MiscData.Q1Missile.IsActive = true
                Lee.MiscData.Q1Missile.LastCreationTime = Game.GetTime()
            end
        end
    end
end

---@param obj GameObject
function events.OnDeleteObject(obj)
    local me = Player

    if obj then
        if obj.IsMissile then
            local missile = obj.AsMissile

            if missile.Caster and missile.Caster.IsMe and missile.Name == Lee.MiscData.Q1Missile.MissileName then
                Lee.MiscData.Q1Missile.IsActive = false
            end
        end
    end
end

---@param obj GameObject
---@param spellCast SpellCast
function events.OnProcessSpell(obj, spellCast)
    local me = Player

    if obj and spellCast then
        if obj.IsMe then
            local curTime = Game.GetTime()

            if OriUtils.MGet("insec.specialRFlashKey") and curTime > Lee.MiscData.Insec.LastActiveT + 0.75 then
                if Lee.MiscData.Insec.CustomPos and spellCast.Slot == slots.R then
                    if spells.Flash.Slot and OriUtils.IsSpellReady(spells.Flash.Slot) then
                        local target = spellCast.Target.AsHero
                        local flashPos = target.ServerPos:Extended(Lee.MiscData.Insec.CustomPos, -200)
                        
                        delay(100, function() OriUtils.CastFlash(flashPos) end)

                        Lee.MiscData.Insec.LastActiveT = curTime
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
        elseif spells.Smite.Slot and spells.Smite.Slot == slot then
            spells.Smite.LastCastT = Game.GetTime()
        end
    end
end

function Lee.RegisterEvents()
    for eventName, eventId in pairs(Enums.Events) do
        if events[eventName] then
            EventManager.RegisterCallback(eventId, events[eventName])
        end
    end
end

function Lee.InitMenu()
    local QHeader, WHeader, EHeader, RHeader = OriUtils.GetMenuHeaders(drawData)

    local function LeeMenu()
        local enemyHeroes = ObjManager.Get("enemy", "heroes")

        Menu.Text("Version: " .. SCRIPT_VERSION, true)
        Menu.Text("Last Updated: " .. SCRIPT_LAST_UPDATED, true)
        if SCRIPT_IS_BETA then
            Menu.ColoredText("This is a beta, if you find any issues, report them to " .. SCRIPT_AUTHOR, 0xFFFF00FF, true)
        end

        Menu.NewTree("LeeSin.comboMenu", "Combo Settings", function()
            Menu.Slider("LeeSin.combo.passive", "Use X passive stacks", 1, 0, 2, 1)

            Menu.ColumnLayout("LeeSin.comboMenu.QW", "LeeSin.comboMenu.QW", 2, true, function()
                QHeader()

                Menu.Checkbox("LeeSin.combo.useQ1", "Enable Q1", true)

                Menu.Checkbox("LeeSin.combo.useQ2", "Enable Q2", true)
                Menu.Indent(function()
                    Menu.Checkbox("LeeSin.combo.useQ2.preventClose", "Prevent Q2 cast if target is in AA range", false)
                    Menu.Indent(function()
                        Menu.ColoredText("It will still cast Q2 if its about to expire", 0xFFFF00FF)
                    end)
                end)

                Menu.NextColumn()

                WHeader()

                Menu.Dropdown("LeeSin.combo.useW1", "W1 Mode", 0, {"Don't use", "Only on me", "Ally heroes and me", "Gapclose to any ally unit"})
                Menu.Checkbox("LeeSin.combo.useW2", "Enable W2", true)
            end)

            Menu.Separator()

            Menu.ColumnLayout("LeeSin.comboMenu.ER", "LeeSin.comboMenu.ER", 2, true, function()
                EHeader()

                Menu.Checkbox("LeeSin.combo.useE1", "Enable E1", true)
                Menu.Checkbox("LeeSin.combo.useE2", "Enable E2", true)

                Menu.NextColumn()

                RHeader()

                Menu.Checkbox("LeeSin.combo.useR", "Enable R", true)
                Menu.Indent(function()
                    Menu.Checkbox("LeeSin.combo.useR.knockInto", "To knock into multiple enemies", true)
                    Menu.Indent(function()
                        Menu.Slider("LeeSin.combo.useR.knockInto.minHit", "Min enemies to knock up", 2, 1, 4, 1)
                    end)

                    Menu.Checkbox("LeeSin.combo.useR.killableQCombo", "To kill with Q1 & Q2 combo", true)
                    Menu.Indent(function()
                        Menu.NewTree("LeeSin.comboMenu.RQ1Q2WL", "Whitelist", function()
                            local addedWL = {}

                            for _, obj in pairs(enemyHeroes) do
                                local hero = obj.AsHero
                                local heroName = hero.CharName

                                if hero and not addedWL[heroName] then
                                    addedWL[heroName] = true

                                    Menu.Checkbox("LeeSin.combo.useR.killableQCombo.wl." .. heroName, "Use R early to kill " .. heroName, true)
                                end
                            end
                        end)
                    end)
                end)
            end)
        end)

        Menu.NewTree("LeeSin.harassMenu", "Harass Settings", function()
            QHeader()

            Menu.Checkbox("LeeSin.harass.useQ1", "Enable Q1", true)
            Menu.Checkbox("LeeSin.harass.useQ2", "Enable Q2", false)

            Menu.Separator()

            EHeader()

            Menu.Checkbox("LeeSin.harass.useE1", "Enable E1", true)
            Menu.Checkbox("LeeSin.harass.useE2", "Enable E2", true)
        end)

        Menu.NewTree("LeeSin.laneClearMenu", "Lane Clear Settings", function()
            Menu.Checkbox("LeeSin.clear.lane.enemyAround", "Clear even if enemies around", false)
            Menu.Slider("LeeSin.clear.lane.passive", "Use X passive stacks", 1, 0, 2, 1)

            QHeader()

            Menu.Checkbox("LeeSin.clear.lane.useQ1", "Enable Q1", false)
            Menu.Checkbox("LeeSin.clear.lane.useQ2", "Enable Q2", false)

            Menu.Separator()

            WHeader()

            Menu.Checkbox("LeeSin.clear.lane.useW1", "Enable W1", false)
            Menu.Checkbox("LeeSin.clear.lane.useW2", "Enable W2", false)

            Menu.Separator()

            EHeader()

            Menu.Checkbox("LeeSin.clear.lane.useE1", "Enable E1", true)
            Menu.Indent(function()
                Menu.Slider("LeeSin.clear.lane.useE1.minHit", "Min minions to hit", 2, 1, 5, 1)
            end)
            Menu.Checkbox("LeeSin.clear.lane.useE2", "Enable E2", true)
        end)

        Menu.NewTree("LeeSin.jungleClearMenu", "Jungle Clear Settings", function()
            Menu.Slider("LeeSin.clear.jungle.passive", "Use X passive stacks", 1, 0, 2, 1)

            QHeader()

            Menu.Checkbox("LeeSin.clear.jungle.useQ1", "Enable Q1", true)
            Menu.Checkbox("LeeSin.clear.jungle.useQ2", "Enable Q2", true)

            Menu.Separator()

            WHeader()

            Menu.Checkbox("LeeSin.clear.jungle.useW1", "Enable W1", true)
            Menu.Checkbox("LeeSin.clear.jungle.useW2", "Enable W2", true)

            Menu.Separator()

            EHeader()

            Menu.Checkbox("LeeSin.clear.jungle.useE1", "Enable E1", true)
            Menu.Checkbox("LeeSin.clear.jungle.useE2", "Enable E2", true)
        end)

        Menu.NewTree("LeeSin.insecMenu", "Insec Settings", function()
            Menu.Keybind("LeeSin.insec.key", "Insec key", string.byte("T"))

            Menu.Separator()

            Menu.Checkbox("LeeSin.insec.gpQ", "Smart gapclose with Q", true)
            Menu.Indent(function()
                Menu.Checkbox("LeeSin.insec.gpQ.smite", "Smite minion to gapclose", false)
            end)
            Menu.Checkbox("LeeSin.insec.moveToPos", "Move to mouse/insec pos", true)
            Menu.Dropdown("LeeSin.insec.blinkPriority", "Blink priority", 2, {"Only ward", "Only flash", "Ward then flash", "Flash then ward"})
            
            Menu.Separator()

            Menu.Keybind("LeeSin.insec.specialRFlashKey", "Toggle flash insec after manual R", string.byte("U"), true)
            Menu.Indent(function()
                Menu.Text("This only works if an Insec custom pos is set")
            end)

            Menu.Separator()

            Menu.ColoredText("Insec target positions", SCRIPT_COLOR)

            Menu.Indent(function()
                Menu.Checkbox("LeeSin.insec.method.custom", "To custom pos", true)
                Menu.Indent(function()
                    Menu.Keybind("LeeSin.insec.method.custom.setPos", "Set custom pos", string.byte("G"))
                    Menu.Keybind("LeeSin.insec.method.custom.clearPos", "Clear custom pos", string.byte("H"))
                end)

                Menu.Separator()

                Menu.Checkbox("LeeSin.insec.method.turret", "To ally turret", true)
                Menu.Slider("LeeSin.insec.method.turret.maxRange", "Ally turret max check range", 3000, 1000, 3000, 100)

                Menu.Separator()
            
                Menu.Checkbox("LeeSin.insec.method.ally", "To ally hero", true)
                Menu.Slider("LeeSin.insec.method.ally.maxRange", "Ally hero max check range", 2000, 1000, 3000, 100)
            end)
        end)

        Menu.NewTree("LeeSin.bowlMenu", "Bowling Settings", function()
            Menu.Keybind("LeeSin.bowl.key", "Bowling Key", string.byte("Z"))

            Menu.Separator()

            Menu.Checkbox("LeeSin.bowl.gpQ", "Smart gapclose with Q", true)
            Menu.Indent(function()
                Menu.Checkbox("LeeSin.bowl.gpQ.smite", "Smite minion to gapclose", false)
            end)

            Menu.Separator()

            Menu.Checkbox("LeeSin.bowl.moveToPos", "Move to mouse/bowl pos", true)
            Menu.Dropdown("LeeSin.bowl.bowlMode", "Bowling Mode", 0, {"Most BonusHp >> Less Hp", "Closest >> Less Hp"})
            Menu.Dropdown("LeeSin.bowl.blinkPriority", "Blink priority", 1, {"Only ward", "Only flash", "Ward then flash", "Flash then ward"})

            local bp = OriUtils.MGet("bowl.blinkPriority")
            if bp == 0 or bp == 2 or bp == 3 then
                Menu.Indent(function()
                    Menu.ColoredText("Bowling with Ward works better on slow/static targets\nbut it may not be accurate on moving targets", 0xFFFF00FF)
                end)
            end
        end)

        Menu.NewTree("LeeSin.fleeMenu", "Flee Settings", function()
            Menu.Checkbox("LeeSin.flee.wardJump", "Use wardjump in flee", true)
            Menu.Indent(function()
                Menu.Checkbox("LeeSin.flee.wardJump.jumpExisting", "Try to jump to existing ward/minion", true)
                Menu.Checkbox("LeeSin.flee.wardJump.maxRange", "Try to always wardjump max range", false)

                Menu.Separator()

                Menu.NewTree("LeeSin.wardMenu", "Ward Whitelist", function()
                    for i, wardData in ipairs(Lee.MiscData.WardPriority) do
                        Menu.Checkbox("LeeSin.ward." .. wardData.name, tostring(i) .. ") Use " .. wardData.name, true)
                    end
                end)
            end)
        end)

        Menu.NewTree("LeeSin.ksMenu", "Killsteal Settings", function()
            Menu.Checkbox("LeeSin.ks.onlyCombo", "Only KS during combo mode", true)

            Menu.Separator()

            Menu.Checkbox("LeeSin.ks.useQ1", "Use Q1 to KS", false)
            Menu.Checkbox("LeeSin.ks.useQ2", "Use Q2 to KS", true)

            Menu.Separator()

            Menu.Checkbox("LeeSin.ks.useE1", "Use E1 to KS", true)

            Menu.Separator()

            Menu.Checkbox("LeeSin.ks.useR", "Use R to KS", true)
            Menu.Indent(function()
                Menu.NewTree("LeeSin.ks.useR.wl", "KS R Whitelist", function()
                    local addedWL = {}

                    for _, obj in pairs(enemyHeroes) do
                        local hero = obj.AsHero
                        local heroName = hero.CharName

                        if hero and not addedWL[heroName] then
                            addedWL[heroName] = true

                            Menu.Checkbox("LeeSin.ks.useR.wl." .. heroName, "Use KS R on " .. heroName, true)
                        end
                    end
                end)
            end)
        end)

        Menu.NewTree("LeeSin.hcMenu", "Hitchance Settings", function()
            Menu.Slider("LeeSin.hc.Q1", "Q1 Hitchance", 30, 0, 100, 1)
        end)

        Menu.NewTree("LeeSin.drawMenu", "Drawings", function()
            OriUtils.AddDrawMenu(drawData)

            Menu.Separator()

            Menu.Checkbox("LeeSin.draw.customPos", "Draw insec custom pos indicators", true)
            Menu.ColorPicker("LeeSin.draw.customPos.color", "Insec custom pos indicators color", SCRIPT_COLOR)

            Menu.Separator()

            Menu.Checkbox("LeeSin.draw.backupPos", "Draw insec backup pos line", false)
            Menu.ColorPicker("LeeSin.draw.backupPos.color", "Insec backup pos line color", 0x00FF00FF)

            Menu.Separator()

            Menu.Checkbox("LeeSin.draw.bowlingHelper", "Draw bowling helpers", false)
            Menu.Indent(function()
                Menu.ColorPicker("LeeSin.draw.bowlingHelper.arrow", "Arrow color", 0xFF0000FF)
                Menu.ColorPicker("LeeSin.draw.bowlingHelper.validCircle", "Valid Circle color", 0x0000FFFF)
            end)

            Menu.Separator()

            Menu.Checkbox("LeeSin.draw.specialRFlash", "Draw Flash after manual R state", true)

        end)
    end

    Menu.RegisterMenu(SCRIPT_NAME, SCRIPT_NAME, LeeMenu)
end

function OnLoad()
    Lee.InitMenu()

    OriUtils.InitCircleRangeHelpers({
        "insec.method.turret.maxRange",
        "insec.method.ally.maxRange"
    })

    Lee.RegisterEvents()

    OriUtils.InitElectrocute()

    return true
end