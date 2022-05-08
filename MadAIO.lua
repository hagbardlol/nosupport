local Player = _G.Player

local supportedChamp = {
    Kalista = true,
    MissFortune = true,
    Lucian = true,
    Gwen = true,
    Xayah = true,
    Fiora = true,
    Kaisa = true,
    Vayne = true
}

if supportedChamp[Player.CharName] then
    LoadEncrypted("Mad"..Player.CharName)
end