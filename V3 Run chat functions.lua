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
local url = "wss://gateway.discord.gg/?v=8&encoding=json"
local APIurl = "https://discord.com/api/v8"
local GuildInfo = {}
local BotTab = {}
local HeartBeat = {}
local ws, err, WSSend, AuthTab
local BeatTime = 10
local LastSeq = 0

function Checks()
	print("Running checks")
	local DIR = "/users/@me"
	local ws, err = http.get(APIurl..DIR,AuthTab)
	if not ws then
		printError("ClientErr = "..err)
		return false
	end
	local ClientInfo = StriToArray(ws.readAll())
	print("Client : Check")

	DIR = "/gateway/bot"
	local ws, err = http.get(APIurl..DIR,AuthTab)
	if not ws then
		printError("GatewayErr = "..err)
		return false
	end
	local GatewayInfo = StriToArray(ws.readAll())
	print("Gateway : Check")

	DIR = "/oauth2/applications/@me"
	local ws, err = http.get(APIurl..DIR,AuthTab)
	if not ws then
		printError("AuthErr = "..err)
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
	ws.send(json.encode(WSSend))
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

function TestFNC(FNCS) 
	local FNC,err = load("return "..FNCS)
	if not (FNC) then
		FNC,err = load(FNCS)
	end
	
	if not(FNC == nil) then
		local work, err = pcall(FNC)
		return err --Return value (may be nil) or error
	else
		return err --compile error (not valid function)
	end
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

AuthTab = {["Authorization"] = "Bot "..Token,["Content-Type"] = "application/json"}

WSSend = {
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

--local myTimer = os.startTimer(20000) --uncomment this to enable a end timer make sure to uncomment it after while loop
local BeatTimer = os.startTimer(0)
local Recived = ""
local i = 0

printError("Setup done listen")
print("Click 10 times to close in a 'safe' manor")

while true do
	local _, url, response, isBinary = os.pullEvent()
	
	if (_ == "timer") then
		if (url == BeatTimer) then
			SendHeartBeat()
			os.cancelTimer(BeatTimer)
			BeatTimer = os.startTimer(BeatTime-.5)
		elseif (url == myTimer) then
			print("Timer triggered")
			break
		end
	elseif (_ == "mouse_click") then
		i = i + 1
		if (i>10) then
			print("Mouse click close")
			break
		end
	elseif (_ == "websocket_closed") then
		printError("websocket_closed recived")
		printError(textutils.serialise({_,url,response,isBinary}))
		break
	elseif (_ == "websocket_message") then
		if (response:sub(1, 1) == "{") then
			local Tab = StriToArray(response)
			if (Tab.t == "MESSAGE_CREATE") then
				Recived = Recived.."\n"..(textutils.serialise(Tab))
				local Data = {
					["content"] = textutils.serialise(TestFNC(Tab.d.content)),
				}
				local request, err = http.post(APIurl.."/channels/"..Tab.d.channel_id.."/messages",json.encode(Data),AuthTab)
				
				if not request then
					printError("Yes "..err)
				end
			end
			UpdateSeq(Tab.s)
		end
	end
end

--os.cancelTimer(myTimer)

local file = fs.open("Recived","w")
file.write(Recived)
file.close()

ws.close()
print("Closed safely")
