--[[

    ██╗  ██╗ ██████╗ ██╗   ██╗██╗██╗  ██╗████████╗ ██████╗ ██████╗ 
    ██║  ██║██╔═══██╗██║   ██║██║██║ ██╔╝╚══██╔══╝██╔═══██╗██╔══██╗
    ███████║██║   ██║██║   ██║██║█████╔╝    ██║   ██║   ██║██████╔╝
    ██╔══██║██║▄▄ ██║╚██╗ ██╔╝██║██╔═██╗    ██║   ██║   ██║██╔══██╗
    ██║  ██║╚██████╔╝ ╚████╔╝ ██║██║  ██╗   ██║   ╚██████╔╝██║  ██║
    ╚═╝  ╚═╝ ╚══▀▀═╝   ╚═══╝  ╚═╝╚═╝  ╚═╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝                                                  
                     ~ Join the glorious evolution ~
--]]

if _G.Player.CharName ~= "Viktor" then return false end

local SCRIPT = {
  NAME = "hqViktor",
  AUTHOR = "hq.af",
  VERSION = "1.0.4",
  UPDATE_URL = "https://github.com/hagbardlol/nosupport/raw/main/hqViktor.lua",
  CHANGELOG = "Auto Harass disable under turret option"
}

module(SCRIPT.NAME, package.seeall, log.setup)
clean.module(SCRIPT.NAME, clean.seeall, log.setup)

_G.CoreEx.AutoUpdate(SCRIPT.UPDATE_URL, SCRIPT.VERSION)

local API = {
  Game = _G.CoreEx.Game,
  Input = _G.CoreEx.Input,
  Geometry = _G.CoreEx.Geometry,
  Vector = _G.CoreEx.Geometry.Vector,
  Polygon = _G.CoreEx.Geometry.Polygon,
  Rectangle = _G.CoreEx.Geometry.Rectangle,
  Player = _G.Player,
  Circle = _G.CoreEx.Geometry.Circle,
  Cone = _G.CoreEx.Geometry.Cone,
  EventManager = _G.CoreEx.EventManager,
  Enums = _G.CoreEx.Enums,
  GetCurrentMillis = _G.getCurrentMillis,
  Renderer = _G.CoreEx.Renderer,
  ObjectManager = _G.CoreEx.ObjectManager,
  Nav = _G.CoreEx.Nav,
  SpellLib = _G.Libs.Spell,
  DamageLib = _G.Libs.DamageLib,
  Orbwalker = _G.Libs.Orbwalker,
  CollisionLib = _G.Libs.CollisionLib,
  HealthPred = _G.Libs.HealthPred,
  Evade = _G.CoreEx.EvadeAPI,
  Menu = _G.Libs.NewMenu,
  TS =  _G.Libs.TargetSelector(),
  Prediction = _G.Libs.Prediction
}

--#region Custom Geometry
local Geometry = {}

function Geometry.RotateAround(p, c, angle)  
  local cos = math.cos(angle)
  local sin = math.sin(angle)
  local x =  cos * (p.x - c.x) - sin * (p.z - c.z) + c.x
  local z = sin * (p.x - c.x) + cos * (p.z - c.z) + c.z

  return API.Vector(
   x,
   API.Nav.GetTerrainHeight(API.Vector(x, 0, z)),
   z
  )
end
--#endregion

local Config = {}

--#region Viktor
local Viktor = {
  Q = API.SpellLib.Targeted({
    Slot = API.Enums.SpellSlots.Q,
    Range = 725,
    Delay = 0.25,
    Speed = 2000,
    Key = "Q",
    BaseDamage = { [1] = 60, [2] = 75, [3] = 90, [4] = 105, [5] = 120 },
    BaseAPRatio = 0.4,
    DischargeDamage = { [1] = 20, [2] = 45, [3] = 70, [4] = 95, [5] = 120  },
    DischargeAPRatio = 0.6
  }),
  W = API.SpellLib.Skillshot({
    Slot = API.Enums.SpellSlots.W,
    Range = 800,
    Delay = 1,
    Speed = 1450,
    Radius = 275,
    Type = "Circular",
    Key = "W"
  }),
  E = API.SpellLib.Skillshot({
    Slot = API.Enums.SpellSlots.E,
    Range = 500,
    Length = 680,
    Width = 165,
    Radius = 170/2,
    Delay = 0,
    Speed = 1050,
    Type = "Linear",
    BaseDamage = { [1] = 70, [2] = 110, [3] = 150, [4] = 190, [5] = 230 },
    BaseAPRatio = 0.5,
    AftershockDamage = { [1] = 20, [2] = 50, [3] = 80, [4] = 110, [5] = 140 },
    AftershockAPRatio = 0.8,
    Key = "E"
  }),
  E_Ext = {
    Range = 680,
    Radius = 170/2,
    Delay = 0,
    Speed = 1050,
    Type = "Linear"
  },
  R = API.SpellLib.Skillshot({
    Slot = API.Enums.SpellSlots.R,
    Range = 700,
    Delay = 0.25,
    Speed = 200,
    Radius = 300,
    Type = "Circular",
    BaseDamage = { [1] = 100, [2] = 175, [3] = 250 },
    BaseAPRatio = 0.5,
    TickDamage = { [1] = 65, [2] = 105, [3] = 145 },
    TickAPRatio = 0.45,
    Key = "R"
  }),
  LaseredAt = 0,
  LaneQModes = { "Farm Assist", "Always", "Never" },
  BasicSpellSlots = { "Q", "W", "E", "R" },
  DrawDamageModes = { "Combo", "E", "None" },
  LastRCastIsAOE = false,
  LastRCastAt = 0,
  NextAAForcedTarget = nil,
  Storm = nil
}

function Viktor.FPSIntersects(rect, circle)

  for _, p in pairs(circle:GetPoints(6)) do
    if rect:Contains(p) then
      return true
    end
  end

  return false
end

function Viktor.BestLaserRect(start_pos, main_target, targets, min_hit_chance, direct_hit, min_hit)

  local best_hit_count = 0
  local best_rect = nil
  local n_targets = #targets
  local temp_end_pos = nil
  
  for _, target in pairs( targets ) do if (not direct_hit or target ~= main_target) and target:Distance(main_target) < Viktor.E.Length * 1.5 then
    
    local main_hit = false

    local pred = API.Prediction.GetPredictedPosition(
      target,
      Viktor.E_Ext,
      start_pos
    )
    
    if pred ~= nil and pred.HitChance >= min_hit_chance then

      local extra_hit = 1
      local end_pos = start_pos:Extended(pred.CastPosition, Viktor.E.Length)

      local rect = API.Rectangle(
        start_pos,
        end_pos,
        Viktor.E.Width
      )

      if not direct_hit and not main_hit and target == main_target then 
        main_hit = true 
        temp_end_pos = end_pos
      end

      for i, target2 in pairs( targets ) do if (not direct_hit or target2 ~= main_target) and target2 ~= target and target2:Distance(main_target) < Viktor.E.Length * 1.5 then
        
        local pred2 = API.Prediction.GetPredictedPosition(
          target2,
          Viktor.E_Ext,
          start_pos
        )

        -- maybe only if champion
        if target2 ~= main_target or (pred2 ~= nil and pred2.HitChance >= min_hit_chance) then
          local hit_circle = API.Circle(
            pred2 ~= nil and pred2.TargetPosition or target2.Position,
            target2.BoundingRadius
          )

          if rect:Contains(hit_circle.pos) or Viktor.FPSIntersects(rect, hit_circle) then
            if not direct_hit and not main_hit and target2 == main_target then
              main_hit = true
              temp_end_pos = end_pos
            end
            extra_hit = extra_hit + 1
          end
        end
       
        -- will never be the best anyway ಥ﹏ಥ (fps)
        local at_best = extra_hit + n_targets - i
        if at_best < best_hit_count or at_best < min_hit then
          break
        end

      end end

      if (direct_hit or main_hit) and extra_hit > best_hit_count then
        best_hit_count = extra_hit
        best_rect = rect
      end

      -- 7 extra hits are enough (fps)
      if extra_hit > 7 then
        break
      end

    end

  end end

  return best_hit_count + (direct_hit and 1 or 0), best_rect, temp_end_pos

end

-- angle step 0.1 -> 0.5 (smaller is better but more fps drop)
function Viktor.LaserIt(main_target, targets, min_hitchance, angle_step, min_hit, no_cast)

  if min_hit == nil then
    min_hit = 0
  end

  local hit_count = 0
  local best_rect = nil
  local start_pos = nil
  local temp_end_pos = nil
  local direct_hit = false
  local main_dist_player = main_target:Distance(API.Player)
  
  if main_dist_player < Viktor.E.Range then
    direct_hit = true
    start_pos = main_target:FastPrediction( API.Game.GetLatency() / 2 )
    hit_count, best_rect, temp_end_pos = Viktor.BestLaserRect(start_pos, main_target, targets, min_hitchance, true, min_hit)
  elseif main_dist_player < (Viktor.E.Range + Viktor.E.Length) * Config.ERangePercent/100 * 1.1 then
    start_pos = API.Player.Position:Extended( main_target.Position, Viktor.E.Range )
    local points = {
      start_pos
    }

    if main_target.IsHero or #targets == 2 then
      for a=angle_step,0.5,angle_step do
        table.insert(points, Geometry.RotateAround(start_pos, API.Player.Position, a))
        table.insert(points, Geometry.RotateAround(start_pos, API.Player.Position, -a))
      end
    end

    for _, point in pairs(points) do
      local hc, rect, tep = Viktor.BestLaserRect(point, main_target, targets, min_hitchance, false, min_hit)
      if hc > hit_count then
        best_rect = rect
        hit_count = hc
        temp_end_pos = tep
      end
    end
  end

  -- in case no other target
  if best_rect == nil then
    if direct_hit then
      if not main_target.IsLaneMinion then
        if main_target.IsMoving then
          best_rect = API.Rectangle(start_pos, start_pos:Extended(main_target.Pathing.EndPos, Viktor.E.Length), Viktor.E.Width)
        elseif not main_target.IsHero then
          best_rect = API.Rectangle(start_pos, start_pos:Extended(API.Player.Position, Viktor.E.Length), Viktor.E.Width)
        end
      else
        best_rect = API.Rectangle(start_pos, API.Player.Position:Extended(start_pos, Viktor.E.Range + Viktor.E.Length), Viktor.E.Width)
      end
    elseif temp_end_pos ~= nil then
      best_rect = API.Rectangle(start_pos, temp_end_pos, Viktor.E.Width)
    end
  end

  if best_rect ~= nil and (min_hit == nil or hit_count >= min_hit) then
    if no_cast then
      return hit_count, best_rect
    end
    Viktor.LaseredAt = API.Game.GetTime() * 1000
    Viktor.E:Cast(best_rect.endPos, best_rect.startPos)
    return true
  end

end

function Viktor.OnPreAttack(args)
  -- fix orb will attack before OnTick triggers
  if args.Target.IsEnemy and args.Target.IsHero and API.Orbwalker.GetMode() ~= "nil" and Viktor.Q:IsReady() then
    args.Process = false
  end
  -- fix orb switch target after Q in Harass
  local forced = Viktor.NextAAForcedTarget
  if forced ~= nil and API.TS:IsValidTarget(forced, API.Orbwalker.GetTrueAutoAttackRange(API.Player, forced)) then
    args.Target = forced
  end
  
  Viktor.NextAAForcedTarget = nil
end

function Viktor.QLogic(checkAA)

  local qRange = Viktor.Q.Range * Config.QRangePercent/100
  local qTarget = nil

  if not checkAA then
    qTarget = API.TS:GetTarget(qRange)
  elseif API.Orbwalker.CanAttack() then
    for range=qRange,API.Orbwalker.GetTrueAutoAttackRange(API.Player),-50 do
      local target = API.TS:GetTarget(range)
      local aaRange = API.Orbwalker.GetTrueAutoAttackRange(API.Player, target)
      if target ~= nil and target:FastPrediction((Viktor.Q.Delay + API.Player.AttackCastDelay) * 1000 + API.Game.GetLatency()):Distance(API.Player) < aaRange then
        qTarget = target
        break
      end
    end
  end

  if qTarget then
    Viktor.Q:Cast(qTarget)
    if checkAA then
      Viktor.NextAAForcedTarget = qTarget
      API.Input.Attack(qTarget)
    end
    return true
  end

end

function Viktor.RActive()
  return Viktor.R:GetName() == "ViktorChaosStormGuide"
end

function Viktor.HasQBuff()
  return API.Player.Buffs["viktorpowertransfer"] ~= nil
end

function Viktor.RDamage(target, ticks)
  local r_level = Viktor.R:GetLevel()
  return API.DamageLib.CalculateMagicalDamage(
    API.Player,
    target,
    Viktor.R.BaseDamage[r_level] + Viktor.R.BaseAPRatio * API.Player.TotalAP +
    (Viktor.R.TickDamage[r_level] + Viktor.R.TickAPRatio * API.Player.TotalAP) * (ticks ~= nil and ticks or 0)
  )
end

function Viktor.EDamage(target, aftershock)
  local e_level = Viktor.E:GetLevel()
  return API.DamageLib.CalculateMagicalDamage(
    API.Player,
    target,
    Viktor.E.BaseDamage[e_level] + Viktor.E.BaseAPRatio * API.Player.TotalAP +
    (Viktor.E.AftershockDamage[e_level] + Viktor.E.AftershockAPRatio * API.Player.TotalAP) * (aftershock and 1 or 0)
  )
end

function Viktor.Q1Damage(target)
  local q_level = Viktor.Q:GetLevel()
  return API.DamageLib.CalculateMagicalDamage(
    API.Player,
    target,
    Viktor.Q.BaseDamage[q_level] + Viktor.Q.BaseAPRatio * API.Player.TotalAP
  )
end

function Viktor.Q2Damage(target)
  local q_level = Viktor.Q:GetLevel()
  return API.DamageLib.CalculateMagicalDamage(
    API.Player,
    target,
    Viktor.Q.DischargeDamage[q_level] + Viktor.Q.DischargeAPRatio * API.Player.TotalAP
  ) + API.DamageLib.GetAutoAttackDamage(API.Player, target, true)
end

function Viktor.CalcDamage(target, ult, check_dist)

  local dist = (check_dist and API.Player:Distance(target) or 0)
  local total = 0
  local mana = API.Player.Mana
  local q = false
  local e_dmg = 0

  local e_range = (Viktor.E.Range + Viktor.E.Length) * Config.ERangePercent/100

  if mana > Viktor.E:GetManaCost() and Viktor.E:IsReady() and dist < e_range then
    e_dmg = Viktor.EDamage(target)
    total = total + e_dmg
    mana = mana - Viktor.E:GetManaCost()
  end

  local q_range = Viktor.Q.Range * Config.QRangePercent/100

  if mana > Viktor.Q:GetManaCost() and Viktor.Q:IsReady() and dist < q_range then
    total = total + Viktor.Q1Damage(target)
    mana = mana - Viktor.Q:GetManaCost()
    q = true
  end

  if (q or Viktor.HasQBuff()) and dist < API.Orbwalker.GetTrueAutoAttackRange(API.Player, target) then
    total = total + Viktor.Q2Damage(target)
  elseif API.Orbwalker.CanAttack() then
    total = total + API.DamageLib.GetAutoAttackDamage(API.Player, target, true)
  end

  local r_dmg = 0
  if ult and mana > Viktor.R:GetManaCost() and Viktor.R:IsReady() and not Viktor.RActive() and dist < Viktor.R.Range then
    r_dmg = Viktor.RDamage(target, Config.ComboRTicks)
    total = total + r_dmg
    mana = mana - Viktor.R:GetManaCost()
  end
  
  return total, e_dmg, r_dmg
end

function Viktor.OnCreateObject(obj)
  if obj.IsAlly and obj.Name == "Storm" then
    Viktor.Storm = obj
  end
end

function Viktor.ELogic(targets, hit_chance, min_hit)
  local e_range = (Viktor.E.Range + Viktor.E.Length) * Config.ERangePercent/100
  local main_target_far = API.TS:GetTargetFromList(targets, nil, nil, e_range * 1.1)
  
  if main_target_far ~= nil and Viktor.LaserIt(main_target_far, targets, hit_chance, Config.ExtendedAngleStep, min_hit) then
    return true
  else
    local main_target_close = API.TS:GetTargetFromList(targets, nil, nil, e_range)
    if main_target_close ~= nil and main_target_close ~= main_target_far and Viktor.LaserIt(main_target_close, targets, hit_chance, Config.ExtendedAngleStep, min_hit) then
      return true
    end
  end
end

function Viktor.Combo()

  -- W X targets
  if Config.ComboWHit and Viktor.W:IsReady() and API.Player.Mana > Config.MinManaW and Viktor.W:CastIfWillHit(Config.ComboWHitMin) then
    return true
  end

  -- R X targets
  if Config.ComboRHit and Viktor.R:IsReady() and not Viktor.RActive() and Viktor.R:CastIfWillHit(Config.ComboRHitMin) then
    Viktor.LastRCastIsAOE = true
    return true
  end

  if Viktor.LastRCastIsAOE and not Viktor.RActive() then
    Viktor.LastRCastIsAOE = false
  end

  local max_r_range = Viktor.R.Range + Viktor.R.Radius*0.75
  local r_delay_ms = Viktor.R.Delay*1000 + API.Game.GetLatency()/2
  local r_delay = r_delay_ms / 1000

  -- R burst
  if Config.ComboRBurst and Viktor.R:IsReady() and not Viktor.RActive() and (Viktor.E:IsReady() or Viktor.Q:IsReady()) then
    local target = API.TS:GetTarget(max_r_range)
    if target ~= nil then
      local hp_pred = API.HealthPred.GetHealthPrediction(target, r_delay, true)
      local total, _, r_dmg = Viktor.CalcDamage(target, true, true)
      local other_dmg = total - r_dmg
      if (not Config.ComboRNoOverkill or other_dmg/hp_pred < 0.75) and total/hp_pred > 0.75 and total/target.MaxHealth > 0.4 then
        local cast_pos = target:FastPrediction(r_delay_ms)
        Viktor.R:Cast(API.Player:Distance(cast_pos) < Viktor.R.Range and cast_pos or API.Player.Position:Extended(cast_pos, Viktor.R.Range))
        return true
      end
    end
  end

  if not API.Orbwalker.CanMove() then return end

  local tick = API.Game.GetTime() * 1000

  -- E
  if Config.ComboE and Viktor.E:IsReady() and tick - Viktor.LaseredAt > 100 then
    local targets = API.TS:GetTargets(1500)   
    if Viktor.ELogic(targets, Config.EComboHitChanceSlider) then
      return true
    end
  end

  -- Q
  if Config.ComboQ and Viktor.Q:IsReady() and Viktor.QLogic() then
    return true
  end

  -- R kill
  if Config.ComboRKill and Viktor.R:IsReady() and not Viktor.RActive() then
    local target = API.TS:GetTarget(max_r_range)
    if target ~= nil then
      local hp_pred = API.HealthPred.GetHealthPrediction(target, r_delay, true)
      local r_damage = Viktor.RDamage(target, Config.ComboRTicks)
      if r_damage > hp_pred and (not Config.ComboRNoOverkill or (hp_pred - Viktor.CalcDamage(target, false, true))/r_damage > 0.2) then
        local cast_pos = target:FastPrediction(r_delay_ms)
        Viktor.R:Cast(API.Player:Distance(cast_pos) < Viktor.R.Range and cast_pos or API.Player.Position:Extended(cast_pos, Viktor.R.Range))
        return true
      end
    end
  end

  -- R follow
  if Config.ComboRFollow and Viktor.RActive() and Viktor.Storm ~= nil and tick - Viktor.LastRCastAt > 100 then
    
    Viktor.LastRCastAt = tick

    local targets = {}
    local points = {}

    for _, target in pairs(API.ObjectManager.GetNearby("enemy", "heroes")) do
      local dist = target:Distance(Viktor.Storm)
      if dist < 800 then
        table.insert(targets, target)
        if Viktor.LastRCastIsAOE and dist < 500 then
          table.insert(points, target:FastPrediction(API.Game.GetLatency() / 2 + 100))
        end
      end
    end

    if Viktor.LastRCastIsAOE then
      local pos, hit_count = API.Geometry.BestCoveringCircle(points, Viktor.R.Radius)
      if hit_count > 1 then
        Viktor.R:Cast(pos)
        return true
      end
    end

    local target = API.TS:GetTargetFromList(targets, false, nil, 2000)
    if target ~= nil then
      Viktor.R:Cast(target:FastPrediction(API.Game.GetLatency() / 2 + 100))
      return true
    end

  end

end

function Viktor.OnHeroImmobilized(Source, EndTime, IsStasis)
  
  if not Source.IsEnemy or not Config.ComboWChainCC or API.Orbwalker.GetMode() ~= "Combo" or not Viktor.W:IsReady() or API.Player.Mana < Config.MinManaW or API.Player:Distance(Source) > Viktor.W.Range then return end

  local remain = EndTime - API.Game.GetTime()
  if (IsStasis and remain < 1) or remain > 0.74 then
    Viktor.W:Cast(Source.Position)
  end

end

function Viktor.OnDrawDamage(target, dmgList)
  local draw_mode = Viktor.DrawDamageModes[Config.DrawDamageMode + 1]
  if draw_mode == "None" then return end
  local total, e_dmg = Viktor.CalcDamage(target, true, false)
  table.insert(dmgList, (draw_mode == "Combo" and total or e_dmg))
end

function Viktor.ValidMinion(minion)
  return minion ~= nil and minion.IsMinion and not minion.IsAlly and (minion.IsMonster or minion.IsLaneMinion or minion.IsPet) and not minion.IsJunglePlant and not minion.IsBarrel and not minion.IsSennaSoul and minion.IsAlive and minion.IsTargetable
end

function Viktor.OnDraw()

  if Config.DrawQ and Viktor.Q:IsReady() then
    API.Renderer.DrawCircle3D(API.Player.Position, Viktor.Q.Range * Config.QRangePercent/100, 30, 2, Config.DrawQColor)
  end

  if Config.DrawW and Viktor.W:IsReady() then
    API.Renderer.DrawCircle3D(API.Player.Position, Viktor.W.Range, 30, 2, Config.DrawWColor)
  end

  local e_range = (Viktor.E.Range + Viktor.E.Length) * Config.ERangePercent/100
  if Config.DrawE and Viktor.E:IsReady() then
    API.Renderer.DrawCircle3D(API.Player.Position, e_range, 30, 2, Config.DrawEColor)
  end

  if Config.DrawR and Viktor.R:IsReady() and not Viktor.RActive() then
    API.Renderer.DrawCircle3D(API.Player.Position, Viktor.R.Range, 30, 2, Config.DrawRColor)
  end

  if Config.DrawComboETarget and Viktor.E:IsReady() then
    local e_target_close = API.TS:GetTarget(e_range)
    local e_target = (e_target_close ~= nil and e_target_close or API.TS:GetTarget(1500))
    if e_target ~= nil then
      API.Renderer.DrawCircle3D(e_target.Position, e_target.BoundingRadius, 30, 2, Config.DrawComboETargetColor)
    end
  end

end

function Viktor.IsUnderTurret()
  for _, turret in pairs(API.ObjectManager.GetNearby("enemy", "turrets")) do
    if turret.IsAlive and not turret.IsInvulnerable and API.Player:Distance(turret) < 800 + API.Player.BoundingRadius then
      return true
    end
  end

  return false
end

function Viktor.Harass(auto)

  if API.Player.ManaPercent * 100 < Config.HarassMinManaPercent then return end

  if auto and Config.AutoHarassCheckTurret and Viktor.IsUnderTurret() then
    return
  end

  if auto and Config.AutoHarassWaitRune and (
    API.Player.Buffs["assets/perks/styles/inspiration/firststrike/firststrikecd.lua"] ~= nil or
    API.Player.Buffs["assets/perks/styles/sorcery/arcanecomet/arcanecometrechargesnipe.lua"] ~= nil
  ) then return end

  if Viktor.Q:IsReady() and Config.HarassQ and (not Config.HarassQAAReady or API.Orbwalker.CanAttack()) and Viktor.QLogic(Config.HarassQAAReady) then
    return true
  end

  if Viktor.E:IsReady() and Config.HarassE then
    local targets = {}
    for _, target in pairs(API.TS:GetTargets(1500)) do
      if Config["HarassE" .. target.CharName] then
        table.insert(targets, target)
      end
    end

    if Viktor.ELogic(targets, Config.EHarassHitChanceSlider, Config.HarassEMinHit) then
      return true
    end
  end

end

function Viktor.Clear(lane, smartKey)

  local tick = API.Game.GetTime() * 1000

  if (smartKey or (lane and Config.LaneE) or (not lane and Config.JungleE)) and Viktor.E:IsReady() and tick - Viktor.LaseredAt > 100 then
    local e_range = (Viktor.E.Range + Viktor.E.Length) * Config.ERangePercent/100 * 1.1
    local e_range_sqr = e_range * e_range

    local all = API.ObjectManager.GetNearby((lane and "enemy" or "neutral"), "minions")
    local targets = {}

    for _, t in pairs(all) do
      if Viktor.ValidMinion(t) and #targets < 8 then
        table.insert(targets, t)
      end
    end

    for _, h in pairs(API.ObjectManager.GetNearby("enemy", "heroes")) do
      table.insert(targets, h)
    end

    local best_count = 0
    if not smartKey and lane then
      best_count = Config.LaneEMinHit
    end
    local best_rect = nil
    local min_dist_sqr = math.huge

    for _, main in pairs(targets) do if not main.IsHero then

      local count, rect = Viktor.LaserIt(main, targets, 0.75, Config.ExtendedAngleStep, best_count, true, true)
      if rect ~= nil then
        local dist_sqr = main.Position:DistanceSqr(API.Player.Position)
        if count > best_count or dist_sqr < min_dist_sqr then
          best_count = count
          best_rect = rect
          min_dist_sqr = dist_sqr
        end
      end
    end end

    if best_rect ~= nil then
      Viktor.E:Cast(best_rect.endPos, best_rect.startPos)
      Viktor.LaseredAt = tick
      return true
    end
  end

  if Viktor.Q:IsReady() and API.Orbwalker.CanAttack() and (lane and Viktor.LaneQModes[Config.LaneQMode + 1] == "Always") or (not lane and Config.JungleQ) then
    local last_target = API.Orbwalker.GetLastTarget()
    local q_range = Viktor.Q.Range * Config.QRangePercent/100
    if last_target ~= nil and Viktor.ValidMinion(last_target) and last_target:Distance(API.Player) < q_range then
      Viktor.Q:Cast(last_target)
      return true
    end
  end

end

function Viktor.Waveclear(smartKey)
  
  if not smartKey and API.Player.ManaPercent*100 < Config.FarmMinManaPercent then return end

  if API.Player.IsInJungle or API.Player.IsInRiver or API.Player.IsInDragonPit or API.Player.IsInBaronPit then
    return Viktor.Clear(false, smartKey)
  else
    return Viktor.Clear(true, smartKey)
  end

end

function Viktor.OnUnkillableMinion(minion)
  local mode = API.Orbwalker.GetMode()
  if (mode == "Waveclear" or mode == "Harass" or mode == "Lasthit") and API.Player.ManaPercent*100 > Config.FarmMinManaPercent and Viktor.LaneQModes[Config.LaneQMode + 1] == "Farm Assist" and Viktor.Q:IsReady() and minion:Distance(API.Player) < Viktor.Q.Range then
    local pred_health = API.HealthPred.GetHealthPrediction(minion, Viktor.Q.Delay + (API.Game.GetLatency() / 1000) / 2)
    if pred_health > 0 and Viktor.Q1Damage(minion) > pred_health then
      Viktor.Q:Cast(minion)
      return
    end
  end
end

function Viktor.OnInterruptibleSpell(Source, SpellCast, Danger, EndTime, CanMoveDuringChannel)

  if not Config.InterruptREnabled or not Viktor.R:IsReady() then return end

  local dist = Source:Distance(API.Player)
  if dist > Viktor.R.Range + Viktor.R.Radius * (CanMoveDuringChannel and 0.5 or 0.9) then return end
  
  local slot = nil
  if SpellCast.Slot == API.Enums.SpellSlots.Q then
    slot = "Q"
  elseif SpellCast.Slot == API.Enums.SpellSlots.W then
    slot = "W"
  elseif SpellCast.Slot == API.Enums.SpellSlots.E then
    slot = "E"
  elseif SpellCast.Slot == API.Enums.SpellSlots.R then
    slot = "R"
  end

  if slot ~= nil and Config["InterruptR" .. Source.CharName .. slot] then
    Viktor.R:Cast( (dist > Viktor.R.Range and API.Player.Position:Extended(Source.Position, Viktor.R.Range) or Source.Position) )
  end
end

function Viktor.OnGapclose(source, dash)
  if not source.IsEnemy or dash.Invulnerable or not Config.GapcloseEnabled or not Config["Gapclose" .. source.CharName] or not source:IsFacing(API.Player.Position, 30) then
      return
  end

  -- source: ViktorMechanics (ronaldinhosocce)
  local pos = dash:GetPosition(10000)
  
  if pos:Distance(API.Player) < math.min(400, API.Orbwalker.GetTrueAutoAttackRange(source, API.Player) * 1.2) then
      if Config.GapcloseW and Viktor.W:IsReady() and API.Player.Mana > Config.MinManaW then
          Viktor.W:Cast(API.Player.Position)
          return
      end
      if Config.GapcloseQ and Viktor.Q:IsReady() then
          Viktor.Q:Cast(source)
          return
      end
  end
end

function Viktor.KS()
  
  local tick = API.Game.GetTime() * 1000

  local ksQ, ksE, ksR = Config.KSQ and Viktor.Q:IsReady(), Config.KSE and tick - Viktor.LaseredAt > 100 and Viktor.E:IsReady(), Config.KSR and Viktor.R:IsReady() 

  if not Config.KSQ and not Config.KSE and not Config.KSR then return end

  local latency = (API.Game.GetLatency()/1000)/2
  local q_range = Viktor.Q.Range * Config.QRangePercent/100
  local e_range = (Viktor.E.Range + Viktor.E.Length) * Config.ERangePercent/100
  local r_range = Viktor.R.Range + Viktor.R.Radius/2
  
  for _, enemy in pairs(API.ObjectManager.GetNearby("enemy", "heroes")) do

    local hp_pred = API.HealthPred.GetHealthPrediction(enemy, 0.25 + latency, API.Enums.DamageTypes.Magical)
    local dist = enemy:Distance(API.Player)

    if ksQ and dist < q_range and Viktor.Q1Damage(enemy) > hp_pred then
      Viktor.Q:Cast(enemy)
      return true
    end

    if ksE and dist < e_range and Viktor.EDamage(enemy) > hp_pred and Viktor.LaserIt(enemy, { enemy }, Config.EComboHitChanceSlider, Config.ExtendedAngleStep) then
      return true
    end

    if ksR and dist < r_range and Viktor.RDamage(enemy) > hp_pred then
      Viktor.R:Cast( (dist < Viktor.R.Range and enemy.Position or API.Player.Position:Extended(enemy.Position, Viktor.R.Range)) )
      return true
    end

  end
end

function Viktor.OnTick()

  local mode = API.Orbwalker.GetMode()

  if Viktor.KS() then
    return
  end

  if Config.FarmSmartKey and Viktor.Waveclear(true) then
    return
  end

  if Viktor[mode] ~= nil and Viktor[mode]() then
    return
  end

  if Config.AutoHarassToggle and Viktor.Harass(true) then
    return
  end

end

--#endregion

--#region Config & Menu

function Config.Setup()

  local m = API.Menu

  local enemies = {}
  for _, enemy in pairs(API.ObjectManager.Get("enemy", "heroes")) do
    if enemies[enemy.CharName] == nil then
      enemies[enemy.CharName] = enemy
    end
  end
  
  m.RegisterMenu(SCRIPT.NAME, SCRIPT.NAME, function()

    m.ColoredText(SCRIPT.NAME .. " v" .. SCRIPT.VERSION .. " by " .. SCRIPT.AUTHOR, 0xB65A94FF, true)

    m.NewTree("Combo", "Combo", function()
      m.Checkbox("ComboQ", "Use Q", true) -- OK
      m.Checkbox("ComboWChainCC", "Use W chain CC", true) -- OK
      m.Checkbox("ComboWHit", "Use W if hit X targets", true) -- OK
      m.Slider("ComboWHitMin", "^ Min W hit targets", 3, 1, 6, 1) -- OK
      m.Checkbox("ComboE", "Use E", true) -- OK
      m.Checkbox("ComboRKill", "Use R if killable", true) -- OK
      m.SameLine()
      m.Checkbox("ComboRBurst", "Use R for burst", true) -- OK
      m.SameLine()
      m.Checkbox("ComboRNoOverkill", "R prevent overkill", true) -- OK
      m.Slider("ComboRTicks", "^ R ticks", 3, 0, 6, 1) -- OK
      m.Checkbox("ComboRHit", "Use R if hit X targets", true) -- OK
      m.Slider("ComboRHitMin", "^ Min R hit targets", 3, 1, 6, 1) -- OK
      m.Checkbox("ComboRFollow", "R follow", true) -- OK
    end)

    m.NewTree("Harass", "Harass", function()
      m.Slider("HarassMinManaPercent", "Min Mana %", 30, 0, 100, 1) -- OK
      m.Checkbox("HarassQ", "Use Q", true) -- OK
      m.SameLine()
      m.Checkbox("HarassQAAReady", "Q Only if AA is ready", true) -- OK
      m.Checkbox("HarassE", "Use E", true) -- OK
      m.Slider("HarassEMinHit", "E Min hit", 1, 1, 6, 1) -- OK
      m.NewTree("HarassEWhitelist", "E Whitelist", function()
        for charName, _ in pairs(enemies) do
          m.Checkbox("HarassE" .. charName, charName, true) -- OK
        end
      end)
      m.ColoredText("Auto Harass", 0xB65A94FF, true)
      m.Keybind("AutoHarassToggle", "Auto Harass Toggle", string.byte('L'), true, false) -- OK
      m.Checkbox("AutoHarassWaitRune", "Auto Harass wait for rune (FirstStrike/Comet)", false) -- OK
      m.Checkbox("AutoHarassCheckTurret", "Auto Harass disabled under turret", true) -- OK
    end)

    m.NewTree("Farm", "Farm", function()
      m.ColoredText("Global", 0xB65A94FF, true)
      m.Keybind("FarmSmartKey", "Quick E cast", string.byte('Z')) -- OK
      m.Slider("FarmMinManaPercent", "Min Mana % (Lane & Jungle)", 30, 0, 100, 1) -- OK
      m.ColoredText("Lane", 0xB65A94FF, true)
      m.Text("Use Q")
      m.Dropdown("LaneQMode", "Use Q Mode", 0, Viktor.LaneQModes) -- OK
      m.Checkbox("LaneE", "Use E", false) -- OK
      m.Slider("LaneEMinHit", "Lane E Min hit", 3, 1, 8, 1) -- OK
      m.ColoredText("Jungle", 0xB65A94FF, true)
      m.Checkbox("JungleQ", "Use Q", true) -- OK
      m.Checkbox("JungleE", "Use E", false) -- OK
    end)

    m.NewTree("InterruptR", "Interrupt R", function()
      m.Checkbox("InterruptREnabled", "Enabled", true) -- OK
      m.NewTree("InterruptRWhitelist", "Whitelist", function()
        for charName, _ in pairs(enemies) do
          m.NewTree("InterruptR" .. charName, charName, function()
            for _, slot in pairs(Viktor.BasicSpellSlots) do
              m.Checkbox("InterruptR" .. charName .. slot, slot, false) -- OK
            end
          end)
        end
      end)
    end)

    m.NewTree("Gapclose", "Anti Gapcloser", function()
      m.Checkbox("GapcloseEnabled", "Enabled", true) -- OK
      m.Checkbox("GapcloseQ", "Use Q", true) -- OK
      m.Checkbox("GapcloseW", "Use W", true) -- OK
      m.NewTree("GapcloseWhitelist", "Whitelist", function()
        for charName, _ in pairs(enemies) do
          m.Checkbox("Gapclose" .. charName, charName, false) -- OK
        end
      end)
    end)

    m.NewTree("KS", "KS", function()
      m.ColoredText("KS", 0xB65A94FF, true)
      
      m.Checkbox("KSQ", "KS Q", true) -- OK
      m.Checkbox("KSE", "KS E", true) -- OK
      m.Checkbox("KSR", "KS R", false) -- OK
    end)

    m.NewTree("Tuning", "Tuning (FPS & Advanced)", function()
      
      m.ColoredText("FPS", 0xB65A94FF, true)
      m.Slider("ExtendedAngleStep", "Extended E Angle Step", 0.1, 0.05, 3.3, 0.05) -- OK
      m.Text("^ lower is better but worst fps ^")

      m.ColoredText("Spells", 0xB65A94FF, true)
      m.Slider("EComboHitChanceSlider", "E Combo HitChance", 0.75, 0.1, 1, 0.01) -- OK
      m.Slider("EHarassHitChanceSlider", "E Harass HitChance", 0.9, 0.1, 1, 0.01) -- OK
      m.Slider("QRangePercent", "Q Range %", 100, 1, 125, 1) -- OK
      m.Slider("ERangePercent", "E Range %", 100, 1, 125, 1) -- OK

      m.ColoredText("Mana", 0xB65A94FF, true)
      m.Slider("MinManaW", "W Min Mana", 175, 0, 1000, 1) -- OK
    end)

    m.NewTree("Draw", "Draw", function()

      m.ColoredText("Spells", 0xB65A94FF, true)

      m.Checkbox("DrawQ", "Draw Q Range", false) -- OK
      m.SameLine()
      m.ColorPicker("DrawQColor", "", 0xFFFFFFFFF) -- OK
      
      m.Checkbox("DrawW", "Draw W Range", false)
      m.SameLine()
      m.ColorPicker("DrawWColor", "", 0xFFFFFFFFF) -- OK

      m.Checkbox("DrawE", "Draw E Range", true)
      m.SameLine()
      m.ColorPicker("DrawEColor", "", 0xFFFFFFFFF) -- OK
      
      m.Checkbox("DrawR", "Draw R Range", false)
      m.SameLine()
      m.ColorPicker("DrawRColor", "", 0xFFFFFFFFF) -- OK

      m.ColoredText("Misc", 0xB65A94FF, true)

      m.Checkbox("DrawPermashow", "Draw Auto Harass Status (PermaShow)", true) -- OK
      
      m.Checkbox("DrawComboETarget", "Draw Combo E Target", true) -- OK
      m.SameLine()
      m.ColorPicker("DrawComboETargetColor", "", 0xFFFFFFFFF) -- OK

      m.Dropdown("DrawDamageMode", "Draw Damage Mode", 0, Viktor.DrawDamageModes) -- OK
    end)

    m.ColoredText("~ owo ~", 0xB65A94FF, true)

  end)

  m.RegisterPermashow(SCRIPT.NAME, SCRIPT.NAME, function()
    local autoHarass = m.Get("AutoHarassToggle")
    m.ColoredText("Auto Harass (" .. string.char(m.GetKey("AutoHarassToggle")) .. ")" .. " : " .. (autoHarass and "ON " or "OFF"), (autoHarass and 0x00FF33FF or 0xFFFFFFFF))
  end, function() return m.Get("DrawPermashow") end)

  setmetatable(Config, {
    __index = function(obj, key) 
      return API.Menu.Get(key, true)
    end
  })  
end
--#endregion

function OnLoad()

  INFO(SCRIPT.NAME .. " v" .. SCRIPT.VERSION .. " by " .. SCRIPT.AUTHOR .. " loaded")
  if SCRIPT.CHANGELOG ~= "" then
    INFO("Changelog: " .. SCRIPT.CHANGELOG)
  end

  Config.Setup()

  for eventName, eventId in pairs(API.Enums.Events) do
    if Viktor[eventName] then
        API.EventManager.RegisterCallback(eventId, Viktor[eventName])
    end
  end

  return true
end
