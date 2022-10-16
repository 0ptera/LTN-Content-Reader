data:extend({
  {
    type = "int-setting",
    name = "ltn_content_reader_update_interval",
    order = "aa",
    setting_type = "runtime-global",
    default_value = 120,
    minimum_value = 1,
    maximum_value = 216000, -- 1h
  },
  {
    type = "string-setting",
    name = "ltn_content_reader_default_surface",
    order = "ab",
    setting_type = "runtime-global",
    default_value = "all",
    allowed_values = {"all", "current"},
  },
})