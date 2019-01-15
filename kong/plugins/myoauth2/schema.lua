return {
  no_consumer = true, -- this plugin is available on APIs as well as on Consumers,
  fields = {
    -- Describe your plugin's configuration's schema here.
    token_name = {type = "string", required = true, default = "token"},
    redis_host = {type = "string", required = true, default = "127.0.0.1"},
    redis_port = {type = "number", required = true, default = 6379},
    redis_key_prefix = {type = "string", default = ""},
    hide_credentials = {type = "boolean", default = false}
  },
  self_check = function(schema, plugin_t, dao, is_updating)
    -- perform any custom verification
    return true
  end
}
