-- gets JSON api
local JSON = fs.open("json", "r")
if not JSON then
	print("Missing JSON api getting now")
	shell.run("pastebin","get","4nRg9CHU","json")
else
	JSON.close()
end
os.loadAPI("json")

function StriToArray(str)
	return json.decode(str)
end

local Token = ""
local url = "wss://gateway.discord.gg/?v=7&encoding=json"
local GuildInfo = {}
local BotTab = {}
local HeartBeat = {}
local ws, err
local BeatTime = 10
local LastSeq = 0

function Checks()
	local headers = {["Authorization"] = "Bot "..Token}
	local APIurl = "https://discord.com/api/v7"

	print("Running checks")
	local DIR = "/users/@me"
	local ws, err = http.get(APIurl..DIR,headers)
	if not ws then
		printError("ClientErr\n"..err)
		return false
	end
	local ClientInfo = StriToArray(ws.readAll())
	print("Client : Check")

	DIR = "/gateway/bot"
	local ws, err = http.get(APIurl..DIR,headers)
	if not ws then
		printError("GatewayErr\n"..err)
		return false
	end
	local GatewayInfo = StriToArray(ws.readAll())
	print("Gateway : Check")

	DIR = "/oauth2/applications/@me"
	local ws, err = http.get(APIurl..DIR,headers)
	if not ws then
		printError("AuthErr\n"..err)
		return false
	end
	local AuthInfo = StriToArray(ws.readAll())
	print("Auth : Check")
	local file = fs.open("CheckLog.txt","w")
	file.write("-=-=- Client -=-=-\n"	..textutils.serialise(ClientInfo))
	file.write("\n-=-=- Gateway -=-=-\n"	..textutils.serialise(GatewayInfo))
	file.write("\n-=-=- Auth -=-=-\n"		..textutils.serialise(AuthInfo))
	file.close()
	print("Checking done : Details in CheckLog.txt")
	return true
end

function WSSend()
	return {
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
	  ["intents"] = 12
	}
end

function WaitForCreds()
	local myTimer = os.startTimer(10)
	local ToFile = ""
	local BTF = true
	local GTF = true
	
	while (BTF or GTF) do
		local _, url, response, isBinary = os.pullEvent()
		
		if (_ == "websocket_message") then
			if (response:sub(1, 1) == "{") then
				local Tab = StriToArray(response)
				ToFile = ToFile.."\n"..(textutils.serialise(Tab))
				if (Tab.t == "READY") then
					print("Recived Bot Info")
					BotTab = Tab.d
					BTF = false
				elseif (Tab.t == "GUILD_CREATE") then
					print("Recived Guild Info")
					GuildInfo = Tab.d
					GTF = false
				end
				
				UpdateSeq(Tab.s)
			else
				ToFile = ToFile.."\n"..(textutils.serialise(response))
			end
		end
	end
	os.cancelTimer(myTimer)
end

function UpdateSeq(Seq)
	if Seq then
		LastSeq = Seq
	end
end

function LogIn()
	print("Getting creds")
	ws.send(json.encode(WSSend()))
	print("waiting for response")
	WaitForCreds()
	print("Finished cred collecting")
end

function SendHeartBeat()
	local HeartBeatOut = {
		["op"] = 1,
		["d"] = LastSeq,
	}
	ws.send(json.encode(HeartBeatOut))
	print("HeartBeat")
end

--
-- execution
--

local TokenFile = fs.open("Token.txt", "r")
if not TokenFile then
	printError("No token found please enter bot token")
	Token = read()
	local TokenFile = fs.open("Token.txt", "w")
	TokenFile.write(Token)
	TokenFile.close()
else
	Token = TokenFile.readAll()
	TokenFile.close()
end

if not Checks() then
	return printError("Checks failed check token in computer or check discord")
end

print("Connecting to websocket")
ws, err = http.websocket(url)
if not ws then
	return printError("WebSockErr\n"..err)
end
print("Connected to websocket")

print("Waiting for hello")
local _, url, response, isBinary = os.pullEvent("websocket_message")
local Tab = StriToArray(response)
HeartBeat = Tab.d
BeatTime = HeartBeat.heartbeat_interval/1000
print("Hello recived")
SendHeartBeat()

print("Logging onto bot")
LogIn()
print("Logged in") --logged in and ws is the websocket

local Status = {
  ["op"] = 3,
  ["d"] = {
	["since"] = 100,
    ["status"] = "dnd",
    ["afk"] = false,
  },
}

--local myTimer = os.startTimer(20000) --uncomment this to enable a end timer make sure to uncomment it after while loop
local StatTimer = os.startTimer(3)
local BeatTimer = os.startTimer(0)
local ToFile = ""
local Recived = ""
local MSGES = ""
local i = 0

printError("Setup done listen")
print("Click 10 times to close in a 'safe' manor")

while true do
	local _, url, response, isBinary = os.pullEvent()
	
	ToFile = ToFile.."\n"..(textutils.serialise({_,url,response,isBinary}))
	
	if (_ == "timer") then
		if (url == BeatTimer) then
			SendHeartBeat()
			os.cancelTimer(BeatTimer)
			BeatTimer = os.startTimer(BeatTime-.5)
		elseif (url == StatTimer) then
			print("Status") -- this is breaking the bot for some reason
			os.cancelTimer(StatTimer)
			--StatTimer = os.startTimer(5)
			--ws.send(json.encode(Status))
		elseif (url == myTimer) then
			print("Timer triggered")
			break
		end
	end
	
	if (_ == "mouse_click") then
		i = i + 1
		if (i>10) then
			break
		end
	end
	
	if (_ == "websocket_closed") then
		printError("websocket_closed recived")
		break
	end
	
	if (_ == "websocket_message") then
		if (response:sub(1, 1) == "{") then
			local Tab = StriToArray(response)
			Recived = Recived.."\n"..(textutils.serialise(Tab))
			if (Tab.t == "MESSAGE_CREATE") then
				MSGES = MSGES..Tab.d.content.."\n"
			end
			UpdateSeq(Tab.s)
		else
			Recived = Recived.."\n"..(textutils.serialise(response))
		end
	end
end

--os.cancelTimer(myTimer)

local file = fs.open("Msg","w")
file.write(MSGES)
file.close()

local file = fs.open("Recived","w")
file.write(Recived)
file.close()

local file = fs.open("Arr","w")
file.write(ToFile)
file.close()

print("All events in file Arr")
print("Websocket payloads in Recived")
print("Msgs in msg file")
ws.close()
