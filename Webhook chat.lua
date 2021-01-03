local payload = [[ {"username":"NAME","avatar_url":"","content":"MESSAGE"} ]]

http.request
{
    url = "https://discord.com/api/webhooks/*Censored*", -- insertwebhook here
    method = "POST",
    headers =
    {
        ["Content-Type"] = "application/json",
        ["Content-Length"] = payload:len()
    },
    source = ltn12.source.string(payload),
}