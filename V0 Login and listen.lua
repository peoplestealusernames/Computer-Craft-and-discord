os.loadAPI("json")
function StriToArray(str)
	return json.decode(str)
end

local Token = "*Censored*" -- insert token here

local headers = {["Authorization"] = "Bot "..Token}
local APIurl = "https://discord.com/api/v7"

local DIR = "/users/@me"

-- ws, err = http.get("https://discord.com/api/v7/users/@me",headers)
local ws, err = http.get(APIurl..DIR,headers)
if not ws then
	return printError(err)
end
local ClientInfo = StriToArray(ws.readAll())

DIR = "/gateway/bot"
local ws, err = http.get(APIurl..DIR,headers)
if not ws then
	return printError(err)
end
local GatewayInfo = StriToArray(ws.readAll())

DIR = "/oauth2/applications/@me"
local ws, err = http.get(APIurl..DIR,headers)
if not ws then
	return printError(err)
end
local AuthInfo = StriToArray(ws.readAll())

print(textutils.serialise(GatewayInfo))

local url = "wss://gateway.discord.gg/?v=6&encoding=json"
local ws, err = http.websocket(url)

-- local ws, err = http.websocket(url)
-- if not ws then
	-- return printError(err)
-- end

local WSSend = {
  ["op"]= 2,
  ["d"] = {
    ["token"] = Token,
    ["intents"] = 513,
    ["properties"] = {
      ["$os"] = "linux",
      ["$browser"] = "Custom",
      ["$device"] = "Custom",
    },
  },
}

local myTimer = os.startTimer(10)
ws.send(json.encode(WSSend))

local ToFile = ""

while true do
	local _, url, response, isBinary = os.pullEvent()
	
	if (_ == "timer") then
		print("Timer")
		ws.close()
		
		local file = fs.open("Arr","w")
		file.write(ToFile)
		file.close()
		print("In file Arr")
		break
	end
	ToFile = ToFile..(textutils.serialise(StriToArray(response)))
	
end
