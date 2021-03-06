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
function access.config_get_session_domain(self)
	return ngx.var.auth_session_domain or ngx.var.http_host
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
		if ngx.var.allow_user then
			ngx.log(ngx.ERR, "allow_user: " .. ngx.var.allow_user)
			ngx.log(ngx.ERR, "username: " .. username)
			local allow = false
			string.gsub(ngx.var.allow_user, "[^,]+", function(user)
				ngx.log(ngx.ERR, "user: " .. user)
				if user == username then allow = true end
			end)
			if not allow then return access:show_auth_page() end
		end
		sid = access:check_password(username, password)
		if sid then
			return access:redirect(referer) --Avoid resubmit on refresh
		end
	elseif sid then
		local username = access:check_session(sid)
		if username ~= false then
			local cookie = string.gsub(ngx.var.http_COOKIE, " *ngx_sid=[^;]+;? *", "")
			if cookie == "" then cookie = nil end
			ngx.req.set_header("Cookie", cookie)
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
			<meta name="viewport" content="width=device-width, initial-scale=1.0">
			<style>
				.container {font-weight: 400; text-align: center; display: table; margin-left: auto; margin-right: auto; height: 100%; }
				.login { display: table-cell; vertical-align: middle; width: 300px;}
				input { width: 100%; height: 30px; padding: 6 12px; font-size: 14px; border: solid 1px; background-color: #e2e2e2; }
			</style>
			</head>
			<body>
			  <section class="container">
			    <div class="login">
			      <h1>Login please ...</h1>
			      <form method="post">
				<p><input type="text" name="portal_username" value="" placeholder="Username"></p>
				<p><input type="password" name="portal_password" value="" placeholder="Password"></p>
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
	ngx.header['Set-Cookie'] = string.format('ngx_sid=%s; domain=.%s; path=/', sid, self:config_get_session_domain())
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
	ngx.header['Set-Cookie'] = string.format('ngx_sid=deleted; domain=.%s; path=/; expires=%s', self:config_get_session_domain(), ngx.cookie_time(1))
	ngx.redirect(self:config_get_login_url(), 302)
	ngx.eof()
end

function access.append_logout_button()
	local body, eof = ngx.arg[1], ngx.arg[2]
	if not eof then return end
	local logout_page_url = access:config_get_logout_page_url()
	local request_uri = ngx.var.request_uri
	if logout_page_url == request_uri then
		ngx.arg[1] = ngx.arg[1] .. access:logout_html()
		return
	end
	if ngx.req.get_headers()['X-Requested-With'] == "XMLHttpRequest" then return end
	if logout_page_url ~= "*" then return end
	if request_uri == access:config_get_login_url() or request_uri == access:config_get_logout_url() then return end

	local resp_content_type = ngx.resp.get_headers()["content-type"]
	if resp_content_type then
		if string.match(resp_content_type, "^text/html") then
			ngx.arg[1] = ngx.arg[1] .. access:logout_html()
		end
		return
	end
	local ext = ngx.var.uri:match(".+%.(%w+)$")
	if (ext == nil or ext == "html" or ext == "htm") then
		ngx.arg[1] = ngx.arg[1] .. access:logout_html()
	end
end

function access.logout_html(self)
	return [[
		<style>
			.portal_logout {
			    z-index: 9999;
			    position: fixed;
			    padding: 5px;
			    background: rgb(241, 237, 237);
			    border-style: solid solid solid solid;
			    border-color: rgb(145, 145, 145);
			    top: 40px;
			    right: 0px;
			    border-width: 1px 0px 1px 1px;
			}
    			.portal_logout a {
			    text-decoration: none;
			    color: rgb(51, 51, 51);
			}
		</style>
		<div class="portal_logout">
			<a href="/~portal/logout">Logout</a>
		</div>
	]]
end

return {auth = access.auth, append_logout_button = access.append_logout_button }
