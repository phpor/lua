--
-- Created by IntelliJ IDEA.
-- User: junjie
-- Date: 2014/11/21
-- Time: 14:10
-- for http
--

--[[ 关于require的说明
-- 1. require 只会执行一次，也就是说require_once
 - 2. 后续的require只会返回第一次require时执行的结果，不管结果是什么（print输出不算结果，结果指的是return)
 - 3. 修改代码后重新reload 是必须的
 ]]

local request = {}
local http = require("socket.http")
request.requestBaidu = function()
	return http.request("http://baidu.com/")
end

request.Test1 = function()
	ngx.header["Content-Type"] = "text/plain"
	local _, code,_ = request.requestBaidu()
	ngx.say(code)
end

return request
