if _G.CoreEx.ObjectManager.Player.CharName ~= "Tristana" then
    return
end
local ScriptName, Version = "TristanaMechanics", "1.0.7"
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
