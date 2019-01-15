-- Grab pluginname from module name
local plugin_name = ({...})[1]:match("^kong%.plugins%.([^%.]+)")

-- load the base plugin object and create a subclass
local MyOAuth2Handler = require("kong.plugins.base_plugin"):extend()

local redis = require("kong.plugins.".. plugin_name .. ".lib.resty.redis")

-- constructor
function MyOAuth2Handler:new()
  MyOAuth2Handler.super.new(self, plugin_name)
  
  -- do initialization here, runs in the 'init_by_lua_block', before worker processes are forked

end

---[[ 在每个Nginx worker进程启动时执行。

function MyOAuth2Handler:init_work( plugin_conf )
	MyOAuth2Handler.super.init_work(self)
	-- body
end 
--]]


--[[
	在SSL握手的SSL证书服务阶段执行。
--]]

function MyOAuth2Handler:certificate( plugin_conf )
	MyOAuth2Handler.super.certificate(self)
	-- body
end




---[[
  --作为重写阶段处理器，在客户端接受到的每个请求时执行
  --注意，在这个阶段，服务和消费者都没有被标识，因此这个处理程序只有在插件被配置为全局插件时才会被执行!
  --:rewrite()

function MyOAuth2Handler:rewrite( plugin_conf )
	MyOAuth2Handler.super.rewrite(self)
	-- body
end

--]]

---[[ runs in the 'access_by_lua_block'
  -- 执行来自客户机的每个请求，并在请求被代理到上游服务之前执行。
function MyOAuth2Handler:access(plugin_conf)
	MyOAuth2Handler.super.access(self)
	-- your custom code here
	ngx.req.set_header("Hello-World", "this is on a request")

	-- 接收access_token,并处理一下
	local auth_token = kong.request.get_header('Authorization')
	local url_token = kong.request.get_query_arg(plugin_conf.token_name) --这里的token 需要配置，自定义参数名

	if auth_token ~= nil
	then
		access_token = string.gsub(auth_token,"Bearer ","")
	elseif url_token ~= nil

	then
		access_token = url_token
	end

	kong.log.inspect("recieve token: " .. access_token)
	-- 基础判断
	if access_token == nil
	then
	--   return kong.response.exit(200, { message = "Congratulation！you has pass check！" })
	-- else
	return kong.response.exit(401, { message = "Token is required！" })
	end

	--连接redis
	local rds = redis:new()
	rds:set_timeout(1000) -- 1 sec
	kong.log.inspect(plugin_conf.redis_host .. ":" .. plugin_conf.redis_port)
	local ok, err = rds:connect(plugin_conf.redis_host, plugin_conf.redis_port) --172.30.5.99 6379
	if not ok then
		return kong.response.exit(500, { message = "failed to connect:" .. err })
	end
    -- 到授权服务器验证access_token
	local check_token, cerr = rds:hmget(plugin_conf.redis_key_prefix .. access_token, "jwt_token", "expired_at")

	--关闭redis 链接
	local close, err = rds:close()
	if not close then
        kong.log.inspect(close)
        return kong.response.exit(500, { message = err })
    end

	if not check_token then
        --ngx.say("failed to get dog: ", err)
        return kong.response.exit(401, { message = "access_token is invalid: " .. cerr})
    end

    if check_token == ngx.null or check_token[1] == ngx.null then
        return kong.response.exit(401, { message = "access_token is invalid." })
    end

    -- if check_token[1] == ngx.null then
    --     return kong.response.exit(401, { message = "access_token is invalid." })
    -- end

    -- token验证过期
    -- refresh token验证过期，这个好像不需要
    -- 当重新获取授权后怎么处理，旧token是否有效？？

    -- 验证是否一致

    -- 缓存一下换取的jwt token
	local jwt_token = check_token[1] --根据hmget入参顺序确定索引
	
	-- 改写header，传递jwt token 到后端服务器
	ngx.req.set_header("Authorization", "Bearer " .. jwt_token)

	-- if plugin_conf.hide_credentials then
	--     ngx.req.clear_header("authorization")
	-- end
	-- return kong.response.exit(401, { message = "You don't have permission" })
end --]]

---[[ runs in the 'header_filter_by_lua_block'
	--当从上游服务接收到所有响应头字节时执行。
function MyOAuth2Handler:header_filter(plugin_conf)
  MyOAuth2Handler.super.access(self)
end --]]


---[[ runs in the 'header_filter_by_lua_block'
	--对从上游服务接收的响应体的每个块执行。
	--由于响应被流回客户机，因此它可能会超过缓冲区大小，并被一个块一个块地流。
	--因此，如果响应很大，可以多次调用此方法。有关更多细节，请参见lua-nginx-module文档。
--function MyOAuth2Handler:body_filter(plugin_conf)


--end 
--]]

function MyOAuth2Handler:log( plugin_conf )
	MyOAuth2Handler.super.log(self)
	-- body
end

-- set the plugin priority, which determines plugin execution order
MyOAuth2Handler.PRIORITY = 999

-- return our plugin object
return MyOAuth2Handler