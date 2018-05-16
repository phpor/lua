nginx 配置文件示例：
```
  server {
        listen  80;
        server_name  gateway.phpor.net;
        default_type "text/html; charset=utf-8";
        set $auth_url "https://sso.phpor.net/check_pwd";
        resolver 8.8.8.8;
        lua_ssl_verify_depth 2;
        lua_ssl_trusted_certificate /etc/ssl/certs/ca-bundle.trust.crt;

        access_by_lua_block {
                require("ngx_lua"):auth()
        }
        body_filter_by_lua_block {
                require("ngx_lua"):append_logout_button()
        }
        location / {
                content_by_lua_block {
                        ngx.say("service list");
                }
        }

  }
  ```
