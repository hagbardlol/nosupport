local SCRIPT_NAME, VERSION, LAST_UPDATE = "SallyAIO", "1.0.9", "08/18/2021"
_G.CoreEx.AutoUpdate("https://raw.githubusercontent.com/hagbardlol/nosupport/main/SallyAIO.lua", VERSION)
module(SCRIPT_NAME, package.seeall, log.setup)
clean.module(SCRIPT_NAME, clean.seeall, log.setup)

local Player = _G.Player

local supportedChamp = {
    Irelia = true,
    Pyke = true,
    Sett = true,
}

if supportedChamp[Player.CharName] then
    LoadEncrypted("Sally"..Player.CharName)
end
