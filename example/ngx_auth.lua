

function auth() 
	local username = ngx.var.remote_user 
	local password = ngx.var.remote_passwd 
	local sid = ngx.var.cookie_sid
	--ngx.say(username)
	--ngx.say(password)
	--ngx.exit(200)

	if sid then
		local username = check_session(sid)
		if username ~= false then
			return username
		end
	elseif username  and password  then
		if check_password(username, password) then
			return username
		end
	end
	show_auth_page()
end

function show_auth_page()
	auth_401()
end

function auth_401()
	ngx.header.www_authenticate = [[Basic realm=""]]
	ngx.exit(401)
end

function check_password(username, password)
	if username == "phpor" and password == "phpor" then
		create_session(username)
		return true
	end
	return false
end

function create_session(username)
	local sid = make_string(12)

	local redis = get_redis()
	redis:set(sid, {username = username})
	ngx.header['Set-Cookie'] = string.format('sid=%s; path=/', sid)
	return sid
end

function make_string(len)
        if len < 1 then return nil end -- Check for l < 1
	local str = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
        local s = "" -- Start string
        for i = 1, len do
            n = math.random(1, 62) 
	    s = s .. string.sub(str, n, n)
        end
        return s -- Return string
end

function system_error()
	ngx.say("system fail")
	show_auth_page()
end
function get_redis() 
	local redis_info = {
		host="127.0.0.1",
		port=6379,
		--db=0,
		--password="mypass"
	}
	local redis = require "resty.redis"
	local red = redis:new()
	red:set_timeout(3000) -- 3 sec
	local ok, err = red:connect(redis_info["host"], redis_info["port"])
	if not ok then
		ngx.log("failed to connect: ", err)
		system_error()
		return false
	end
	if redis_info["password"] then
		local res, err = red:auth(redis_info["password"])
		if not res then
			ngx.log("failed to authenticate: ", err)
			system_error()
			return false
		end
	end
	return red
end

function check_session(sid) 
    local redis = get_redis()
    local res, err = redis:hmget(sid, "username")
    if res and res ~= ngx.null then
    	local username = res[1] or ""
	if username ~= "" then
	    	return username
	end
    end
    return false
end

auth()
