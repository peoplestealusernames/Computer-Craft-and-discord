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

-- function WSResume()
	-- return {
	  -- ["op"]= 6,
	  -- ["d"] = {
		-- ["token"] = Token,
		-- ["session_id"] = SessID,
		-- ["seq"] = LastSeq,
		-- ["intents"] = 513,
		-- ["properties"] = {
		  -- ["$os"] = "linux",
		  -- ["$browser"] = "Custom",
		  -- ["$device"] = "Custom",
		-- },
	  -- },
	-- }
-- end


function WSResume(SessID)
	return {
		["op"] = 6,
		["d"] = {
			["token"] = Token,
			["session_id"] = SessID,
			["seq"] = LastSeq,
		},
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
					local file = fs.open("SessionID.txt", "w")
					file.write(BotTab.session_id)
					file.close()
					
					local file = fs.open("BotTab.txt", "w")
					file.write(textutils.serialise(BotTab))
					file.close()
					BTF = false
				elseif (Tab.t == "GUILD_CREATE") then
					print("Recived Guild Info")
					GuildInfo = Tab.d
					local file = fs.open("GuildInfo.txt", "w")
					file.write(textutils.serialise(GuildInfo))
					file.close()
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
		local file = fs.open("Sequence.txt", "w")
		file.write(textutils.serialise(Seq))
		file.close()
		LastSeq = Seq
	end
end

function CheckSessionID()
	local file = fs.open("SessionID.txt", "r")
	if not file then
		printError("SessionID missing returning")
		return false
	end
	print("Found SessionID")
	local SessID = textutils.unserialise(file.readAll())
	file.close()
	
	local Botfile = fs.open("BotTab.txt", "r")
	if not Botfile then
		printError("Botfile missing returning")
		return false
	end
	
	local Guildfile = fs.open("GuildInfo.txt", "r")
	if not Guildfile then
		printError("Guildfile missing returning")
		return false
	end
	
	local Seqfile = fs.open("Sequence.txt", "r")
	if not Seqfile then
		printError("Seqfile missing returning")
		return false
	end
	print("Guild bot and Sequance file found")
	
	local BotTab = textutils.unserialise(Botfile.readAll())
	local GuildInfo = textutils.unserialise(Guildfile.readAll())
	LastSeq = textutils.unserialise(Seqfile.readAll())
	
	ws.send(json.encode(WSResume(SessID)))
	return true
end

function LogIn()
	if CheckSessionID() then
		print("SessionID worked and values were found")
	else
		printError("SessionID failed or not found")
		print("Getting new creds")
		ws.send(json.encode(WSSend()))
		print("waiting for response")
		WaitForCreds()
		print("Finished cred collecting")
	end
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

--Status calls causing websocket to close

--local myTimer = os.startTimer(20000)
local StatTimer = os.startTimer(3)
local BeatTimer = os.startTimer(0)
local ToFile = ""
local MSGES = ""
local i = 0

while true do
	local _, url, response, isBinary = os.pullEvent()
	
	ToFile = ToFile.."\n"..(textutils.serialise({_,url,response,isBinary}))
	
	if (_ == "timer") then
		if (url == StatTimer) then
			print("Status") -- this is breaking the bot for some reason
			os.cancelTimer(StatTimer)
			--StatTimer = os.startTimer(5)
			--ws.send(json.encode(Status))
		end
		if (url == myTimer) then
			break
		end
		if (url == BeatTimer) then
			SendHeartBeat()
			os.cancelTimer(BeatTimer)
			BeatTimer = os.startTimer(BeatTime-.5)
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
			MSGES = MSGES.."\n"..(textutils.serialise(Tab))
			UpdateSeq(Tab.s)
		else
			MSGES = MSGES.."\n"..(textutils.serialise(response))
		end
	end
end

local file = fs.open("Msg","w")
file.write(MSGES)
file.close()

local file = fs.open("Arr","w")
file.write((json.encode(Status)).."\n"..ToFile)
file.close()

--os.cancelTimer(myTimer)

print("Results in file Arr")
ws.close()
