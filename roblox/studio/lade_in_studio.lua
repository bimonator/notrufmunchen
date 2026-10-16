-- lade_in_studio.lua: legt in ServerStorage das ModuleScript "MapBuilder" mit den Kindern "Teil1" und "Teil2" an (Quelltexte per HTTP von einem lokalen Server).
-- Ausführen im Edit-Modus von Roblox Studio, z. B. über das MCP-Werkzeug zum Ausführen von Luau-Code.
-- Voraussetzungen:
--   1) Lokaler Server im Repo:  python3 -m http.server 8765 --directory roblox     (Port bei Bedarf unten anpassen)
--   2) Studio erlaubt HTTP-Anfragen: Game Settings > Security > "Allow HTTP Requests" (HttpService.HttpEnabled)
-- Danach bauen mit studio/bauen.lua. Nach jeder Änderung am Code: python3 roblox/make_bundles.py, dieses Skript erneut ausführen.
local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")
local BASE = "http://localhost:8765/"

local function fetch(name)
	local ok, res = pcall(function() return HttpService:GetAsync(BASE .. name) end)
	assert(ok, "Abruf fehlgeschlagen: " .. name .. " -> " .. tostring(res) .. " (läuft der lokale Server? HTTP-Anfragen in Studio erlaubt?)")
	return res
end

local old = ServerStorage:FindFirstChild("MapBuilder")
if old then old:Destroy() end
local main = Instance.new("ModuleScript")
main.Name = "MapBuilder"
main.Source = fetch("MapBuilder_Modul.lua")
for _, n in ipairs({ "Teil1", "Teil2" }) do
	local m = Instance.new("ModuleScript")
	m.Name = n
	m.Source = fetch("MapBuilder_" .. n .. ".lua")
	m.Parent = main
end
main.Parent = ServerStorage
print(string.format("MapBuilder geladen: Modul %d, Teil1 %d, Teil2 %d Zeichen", #main.Source, #main.Teil1.Source, #main.Teil2.Source))
