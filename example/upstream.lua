local concat = table.concat
local upstream = require "ngx.upstream"
local json = require "cjson"
local get_servers = upstream.get_servers
local get_upstreams = upstream.get_upstreams

local us = get_upstreams()
local row = {}
for _, u in ipairs(us) do
	local srvs, err = get_servers(u)
	if srvs then
		row[u] = srvs
	end
end
ngx.print(json.encode(row))
