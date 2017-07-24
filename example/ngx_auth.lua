local access = {}
function access.config_get_login_url(self)
	return ngx.var.login_url or "/~portal/login"
end
function access.config_get_logout_url(self)
	return ngx.var.logout_url or "/~portal/logout"
end

function access.config_get_logout_page_url(self)
	return ngx.var.logout_page_url or "*"
end

function access.config_get_auth_url(self)
	return ngx.var.auth_url or "https://phpor.net/api/ldap/check"
end

function access.config_get_session_ttl(self)
	return ngx.var.auth_session_ttl or 3600
end

function access.config_get_redis_info(self)
        return {
                host= ngx.var.auth_redis_host or "127.0.0.1",
                port=ngx.var.auth_redis_port or 6379,
                db=ngx.var.auth_redis_db or 1,
                password=ngx.var.auth_redis_password or nil
        }
end
function access.auth()
	ngx.req.read_body()
	local args, err = ngx.req.get_post_args()
	local username, password, referer

	if args then
		username = args["portal_username"]
		password = args["portal_password"]
		referer = args["portal_referer"] or "/"
	end
	local sid = ngx.var.cookie_ngx_sid

	if ngx.var.request_uri == access:config_get_logout_url() then
		access:logout()
	end

	if username and password  then
		sid = access:check_password(username, password)
		if sid then
			return access:redirect(referer) --Avoid resubmit on refresh
		end
	elseif sid then
		local username = access:check_session(sid)
		if username ~= false then
			ngx.log(ngx.ERR, "username: " .. username)
			return access:auth_succ(username)
		end
	end
	if ngx.var.request_uri == access:config_get_login_url() then
		return access:show_auth_page()
	end
	access:redirect(access:config_get_login_url())
end

function access.redirect(self, url)
	ngx.redirect(url, 302)
	ngx.eof()
end
function access.auth_succ(self, username)
	--ngx.header['x-user'] = username
	return username
end

function access.show_auth_page(self)
	ngx.status = 401
	ngx.header['Content-Type'] = "text/html; charset=utf-8"
	local str = [[
		<html>
			<head>
			<title>login</title>
			<meta charset="utf-8">
			<style>
				.container {text-align: center; margin-top: inherit; }
			</style>
			</head>
			<body>
			  <section class="container">
			    <div class="login">
			      <h1>Login please ...</h1>
			      <form method="post">
				<p><input type="text" name="portal_username" value="junjie.li" placeholder="Username"></p>
				<p><input type="password" name="portal_password" value="Lijunjie1983" placeholder="Password"></p>
				<p><input type="hidden" name="portal_referer" value="#referer"></p>
				<p class="submit"><input type="submit" name="commit" value="Login"></p>
			      </form>
			    </div>
			  </section>
			</body>
		</html>
	]]
	str = string.gsub(str, '#referer', ngx.req.referer or "/")
	ngx.say(str)
	ngx.eof()
end

function access.auth_401(self)
	ngx.header.www_authenticate = [[Basic realm=""]]
	ngx.exit(401)
end

function access.check_password(self, username, password)
	local http = require "resty.http"
	local cjson = require "cjson"
	local httpc = http.new()
	httpc:set_keepalive(0, 100)
	httpc:set_timeout(time_out)
	local url = self:config_get_auth_url()
	local params = string.format("username=%s&password=%s&app=nginx&ip=%s", username, password, ngx.var.remote_addr)
	local res, err = httpc:request_uri(url, {
		method = "POST", body = params,
		headers = {
			["Content-Type"] = "application/x-www-form-urlencoded",
		}
	})
	if res == nil then
		ngx.log(ngx.ERR, "call " .. url .. " fail ",  err)
		return false
	end
	if res.status ~= 200 then
		ngx.log(ngx.ERR, "call " .. url .. " fail ",  err)
		return false
	end
	if pcall(cjson.decode, res.body) == false then
		ngx.log(ngx.ERR, "uri:" .. url .. ",response parse fail:" .. res.body)
		return false
	end
	local result = cjson.decode(res.body)
	if result["retcode"] ~= 2000000 then
		ngx.log(ngx.ERR, "auth fail", url, " ", params ," ", res.body)
		return false
	end
	return self:create_session(username)
end

function access.create_session(self, username)
	local sid = self:make_string(24)
	local redis = self:get_redis()
	redis:hmset(sid, 'username' , username)
	redis:expire(sid, self:config_get_session_ttl())
	ngx.header['Content-Type'] = "text/html; charset=utf-8"
	ngx.header['Set-Cookie'] = string.format('ngx_sid=%s; path=/', sid)
	return sid
end

function access.make_string(self, len)
        if len < 1 then return nil end -- Check for l < 1
	local str = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
        local s = "" -- Start string
	math.randomseed(os.time())
	math.random() -- the first value maybe not random
        for i = 1, len do
            n = math.random(1, 62)
	    s = s .. string.sub(str, n, n)
        end
        return s -- Return string
end

function access.system_error(self)
	ngx.say("system error")
	ngx.exit(500)
end
function access.get_redis(self)
        local redis_info = self:config_get_redis_info()
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
			self:system_error()
			return false
		end
	end
	return red
end

function access.check_session(self, sid)
    if #sid ~= 24 then return false end
    local redis = self:get_redis()
    local res, err = redis:hmget(sid, "username")
    if not res or table.getn(res) == 0 or res[1] == ngx.null then
	ngx.log(ngx.ERR, 'not res')
	return false
    end
    local username = res[1] or ""
    
    if type(username) == "string" and username ~= "" and username ~= nil then
        redis:expire(sid, self:config_get_session_ttl())
        return username
    end
    return false
end

function access.logout(self)
	local sid = ngx.var.cookie_ngx_sid
	local redis = self:get_redis()
	redis:del(sid)
	ngx.redirect(self:config_get_login_url(), 302)
	ngx.header['Set-Cookie'] = string.format('ngx_sid=deleted; path=/deleted; expires='..ngx.cookie_time(1), sid)
	ngx.eof()
end

function access.append_logout_button()
	local logout_page_url = access:config_get_logout_page_url()
	local request_uri = ngx.var.request_uri
	if logout_page_url ~= "*" then 
		if logout_page_url ~= request_uri then return end
	end
	if request_uri == access:config_get_login_url() or request_uri == access:config_get_logout_url() then return end
	if not string.gmatch(ngx.header['Content-Type'], "^text/html") then return end
	local body, eof = ngx.arg[1], ngx.arg[2]
	if eof then
		ngx.arg[1] = ngx.arg[1] .. access:logout_html()
	end
end

function access.logout_html(self)
	return [[
		<div style="float: right;margin: 7px 7px; z-index:9999" class="portal_logout">
			<a href="/~portal/logout">logout</a>
		</div>
	]]
end

return {auth = access.auth, append_logout_button = access.append_logout_button }
