
local provider_reader_entity = copyPrototype("constant-combinator", "constant-combinator", "ltn-provider-reader")
provider_reader_entity.item_slot_count = 50 -- will be overwritten in final-fixes
provider_reader_entity.icon = "__LTN_Content_Reader__/graphics/icons/ltn-provider-reader.png"
provider_reader_entity.icon_size = 32

local provider_reader_item = copyPrototype("item", "constant-combinator", "ltn-provider-reader")
provider_reader_item.icon = "__LTN_Content_Reader__/graphics/icons/ltn-provider-reader.png"
provider_reader_item.icon_size = 32
provider_reader_item.order = provider_reader_item.order.."b" -- sort after constant_combinator

local provider_reader_recipe = copyPrototype("recipe", "constant-combinator", "ltn-provider-reader")


local requester_reader_entity = copyPrototype("constant-combinator", "constant-combinator", "ltn-requester-reader")
requester_reader_entity.item_slot_count = 50 -- will be overwritten in final-fixes
requester_reader_entity.icon = "__LTN_Content_Reader__/graphics/icons/ltn-requester-reader.png"
requester_reader_entity.icon_size = 32
requester_reader_entity.sprites = make_4way_animation_from_spritesheet(
  { layers =
    {
      {
        filename = "__LTN_Content_Reader__/graphics/entity/ltn-requester-reader.png",
        width = 58,
        height = 52,
        frame_count = 1,
        shift = util.by_pixel(0, 5),
        hr_version =
        {
          scale = 0.5,
          filename = "__LTN_Content_Reader__/graphics/entity/hr-ltn-requester-reader.png",
          width = 114,
          height = 102,
          frame_count = 1,
          shift = util.by_pixel(0, 5),
        },
      },
      {
        filename = "__base__/graphics/entity/combinator/constant-combinator-shadow.png",
        width = 50,
        height = 34,
        frame_count = 1,
        shift = util.by_pixel(9, 6),
        draw_as_shadow = true,
        hr_version =
        {
          scale = 0.5,
          filename = "__base__/graphics/entity/combinator/hr-constant-combinator-shadow.png",
          width = 98,
          height = 66,
          frame_count = 1,
          shift = util.by_pixel(8.5, 5.5),
          draw_as_shadow = true,
        },
      },
    },
  })


local requester_reader_item = copyPrototype("item", "constant-combinator", "ltn-requester-reader")
requester_reader_item.icon = "__LTN_Content_Reader__/graphics/icons/ltn-requester-reader.png"
requester_reader_item.icon_size = 32
requester_reader_item.order = requester_reader_item.order.."c" -- sort after constant_combinator

local requester_reader_recipe = copyPrototype("recipe", "constant-combinator", "ltn-requester-reader")


data:extend({
  provider_reader_entity,
  provider_reader_item,
  provider_reader_recipe,
  requester_reader_entity,
  requester_reader_item,
  requester_reader_recipe
})

if data.raw["technology"]["circuit-network"] then
  table.insert( data.raw["technology"]["circuit-network"].effects,
    {
        type = "unlock-recipe",
        recipe = "ltn-provider-reader"
    } )
  table.insert( data.raw["technology"]["circuit-network"].effects,
    {
        type = "unlock-recipe",
        recipe = "ltn-requester-reader"
    } )
end
