--
-- Created by IntelliJ IDEA.
-- User: junjie
-- Date: 2014/11/21
-- Time: 14:55
-- To change this template use File | Settings | File Templates.
--

print = ngx.say
local act = ngx.req.get_uri_args()["act"]
ngx.header.content_type = 'text/html'

if act == nil then return end

ngx.say("<h2>"..act.."</h2><hr>")
local t = require("example."..act)
for k,v in pairs(t) do
	if type(v) == "function" and string.match(k, "^Test") then
		v()
	end
end



