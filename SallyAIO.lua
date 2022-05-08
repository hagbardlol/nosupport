local SCRIPT_NAME, VERSION, LAST_UPDATE = "SallyAIO", "1.0.7", "08/18/2021"
_G.CoreEx.AutoUpdate("https://github.com/hagbardlol/nosupport/raw/main/SallyAIO.lua", VERSION)
module(SCRIPT_NAME, package.seeall, log.setup)
clean.module(SCRIPT_NAME, clean.seeall, log.setup)

local Player = _G.Player

local supportedChamp = {
    Ahri = true,
    Irelia = true,
    Pyke = true,
    Samira = true,
    Sett = true,
    Twitch = true,
    Yone = true,
}

if supportedChamp[Player.CharName] then
    LoadEncrypted("Sally"..Player.CharName)
end